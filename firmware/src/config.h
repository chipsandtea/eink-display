#pragma once

// ==========================================
// Pin Configurations (FireBeetle 2 ESP32-E)
// ==========================================

// Waveshare 4.2" e-Paper Module (G) via VSPI
#define EINK_MOSI 23   // DIN (Blue)
#define EINK_SCK  18   // CLK (Yellow)
#define EINK_CS    5   // CS  (Orange)
#define EINK_DC   17   // DC  (Green)
#define EINK_RST  16   // RST (White)
#define EINK_BUSY  4   // BUSY (Purple)

// Battery & Wakeup
// On FireBeetle 2, the built-in battery voltage divider is wired to A0 (GPIO 36 / SENSOR_VP)
#define BATTERY_ADC   36
// Button to wake from deep sleep into Upload Mode (active LOW with internal pullup)
#define UPLOAD_BUTTON 27 

// ==========================================
// WiFi Access Point & Network
// ==========================================
#define AP_SSID "EinkFrame"
#define AP_PASS "" // Open network for instant captive portal
#define AP_IP   "192.168.4.1"

// ==========================================
// Storage & Image Specifications
// ==========================================
#define MAX_PHOTOS            400     // 400 * 30KB = 12MB in LittleFS
#define DEFAULT_REFRESH_HOURS 4       // Refresh interval in hours
#define UPLOAD_TIMEOUT_MS     300000  // 5 minutes of idle before entering display sleep
#define IMAGE_SIZE            30000   // 400 * 300 * 2 bits / 8 bits = 30,000 bytes
#define DISPLAY_WIDTH         400
#define DISPLAY_HEIGHT        300
