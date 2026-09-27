#pragma once

#include <Arduino.h>
#include <SPI.h>
#include <GxEPD2_4C.h>
#include <epd4c/GxEPD2_420c_GDEY0420F51.h>
#include <Fonts/FreeSansBold12pt7b.h>
#include "qrcode.h"

class DisplayDriver {
public:
    bool init();
    void showImage(const uint8_t* data, size_t len);
    void showUploadModeScreen(const char* ssid, const char* ip);
    void showStatusMessage(const char* msg);
    void showBatteryWarning();
    void powerOff();
private:
    SPIClass* _fspi = nullptr;
    GxEPD2_4C<GxEPD2_420c_GDEY0420F51, GxEPD2_420c_GDEY0420F51::HEIGHT>* _display = nullptr;
};
