# DragonSync - Drone Detection

**Status:** ✅ Operational - AtomS3 flashed and running

## Übersicht

DragonSync erkennt Drohnen via **WiFi/Bluetooth Remote ID** (EU-Pflicht seit 2024 für Drohnen >250g) und sendet die Daten an Home Assistant.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AtomS3 (ESP32-S3)                                    │
│  - Empfängt WiFi Beacon + Bluetooth LE Remote ID                           │
│  - Dual-Core: Core0=WiFi, Core1=Bluetooth                                  │
│  - Sendet JSON über USB-Serial (115200 baud)                               │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │ USB (/dev/remoteid)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Raspberry Pi                                          │
│                                                                              │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────────┐   │
│  │  zmq-decoder    │────▶│   DragonSync    │────▶│  Home Assistant     │   │
│  │  (Serial→ZMQ)   │     │   (Gateway)     │     │  (MQTT Discovery)   │   │
│  │  Port 4224      │     │  Port 8088 API  │     │  192.168.1.21:1883  │   │
│  └─────────────────┘     └─────────────────┘     └─────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Was wird erkannt?

| Protokoll | Frequenz | Reichweite | Daten |
|-----------|----------|------------|-------|
| Bluetooth Remote ID | 2.4 GHz BLE | ~500m | Drohne + Pilot Position |
| WiFi Remote ID | 2.4 GHz Beacon | ~1km | Drohne + Pilot Position |
| DJI DroneID* | 2.4 GHz OFDM | ~2km | Drohne + Pilot Position |

*DJI DroneID erfordert zusätzlichen RTL-SDR auf 2.4 GHz

## Upload zu öffentlichen Netzwerken?

**❌ KEIN Community-Upload möglich** - Remote ID Daten bleiben lokal.

### Warum kein öffentliches Drohnen-Tracking?

| Grund | Erklärung |
|-------|-----------|
| **Rechtslage** | EU DSGVO & USA Privacy Laws verbieten unbefugte Weitergabe von Remote ID Daten |
| **Datenschutz** | Remote ID ist für lokale Behörden gedacht, nicht für öffentliches Tracking |
| **Keine Community-Plattform** | Im Gegensatz zu ADS-B (FlightAware) oder OGN (glidernet.org) existiert keine öffentliche Drohnen-Tracking-Plattform |
| **Sicherheitsbedenken** | Öffentliches Tracking könnte für Spionage/Stalking missbraucht werden |
| **Kein Flugsicherungs-Bedarf** | Drohnen fliegen nur bis 120m Höhe - keine Kollisionsgefahr mit Verkehrsfliegern |

### Was gibt es stattdessen?

**Kommerzielle Systeme (nur für Behörden/Betreiber):**
- **DroneScout**: Upload zu UTM-Plattformen (Altitude Angel) - kostenpflichtig
- **Dronetag Cloud**: Eigenes Cloud-System für Scout-Receiver - kostenpflichtig
- **Network Remote ID (USS)**: Offizielle FAA/EASA-Systeme für Luftraum-Management

**DragonSync (dein Setup):**
- Fokus: Lokale Situational Awareness (Home Assistant + TAK/ATAK)
- Kein Upload-Feature (by design)
- Daten bleiben auf dem eigenen Netzwerk

**Fazit:** Remote ID ist bewusst **nicht** wie ADS-B oder OGN - es dient der Identifikation für Behörden, nicht dem Community-Tracking.

## Dateien

| Pfad | Beschreibung |
|------|--------------|
| `/home/pi/DragonSync/` | Hauptverzeichnis |
| `/home/pi/DragonSync/config.ini` | Konfiguration |
| `/home/pi/DragonSync/gps.ini` | Statische GPS-Position |
| `/home/pi/DroneID/` | ZMQ-Decoder + OpenDroneID |
| `/etc/systemd/system/dragonsync.service` | DragonSync Service |
| `/etc/systemd/system/zmq-decoder.service` | ZMQ-Decoder Service |
| `/etc/udev/rules.d/99-remoteid.rules` | USB-Geräteerkennung |

## Services

### dragonsync.service
- **Läuft dauerhaft** (auch ohne ESP32)
- Verbindet mit MQTT und wartet auf Drohnen-Daten
- API auf Port 8088

```bash
sudo systemctl status dragonsync
sudo systemctl restart dragonsync
journalctl -u dragonsync -f
```

### zmq-decoder.service
- **Startet automatisch** wenn AtomS3 angeschlossen wird
- Liest Serial-Daten vom ESP32
- Sendet an ZMQ Port 4224

