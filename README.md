# DIY E-Ink Photo Frame (PicPak Style)

A battery-powered, self-contained e-ink photo frame built around the **Seeed Studio XIAO ESP32S3** and a **Waveshare 4.2" 4-Color (B/W/Y/R) e-Paper Module (G)**.

The XIAO ESP32S3 **is** the server—no Raspberry Pi, no cloud, and no external SD card module required. Connect to its WiFi hotspot from your phone, pick photos in your browser, and the browser automatically crops, sharpens, dithers to the 4-color e-ink palette, and uploads a compact 30KB binary directly to the XIAO's onboard LittleFS flash (~180 photo capacity).

## Key Features

- **Zero External Storage or Charger Needed**: Uses the XIAO ESP32S3's built-in 8MB Flash (~6MB LittleFS partition storing up to 180 photos) and built-in USB-C LiPo charging circuit.
- **Browser-Side Image Pipeline**: Client-side JavaScript (`firmware/data/app.js`) handles EXIF orientation, 4:3 center-cropping, 400×300 scaling, contrast/unsharp mask, Floyd-Steinberg 4-color dithering, and 2-bits-per-pixel packing.
- **Live Gallery Thumbnails**: The web UI renders real dithered 4-color previews of all stored photos directly from their 30KB binaries.
- **Ultra-Low Power Sleep**: Wakes on an RTC timer (1h–24h), updates the e-ink screen, hibernates the panel, and returns to deep sleep (~14µA on XIAO ESP32S3). Pressing the physical button wakes the frame immediately into Upload Mode with an on-screen WiFi QR code.
- **3D-Printable Enclosure**: Parametric OpenSCAD enclosure (`enclosure/frame.scad`) with a flush fold-out kickstand and 4x fridge magnet recesses.

## Wiring (Seeed Studio XIAO ESP32S3)

| Waveshare 4.2" (G) Pin | XIAO ESP32S3 Pin | GPIO | Wire Color (Typical) |
|------------------------|------------------|------|----------------------|
| **VCC**                | **3V3**          | —    | Red                  |
| **GND**                | **GND**          | —    | Black                |
| **DIN** (MOSI)         | **D10**          | `9`  | Blue                 |
| **CLK** (SCK)          | **D8**           | `7`  | Yellow               |
| **CS**                 | **D1**           | `2`  | Orange               |
| **DC**                 | **D2**           | `3`  | Green                |
| **RST**                | **D3**           | `4`  | White                |
| **BUSY**               | **D4**           | `5`  | Purple               |

**Peripherals:**
- **Upload Wake Button**: Momentary button between **D5 (`GPIO 6`)** and **GND** (uses internal RTC pull-up; no external resistor needed).
- **LiPo Battery**: 3.7V LiPo soldered to the **BAT+ / BAT-** pads on the bottom of the XIAO ESP32S3.
- **Battery Voltage Sense (Optional)**: Two equal resistors (e.g., 2× 220kΩ) forming a 2:1 divider from **BAT+** to **D0 (`GPIO 1`)** and **GND**. (If omitted, firmware safely defaults to reporting 100%).

## Flashing Firmware & Web App (PlatformIO)

```bash
cd firmware

# 1. Build and upload the LittleFS web app (index.html, style.css, app.js)
pio run --target uploadfs

# 2. Build and upload the ESP32-S3 firmware
pio run --target upload
```

## Project Structure

- [`firmware/`](file:///d:/antigravity/eink-display/firmware/platformio.ini) — PlatformIO C++ firmware for Seeed Studio XIAO ESP32S3
  - [`src/config.h`](file:///d:/antigravity/eink-display/firmware/src/config.h) — XIAO ESP32S3 pin definitions and constants
  - [`src/main.cpp`](file:///d:/antigravity/eink-display/firmware/src/main.cpp) — Boot wake state machine (Display Mode vs. Upload Mode)
  - [`src/display_driver.cpp`](file:///d:/antigravity/eink-display/firmware/src/display_driver.cpp) — GxEPD2 4-color driver & WiFi QR code screen
  - [`src/storage_manager.cpp`](file:///d:/antigravity/eink-display/firmware/src/storage_manager.cpp) — LittleFS `/p/NNNN.bin` photo storage & `/config.json` settings
  - [`src/web_server.cpp`](file:///d:/antigravity/eink-display/firmware/src/web_server.cpp) — Captive portal AP, REST API, and LittleFS static server
  - [`src/power.cpp`](file:///d:/antigravity/eink-display/firmware/src/power.cpp) — Deep sleep, RTC button wakeup, and calibrated ADC battery reading
  - [`data/`](file:///d:/antigravity/eink-display/firmware/data/index.html) — Self-contained web app (`index.html`, `style.css`, `app.js`)
- [`enclosure/frame.scad`](file:///d:/antigravity/eink-display/enclosure/frame.scad) — Parametric 3D-printable Polaroid-style frame with kickstand & magnet mounts
- [`IMPLEMENTATION_PLAN.md`](file:///d:/antigravity/eink-display/IMPLEMENTATION_PLAN.md) — Full hardware BOM, architecture diagrams, and verification plan
