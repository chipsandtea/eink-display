// app.js

const DISPLAY_WIDTH = 400;
const DISPLAY_HEIGHT = 300;

// Colors
const PALETTE = [
    { r: 0, g: 0, b: 0, val: 0 },         // Black: 00
    { r: 255, g: 255, b: 255, val: 1 },   // White: 01
    { r: 255, g: 255, b: 0, val: 2 },     // Yellow: 10
    { r: 200, g: 0, b: 0, val: 3 }        // Red: 11
];

// Helper: Color Distance
function colorDistanceSq(c1, c2) {
    const dr = c1.r - c2.r;
    const dg = c1.g - c2.g;
    const db = c1.b - c2.b;
    return dr * dr + dg * dg + db * db;
}

// Helper: Find nearest palette color
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
            if (view.getUint16(0, false) != 0xFFD8) return resolve(-2);
            const length = view.byteLength;
            let offset = 2;
            while (offset < length) {
                const marker = view.getUint16(offset, false);
                offset += 2;
                if (marker == 0xFFE1) {
                    if (view.getUint32(offset += 2, false) != 0x45786966) return resolve(-1);
                    const little = view.getUint16(offset += 6, false) == 0x4949;
                    offset += view.getUint32(offset + 4, little);
                    const tags = view.getUint16(offset, little);
                    offset += 2;
                    for (let i = 0; i < tags; i++) {
                        if (view.getUint16(offset + (i * 12), little) == 0x0112) {
                            return resolve(view.getUint16(offset + (i * 12) + 8, little));
                        }
                    }
                } else if ((marker & 0xFF00) != 0xFF00) {
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
        const img = new Image();
        img.onload = () => resolve(img);
        img.onerror = reject;
        img.src = URL.createObjectURL(file);
    });
}

// 1. Image Processor
async function processImage(file) {
    const img = await loadImage(file);
    let orientation = await getExifOrientation(file);
    
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    
    // Rotate canvas based on EXIF
    let width = img.width;
    let height = img.height;
    
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
    
    // Contrast and unsharp mask
    let imageData = rctx.getImageData(0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT);
    let data = imageData.data;
    
    const contrast = 1.2;
    const intercept = 128 * (1 - contrast);
    
    for (let i = 0; i < data.length; i += 4) {
        data[i] = data[i] * contrast + intercept;
        data[i+1] = data[i+1] * contrast + intercept;
        data[i+2] = data[i+2] * contrast + intercept;
    }
    
    // Minimal unsharp mask (sharpening) via a simple convolution kernel [0, -1, 0, -1, 5, -1, 0, -1, 0]
    const w = DISPLAY_WIDTH;
    const h = DISPLAY_HEIGHT;
    const temp = new Uint8ClampedArray(data);
    for (let y = 1; y < h - 1; y++) {
        for (let x = 1; x < w - 1; x++) {
            const idx = (y * w + x) * 4;
            for (let c = 0; c < 3; c++) {
                let val = temp[idx + c] * 5 
                        - temp[idx - 4 + c] 
                        - temp[idx + 4 + c] 
                        - temp[idx - w * 4 + c] 
                        - temp[idx + w * 4 + c];
                data[idx + c] = Math.min(255, Math.max(0, val));
            }
        }
    }
    
    // Floyd-Steinberg Dithering
    // Work with Float32 for error accumulation
    const floatData = new Float32Array(w * h * 3);
    for (let i = 0; i < w * h; i++) {
        floatData[i * 3] = data[i * 4];
        floatData[i * 3 + 1] = data[i * 4 + 1];
        floatData[i * 3 + 2] = data[i * 4 + 2];
    }
    
    const processed = new Uint8Array( (w * h) / 4 );
    
    const previewCanvas = document.createElement('canvas');
    previewCanvas.width = DISPLAY_WIDTH;
    previewCanvas.height = DISPLAY_HEIGHT;
    const pctx = previewCanvas.getContext('2d');
    const previewImageData = pctx.createImageData(w, h);
    const pData = previewImageData.data;

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
            
            // Pack bits
            currentByte |= (nearest.val << bitShift);
            bitShift -= 2;
            if (bitShift < 0) {
                processed[byteIndex++] = currentByte;
                currentByte = 0;
                bitShift = 6;
            }
            
            // Render to preview
            const pIdx = (y * w + x) * 4;
            pData[pIdx] = nearest.r;
            pData[pIdx+1] = nearest.g;
            pData[pIdx+2] = nearest.b;
            pData[pIdx+3] = 255;
            
            const errR = oldR - nearest.r;
            const errG = oldG - nearest.g;
            const errB = oldB - nearest.b;
            
            // Distribute error
            const distribute = (dx, dy, factor) => {
                const nx = x + dx;
                const ny = y + dy;
                if (nx >= 0 && nx < w && ny < h) {
                    const ni = (ny * w + nx) * 3;
                    floatData[ni] += errR * factor;
                    floatData[ni+1] += errG * factor;
                    floatData[ni+2] += errB * factor;
                }
            };
            
            distribute(1, 0, 7/16);
            distribute(-1, 1, 3/16);
            distribute(0, 1, 5/16);
            distribute(1, 1, 1/16);
        }
    }
    
    pctx.putImageData(previewImageData, 0, 0);

    return {
        original: resizedCanvas,
        processed: processed,
        preview: previewCanvas
    };
}

