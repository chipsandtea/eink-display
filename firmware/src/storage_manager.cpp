#include "storage_manager.h"
#include "config.h"

static const char* SETTINGS_FILE = "/config.json";
static const char* PHOTOS_DIR = "/p";

bool StorageManager::init() {
    if (!LittleFS.begin(true)) {
        Serial.println("[Storage] LittleFS Mount Failed");
        return false;
    }
    
    if (!LittleFS.exists(PHOTOS_DIR)) {
        LittleFS.mkdir(PHOTOS_DIR);
    }
    
    // Load current index
    JsonDocument doc;
    loadSettings(doc);
    _currentPhotoIndex = doc["currentIndex"] | 0;
    
    Serial.printf("[Storage] LittleFS Total: %u KB, Used: %u KB\n", 
                  LittleFS.totalBytes() / 1024, LittleFS.usedBytes() / 1024);
    Serial.printf("[Storage] Found %d photos\n", getPhotoCount());
    return true;
}

String StorageManager::getPhotoPath(int id) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%s/%04d.bin", PHOTOS_DIR, id);
    return String(buf);
}

int StorageManager::savePhoto(const uint8_t* data, size_t len) {
    if (len != IMAGE_SIZE) {
        Serial.printf("[Storage] Invalid image size: %u (expected %u)\n", len, IMAGE_SIZE);
        return -1;
    }

    if (getPhotoCount() >= MAX_PHOTOS) {
        Serial.println("[Storage] Photo limit reached");
        return -1;
    }

    // Find next available ID (1..MAX_PHOTOS)
    int nextId = 1;
    for (int i = 1; i <= MAX_PHOTOS + 1; i++) {
        if (!LittleFS.exists(getPhotoPath(i))) {
            nextId = i;
            break;
        }
    }

    String path = getPhotoPath(nextId);
    File f = LittleFS.open(path, "w");
    if (!f) {
        Serial.printf("[Storage] Failed to open %s for write\n", path.c_str());
        return -1;
    }

    size_t written = f.write(data, len);
    f.close();

    if (written != len) {
        Serial.println("[Storage] Incomplete write, deleting file");
        LittleFS.remove(path);
        return -1;
    }

    Serial.printf("[Storage] Saved photo ID %d to %s\n", nextId, path.c_str());
    return nextId;
}

bool StorageManager::loadPhoto(int id, uint8_t* buffer, size_t bufLen) {
    if (bufLen < IMAGE_SIZE) return false;
    String path = getPhotoPath(id);
    if (!LittleFS.exists(path)) return false;

    File f = LittleFS.open(path, "r");
    if (!f) return false;

    size_t readBytes = f.read(buffer, IMAGE_SIZE);
    f.close();
    return readBytes == IMAGE_SIZE;
}

bool StorageManager::deletePhoto(int id) {
    String path = getPhotoPath(id);
    if (LittleFS.exists(path)) {
        return LittleFS.remove(path);
    }
    return false;
}

int StorageManager::getPhotoCount() {
    int count = 0;
    File dir = LittleFS.open(PHOTOS_DIR);
    if (!dir || !dir.isDirectory()) return 0;

    File file = dir.openNextFile();
    while (file) {
        if (!file.isDirectory() && String(file.name()).endsWith(".bin")) {
            count++;
        }
        file = dir.openNextFile();
    }
    dir.close();
    return count;
}

bool StorageManager::getPhotoList(JsonArray& arr) {
    File dir = LittleFS.open(PHOTOS_DIR);
    if (!dir || !dir.isDirectory()) return false;

    File file = dir.openNextFile();
    while (file) {
        if (!file.isDirectory()) {
            String name = String(file.name());
            if (name.endsWith(".bin")) {
                int lastSlash = name.lastIndexOf('/');
                String base = (lastSlash >= 0) ? name.substring(lastSlash + 1) : name;
                int id = base.substring(0, base.length() - 4).toInt();
                if (id > 0) {
                    JsonObject obj = arr.add<JsonObject>();
                    obj["id"] = id;
                    obj["size"] = file.size();
                }
            }
        }
        file = dir.openNextFile();
    }
    dir.close();
    return true;
}

int StorageManager::getNextPhotoId() {
    int ids[MAX_PHOTOS];
    int idx = 0;
    
    File dir = LittleFS.open(PHOTOS_DIR);
    if (dir && dir.isDirectory()) {
        File file = dir.openNextFile();
        while (file && idx < MAX_PHOTOS) {
            String name = String(file.name());
            if (name.endsWith(".bin")) {
                int lastSlash = name.lastIndexOf('/');
                String base = (lastSlash >= 0) ? name.substring(lastSlash + 1) : name;
                int id = base.substring(0, base.length() - 4).toInt();
                if (id > 0) {
                    ids[idx++] = id;
                }
            }
            file = dir.openNextFile();
        }
        dir.close();
    }

    if (idx == 0) return -1;

    // Sort IDs ascending so sequential order is deterministic
    for (int i = 0; i < idx - 1; i++) {
        for (int j = i + 1; j < idx; j++) {
            if (ids[j] < ids[i]) {
                int tmp = ids[i];
                ids[i] = ids[j];
                ids[j] = tmp;
            }
        }
    }

    JsonDocument doc;
    loadSettings(doc);
    String cycleMode = doc["cycleMode"] | "sequential";

    int selectedId = -1;
    if (cycleMode == "random") {
        selectedId = ids[random(0, idx)];
    } else {
        // Sequential
        _currentPhotoIndex = (_currentPhotoIndex + 1) % idx;
        selectedId = ids[_currentPhotoIndex];
        doc["currentIndex"] = _currentPhotoIndex;
        saveSettings(doc);
    }

    return selectedId;
}

void StorageManager::loadSettings(JsonDocument& doc) {
    if (!LittleFS.exists(SETTINGS_FILE)) {
        doc["refreshHours"] = DEFAULT_REFRESH_HOURS;
        doc["cycleMode"] = "sequential";
        doc["currentIndex"] = 0;
        return;
    }

    File f = LittleFS.open(SETTINGS_FILE, "r");
    if (!f) return;
    deserializeJson(doc, f);
    f.close();
}

void StorageManager::saveSettings(const JsonDocument& doc) {
    File f = LittleFS.open(SETTINGS_FILE, "w");
    if (!f) return;
    serializeJson(doc, f);
    f.close();
}
