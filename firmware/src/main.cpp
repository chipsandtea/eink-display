#include <Arduino.h>
#include "config.h"
#include "power.h"
#include "display_driver.h"
#include "storage_manager.h"
#include "web_server.h"

PowerManager pwr;
DisplayDriver disp;
StorageManager storage;
WebServerManager webServer(storage, disp, pwr);

void runUploadMode() {
    disp.showUploadModeScreen(AP_SSID, AP_IP);
    webServer.start();
    
    while (!webServer.shouldExit()) {
        webServer.loop();
        delay(10);
    }
    
    webServer.stop();
}

void displayNextPhoto() {
    int id = storage.getNextPhotoId();
    if (id >= 0) {
        uint8_t* buffer = (uint8_t*)malloc(IMAGE_SIZE);
        if (buffer) {
            if (storage.loadPhoto(id, buffer, IMAGE_SIZE)) {
                disp.showImage(buffer, IMAGE_SIZE);
            }
            free(buffer);
        }
    } else {
        disp.showStatusMessage("No Photos Yet\nPress Button to Upload");
    }
}

void setup() {
    Serial.begin(115200);
    pwr.init();
    
    int batPct = pwr.batteryPercent();
    if (batPct < 10 && !pwr.isFirstBoot()) {
        disp.init();
        disp.showBatteryWarning();
        disp.powerOff();
        // Deep sleep indefinitely until button wake / recharge
        pwr.enterDeepSleep(0);
        return;
    }

    if (pwr.isButtonWake() || pwr.isFirstBoot()) {
        disp.init();
        if (!storage.init()) {
            disp.showStatusMessage("Storage Mount Failed");
        } else {
            runUploadMode();
            displayNextPhoto();
        }
        disp.powerOff();
        
    } else if (pwr.isTimerWake()) {
        disp.init();
        if (storage.init()) {
            displayNextPhoto();
        }
        disp.powerOff();
    }

    // Get next wake time from config
    JsonDocument doc;
    storage.loadSettings(doc);
    uint32_t hours = doc["refreshHours"] | DEFAULT_REFRESH_HOURS;
    if (hours == 0) hours = DEFAULT_REFRESH_HOURS;
    
    pwr.enterDeepSleep(hours);
}

void loop() {
    // Everything handled in setup() and deep sleep
}