```bash
sudo systemctl status zmq-decoder
journalctl -u zmq-decoder -f
```

## Home Assistant Integration

DragonSync erstellt automatisch via MQTT Discovery:

### Device Tracker
- `device_tracker.drone_<serial>` - Drohnen-Position auf Karte
- `device_tracker.pilot_<serial>` - Piloten-Position (wenn bekannt)
- `device_tracker.home_<serial>` - Start-Position (wenn bekannt)

### Sensoren (pro Drohne)
- `sensor.drone_<id>_altitude` - Höhe (m)
- `sensor.drone_<id>_speed` - Geschwindigkeit (m/s)
- `sensor.drone_<id>_rssi` - Signalstärke (dBm)
- `sensor.drone_<id>_frequency` - Frequenz (MHz)

### MQTT Topics
```
dragonsync/drones           # Alle Drohnen (aggregiert)
dragonsync/drone/<id>       # Einzelne Drohne
homeassistant/device_tracker/drone_<id>/config  # HA Discovery
```

## Hardware-Empfehlung

### M5Stack AtomS3 vs AtomS3R

| Feature | AtomS3 | AtomS3R |
|---------|--------|---------|
| **Preis** | ~10-12€ | ~30€ |
| **PSRAM** | ❌ Kein | ✅ 8MB |
| **Mehrkosten** | - | +250% |
| **Max. Drohnen** | 5-10 gleichzeitig | 20-50 gleichzeitig |
| **Kompatibilität** | ✅ Voll kompatibel | ✅ Voll kompatibel |

### Empfehlung nach Anwendungsfall

**Standard: M5Stack AtomS3** (~10-12€) ✅ **EMPFOHLEN**
- Ausreichend für 5-10 Drohnen gleichzeitig
- Perfekt für Wohngebiete und normale Nutzung
- Stabiler Dauerbetrieb
- **Für 99% der Nutzer die richtige Wahl**

**Premium: M5Stack AtomS3R** (~30€)
- 8MB PSRAM für >20 Drohnen gleichzeitig
- Nur sinnvoll bei speziellen Anwendungsfällen:
  - 🏢 Flughafen-Nähe (regelmäßig >10 Drohnen)
  - 🎪 Event-Locations (Drohnen-Shows, Messen)
  - 📊 Kommerzielle Überwachung
  - 🔬 Forschung/Firmware-Entwicklung
- 250% Mehrkosten für spezialisierte Nutzung

### Praktische Performance (AtomS3)
- ✅ 1-3 Drohnen: Kein Problem, perfekte Erfassung
- ✅ 5-10 Drohnen: Stabil, alle werden getrackt
- ⚠️ 10-15 Drohnen: Kann zu Drops führen (älteste werden verworfen)
- ❌ >15 Drohnen: System überlastet, AtomS3R empfohlen

**Fazit:** AtomS3 reicht für normale Nutzung vollkommen aus. AtomS3R nur upgraden wenn regelmäßig >10 Drohnen sichtbar sind UND das System Probleme zeigt.

---

## AtomS3 Setup (English)

### Current Hardware
| Property | Value |
|----------|-------|
| Chip | ESP32-S3-PICO-1 (LGA56) rev 0.2 (AtomS3R) |
| MAC | e4:b3:23:fa:93:f4 (AtomS3R) |
| Firmware | drone-mesh-mapper esp32s3-dual-rid.bin (1.4 MB) |
| USB | `/dev/remoteid` → `/dev/ttyACM0` |

### Step 1: Install esptool

```bash
pip3 install --user --break-system-packages esptool
```

### Step 2: Clone Firmware Repository

```bash
git clone https://github.com/colonelpanichacks/drone-mesh-mapper.git ~/drone-mesh-mapper
```

Pre-compiled binaries are in:
- `~/drone-mesh-mapper/binaries/esp32s3-dual-rid.bin` - **Recommended** for AtomS3

### Step 3: Connect AtomS3

1. Connect AtomS3 via USB
2. Check detection:
   ```bash
   lsusb | grep -i espressif
   ls -la /dev/ttyACM0
   ```

### Step 4: Flash Firmware

```bash
~/.local/bin/esptool --chip esp32s3 --port /dev/ttyACM0 \
  --baud 460800 --before default_reset --after hard_reset \
  write_flash --flash-mode dio --flash-freq 80m --flash-size 8MB \
  0x0 ~/drone-mesh-mapper/binaries/esp32s3-dual-rid.bin
```

Expected output:
```
Writing at 0x00160000... (100 %)
Wrote 1497600 bytes ... Hash of data verified.
```

