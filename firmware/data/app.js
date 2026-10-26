const DISPLAY_WIDTH = 400;
const DISPLAY_HEIGHT = 300;

// 4-color palette matching GxEPD2 2bpp packing:
// 00 = Black, 01 = White, 10 = Yellow, 11 = Red
const PALETTE = [
    { r: 0, g: 0, b: 0, val: 0 },         // Black: 00
    { r: 255, g: 255, b: 255, val: 1 },   // White: 01
    { r: 255, g: 230, b: 0, val: 2 },     // Yellow: 10
    { r: 200, g: 0, b: 0, val: 3 }        // Red: 11
];

function colorDistanceSq(c1, c2) {
    const dr = c1.r - c2.r;
    const dg = c1.g - c2.g;
    const db = c1.b - c2.b;
    return dr * dr + dg * dg + db * db;
}

function findNearestColor(r, g, b) {
    let minDistance = Infinity;
    let bestColor = PALETTE[0];
    const c = { r, g, b };
    for (const p of PALETTE) {
        const d = colorDistanceSq(c, p);
        if (d < minDistance) {
            minDistance = d;
            bestColor = p;
        }
    }
    return bestColor;
}

// Minimal EXIF orientation reader
async function getExifOrientation(file) {
    return new Promise((resolve) => {
        const reader = new FileReader();
        reader.onload = function (e) {
            const view = new DataView(e.target.result);
            if (view.byteLength < 2 || view.getUint16(0, false) !== 0xFFD8) return resolve(-2);
            const length = view.byteLength;
            let offset = 2;
            while (offset < length - 2) {
                const marker = view.getUint16(offset, false);
                offset += 2;
                if (marker === 0xFFE1) {
                    if (offset + 10 >= length) return resolve(-1);
                    if (view.getUint32(offset + 2, false) !== 0x45786966) return resolve(-1);
                    const tiffOffset = offset + 8;
                    const little = view.getUint16(tiffOffset, false) === 0x4949;
                    const ifdOffset = tiffOffset + view.getUint32(tiffOffset + 4, little);
                    if (ifdOffset + 2 >= length) return resolve(-1);
                    const tags = view.getUint16(ifdOffset, little);
                    for (let i = 0; i < tags; i++) {
                        const tagOffset = ifdOffset + 2 + (i * 12);
                        if (tagOffset + 10 >= length) break;
                        if (view.getUint16(tagOffset, little) === 0x0112) {
                            return resolve(view.getUint16(tagOffset + 8, little));
                        }
                    }
                    return resolve(-1);
                } else if ((marker & 0xFF00) !== 0xFF00) {
                    break;
                } else {
                    offset += view.getUint16(offset, false);
                }
            }
            return resolve(-1);
        };
        reader.readAsArrayBuffer(file.slice(0, 65536));
    });
}

async function loadImage(file) {
    return new Promise((resolve, reject) => {
        const url = URL.createObjectURL(file);
        const img = new Image();
        img.onload = () => {
            URL.revokeObjectURL(url);
            resolve(img);
        };
        img.onerror = (err) => {
            URL.revokeObjectURL(url);
            reject(err);
        };
        img.src = url;
    });
}

