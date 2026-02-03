# AtomS3R Remote ID Firmware

Kompilierte Firmware für M5Stack AtomS3R (ESP32-S3 + 8MB PSRAM) zur Erkennung von Drohnen via Remote ID (BLE + WiFi).

## Firmware-Versionen

### atoms3r-remote-id-psram-20260203.bin (865 KB)

**Build-Datum:** 2026-02-03  
**Git Commit:** 50ac395 (drone-mesh-mapper, modified)  
**Board:** M5Stack AtomS3R (ESP32-S3-PICO-1 + 8MB PSRAM)  
**Features:** BLE Remote ID (minimale Firmware ohne WiFi für Stabilität)

**Spezifikationen:**
- Flash: 33% (865 KB / 2.5 MB)
- RAM: 14.4% (47 KB / 327 KB)
- PSRAM: 8 MB (aktiviert mit BOARD_HAS_PSRAM)
- USB CDC: Hardware CDC (ARDUINO_USB_CDC_ON_BOOT=1)

**PlatformIO Build-Flags:**
```ini
[env:m5stack_atoms3r]
platform = espressif32
board = m5stack-atoms3
framework = arduino
board_build.arduino.memory_type = qio_opi
build_flags = 
    -DBOARD_HAS_PSRAM
    -mfix-esp32-psram-cache-issue
    -DARDUINO_USB_CDC_ON_BOOT=1
    -DARDUINO_USB_MODE=1
lib_deps = 
    m5stack/M5Unified
    bblanchon/ArduinoJson
    esp32-nimble
```

**Funktionen:**
- BLE Remote ID Empfang (ASTM F3411-22a)
- JSON-Output über USB Serial (115200 baud)
- Status-Messages alle 60 Sekunden
- NimBLE Stack (geringer Speicherverbrauch)
- BLE Error-Logs unterdrückt (stabiler Betrieb)

**Integration:**
- Serial Port: `/dev/remoteid` → `/dev/ttyACM0`
- atoms3-proxy liest Serial, routet via ZMQ
- DragonSync empfängt ZMQ-Stream → MQTT → Home Assistant

---

## Flash-Anleitung

### Voraussetzungen

```bash
sudo apt install esptool python3-serial
```

### Flash-Prozess

```bash
# 1. Services stoppen
sudo systemctl stop atoms3-proxy dragonsync

# 2. Flash komplett löschen (empfohlen bei Firmware-Wechsel)
esptool.py --chip esp32s3 --port /dev/ttyACM0 erase_flash

# 3. Firmware flashen
esptool.py --chip esp32s3 --port /dev/ttyACM0 \
  --before default_reset --after hard_reset \
  write_flash -z 0x0 atoms3r-remote-id-psram-20260203.bin

# 4. Services starten
sudo systemctl start atoms3-proxy dragonsync
```

### Firmware-Verifikation

```bash
# Serial Monitor (sollte JSON-Output zeigen)
sudo systemctl status atoms3-proxy
journalctl -u atoms3-proxy -f

# Erwartete Ausgabe:
# {"type":"status","message":"Device is active and scanning","timestamp":1234567890}
# {"type":"remoteid","mac":"XX:XX:XX:XX:XX:XX",...}
```

---

## Build-Prozess (selbst kompilieren)

### Voraussetzungen

```bash
# PlatformIO installieren
pip3 install platformio --user

# Repository klonen
git clone https://github.com/colonelpanichacks/drone-mesh-mapper.git
cd drone-mesh-mapper/remoteid-mesh-dualcore
```

### platformio.ini anpassen

Erstelle oder bearbeite `[env:m5stack_atoms3r]` Sektion (siehe oben).

### Kompilieren

```bash
~/.local/bin/pio run -e m5stack_atoms3r

# Firmware-Output:
# .pio/build/m5stack_atoms3r/firmware.bin
```

### Flashen

```bash
~/.local/bin/pio run -e m5stack_atoms3r -t upload
```

---

## Hardware-Spezifikationen

**M5Stack AtomS3R:**
- Chip: ESP32-S3-PICO-1 (LGA56) rev v0.2
- Flash: 8 MB
- PSRAM: 8 MB (Octal PSRAM, QPI mode)
- USB: Native USB CDC (kein externer UART-Chip)
- Power: 5V via USB-C

**Pins:**
- GPIO 38: Button (mit Pullup)
- GPIO 35: RGB LED (WS2812)

---

## Troubleshooting

### "Invalid image block, can't boot"

**Ursache:** Korrupte Firmware oder falsches Board-Target  
**Lösung:** `esptool.py erase_flash` vor Reflash

### USB Device nicht gefunden

**Ursache:** USB-Kabel ist Charge-Only (keine Datenleitungen)  
**Lösung:** Geschirmtes USB3-Kabel verwenden (Data+, Data-, GND, VCC, Shield)

### Firmware läuft, aber kein Serial-Output

**Ursache:** `ARDUINO_USB_CDC_ON_BOOT=1` fehlt  
**Lösung:** platformio.ini prüfen, neu kompilieren

### Memory Leak nach 10+ Stunden

**Ursache:** PSRAM nicht aktiviert oder nicht korrekt initialisiert  
**Lösung:** `BOARD_HAS_PSRAM` + `board_build.arduino.memory_type = qio_opi` setzen

---

## Dokumentation

Vollständige Dokumentation siehe:
- `~/docs/ATOMS3-FIRMWARE.md` - Firmware-Details & Troubleshooting
- `~/docs/ATOMS3-PROXY.md` - Serial Port Proxy Architektur
- `~/docs/PRESENCE-DETECTION.md` - WiFi Presence Detection

---

**Repository:** https://github.com/jleinenbach/raspberry-pi-adsb-docs  
**Upstream:** https://github.com/colonelpanichacks/drone-mesh-mapper
