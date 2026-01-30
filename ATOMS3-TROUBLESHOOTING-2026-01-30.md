# AtomS3 Remote ID Receiver - Troubleshooting & Repair (2026-01-30)

**System:** Raspberry Pi 4 Model B | Debian 12 (bookworm)
**Hardware:** M5Stack AtomS3 ESP32-S3 (MAC: 48:27:e2:e3:fa:a8)
**Firmware:** drone-mesh-mapper esp32s3-dual-rid.bin (1.4 MB)

## Problem: USB Disconnect Loop + Watchdog Spam

### Symptome
- zmq-decoder inactive alle 5 Minuten
- feeder-watchdog Spam-Benachrichtigungen
- USB disconnect/reconnect alle ~3 Sekunden
- Logs: "Invalid image block, can't boot" / "TG0WDT_SYS_RST"

### Root Cause Analysis

**Zwei kombinierte Probleme:**

1. **Charge-Only USB-Kabel (Hauptproblem)**
   - Cable Health: 0%
   - Shorted Pin, nur 5V (VCC+GND)
   - **Keine D+/D- Datenleitungen → Keine USB-Kommunikation möglich**
   - ESP32 versuchte zu enumerieren → Reset Loop

2. **Korrupte AtomS3-Firmware (Sekundärproblem)**
   - "Invalid image block, can't boot"
   - Firmware-Flash beschädigt
   - Watchdog Timer Reset (TG0WDT_SYS_RST)

### Diagnose-Tools

```bash
# USB-Topologie prüfen
lsusb -t

# Disconnect-Rate messen
BEFORE=$(sudo dmesg | grep -c "1-1.4: USB disconnect")
sleep 60
AFTER=$(sudo dmesg | grep -c "1-1.4: USB disconnect")
echo "Disconnects/min: $(($AFTER - $BEFORE))"

# AtomS3 Raw-Output lesen
sudo systemctl stop zmq-decoder
timeout 5 cat /dev/remoteid

# USB-Kabel testen (mit BLE cableQU App)
# Erwartung: 100% Health, <200mΩ, alle Pins connected
```

### Lösung

#### 1. USB-Kabel austauschen
**Alt:** 20cm Verlängerungskabel
- Cable Health: 0%
- Nur Ladekabel (kein Datentransfer)

**Neu:** Geschirmtes USB3-Kabel
- Cable Health: 100%
- Widerstand: 109mΩ
- Pins: Vbus, GND, D+, D-, TX1+/-, RX1+/-, Shield
- Vollständige Abschirmung (wichtig gegen EMI von RTL-SDRs)

#### 2. Firmware Reflash

```bash
# 1. Stoppe Services
sudo systemctl stop zmq-decoder

# 2. Flash komplett löschen (wichtig bei Korruption!)
esptool --port /dev/remoteid erase_flash

# 3. Neue Firmware flashen
esptool --port /dev/remoteid \
  --chip esp32s3 \
  --baud 921600 \
  write_flash -z 0x0 /home/pi/drone-mesh-mapper/firmware/esp32s3-dual-rid.bin

# 4. Service starten
sudo systemctl start zmq-decoder

# 5. Überwachen (60s Test)
BEFORE=$(sudo dmesg | grep -c "1-1.4: USB disconnect")
sleep 60
AFTER=$(sudo dmesg | grep -c "1-1.4: USB disconnect")
echo "Disconnects in 60s: $(($AFTER - $BEFORE))"
# Erwartung: 0
```

#### 3. Service-Unit robuster gemacht

**Datei:** `/etc/systemd/system/zmq-decoder.service`

**Änderungen:**
- Entfernt: `BindsTo=dev-remoteid.device` (stoppte Service bei USB-Disconnect)
- Geändert: `Restart=always` (statt `no`)
- Geändert: `RestartSec=5s` (statt `30s`)
- Hinzugefügt: `StartLimitBurst=5`

**udev-Trigger-Service:** `/etc/systemd/system/udev-remoteid-trigger.service`
- Triggert udev-Regeln beim Boot
- Erstellt `/dev/remoteid` Symlink zuverlässig

### Ergebnis

✅ **USB-Verbindung stabil:** 0 Disconnects in 60 Sekunden
✅ **zmq-decoder funktional:** Service läuft dauerhaft
✅ **Keine Watchdog-Spam:** feeder-watchdog meldet keine Probleme mehr
✅ **Firmware bootet korrekt:** Keine "Invalid image block" Errors

**JSON Decode Errors sind normal**, wenn keine Remote ID Signale empfangen werden.

## Firmware-Update-Überwachung

**Repository:** `/home/pi/drone-mesh-mapper`
**Remote:** https://github.com/colonelpanichacks/drone-mesh-mapper

**Aktuelle Version:** 15af540
**Update-Check:** Integriert in `/usr/local/sbin/claude-respond-to-reports`

```bash
# Manuell prüfen
cd /home/pi/drone-mesh-mapper
git fetch --quiet
CURRENT=$(git rev-parse --short HEAD)
LATEST=$(git rev-parse --short origin/main)
if [ "$CURRENT" != "$LATEST" ]; then
    echo "Update verfügbar: $CURRENT -> $LATEST"
fi
```

**Bei Update:**
```bash
cd /home/pi/drone-mesh-mapper
git pull
# Neue Firmware in: firmware/esp32s3-dual-rid.bin
# Reflash wie oben beschrieben
```

## Lessons Learned

| Problem | Erkenntnis |
|---------|-----------|
| USB-Kabel | **Charge-Only Kabel haben keine D+/D- → USB-Kommunikation unmöglich** |
| Cable Health | BLE cableQU App ist perfektes Diagnose-Tool (Widerstand, Pins, Shield) |
| USB-Bus-Topologie | `lsusb -t` zeigt welche Geräte welchen Bus/Port nutzen |
| ESP32 Firmware-Flash | Bei "Invalid image block" → Flash komplett löschen (erase_flash) |
| esptool | Immer `-z` (komprimiert) und `0x0` (Startadresse 0) verwenden |
| systemd BindsTo | Stoppt Service wenn Gerät verschwindet → Nicht für USB-Geräte nutzen |
| Restart-Policy | `Restart=always` + `RestartSec=5s` = Automatische Reconnects |

## Monitoring

**Service-Status:**
```bash
systemctl status zmq-decoder dragonsync
```

**USB-Stabilität:**
```bash
sudo dmesg | grep "1-1" | tail -10
```

**ZMQ-Port:**
```bash
ss -tlnp | grep 4224
```

**DragonSync API:**
```bash
curl -s http://localhost:8088/drones | python3 -m json.tool
```

**Telegram Bot:**
```
/status  # Zeigt zmq-decoder Status in Hardware-Sektion
```

## Referenzen

- [drone-mesh-mapper GitHub](https://github.com/colonelpanichacks/drone-mesh-mapper)
- [WiFi-RemoteID](https://github.com/colonelpanichacks/WiFi-RemoteID)
- [mesh-detect](https://github.com/colonelpanichacks/mesh-detect)
- [CNX Software Article](https://www.cnx-software.com/2025/06/05/map-remote-id-enabled-drones-with-esp32-c3-s3-and-meshtastic-lora-modules/)
- [Hackster.io Project](https://www.hackster.io/colonelpanic/mesh-mapper-drone-remote-id-mapping-and-mesh-alerts-8e7c61)

---

**Zusammenfassung:** Das Problem war ein Charge-Only USB-Kabel (0% health) kombiniert mit korrupter Firmware. Lösung: Geschirmtes USB3-Kabel (100% health) + kompletter Firmware-Reflash. System jetzt stabil.
