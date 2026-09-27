#include "web_server.h"
#include "config.h"
#include <LittleFS.h>
#include <ESPmDNS.h>

WebServerManager::WebServerManager(SDManager& sd, DisplayDriver& disp, PowerManager& pwr) 
    : _sd(sd), _disp(disp), _pwr(pwr) {
    _server = new AsyncWebServer(80);
    _dns = new DNSServer();
}

void WebServerManager::start() {
    if (!LittleFS.begin(true)) {
        Serial.println("LittleFS Mount Failed");
    }

    WiFi.mode(WIFI_AP);
    WiFi.softAP(AP_SSID, AP_PASS);
    IPAddress IP = WiFi.softAPIP();
    
    _dns->start(53, "*", IP);
    MDNS.begin("einkframe");
    
    setupRoutes();
    
    _server->begin();
    resetTimeout();
}

void WebServerManager::stop() {
    _server->end();
    _dns->stop();
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
    _dns->processNextRequest();
}

void WebServerManager::setupRoutes() {
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

    _server->on("/style.css", HTTP_GET, [this](AsyncWebServerRequest *request) {
        request->send(LittleFS, "/style.css", "text/css");
    });
    
    _server->on("/app.js", HTTP_GET, [this](AsyncWebServerRequest *request) {
        request->send(LittleFS, "/app.js", "application/javascript");
    });

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
                if (total == IMAGE_SIZE) {
                    int id = _sd.savePhoto(buffer, total);
                    // could send better response here if handling allows
                }
                if (buffer) {
                    free(buffer);
                    buffer = nullptr;
                }
            }
        });

    _server->on("/api/photos", HTTP_GET, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        JsonDocument doc;
        JsonArray arr = doc["photos"].to<JsonArray>();
        _sd.getPhotoList(arr);
        String response;
        serializeJson(doc, response);
        request->send(200, "application/json", response);
    });

    _server->on("^\\/api\\/photos\\/([0-9]+)$", HTTP_DELETE, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        String idStr = request->pathArg(0);
        if (_sd.deletePhoto(idStr.toInt())) {
            request->send(200);
        } else {
            request->send(404);
        }
    });

    _server->on("^\\/api\\/display\\/([0-9]+)$", HTTP_POST, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        String idStr = request->pathArg(0);
        uint8_t* buffer = (uint8_t*)malloc(IMAGE_SIZE);
        if (buffer && _sd.loadPhoto(idStr.toInt(), buffer, IMAGE_SIZE)) {
            _disp.showImage(buffer, IMAGE_SIZE);
            request->send(200);
        } else {
            request->send(500);
        }
        if (buffer) free(buffer);
    });

    _server->on("/api/status", HTTP_GET, [this](AsyncWebServerRequest *request) {
        resetTimeout();
        JsonDocument doc;
        doc["battery"] = _pwr.batteryPercent();
        doc["photoCount"] = _sd.getPhotoCount();
        doc["maxPhotos"] = MAX_PHOTOS;
        
        JsonDocument settings;
        _sd.loadSettings(settings);
        doc["refreshHours"] = settings["refreshHours"];
        doc["cycleMode"] = settings["cycleMode"];
        
        String response;
        serializeJson(doc, response);
        request->send(200, "application/json", response);
    });

    // Handle Settings (Body parsing via callback)
    _server->on("/api/settings", HTTP_POST, 
        [this](AsyncWebServerRequest *request){ /* Handled in body */ },
        nullptr,
        [this](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total){
            resetTimeout();
            if (index == 0) {
                JsonDocument doc;
                DeserializationError err = deserializeJson(doc, data, len);
                if (!err) {
                    _sd.saveSettings(doc);
                    request->send(200);
                } else {
                    request->send(400);
                }
            }
        });

    _server->on("/api/exit", HTTP_POST, [this](AsyncWebServerRequest *request) {
        _exitFlag = true;
        request->send(200);
    });

    _server->onNotFound([this](AsyncWebServerRequest *request) {
        request->redirect("/");
    });
}
