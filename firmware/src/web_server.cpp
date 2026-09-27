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
    if (!LittleFS.begin(true)) {
        Serial.println("[WebServer] LittleFS Mount Failed");
    }

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
            request->send(200, "application/json", "{\"status\":\"ok\"}");
        },
        nullptr,
        [this](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total){
            resetTimeout();
            static uint8_t* buffer = nullptr;
            if (index == 0) {
                buffer = (uint8_t*)malloc(IMAGE_SIZE);
            }
            if (buffer && index + len <= IMAGE_SIZE) {
                memcpy(buffer + index, data, len);
            }
            if (index + len == total) {
                if (total == IMAGE_SIZE && buffer) {
                    _storage.savePhoto(buffer, total);
                }
                if (buffer) {
                    free(buffer);
                    buffer = nullptr;
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

    // Delete photo by ID
    _server->on("^\\/api\\/photos\\/([0-9]+)$", HTTP_DELETE, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        String idStr = request->pathArg(0);
        if (_storage.deletePhoto(idStr.toInt())) {
            request->send(200);
        } else {
            request->send(404);
        }
    });

    // Display photo immediately on e-ink screen
    _server->on("^\\/api\\/display\\/([0-9]+)$", HTTP_POST, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        String idStr = request->pathArg(0);
        uint8_t* buffer = (uint8_t*)malloc(IMAGE_SIZE);
        if (buffer && _storage.loadPhoto(idStr.toInt(), buffer, IMAGE_SIZE)) {
            _disp.showImage(buffer, IMAGE_SIZE);
            request->send(200);
        } else {
            request->send(500);
        }
        if (buffer) free(buffer);
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

    // Update settings
    _server->on("/api/settings", HTTP_POST, 
        [this](AsyncWebServerRequest *request){ /* Handled in body */ },
        nullptr,
        [this](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total){
            resetTimeout();
            if (index == 0) {
                JsonDocument doc;
                DeserializationError err = deserializeJson(doc, data, len);
                if (!err) {
                    _storage.saveSettings(doc);
                    request->send(200);
                } else {
                    request->send(400);
                }
            }
        });

    // Exit upload mode command
    _server->on("/api/exit", HTTP_POST, [this](AsyncWebServerRequest *request) {
        _exitFlag = true;
        request->send(200);
    });

    // Captive portal fallback redirect
    _server->onNotFound([this](AsyncWebServerRequest *request) {
        request->redirect("/");
    });
}