// 1. Image Processor
async function processImage(file) {
    const img = await loadImage(file);
    // Modern browsers usually apply EXIF rotation automatically on <img> drawImage,
    // so only manually rotate if imageOrientation style is not supported.
    const supportsAutoExif = 'imageOrientation' in document.createElement('div').style;
    const orientation = supportsAutoExif ? 1 : await getExifOrientation(file);

    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d', { willReadFrequently: true });

    const width = img.width;
    const height = img.height;

    if (orientation >= 5 && orientation <= 8) {
        canvas.width = height;
        canvas.height = width;
    } else {
        canvas.width = width;
        canvas.height = height;
    }

    ctx.save();
    switch (orientation) {
        case 2: ctx.transform(-1, 0, 0, 1, width, 0); break;
        case 3: ctx.transform(-1, 0, 0, -1, width, height); break;
        case 4: ctx.transform(1, 0, 0, -1, 0, height); break;
        case 5: ctx.transform(0, 1, 1, 0, 0, 0); break;
        case 6: ctx.transform(0, 1, -1, 0, height, 0); break;
        case 7: ctx.transform(0, -1, -1, 0, height, width); break;
        case 8: ctx.transform(0, -1, 1, 0, 0, width); break;
        default: break;
    }
    ctx.drawImage(img, 0, 0);
    ctx.restore();

    // Center crop to 4:3
    const cw = canvas.width;
    const ch = canvas.height;
    const targetAspect = DISPLAY_WIDTH / DISPLAY_HEIGHT;
    const currentAspect = cw / ch;

    let sx = 0, sy = 0, sw = cw, sh = ch;
    if (currentAspect > targetAspect) {
        sw = ch * targetAspect;
        sx = (cw - sw) / 2;
    } else {
        sh = cw / targetAspect;
        sy = (ch - sh) / 2;
    }

    const resizedCanvas = document.createElement('canvas');
    resizedCanvas.width = DISPLAY_WIDTH;
    resizedCanvas.height = DISPLAY_HEIGHT;
    const rctx = resizedCanvas.getContext('2d', { willReadFrequently: true });
    rctx.drawImage(canvas, sx, sy, sw, sh, 0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT);

    // Work on a copy of the image data so resizedCanvas stays clean as the original preview
    const imageData = rctx.getImageData(0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT);
    const data = new Uint8ClampedArray(imageData.data);

    const contrast = 1.18;
    const intercept = 128 * (1 - contrast);

    for (let i = 0; i < data.length; i += 4) {
        data[i] = data[i] * contrast + intercept;
        data[i + 1] = data[i + 1] * contrast + intercept;
        data[i + 2] = data[i + 2] * contrast + intercept;
    }

    // Gentle sharpening convolution
    const w = DISPLAY_WIDTH;
    const h = DISPLAY_HEIGHT;
    const temp = new Uint8ClampedArray(data);
    for (let y = 1; y < h - 1; y++) {
        for (let x = 1; x < w - 1; x++) {
            const idx = (y * w + x) * 4;
            for (let c = 0; c < 3; c++) {
                const val = temp[idx + c] * 5
                    - temp[idx - 4 + c]
                    - temp[idx + 4 + c]
                    - temp[idx - w * 4 + c]
                    - temp[idx + w * 4 + c];
                data[idx + c] = Math.min(255, Math.max(0, (temp[idx + c] + val) / 2));
            }
        }
    }

    // Floyd-Steinberg Dithering
    const floatData = new Float32Array(w * h * 3);
    for (let i = 0; i < w * h; i++) {
        floatData[i * 3] = data[i * 4];
        floatData[i * 3 + 1] = data[i * 4 + 1];
        floatData[i * 3 + 2] = data[i * 4 + 2];
    }

    const processed = new Uint8Array((w * h) / 4);
    let byteIndex = 0;
    let bitShift = 6;
    let currentByte = 0;

    for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
            const i = (y * w + x) * 3;
            const oldR = floatData[i];
            const oldG = floatData[i + 1];
            const oldB = floatData[i + 2];

            const nearest = findNearestColor(oldR, oldG, oldB);

            // Pack 4 pixels per byte (MSB first)
            currentByte |= (nearest.val << bitShift);
            bitShift -= 2;
            if (bitShift < 0) {
                processed[byteIndex++] = currentByte;
                currentByte = 0;
                bitShift = 6;
            }

            const errR = oldR - nearest.r;
            const errG = oldG - nearest.g;
            const errB = oldB - nearest.b;

            const distribute = (dx, dy, factor) => {
                const nx = x + dx;
                const ny = y + dy;
                if (nx >= 0 && nx < w && ny < h) {
                    const ni = (ny * w + nx) * 3;
                    floatData[ni] += errR * factor;
                    floatData[ni + 1] += errG * factor;
                    floatData[ni + 2] += errB * factor;
                }
            };

            distribute(1, 0, 7 / 16);
            distribute(-1, 1, 3 / 16);
            distribute(0, 1, 5 / 16);
            distribute(1, 1, 1 / 16);
        }
    }

    const previewCanvas = document.createElement('canvas');
    renderPreview(processed, previewCanvas);

    return {
        original: resizedCanvas,
        processed: processed,
        preview: previewCanvas
    };
}

// 2. E-Ink 2bpp Unpacker & Canvas Renderer
function renderPreview(processedData, canvas) {
    canvas.width = DISPLAY_WIDTH;
    canvas.height = DISPLAY_HEIGHT;
    const ctx = canvas.getContext('2d');
    const imgData = ctx.createImageData(DISPLAY_WIDTH, DISPLAY_HEIGHT);
    const data = imgData.data;

    let pIdx = 0;
    for (let i = 0; i < processedData.length; i++) {
        const b = processedData[i];
        for (let j = 3; j >= 0; j--) {
            const val = (b >> (j * 2)) & 0x03;
            const color = PALETTE[val] || PALETTE[1];
            data[pIdx++] = color.r;
            data[pIdx++] = color.g;
            data[pIdx++] = color.b;
            data[pIdx++] = 255;
        }
    }
    ctx.putImageData(imgData, 0, 0);
}