// 2. E-Ink Preview Renderer
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
            const color = PALETTE.find(p => p.val === val);
            
            // Add subtle noise for paper texture
            const noise = (Math.random() - 0.5) * 10;
            
            data[pIdx++] = Math.min(255, Math.max(0, color.r + noise));
            data[pIdx++] = Math.min(255, Math.max(0, color.g + noise));
            data[pIdx++] = Math.min(255, Math.max(0, color.b + noise));
            data[pIdx++] = 255;
        }
    }
    ctx.putImageData(imgData, 0, 0);
}

// 3. API Client
async function apiCall(url, options = {}) {
    try {
        const response = await fetch(url, options);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        if (options.method === 'DELETE' || options.method === 'POST') {
            const contentType = response.headers.get("content-type");
            if (contentType && contentType.indexOf("application/json") !== -1) {
                return await response.json();
            }
            return await response.text();
        }
        return await response.json();
    } catch (e) {
        console.error("API call failed:", url, e);
        throw e;
    }
}

async function uploadPhoto(processedData) {
    const response = await fetch('/api/upload', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/octet-stream'
        },
        body: processedData
    });
    if (!response.ok) throw new Error("Upload failed");
    return response.text();
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


// 4. Gallery Manager
let photoList = [];

async function loadGallery() {
    try {
        photoList = await listPhotos();
        renderGalleryGrid();
    } catch (e) {
        showToast("Failed to load gallery", "error");
    }
}

function renderGalleryGrid() {
    const grid = document.getElementById('gallery-grid');
    if (!grid) return;
    
    grid.innerHTML = '';
    
    if (photoList.length === 0) {
        grid.innerHTML = '<div class="empty-state">No photos yet. Upload one!</div>';
        return;
    }
    
    photoList.forEach(photo => {
        const item = document.createElement('div');
        item.className = 'gallery-item';
        
        // We'd typically load the thumbnail here from an endpoint, e.g. /api/thumb/id
        // Since we don't have a thumbnail endpoint specified, we might just show an icon or a placeholder
        item.innerHTML = `
            <div class="photo-placeholder">IMG ${photo.id || photo}</div>
            <div class="photo-actions">
                <button class="btn-display" data-id="${photo.id || photo}">Display</button>
                <button class="btn-delete" data-id="${photo.id || photo}">Delete</button>
            </div>
        `;
        grid.appendChild(item);
    });
    
    document.querySelectorAll('.btn-display').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            const id = e.target.getAttribute('data-id');
            try {
                await displayNow(id);
                showToast("Displaying photo...", "success");
            } catch(err) {
                showToast("Failed to display", "error");
            }
        });
    });
    
    document.querySelectorAll('.btn-delete').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            const id = e.target.getAttribute('data-id');
            if (confirm("Delete this photo?")) {
                try {
                    await deletePhoto(id);
                    showToast("Photo deleted", "success");
                    loadGallery();
                } catch(err) {
                    showToast("Failed to delete", "error");
                }
            }
        });
    });
}

