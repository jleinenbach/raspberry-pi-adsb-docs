# M5Stack AtomS3 Remote ID Scanner - Firmware Dokumentation

**Hardware:** M5Stack AtomS3R (ESP32-S3-PICO-1)
**Firmware:** drone-mesh-mapper Dual-Core Remote ID Scanner
**Repository:** `/home/pi/drone-mesh-mapper/remoteid-mesh-dualcore/`
**Status:** ✅ Produktionsbereit (2026-02-02)
**USB Stability:** ✅ Hardware is STABLE - Previous "disconnect" errors were serial port conflicts, NOT hardware issues (Resolved with atoms3-proxy)

---

## Hardware-Spezifikationen

| Komponente | Spezifikation |
|------------|---------------|
| Chip | ESP32-S3-PICO-1 (LGA56) rev 0.2 |
| CPU | Dual Xtensa LX7 @ 240 MHz |
| RAM | 320 KB SRAM + 8 MB Octal PSRAM |
| Flash | 8 MB QIO |
| Connectivity | WiFi 802.11 b/g/n, BLE 5.0 |
| USB | CDC/JTAG (kein externes UART-IC) |
| MAC | e4:b3:23:fa:93:f4 |

**USB-Kabel:** Geschirmtes USB 3.0 Kabel (109mΩ, 100% health)
**USB-Port:** Raspberry Pi USB 3.0 (Bus 001, Port 1-1.4)

---

## Firmware-Architektur

### Dual-Core-Design

```
┌─────────────────────────────────────────────────────────────┐
│ CORE 0 (Protocol CPU)                                       │
│   • WiFi Driver Task (Priority 23, automatisch)            │
│   • WiFi Promiscuous Callback (IRAM_ATTR)                  │
│   • NimBLE Stack (automatisch)                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ CORE 1 (Application CPU)                                    │
│   • bleScanTask (Priority 8, 4KB Stack)                    │
│   • parserTask (Priority 5, 8KB Stack)                     │
│   • outputTask (Priority 2, 2KB Stack)                     │
│   • Arduino loop() (Priority 1)                             │
└─────────────────────────────────────────────────────────────┘
```

### Datenfluss

```
BLE Devices ──► BLE Callback ──► bleQueue (30) ─┐
                                                  ├──► Parser ──► outputQueue (50) ──► Serial JSON
WiFi Packets ─► WiFi Callback ─► wifiQueue (30) ─┘
```

### Queue-Größen (optimiert)

- **bleQueue:** 30 Einträge (Phase 2 Testing: 12% Auslastung bei 50)
- **wifiQueue:** 30 Einträge
- **outputQueue:** 50 Einträge (größer für JSON-Serialisierung)

### Remote ID Protokolle

**BLE Remote ID (ASTM F3411-22a):**
- Signatur: `0x16 0xFA 0xFF 0x0D`
- Message Types: BasicID (0x00), Location (0x10), System (0x40), OperatorID (0x50)
- Reichweite: ~500m

**WiFi Remote ID:**
- NAN Action Frames: Destination `51:6f:9a:01:00:00`
- Beacon Frames: Vendor IE `0xdd` mit OUI `0x90 0x3a 0xe6` oder `0xfa 0x0b 0xbc`
- Reichweite: ~1km

---

## Build-Konfiguration

### platformio.ini

**Kritische Flags:**

```ini
[env:m5stack_atoms3]
platform = espressif32@^6.0.0
board = m5stack-atoms3
framework = arduino
monitor_speed = 115200

build_flags =
  -std=gnu++17
  -D ARDUINO_USB_MODE=1              # Hardware CDC + JTAG
  -DARDUINO_USB_CDC_ON_BOOT=1        # KRITISCH: USB CDC aktivieren!
  -DBOARD_HAS_PSRAM
  -DCORE_DEBUG_LEVEL=0
  -mfix-esp32-psram-cache-issue

board_build.arduino.memory_type = qio_opi
board_build.flash_mode = qio
board_build.psram_type = opi
board_upload.flash_size = 8MB
board_build.partitions = default_8MB.csv

lib_deps =
  bblanchon/ArduinoJson@^6.18.5
  h2zero/NimBLE-Arduino@^1.4.2
```

