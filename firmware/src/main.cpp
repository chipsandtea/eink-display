#include <Arduino.h>
#include "config.h"
#include "power.h"
#include "display_driver.h"
#include "sd_manager.h"
#include "web_server.h"

PowerManager pwr;
DisplayDriver disp;
SDManager sd;
WebServerManager webServer(sd, disp, pwr);

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
    int id = sd.getNextPhotoId();
    if (id >= 0) {
        uint8_t* buffer = (uint8_t*)malloc(IMAGE_SIZE);
        if (buffer) {
            if (sd.loadPhoto(id, buffer, IMAGE_SIZE)) {
                disp.showImage(buffer, IMAGE_SIZE);
            }
            free(buffer);
        }
    } else {
        disp.showStatusMessage("No Photos");
    }
}

void setup() {
    Serial.begin(115200);
    pwr.init();
    
    int batPct = pwr.batteryPercent();
    if (batPct < 10 && !pwr.isFirstBoot()) {
        pwr.enableDisplayPower();
        disp.init();
        disp.showBatteryWarning();
        disp.powerOff();
        pwr.disableDisplayPower();
        // Deep sleep indefinitely, waiting for charge/button
        pwr.enterDeepSleep(0);
        return;
    }

    if (pwr.isButtonWake() || pwr.isFirstBoot()) {
        pwr.enableDisplayPower();
        disp.init();
        if (!sd.init()) {
            disp.showStatusMessage("SD Init Failed");
        } else {
            runUploadMode();
            displayNextPhoto();
        }
        disp.powerOff();
        pwr.disableDisplayPower();
        
    } else if (pwr.isTimerWake()) {
        pwr.enableDisplayPower();
        disp.init();
        if (sd.init()) {
            displayNextPhoto();
        }
        disp.powerOff();
        pwr.disableDisplayPower();
    }

    // Get next wake time from config
    JsonDocument doc;
    sd.loadSettings(doc);
    uint32_t hours = doc["refreshHours"] | DEFAULT_REFRESH_HOURS;
    if (hours == 0) hours = DEFAULT_REFRESH_HOURS;
    
    pwr.enterDeepSleep(hours);
}

void loop() {
    // Everything handled in setup() or deep sleep
}
