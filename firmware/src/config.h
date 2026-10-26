#pragma once

// ==========================================
// Pin Configurations (Seeed Studio XIAO ESP32S3)
// ==========================================
// XIAO ESP32S3 Pinout Mapping:
//   D0 = GPIO 1  (A0 / RTC_GPIO1)
//   D1 = GPIO 2  (A1 / RTC_GPIO2)
//   D2 = GPIO 3  (A2 / RTC_GPIO3)
//   D3 = GPIO 4  (A3 / RTC_GPIO4)
//   D4 = GPIO 5  (A4 / SDA / RTC_GPIO5)
//   D5 = GPIO 6  (A5 / SCL / RTC_GPIO6)
//   D6 = GPIO 43 (TX)
//   D7 = GPIO 44 (RX)
//   D8 = GPIO 7  (SCK)
//   D9 = GPIO 8  (MISO)
//   D10 = GPIO 9 (MOSI)

// Waveshare 4.2" e-Paper Module (G) via Hardware SPI
#define EINK_MOSI  9   // D10 -> DIN (Blue)
#define EINK_SCK   7   // D8  -> CLK (Yellow)
#define EINK_CS    2   // D1  -> CS  (Orange)
#define EINK_DC    3   // D2  -> DC  (Green)
#define EINK_RST   4   // D3  -> RST (White)
#define EINK_BUSY  5   // D4  -> BUSY (Purple)

// Battery & Wakeup
// Optional external 2:1 voltage divider (2x 100k..220k ohm) from BAT+ to D0 (GPIO 1)
#define BATTERY_ADC   1   // D0 (GPIO 1)
// Button to wake from deep sleep into Upload Mode (active LOW with internal RTC pullup)
#define UPLOAD_BUTTON 6   // D5 (GPIO 6 - RTC_GPIO6)

// ==========================================
// WiFi Access Point & Network
// ==========================================
#define AP_SSID "EinkFrame"
#define AP_PASS "" // Open network for instant captive portal
#define AP_IP   "192.168.4.1"

// ==========================================
// Storage & Image Specifications
// ==========================================
// 8MB Flash with ~6MB LittleFS partition comfortably holds ~180 30KB photos
#define MAX_PHOTOS            180     // Safe cap for 8MB flash (~5.4MB max usage)
#define DEFAULT_REFRESH_HOURS 4       // Refresh interval in hours
#define UPLOAD_TIMEOUT_MS     300000  // 5 minutes of idle before entering display sleep
#define IMAGE_SIZE            30000   // 400 * 300 * 2 bits / 8 bits = 30,000 bytes
#define DISPLAY_WIDTH         400
#define DISPLAY_HEIGHT        300
