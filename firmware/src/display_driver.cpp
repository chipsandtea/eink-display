#include "display_driver.h"
#include "config.h"

bool DisplayDriver::init() {
    if (!_display) {
        _fspi = new SPIClass(VSPI);
        _fspi->begin(EINK_SCK, -1, EINK_MOSI, EINK_CS);

        _display = new GxEPD2_4C<GxEPD2_420c_GDEY0420F51, GxEPD2_420c_GDEY0420F51::HEIGHT>(
            GxEPD2_420c_GDEY0420F51(EINK_CS, EINK_DC, EINK_RST, EINK_BUSY)
        );
        _display->epd2.selectSPI(*_fspi, SPISettings(4000000, MSBFIRST, SPI_MODE0));
    }
    _display->init(115200, true, 2, false);
    return true;
}

void DisplayDriver::showImage(const uint8_t* data, size_t len) {
    if (!_display || len != IMAGE_SIZE) return;
    
    _display->setFullWindow();
    _display->firstPage();
    do {
        _display->fillScreen(GxEPD_WHITE);
        int byteIdx = 0;
        for (int y = 0; y < DISPLAY_HEIGHT; y++) {
            for (int x = 0; x < DISPLAY_WIDTH; x += 4) {
                uint8_t b = data[byteIdx++];
                for (int p = 0; p < 4; p++) {
                    uint8_t px = (b >> (6 - p * 2)) & 0x03;
                    uint16_t color = GxEPD_WHITE;
                    if (px == 0x00) color = GxEPD_BLACK;
                    else if (px == 0x01) color = GxEPD_WHITE;
                    else if (px == 0x02) color = GxEPD_YELLOW;
                    else if (px == 0x03) color = GxEPD_RED;
                    _display->drawPixel(x + p, y, color);
                }
            }
        }
    } while (_display->nextPage());
}

void DisplayDriver::showUploadModeScreen(const char* ssid, const char* ip) {
    if (!_display) return;

    QRCode qrcode;
    uint8_t qrcodeData[qrcode_getBufferSize(3)];
    
    // Standard WiFi connection QR code string
    String qrText = "WIFI:T:nopass;S:" + String(ssid) + ";P:;H:false;;";
    qrcode_initText(&qrcode, qrcodeData, 3, 0, qrText.c_str());

    _display->setFullWindow();
    _display->setFont(&FreeSansBold12pt7b);
    _display->setTextColor(GxEPD_BLACK);
    _display->firstPage();
    do {
        _display->fillScreen(GxEPD_WHITE);
        
        // Header
        _display->setCursor(20, 45);
        _display->print("Upload Mode");
        
        // Network instructions
        _display->setCursor(20, 95);
        _display->print("Connect to:");
        _display->setCursor(20, 125);
        _display->print(ssid);
        
        _display->setCursor(20, 175);
        _display->print("Or visit:");
        _display->setCursor(20, 205);
        _display->print(ip);

        _display->setCursor(20, 260);
        _display->print("Scan QR to join ->");

        // Draw QR code on right half
        int scale = 4;
        int xOffset = 260;
        int yOffset = 70;
        
        for (uint8_t y = 0; y < qrcode.size; y++) {
            for (uint8_t x = 0; x < qrcode.size; x++) {
                if (qrcode_getModule(&qrcode, x, y)) {
                    _display->fillRect(xOffset + x * scale, yOffset + y * scale, scale, scale, GxEPD_BLACK);
                }
            }
        }
    } while (_display->nextPage());
}

void DisplayDriver::showStatusMessage(const char* msg) {
    if (!_display) return;
    _display->setFullWindow();
    _display->setFont(&FreeSansBold12pt7b);
    _display->setTextColor(GxEPD_BLACK);
    _display->firstPage();
    do {
        _display->fillScreen(GxEPD_WHITE);
        _display->setCursor(40, 150);
        _display->print(msg);
    } while (_display->nextPage());
}

void DisplayDriver::showBatteryWarning() {
    showStatusMessage("Battery Low!\nPlease Charge Device.");
}

void DisplayDriver::powerOff() {
    if (_display) {
        _display->hibernate();
    }
}