**WICHTIG:** `ARDUINO_USB_CDC_ON_BOOT=1` (NICHT `ARDUINO_USB_CDC`!)

### Bibliotheken

- **NimBLE-Arduino:** v1.4.2+ (Lightweight BLE Stack)
- **OpenDroneID:** Integriert (opendroneid.h, odid_wifi.h)
- **ArduinoJson:** v6.18.5+ (optional, für zukünftige Erweiterungen)

---

## Kompilierung und Deployment

### Voraussetzungen

```bash
# PlatformIO installiert
pio --version  # Sollte >= 6.0.0 sein

# AtomS3 per USB verbunden
ls -l /dev/ttyACM0
lsusb | grep "303a:1001"
```

### Build-Prozess

```bash
cd ~/drone-mesh-mapper/remoteid-mesh-dualcore

# Clean build (empfohlen nach Code-Änderungen)
pio run --environment m5stack_atoms3 --target clean
pio run --environment m5stack_atoms3

# Oder: Silent build (weniger Output)
pio run --environment m5stack_atoms3 --silent
```

**Erwartete Größen:**
- RAM: ~15-16% (50-52 KB)
- Flash: ~26-27% (880-890 KB)

### Flash-Prozess

```bash
# Option 1: Via PlatformIO (einfach)
pio run --environment m5stack_atoms3 --target upload

# Option 2: Manuell mit esptool (mehr Kontrolle)
esptool --chip esp32s3 --port /dev/ttyACM0 --baud 115200 \
  --after hard-reset write-flash -z --flash-mode dio --flash-freq 40m \
  0x0 .pio/build/m5stack_atoms3/bootloader.bin \
  0x8000 .pio/build/m5stack_atoms3/partitions.bin \
  0x10000 .pio/build/m5stack_atoms3/firmware.bin
```

**Flash-Dauer:** ~10-15 Sekunden

### Vollständiger Erase + Flash (bei Problemen)

```bash
# 1. Kompletten Flash löschen
esptool --chip esp32s3 --port /dev/ttyACM0 erase-flash

# 2. USB Power Cycle
sudo uhubctl -l 2 -p 4 -a off && sleep 2 && sudo uhubctl -l 2 -p 4 -a on
sleep 3

# 3. Neu flashen (siehe oben)
```

---

## Serial-Monitoring

### Wichtiges Timing-Verhalten

**KRITISCH:** ESP32-S3 USB CDC braucht ~3 Sekunden zum Enumerieren!

❌ **FALSCH:**
```bash
# Zu früh - verpasst setup() Output
sleep 1 && cat /dev/ttyACM0
```

✅ **RICHTIG:**
```python
import serial
import time

# 1. ZUERST Monitoring starten
ser = serial.Serial('/dev/ttyACM0', 115200, timeout=1)

# 2. DANN Reset senden
time.sleep(0.5)
ser.setDTR(False)
ser.setRTS(True)
time.sleep(0.2)
ser.setRTS(False)

# 3. JETZT empfangen wir alles ab Boot
while True:
    if ser.in_waiting > 0:
        line = ser.readline().decode('utf-8', errors='ignore')
        print(line.strip())
```

### Erwarteter Boot-Output

```
=== Remote ID Scanner DEBUG ===
[Setup] NVS init...
[Setup] WiFi promiscuous...
[Setup] NimBLE init...
[Setup] Creating queues...
[Setup] Creating tasks...
[BLE Task] Started on Core 1
[Parser Task] Started on Core 1
[Output Task] Started on Core 1
[Setup] Complete!

CPU: 240 MHz | Heap: 201304 | PSRAM: 8366103
Scanning for drones...

>>> loop() is running <<<
```

### Status-Updates (alle 30 Sekunden)

```
--- DEBUG Status ---
Uptime: 30 s
BLE Packets: 0 | WiFi Packets: 201 | WiFi Callbacks: 201
Drones Detected: 0
Heap: 198280 | PSRAM: 8366103
Task Heartbeats: BLE=26 Parser=2850 Output=1
Queues: BLE=0/30 WiFi=0/30 Out=0/50
--------------------
```

