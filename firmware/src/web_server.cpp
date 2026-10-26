#include "web_server.h"
#include "config.h"
#include <LittleFS.h>
#include <ESPmDNS.h>

WebServerManager::WebServerManager(StorageManager& storage, DisplayDriver& disp, PowerManager& pwr) 
    : _storage(storage), _disp(disp), _pwr(pwr) {
    _server = new AsyncWebServer(80);
    _dns = new DNSServer();
}

void WebServerManager::start() {
    WiFi.mode(WIFI_AP);
    WiFi.softAP(AP_SSID, AP_PASS);
    IPAddress IP = WiFi.softAPIP();
    
    // Captive portal: redirect all DNS requests to frame's IP
    _dns->start(53, "*", IP);
    MDNS.begin("einkframe");
    
    setupRoutes();
    
    _server->begin();
    resetTimeout();
    Serial.printf("[WebServer] AP started. IP: %s\n", IP.toString().c_str());
}

void WebServerManager::stop() {
    if (_uploadBuffer) {
        free(_uploadBuffer);
        _uploadBuffer = nullptr;
    }
    if (_server) _server->end();
    if (_dns) _dns->stop();
    WiFi.softAPdisconnect(true);
    MDNS.end();
}

bool WebServerManager::shouldExit() {
    if (_exitFlag) return true;
    if (millis() - _lastActivity > UPLOAD_TIMEOUT_MS) return true;
    return false;
}

void WebServerManager::resetTimeout() {
    _lastActivity = millis();
}

void WebServerManager::loop() {
    if (_dns) _dns->processNextRequest();

    // Handle display refresh outside of the AsyncTCP task to prevent watchdog timeouts
    if (_pendingDisplayId > 0) {
        int idToDisplay = _pendingDisplayId;
        _pendingDisplayId = -1;
        uint8_t* buffer = (uint8_t*)malloc(IMAGE_SIZE);
        if (buffer) {
            if (_storage.loadPhoto(idToDisplay, buffer, IMAGE_SIZE)) {
                _disp.showImage(buffer, IMAGE_SIZE);
            }
            free(buffer);
        }
        resetTimeout();
    }
}

