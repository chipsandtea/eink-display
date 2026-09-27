#pragma once
#include <Arduino.h>
#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <DNSServer.h>
#include "storage_manager.h"
#include "display_driver.h"
#include "power.h"

class WebServerManager {
public:
    WebServerManager(StorageManager& storage, DisplayDriver& disp, PowerManager& pwr);
    void start();
    void stop();
    bool shouldExit();
    void resetTimeout();
    void loop();

private:
    StorageManager& _storage;
    DisplayDriver& _disp;
    PowerManager& _pwr;
    bool _exitFlag = false;
    uint32_t _lastActivity = 0;
    
    AsyncWebServer* _server = nullptr;
    DNSServer* _dns = nullptr;
    
    void setupRoutes();
};