**Interpretation:**
- **BLE Packets:** Remote ID BLE-Pakete empfangen
- **WiFi Packets:** Management-Frames mit Remote ID
- **WiFi Callbacks:** Gesamt WiFi-Frames (incl. Non-Remote-ID)
- **Task Heartbeats:** Wie oft jede Task ausgeführt wurde
- **Queues:** Aktuelle/Maximale Queue-Belegung

### Drohnen-Erkennung (JSON-Output)

```json
{
  "src":"BLE",
  "mac":"12:34:56:78:9a:bc",
  "rssi":-45,
  "lat":49.866250,
  "lon":10.839480,
  "alt":350,
  "agl":120,
  "spd":15,
  "hdg":180,
  "id":"DJI-ABCD1234",
  "pilot_lat":49.865000,
  "pilot_lon":10.838000,
  "op_id":"PILOT123"
}
```

---

## Debugging-Checkliste

### 1. USB-Verbindung prüfen

```bash
# Device vorhanden?
ls -l /dev/ttyACM0

# USB-Enumeration OK?
lsusb | grep "303a:1001"

# dmesg-Log OK?
sudo dmesg | tail -20 | grep -E "usb|ttyACM|303a"

# Erwartete Ausgabe:
# usb X-X.X: New USB device found, idVendor=303a, idProduct=1001
# cdc_acm X-X.X:1.0: ttyACM0: USB ACM device
```

### 2. Firmware geflasht?

```bash
# Build-Artefakte vorhanden?
ls -lh ~/drone-mesh-mapper/remoteid-mesh-dualcore/.pio/build/m5stack_atoms3/*.bin

# Erwartete Dateien:
# bootloader.bin (~15 KB)
# partitions.bin (~3 KB)
# firmware.bin (~860-890 KB)
```

### 3. Serial-Output kommt?

**IMPORTANT:** Check that NO other process is using the serial port!

```bash
# First check if port is busy
lsof /dev/ttyACM0

# If output shows OTHER processes: Kill them or use atoms3-proxy instead!
# Only ONE process can read serial at a time
```

**For testing firmware (atoms3-proxy NOT running):**
```python
# Korrektes Monitoring-Pattern (mit Reset)
ser = serial.Serial('/dev/ttyACM0', 115200, timeout=1)
time.sleep(0.5)
ser.setRTS(True)
time.sleep(0.2)
ser.setRTS(False)

# Warte mindestens 5 Sekunden auf Output
start = time.time()
while time.time() - start < 5:
    if ser.in_waiting > 0:
        print(ser.readline().decode('utf-8', errors='ignore').strip())
    time.sleep(0.01)
```

**Wenn kein Output:**
- ✅ USB CDC Flag korrekt? (`ARDUINO_USB_CDC_ON_BOOT=1`)
- ✅ `Serial.begin(115200)` in setup()?
- ✅ `delay(3000)` NACH Serial.begin()?
- ✅ Monitoring VOR Reset gestartet?
- ✅ **NO other process using port?** (`lsof /dev/ttyACM0`)

### 4. Tasks laufen?

Status-Update (nach 30s) muss zeigen:
- **BLE Heartbeat:** >0 (sollte ~26-30 bei 30s sein)
- **Parser Heartbeat:** >>0 (sollte ~2800-3000 sein)
- **Output Heartbeat:** >=1 (wartet auf Drohnen)
- **WiFi Callbacks:** >0 (sollte ~200-400 sein)

**Wenn Heartbeats = 0:**
- Task crasht beim Start
- Prüfe `dmesg` auf Kernel Panics
- Prüfe Heap/Stack-Overflow

### 5. WiFi Promiscuous funktioniert?

Nach 30s sollte **WiFi Callbacks >0** sein (normale WLAN-Pakete).

**Wenn WiFi Callbacks = 0:**
- WiFi-Treiber nicht aktiv
- Promiscuous Mode nicht gesetzt
- Channel nicht gesetzt

### 6. BLE Scanner funktioniert?

**BLE Task Heartbeat** sollte ~1/Sekunde sein (~26-30 bei 30s).

**Wenn BLE Heartbeat = 0:**
- NimBLE-Init fehlgeschlagen
- BLE-Task crasht
- Stack zu klein (4KB sollte OK sein)