// 3. API Client
async function apiCall(url, options = {}) {
    const response = await fetch(url, options);
    if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
    }
    const contentType = response.headers.get('content-type') || '';
    if (contentType.includes('application/json')) {
        return await response.json();
    }
    return await response.text();
}

async function uploadPhoto(processedData) {
    return apiCall('/api/upload', {
        method: 'POST',
        headers: { 'Content-Type': 'application/octet-stream' },
        body: processedData
    });
}
async function listPhotos() { return apiCall('/api/photos'); }
async function deletePhoto(id) { return apiCall(`/api/photos/${id}`, { method: 'DELETE' }); }
async function displayNow(id) { return apiCall(`/api/display/${id}`, { method: 'POST' }); }
async function getStatus() { return apiCall('/api/status'); }
async function updateSettings(settings) {
    return apiCall('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings)
    });
}
async function exitUploadMode() { return apiCall('/api/exit', { method: 'POST' }); }

// 4. Gallery Manager with Live 2bpp Canvas Thumbnails
let photoList = [];

async function loadGallery() {
    try {
        const res = await listPhotos();
        photoList = Array.isArray(res) ? res : (res.photos || []);
        photoList.sort((a, b) => a.id - b.id);
        renderGalleryGrid();
    } catch (e) {
        showToast("Failed to load gallery", "error");
    }
}

async function loadThumbnailIntoCanvas(id, canvas) {
    try {
        const resp = await fetch(`/api/photos/${id}.bin`);
        if (!resp.ok) return;
        const buf = await resp.arrayBuffer();
        if (buf.byteLength === (DISPLAY_WIDTH * DISPLAY_HEIGHT) / 4) {
            renderPreview(new Uint8Array(buf), canvas);
        }
    } catch (e) {
        // Ignore individual thumbnail error
    }
}

function renderGalleryGrid() {
    const grid = document.getElementById('gallery-grid');
    if (!grid) return;

    grid.innerHTML = '';

    if (photoList.length === 0) {
        grid.innerHTML = '<div class="empty-state">No photos stored yet. Tap above to upload your first memory!</div>';
        return;
    }

    photoList.forEach(photo => {
        const id = photo.id || photo;
        const item = document.createElement('div');
        item.className = 'gallery-item';

        const canvas = document.createElement('canvas');
        canvas.width = DISPLAY_WIDTH;
        canvas.height = DISPLAY_HEIGHT;
        item.appendChild(canvas);

        const badge = document.createElement('span');
        badge.className = 'photo-badge';
        badge.textContent = `#${id}`;
        item.appendChild(badge);

        const btnDisplay = document.createElement('button');
        btnDisplay.className = 'btn-display';
        btnDisplay.textContent = 'Show on E-Ink';
        btnDisplay.addEventListener('click', async () => {
            try {
                btnDisplay.disabled = true;
                btnDisplay.textContent = 'Refreshing (~20s)...';
                await displayNow(id);
                showToast(`Refreshing e-ink with photo #${id}`);
            } catch (err) {
                showToast("Failed to trigger display", "error");
            } finally {
                setTimeout(() => {
                    btnDisplay.disabled = false;
                    btnDisplay.textContent = 'Show on E-Ink';
                }, 4000);
            }
        });
        item.appendChild(btnDisplay);

        const btnDelete = document.createElement('button');
        btnDelete.className = 'btn-delete';
        btnDelete.title = 'Delete photo';
        btnDelete.textContent = '✕';
        btnDelete.addEventListener('click', async () => {
            if (confirm(`Delete photo #${id}?`)) {
                try {
                    await deletePhoto(id);
                    showToast("Photo deleted");
                    await loadGallery();
                    await loadSettings();
                } catch (err) {
                    showToast("Failed to delete", "error");
                }
            }
        });
        item.appendChild(btnDelete);

        grid.appendChild(item);
        loadThumbnailIntoCanvas(id, canvas);
    });
}

// 5. Upload Flow Controller
let currentProcessedData = null;