// 5. Upload Flow Controller
let currentProcessedData = null;

function setupUploadFlow() {
    const fileInput = document.getElementById('file-upload');
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
            showToast("Processing image...", "info");
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
            
            modal.style.display = 'block';
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
        modal.style.display = 'none';
        currentProcessedData = null;
        fileInput.value = '';
    });
    
    btnConfirm.addEventListener('click', async () => {
        if (!currentProcessedData) return;
        try {
            btnConfirm.disabled = true;
            btnConfirm.innerText = 'Uploading...';
            await uploadPhoto(currentProcessedData);
            showToast("Upload successful", "success");
            modal.style.display = 'none';
            fileInput.value = '';
            loadGallery();
        } catch (e) {
            showToast("Upload failed", "error");
        } finally {
            btnConfirm.disabled = false;
            btnConfirm.innerText = 'Confirm & Upload';
        }
    });
}

// 6. Settings Manager
async function loadSettings() {
    try {
        const status = await getStatus();
        
        // Update UI with status
        const batteryEl = document.getElementById('battery-level');
        if (batteryEl && status.battery !== undefined) {
            batteryEl.innerText = `${status.battery}%`;
        }
        
        // Update settings controls
        const form = document.getElementById('settings-form');
        if (!form) return;
        
        if (status.cycleMode) {
            const radio = form.querySelector(`input[name="cycleMode"][value="${status.cycleMode}"]`);
            if (radio) radio.checked = true;
        }
        if (status.refreshInterval) {
            const select = form.querySelector(`select[name="refreshInterval"]`);
            if (select) select.value = status.refreshInterval;
        }
        
    } catch (e) {
        console.error("Could not load settings");
    }
}

function setupSettings() {
    const form = document.getElementById('settings-form');
    if (form) {
        form.addEventListener('change', async () => {
            const formData = new FormData(form);
            const settings = {
                cycleMode: formData.get('cycleMode'),
                refreshInterval: parseInt(formData.get('refreshInterval'), 10)
            };
            try {
                await updateSettings(settings);
                showToast("Settings saved", "success");
            } catch (e) {
                showToast("Failed to save settings", "error");
            }
        });
    }
    
    const exitBtn = document.getElementById('btn-exit');
    if (exitBtn) {
        exitBtn.addEventListener('click', async () => {
            if (confirm("Exit upload mode? The device will restart or resume showing photos.")) {
                try {
                    await exitUploadMode();
                    showToast("Exiting...", "info");
                } catch(e) {
                    showToast("Error exiting", "error");
                }
            }
        });
    }
}

// 7. Toast Notifications
function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerText = message;
    
    // Minimal styling applied via class in CSS, but we can do inline fallback
    toast.style.position = 'fixed';
    toast.style.bottom = '20px';
    toast.style.left = '50%';
    toast.style.transform = 'translateX(-50%)';
    toast.style.padding = '10px 20px';
    toast.style.borderRadius = '5px';
    toast.style.color = '#fff';
    toast.style.zIndex = '9999';
    toast.style.transition = 'opacity 0.3s';
    
    if (type === 'success') toast.style.backgroundColor = '#4caf50';
    else if (type === 'error') toast.style.backgroundColor = '#f44336';
    else toast.style.backgroundColor = '#2196f3';
    
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// 8. App Initialization
async function init() {
    setupUploadFlow();
    setupSettings();
    
    await loadSettings();
    await loadGallery();
    
    // Poll status every 30 seconds
    setInterval(loadSettings, 30000);
}

document.addEventListener('DOMContentLoaded', init);