### 7. Keine Drohnen gefunden - normal?

Ja! Remote ID ist nur in ~500m Reichweite und nur wenn Drohnen fliegen.

**Test mit Simulator:**
- DJI Drone Simulator (sendet BLE Remote ID)
- OpenDroneID Android App (sendet BLE Remote ID)

---

## Troubleshooting

### Problem: Kein Serial-Output

**Symptom:** `/dev/ttyACM0` existiert, aber `cat` zeigt nichts.

**Ursache:** Timing - USB CDC braucht 3s zum Enumerieren.

**Lösung:**
1. Python-Script nutzen (nicht `cat`)
2. Monitoring VOR Reset starten
3. Mindestens 5s warten

### Problem: "Device Disconnected" Error

**IMPORTANT:** This error can have TWO different root causes!

**Symptom 1: Actual Hardware USB Disconnects**
- `dmesg` shows "USB disconnect" repeatedly
- Device disappears from `lsusb`
- `/dev/ttyACM0` deleted and recreated

**Root Cause:** Bad USB cable (charge-only, high resistance)
**Solution:** Use shielded USB 3.0 cable (<150mΩ resistance)
**Status:** ✅ Resolved (2026-01-30) - Shielded USB3 cable (109mΩ, 100% health)

**Symptom 2: Serial Port Conflict (SOFTWARE Issue!)**
- `dmesg` shows NO disconnects
- Device stays in `lsusb`
- Application error: "serial.serialutil.SerialException: device disconnected"

**Root Cause:** Multiple processes trying to read same serial port
**Solution:** Use atoms3-proxy (single serial reader + ZMQ routing)
**Status:** ✅ Resolved (2026-02-02) - See `/home/pi/docs/ATOMS3-PROXY.md`

**Diagnostic:** Check kernel logs FIRST before assuming hardware problem!
```bash
# Hardware disconnect = Kernel messages
dmesg | tail -20 | grep -i "usb\|ttyACM"

# No kernel messages = Software conflict (check lsof)
lsof /dev/ttyACM0
```

### Problem: Tasks laufen nicht

**Symptom:** Heartbeats = 0 im Status-Update.

**Ursache:** Stack-Overflow, Heap-Exhaustion, oder Crash in Task-Init.

**Debug:**
```cpp
// In jede Task am Anfang:
Serial.println("[TaskName] Started");
Serial.printf("[TaskName] Stack: %u bytes\n", uxTaskGetStackHighWaterMark(NULL) * 4);
```

### Problem: Kompilierung fehlschlägt

**Symptom:** `pio run` gibt Fehler.

**Häufige Ursachen:**
1. Fehlende Library: `pio pkg install`
2. Falsche Platform-Version: `pio pkg update`
3. Korrupter Cache: `pio run --target clean`

### Problem: Flash fehlschlägt

**Symptom:** `esptool` gibt "Failed to connect" oder "Timed out".

**Lösung:**
1. AtomS3 in Bootloader-Mode: Halte BOOT-Button, drücke RESET
2. USB Power Cycle: `sudo uhubctl -l 2 -p 4 -a off && sleep 2 && sudo uhubctl -l 2 -p 4 -a on`
3. Niedrigere Baud-Rate: `--baud 115200` statt `460800`

---

## Firmware-Updates

### Prozedur

1. **Code-Änderungen** in `src/main.cpp`
2. **Kompilieren** (siehe oben)
3. **Backup der aktuellen Firmware:**
   ```bash
   cp ~/drone-mesh-mapper/remoteid-mesh-dualcore/src/main.cpp \
      ~/drone-mesh-mapper/remoteid-mesh-dualcore/src/main.cpp.backup-$(date +%Y%m%d-%H%M%S)
   ```
4. **Flashen** (siehe oben)
5. **Testen:**
   - Serial-Output prüfen
   - 5-Minuten-Stabilitätstest
   - Task-Heartbeats überprüfen
6. **Dokumentation aktualisieren** (diese Datei + CLAUDE.md)

### Wichtige Dateien