void WebServerManager::setupRoutes() {
    // Serve HTML
    _server->on("/", HTTP_GET, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        if (LittleFS.exists("/index.html.gz")) {
            AsyncWebServerResponse *response = request->beginResponse(LittleFS, "/index.html.gz", "text/html");
            response->addHeader("Content-Encoding", "gzip");
            request->send(response);
        } else {
            request->send(LittleFS, "/index.html", "text/html");
        }
    });

    // Serve CSS
    _server->on("/style.css", HTTP_GET, [this](AsyncWebServerRequest *request) {
        request->send(LittleFS, "/style.css", "text/css");
    });
    
    // Serve JS
    _server->on("/app.js", HTTP_GET, [this](AsyncWebServerRequest *request) {
        request->send(LittleFS, "/app.js", "application/javascript");
    });

    // Upload raw 30KB processed binary image
    _server->on("/api/upload", HTTP_POST, 
        [this](AsyncWebServerRequest *request){
            if (_uploadSuccess) {
                request->send(200, "application/json", "{\"status\":\"ok\"}");
            } else {
                request->send(400, "application/json", "{\"error\":\"Upload failed or storage full\"}");
            }
        },
        nullptr,
        [this](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total){
            resetTimeout();
            if (index == 0) {
                _uploadSuccess = false;
                if (_uploadBuffer) {
                    free(_uploadBuffer);
                    _uploadBuffer = nullptr;
                }
                if (total == IMAGE_SIZE) {
                    _uploadBuffer = (uint8_t*)malloc(IMAGE_SIZE);
                }
            }
            if (_uploadBuffer && index + len <= IMAGE_SIZE) {
                memcpy(_uploadBuffer + index, data, len);
            }
            if (index + len == total) {
                if (total == IMAGE_SIZE && _uploadBuffer) {
                    int savedId = _storage.savePhoto(_uploadBuffer, total);
                    _uploadSuccess = (savedId > 0);
                }
                if (_uploadBuffer) {
                    free(_uploadBuffer);
                    _uploadBuffer = nullptr;
                }
            }
        });

    // List all photos
    _server->on("/api/photos", HTTP_GET, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        JsonDocument doc;
        JsonArray arr = doc["photos"].to<JsonArray>();
        _storage.getPhotoList(arr);
        String response;
        serializeJson(doc, response);
        request->send(200, "application/json", response);
    });

    // Serve raw 30KB photo binary for browser canvas thumbnail preview
    _server->on("^\\/api\\/photos\\/([0-9]+)\\.bin$", HTTP_GET, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        int id = request->pathArg(0).toInt();
        String path = _storage.getPhotoPath(id);
        if (LittleFS.exists(path)) {
            request->send(LittleFS, path, "application/octet-stream");
        } else {
            request->send(404);
        }
    });

    // Delete photo by ID
    _server->on("^\\/api\\/photos\\/([0-9]+)$", HTTP_DELETE, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        String idStr = request->pathArg(0);
        if (_storage.deletePhoto(idStr.toInt())) {
            request->send(200, "application/json", "{\"status\":\"deleted\"}");
        } else {
            request->send(404, "application/json", "{\"error\":\"Not found\"}");
        }
    });

    // Queue photo for immediate display on e-ink screen (non-blocking)
    _server->on("^\\/api\\/display\\/([0-9]+)$", HTTP_POST, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        int id = request->pathArg(0).toInt();
        if (LittleFS.exists(_storage.getPhotoPath(id))) {
            _pendingDisplayId = id;
            request->send(202, "application/json", "{\"status\":\"displaying\"}");
        } else {
            request->send(404, "application/json", "{\"error\":\"Not found\"}");
        }
    });

    // Status endpoint (battery %, photo count, refresh interval)
    _server->on("/api/status", HTTP_GET, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        JsonDocument doc;
        doc["battery"] = _pwr.batteryPercent();
        doc["photoCount"] = _storage.getPhotoCount();
        doc["maxPhotos"] = MAX_PHOTOS;
        
        JsonDocument settings;
        _storage.loadSettings(settings);
        doc["refreshHours"] = settings["refreshHours"] | DEFAULT_REFRESH_HOURS;
        doc["cycleMode"] = settings["cycleMode"] | "sequential";
        
        String response;
        serializeJson(doc, response);
        request->send(200, "application/json", response);
    });

    // Update settings (merges with existing settings to preserve currentIndex)
    _server->on("/api/settings", HTTP_POST, 
        [this](AsyncWebServerRequest *request){ /* Handled in body */ },
        nullptr,
        [this](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total){
            resetTimeout();
            if (index == 0) {
                JsonDocument incoming;
                DeserializationError err = deserializeJson(incoming, data, len);
                if (!err) {
                    JsonDocument settings;
                    _storage.loadSettings(settings);
                    if (incoming["refreshHours"].is<int>()) {
                        settings["refreshHours"] = incoming["refreshHours"].as<int>();
                    }
                    if (incoming["cycleMode"].is<const char*>()) {
                        settings["cycleMode"] = incoming["cycleMode"].as<String>();
                    }
                    _storage.saveSettings(settings);
                    request->send(200, "application/json", "{\"status\":\"saved\"}");
                } else {
                    request->send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
                }
            }
        });

    // Exit upload mode command
    _server->on("/api/exit", HTTP_POST, [this](AsyncWebServerRequest *request) {
        _exitFlag = true;
        request->send(200, "application/json", "{\"status\":\"exiting\"}");
    });

    // Captive portal fallback redirect to explicit AP IP
    _server->onNotFound([this](AsyncWebServerRequest *request) {
        request->redirect(String("http://") + AP_IP + "/");
    });
}
