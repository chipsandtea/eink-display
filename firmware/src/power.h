#pragma once
#include <Arduino.h>

class PowerManager {
public:
    void init();
    float readBatteryVoltage();
    int batteryPercent();
    void prepareSleep();
    void enterDeepSleep(uint32_t hours);
    bool isButtonWake();
    bool isTimerWake();
    bool isFirstBoot();
};