```
~/drone-mesh-mapper/remoteid-mesh-dualcore/
├── platformio.ini          # Build-Konfiguration
├── src/
│   ├── main.cpp           # Hauptfirmware
│   └── main.cpp.backup-*  # Backups
├── lib/
│   ├── opendroneid/       # Remote ID Parsing
│   └── odid_wifi/         # WiFi Remote ID
└── .pio/
    └── build/m5stack_atoms3/
        ├── firmware.bin    # Kompilierte Firmware
        ├── bootloader.bin
        └── partitions.bin
```

### Git-Repository

**Lokales Repo:** `/home/pi/drone-mesh-mapper/`
**Upstream:** https://github.com/colonelpanichacks/drone-mesh-mapper

**Updates ziehen:**
```bash
cd ~/drone-mesh-mapper
git fetch
git log --oneline HEAD..origin/main  # Neue Commits ansehen
git pull  # Nur wenn sicher!
```

**WICHTIG:** Vor `git pull` immer Backup der aktuellen `src/main.cpp`!

---

## Performance-Metriken

### Normale Operation (ohne Drohnen)

| Metrik | Wert | Notizen |
|--------|------|---------|
| CPU-Frequenz | 240 MHz | Fest |
| Heap Free | ~198-201 KB | Von 320 KB RAM |
| PSRAM Free | ~8.36 MB | Von 8 MB PSRAM |
| BLE Task Rate | ~1 Hz | Scan alle 1s |
| Parser Task Rate | ~100 Hz | 10ms vTaskDelay |
| WiFi Callbacks | ~6-7 Hz | Normale WLAN-Aktivität |
| Queue-Nutzung | <5% | Minimal ohne Drohnen |

### Mit Drohnen-Aktivität

| Drohnen | BLE Packets/s | WiFi Packets/s | Queue-Nutzung |
|---------|---------------|----------------|---------------|
| 1 | ~1-2 | ~1-2 | <10% |
| 5 | ~5-10 | ~5-10 | ~20% |
| 8 (Max) | ~15-20 | ~15-20 | ~30% |

**Hinweis:** Max 8 Drohnen gleichzeitig (`MAX_UAVS`), danach FIFO-Ersetzung.

---

## Probe Request Monitoring (Planned Feature)

**Status:** 🚧 Prepared in Firmware, Not Yet Active

### Overview

The firmware includes infrastructure for WiFi Presence Detection via IEEE 802.11 Probe Requests, extending the AtomS3R's capabilities beyond drone detection to also monitor nearby WiFi devices.

### Architecture

```
WiFi Promiscuous Mode (Channel 6)
  ↓
Frame Type Detection
  ├─► 0x40 (Probe Request) → probeQueue → Presence Detection ← PLANNED
  ├─► 0x80 (Beacon) → Remote ID Parsing ← ACTIVE
  └─► 0xD0 (NAN Action) → Remote ID Parsing ← ACTIVE
```

**Key Point:** Probe Request monitoring runs **in parallel** with Remote ID detection. No interference between systems.

### Data Structure

```cpp
// Defined in src/main.cpp line 32-37
struct probe_data {
  uint8_t  mac[6];         // Source MAC address (Bytes 10-15 of frame)
  int      rssi;           // Signal strength from rx_ctrl.rssi
  uint32_t last_seen;      // millis() timestamp
  char     ssid[33];       // First SSID from tagged parameters
};

// Queue (line 46)
QueueHandle_t probeQueue;  // 30 entries, 1410 bytes total

// Task handle (line 58)
TaskHandle_t probeOutputTaskHandle = NULL;
```

### Frame Detection Logic (Planned)

```cpp
void IRAM_ATTR wifiSnifferCallback(void* buf, wifi_promiscuous_pkt_type_t type) {
  // ...existing Remote ID code...

  // NEW: Probe Request Detection
  if (payload[0] == 0x40) {  // Frame Control = Probe Request
    probe_data probe;
    memset(&probe, 0, sizeof(probe));

    // Extract MAC from bytes 10-15 (Source Address)
    memcpy(probe.mac, &payload[10], 6);

    // Extract RSSI
    probe.rssi = pkt->rx_ctrl.rssi;
    probe.last_seen = millis();

    // Parse SSID from Tagged Parameters (starts at byte 24)
    int offset = 24;
    while (offset < length - 2) {
      uint8_t tag = payload[offset];
      uint8_t len = payload[offset + 1];

      if (tag == 0x00 && len > 0 && len <= 32) {  // SSID IE
        memcpy(probe.ssid, &payload[offset + 2], len);
        probe.ssid[len] = '\0';
        break;
      }

      offset += len + 2;
    }

    // Send to queue (non-blocking from ISR)
    xQueueSendFromISR(probeQueue, &probe, NULL);
  }
}
```

