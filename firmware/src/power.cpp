#include "power.h"
#include "config.h"

void PowerManager::init() {
    pinMode(UPLOAD_BUTTON, INPUT_PULLUP);
    analogReadResolution(12); // 12-bit ADC (0..4095)
}

float PowerManager::readBatteryVoltage() {
    long sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += analogRead(BATTERY_ADC);
        delay(5);
    }
    float avgAdc = sum / 10.0f;
    // FireBeetle 2 onboard divider: 2:1 (reads half the battery voltage)
    // 3.3V reference / 4095 * 2.0 = approx voltage
    float voltage = (avgAdc / 4095.0f) * 3.3f * 2.0f;
    return voltage;
}

int PowerManager::batteryPercent() {
    float v = readBatteryVoltage();
    if (v >= 4.20f) return 100;
    if (v >= 3.85f) return 75 + (int)((v - 3.85f) / 0.35f * 25.0f);
    if (v >= 3.70f) return 50 + (int)((v - 3.70f) / 0.15f * 25.0f);
    if (v >= 3.40f) return 15 + (int)((v - 3.40f) / 0.30f * 35.0f);
    if (v >= 3.20f) return (int)((v - 3.20f) / 0.20f * 15.0f);
    return 0;
}

void PowerManager::prepareSleep() {
    // Set SPI lines to high impedance to prevent parasitic leakage current
    pinMode(EINK_MOSI, INPUT);
    pinMode(EINK_SCK, INPUT);
    pinMode(EINK_CS, INPUT);
    pinMode(EINK_DC, INPUT);
    pinMode(EINK_RST, INPUT);
}

void PowerManager::enterDeepSleep(uint32_t hours) {
    prepareSleep();
    
    if (hours > 0) {
        uint64_t sleepTimeUs = (uint64_t)hours * 3600ULL * 1000000ULL;
        esp_sleep_enable_timer_wakeup(sleepTimeUs);
    }
    
    // Enable external wakeup via button press (LOW)
    esp_sleep_enable_ext0_wakeup((gpio_num_t)UPLOAD_BUTTON, 0);
    
    Serial.printf("[Power] Entering deep sleep for %u hour(s)...\n", hours);
    Serial.flush();
    esp_deep_sleep_start();
}

bool PowerManager::isButtonWake() {
    return esp_sleep_get_wakeup_cause() == ESP_SLEEP_WAKEUP_EXT0;
}

bool PowerManager::isTimerWake() {
    return esp_sleep_get_wakeup_cause() == ESP_SLEEP_WAKEUP_TIMER;
}

bool PowerManager::isFirstBoot() {
    return esp_sleep_get_wakeup_cause() == ESP_SLEEP_WAKEUP_UNDEFINED;
}