### Step 5: Verify Services

```bash
# Check symlink
ls -la /dev/remoteid

# Services should auto-start
systemctl status zmq-decoder dragonsync

# Test API
curl -s http://localhost:8088/drones | python3 -m json.tool
```

### Alternative Firmware Options
| Firmware | Chip | Features |
|----------|------|----------|
| esp32s3-dual-rid.bin | ESP32-S3 | WiFi + BLE5 dual-core |
| esp32c3-wifi-rid.bin | ESP32-C3 | WiFi only |
| mesh-mapper-ble.bin | ESP32-S3 | BLE only |

### Troubleshooting Flash

| Problem | Solution |
|---------|----------|
| "no supported devices" | Wrong chip or port |
| Permission denied | Add user to dialout: `sudo usermod -aG dialout $USER` |
| Connection failed | Try lower baud rate: `--baud 115200` |

## udev-Regel anpassen

Falls der AtomS3 andere USB-IDs hat:

```bash
# USB-IDs ermitteln
udevadm info -a -n /dev/ttyACM0 | grep -E "idVendor|idProduct"

# Regel anpassen
sudo nano /etc/udev/rules.d/99-remoteid.rules

# Neu laden
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Diagnose

### DragonSync API
```bash
# Active drones (primary endpoint)
curl -s http://localhost:8088/drones | python3 -m json.tool

# Konfiguration
curl -s http://localhost:8088/config | python3 -m json.tool
```

### MQTT testen
```bash
# Alle DragonSync-Nachrichten
mosquitto_sub -h 192.168.1.21 -t 'dragonsync/#' -v

# Home Assistant Discovery
mosquitto_sub -h 192.168.1.21 -t 'homeassistant/#' -v
```

### ZMQ prüfen
```bash
# Port 4224 lauscht?
ss -tnlp | grep 4224

# Verbindungen
ss -tnp | grep 4224
```

## Konfiguration

### config.ini (wichtige Einstellungen)
```ini
[SETTINGS]
# ZMQ vom ESP32
zmq_host = 127.0.0.1
zmq_port = 4224

# MQTT zu Home Assistant
mqtt_enabled = true
mqtt_host = 192.168.1.21
mqtt_port = 1883
mqtt_ha_enabled = true

# Drohnen-Tracking
max_drones = 70
inactivity_timeout = 120.0
```

### gps.ini
```ini
[gps]
use_static_gps = true
static_lat = 49.86625
static_lon = 10.83948
static_alt = 283
```

## Erweiterungen

### DJI DroneID (ohne Remote ID)
Benötigt zweiten RTL-SDR auf 2.4 GHz:

```bash
# Antsdr_DJI installieren
git clone https://github.com/alphafox02/antsdr_dji_droneid

# In config.ini aktivieren
# dji_enabled = true
```

### FPV-Signal-Erkennung (5.8 GHz)
Erkennt FPV-Drohnen ohne Remote ID:

```ini
fpv_enabled = true
fpv_zmq_port = 4226
```

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| `/dev/remoteid` fehlt | udev-Regel prüfen, USB-IDs checken |
| zmq-decoder startet nicht | `journalctl -u zmq-decoder -xe` |
| Keine Drohnen in HA | MQTT-Verbindung prüfen, Drohne in Reichweite? |
| DragonSync crash | `journalctl -u dragonsync -xe`, config.ini prüfen |

## Links

- [DragonSync GitHub](https://github.com/alphafox02/DragonSync)
- [DroneID GitHub](https://github.com/alphafox02/DroneID)
- [WiFi-RemoteID](https://github.com/lukeswitz/WiFi-RemoteID)
- [OpenDroneID](https://github.com/opendroneid/opendroneid-core-c)
- [EU Remote ID Regulation](https://www.easa.europa.eu/en/domains/civil-drones/drones-regulatory-framework-background/remote-identification)

## AtomS3R - Hardware-Upgrade (2026-01-30)

**Von AtomS3 zu AtomS3R:**
- **PSRAM:** 8MB eingebaut (vorher: 0 MB)
- **Flash:** 8MB (vorher: 8MB)
- **Performance:** Deutlich mehr gleichzeitige Drohnen trackbar
- **Firmware:** Gleiche (esp32s3-dual-rid.bin)

**Praktische Verbesserungen:**
- ✅ 10-50 Drohnen: Kein Problem mit PSRAM
- ✅ Große Events: Stabil auch bei vielen Drohnen
- ✅ Puffer für Burst-Empfang
- ✅ Zukunftssicher