### Output Task (Planned)

```cpp
void probeOutputTask(void* param) {
  probe_data probe;

  for (;;) {
    if (xQueueReceive(probeQueue, &probe, portMAX_DELAY)) {
      char mac_str[18];
      snprintf(mac_str, sizeof(mac_str), "%02x:%02x:%02x:%02x:%02x:%02x",
               probe.mac[0], probe.mac[1], probe.mac[2],
               probe.mac[3], probe.mac[4], probe.mac[5]);

      Serial.printf("{\"type\":\"probe\",\"mac\":\"%s\",\"rssi\":%d,\"ssid\":\"%s\",\"ts\":%lu}\n",
                    mac_str, probe.rssi, probe.ssid, probe.last_seen);
      Serial.flush();
    }
  }
}

// Task creation in setup():
xTaskCreatePinnedToCore(probeOutputTask, "ProbeOut", 2048, NULL, 2, &probeOutputTaskHandle, 1);
```

### Memory Impact

| Component | RAM | PSRAM | Notes |
|-----------|-----|-------|-------|
| **Current (Drone Only)** | ~15-16 KB | ~0 KB | BLE + WiFi Remote ID |
| **With Probe Detection** | ~18.5 KB | ~0 KB | +3.5 KB for queue + task |
| **Total Impact** | **+23%** | **0%** | Still well within limits |

**Breakdown:**
- probe_data struct: 47 bytes per entry
- probeQueue (30 entries): 1410 bytes
- probeOutputTask stack: 2048 bytes
- **Total:** 3458 bytes (~3.5 KB)

### Performance Estimates

Based on typical probe request rates:

| Environment | Probe Rate | Queue Usage | CPU Impact (Core 0) |
|-------------|------------|-------------|---------------------|
| **Residential** | 10-50/min | <10% (1-3 items) | +3-5% |
| **Small Office** | 50-200/min | 20-40% (6-12 items) | +5-8% |
| **Airport** | 1000-5000/min | 100% (overflow) | +15-20% |

**Recommendation:** For high-density environments (>200 probes/min), increase queue size to 50 or add RSSI filtering in firmware.

### Configuration Notes

**Channel Selection:**
- Current: Fixed to Channel 6 (line 321 in setup())
- Consideration: Add channel hopping for better coverage (1-13)

**RSSI Filtering (Optional):**
```cpp
// In wifiSnifferCallback, before queueing:
if (probe.rssi < -70) {
  return;  // Too weak - likely neighbor, skip
}
```

**Broadcast SSID Filtering:**
```cpp
// Skip probes without SSID (broadcast scans)
if (strlen(probe.ssid) == 0) {
  return;  // Empty SSID, skip
}
```

### Integration with Raspberry Pi

**See:** `~/docs/PRESENCE-DETECTION.md` for full system architecture

**Data Flow:**
```
AtomS3R → /dev/ttyACM0 → zmq-decoder → presence-detector.py
  JSON: {"type":"probe","mac":"..","rssi":-55,"ssid":"...","ts":123}
```

**Raspberry Pi Processing:**
- OUI database lookup (MAC → Manufacturer)
- SSID/MAC whitelist filtering
- RSSI-based proximity detection
- Cooldown deduplication (default 5 minutes)
- Notifications via Telegram/MQTT

### Activation Steps

To enable Probe Request monitoring:

1. **Update Firmware:** Implement probe detection code in `wifiSnifferCallback`
2. **Create Task:** Add `probeOutputTask` in `setup()`
3. **Compile & Flash:** `pio run -e m5stack_atoms3r -t upload`
4. **Install Pi Service:** Deploy `presence-detector.service`
5. **Configure:** Edit `/etc/presence-detector.conf` (RSSI threshold, whitelists)
6. **Test:** Monitor logs for probe detections

