#pragma once

#include <Arduino.h>
#include <LittleFS.h>
#include <ArduinoJson.h>

class StorageManager {
public:
    bool init();
    int savePhoto(const uint8_t* data, size_t len);
    bool loadPhoto(int id, uint8_t* buffer, size_t bufLen);
    bool deletePhoto(int id);
    int getNextPhotoId();
    int getPhotoCount();
    bool getPhotoList(JsonArray& arr);
    void loadSettings(JsonDocument& doc);
    void saveSettings(const JsonDocument& doc);

private:
    String getPhotoFilename(int id);
    int _currentPhotoIndex = 0;
};