function setupUploadFlow() {
    const fileInput = document.getElementById('file-input');
    const dropZone = document.getElementById('drop-zone');
    const modal = document.getElementById('upload-modal');
    const btnCancel = document.getElementById('btn-cancel-upload');
    const btnConfirm = document.getElementById('btn-confirm-upload');

    if (!fileInput || !dropZone || !modal) return;

    const handleFile = async (file) => {
        if (!file.type.startsWith('image/')) {
            showToast("Please select an image file", "error");
            return;
        }
        try {
            showToast("Dithering image...");
            const result = await processImage(file);
            currentProcessedData = result.processed;

            const origContainer = document.getElementById('preview-original');
            const ditherContainer = document.getElementById('preview-dithered');

            if (origContainer) {
                origContainer.innerHTML = '';
                origContainer.appendChild(result.original);
            }
            if (ditherContainer) {
                ditherContainer.innerHTML = '';
                ditherContainer.appendChild(result.preview);
            }

            modal.classList.add('active');
        } catch (e) {
            console.error(e);
            showToast("Image processing failed", "error");
        }
    };

    fileInput.addEventListener('change', (e) => {
        if (e.target.files.length) handleFile(e.target.files[0]);
    });

    dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('dragover');
    });
    dropZone.addEventListener('dragleave', () => dropZone.classList.remove('dragover'));
    dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropZone.classList.remove('dragover');
        if (e.dataTransfer.files.length) handleFile(e.dataTransfer.files[0]);
    });

    btnCancel.addEventListener('click', () => {
        modal.classList.remove('active');
        currentProcessedData = null;
        fileInput.value = '';
    });

    btnConfirm.addEventListener('click', async () => {
        if (!currentProcessedData) return;
        try {
            btnConfirm.disabled = true;
            btnConfirm.textContent = 'Uploading...';
            await uploadPhoto(currentProcessedData);
            showToast("Photo saved to frame!");
            modal.classList.remove('active');
            fileInput.value = '';
            currentProcessedData = null;
            await loadGallery();
            await loadSettings();
        } catch (e) {
            showToast("Upload failed (storage full?)", "error");
        } finally {
            btnConfirm.disabled = false;
            btnConfirm.textContent = 'Confirm & Upload';
        }
    });
}

// 6. Settings & Status Manager
async function loadSettings() {
    try {
        const status = await getStatus();

        const batteryEl = document.getElementById('battery-indicator');
        if (batteryEl && status.battery !== undefined) {
            batteryEl.textContent = `🔋 ${status.battery}%`;
        }

        const countEl = document.getElementById('photo-count');
        if (countEl && status.photoCount !== undefined) {
            countEl.textContent = `${status.photoCount} / ${status.maxPhotos || 180}`;
        }

        const form = document.getElementById('settings-form');
        if (!form) return;

        if (status.cycleMode) {
            const radio = form.querySelector(`input[name="cycleMode"][value="${status.cycleMode}"]`);
            if (radio) radio.checked = true;
        }
        if (status.refreshHours) {
            const radio = form.querySelector(`input[name="refreshHours"][value="${status.refreshHours}"]`);
            if (radio) radio.checked = true;
        }
    } catch (e) {
        console.error("Could not load status/settings", e);
    }
}

function setupSettings() {
    const form = document.getElementById('settings-form');
    if (form) {
        form.addEventListener('change', async () => {
            const formData = new FormData(form);
            const settings = {
                cycleMode: formData.get('cycleMode'),
                refreshHours: parseInt(formData.get('refreshHours'), 10)
            };
            try {
                await updateSettings(settings);
                showToast("Settings saved");
            } catch (e) {
                showToast("Failed to save settings", "error");
            }
        });
    }

    const exitBtn = document.getElementById('btn-exit');
    if (exitBtn) {
        exitBtn.addEventListener('click', async () => {
            try {
                exitBtn.disabled = true;
                await exitUploadMode();
                showToast("Entering display mode & sleeping...");
            } catch (e) {
                exitBtn.disabled = false;
                showToast("Error exiting upload mode", "error");
            }
        });
    }
}

// 7. Toast Notifications
function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container') || document.body;
    const toast = document.createElement('div');
    toast.className = `toast ${type === 'error' ? 'error' : ''}`;
    toast.textContent = message;
    container.appendChild(toast);

    setTimeout(() => {
        toast.remove();
    }, 3200);
}

// 8. App Initialization
async function init() {
    setupUploadFlow();
    setupSettings();

    await loadSettings();
    await loadGallery();

    setInterval(loadSettings, 30000);
}

document.addEventListener('DOMContentLoaded', init);