### Testing Checklist

- [ ] Queue receives probe requests (check queue usage in status output)
- [ ] MAC addresses extracted correctly (verify against known devices)
- [ ] SSID parsing works for various lengths (1-32 characters)
- [ ] RSSI values reasonable (-30 to -90 dBm)
- [ ] No interference with drone detection (compare BLE/WiFi RID rates)
- [ ] Serial output valid JSON (test with Python json.loads())
- [ ] 24-hour stability test (no memory leaks, queue overflows)

### Privacy Considerations

**MAC Randomization:**
- iOS 14+, Android 10+: Random MAC per network
- iOS 18+: MAC rotates every 24 hours
- Impact: Same device appears as different MACs over time

**Workaround:** Use OUI (first 3 bytes) for manufacturer detection instead of individual device tracking.

**Legal:** See `PRESENCE-DETECTION.md` for GDPR compliance and ethical use guidelines.

---

## Lessons Learned

### USB CDC auf ESP32-S3

1. ✅ **Flag heißt `ARDUINO_USB_CDC_ON_BOOT=1`** (nicht `ARDUINO_USB_CDC`)
2. ✅ **USB CDC braucht 3-5 Sekunden** zum Enumerieren nach Reset
3. ✅ **Monitoring MUSS vor Reset starten**, sonst verpasst man setup()
4. ✅ **Python pyserial funktioniert**, `cat /dev/ttyACM0` ist unzuverlässig
5. ✅ **delay(3000) NACH Serial.begin()** ist essentiell für sichtbaren Output

### NimBLE vs Bluedroid

1. ✅ **NimBLE spart ~370 KB Flash** und ~15 KB RAM
2. ✅ **NimBLE ist stabiler** für Scanning-Only-Anwendungen
3. ✅ **API ist fast identisch** zu Bluedroid ESP32 BLE Arduino
4. ✅ **NimBLEAdvertisedDevice*** (Pointer) statt `BLEScanResults*`

### Dual-Core ESP32-S3

1. ✅ **WiFi-Treiber läuft automatisch auf Core 0** (Priority 23)
2. ✅ **BLE-Stack läuft automatisch auf Core 0** (egal wo Task gepinnt)
3. ✅ **BLE-Scan-Task kann auf Core 1** laufen (nur API-Wrapper)
4. ✅ **FreeRTOS Queues sind thread-safe** zwischen Cores
5. ✅ **Callbacks (BLE, WiFi) laufen wo Task gepinnt** ist

### Serial-Output Debugging

1. ✅ **Serial.flush() kann blockieren** - besser `delay(100)`
2. ✅ **printf() in Tasks braucht ausreichend Stack** (min 2KB für Output-Task)
3. ✅ **USB CDC Serial-Buffer ist ~1KB** - große Ausgaben aufteilen
4. ✅ **Heartbeat-Counter sind essentiell** für Task-Liveness-Check

### USB-Hardware

1. ✅ **Kabel-Qualität ist kritisch** - nur <150mΩ Widerstand OK
2. ✅ **Charge-Only Kabel (nur VCC+GND) funktionieren nicht** für Daten
3. ✅ **USB 3.0 Ports sind stabiler** als USB 2.0
4. ✅ **BLE cableQU App zeigt Kabel-Health** (Widerstand, Pin-Belegung)

---

## Kontakt & Support

**Dokumentation:** `/home/pi/docs/ATOMS3-FIRMWARE.md`
**CLAUDE.md:** `/home/pi/CLAUDE.md` (Abschnitt: DragonSync)
**Logs:** Serial-Output (kein persistentes Logging auf ESP32)

**Bei Problemen:**
1. Diese Datei konsultieren (Troubleshooting-Sektion)
2. **FIRST: Check for serial port conflicts:** `lsof /dev/ttyACM0`
3. Serial-Output mit Python-Monitoring prüfen (stop atoms3-proxy first!)
4. Task-Heartbeats im Status-Update checken
5. dmesg für ECHTE USB-Hardware-Probleme prüfen

**Production Setup:**
- See `/home/pi/docs/ATOMS3-PROXY.md` for proxy-based architecture
- atoms3-proxy routes to multiple consumers without conflicts
