# Quick Reference - Raspberry Pi ADS-B System

**Schnelle Referenz für häufige Aufgaben und Troubleshooting**

---

## 📡 System Status

```bash
# Vollständiger Status
systemctl is-active readsb piaware fr24feed adsbexchange-feed adsbfi-feed \
  opensky-feeder theairtraffic-feed rbfeeder airplanes-feed pfclient \
  mlathub adsbexchange-mlat adsbfi-mlat airplanes-mlat \
  tar1090 graphs1090 adsbexchange-stats \
  ogn-rf-procserv ogn-decode-procserv ogn2dump1090 \
  dragonsync atoms3-proxy \
  aircraft-alert-notifier ogn-balloon-notifier drone-alert-notifier \
  ntripcaster ntrip-proxy chronyd gps-mqtt-publisher

# Hardware
lsusb | grep -i RTL                    # RTL-SDR Dongles
ls -la /dev/remoteid                   # AtomS3
ls -la /dev/pps0                       # GPS PPS

# Logs
journalctl -p err --since "1 hour ago" --no-pager | tail -30
sudo tail -20 /var/log/feeder-watchdog.log
```

---

## 🛠️ Häufige Reparaturen

### Service restart
```bash
sudo systemctl restart <service>
sudo systemctl status <service> --no-pager
```

### OGN/FLARM (crasht häufig)
```bash
# Status prüfen
curl -s http://localhost:8081/status.html | grep "Aircrafts received"

# Neu starten
sudo systemctl restart ogn-rf-procserv ogn-decode-procserv
```

### DragonSync/Remote ID
```bash
# Drohnen live
curl -s http://localhost:8088/drones | python3 -m json.tool

# AtomS3 prüfen
ls -la /dev/remoteid
sudo systemctl status atoms3-proxy zmq-decoder dragonsync
```

### GPS/RTK
```bash
# PPS Status
chronyc sources | grep PPS
chronyc tracking

# NTRIP Clients
ss -tn | grep :5000

# GPS Status (non-invasive)
/usr/local/sbin/gps-status | jq
```

---

## 📚 Dokumentation Quick Links

### Lokal
- [CLAUDE.md](./CLAUDE.md) - System Overview & Befehle
- [GPS-AGNSS.md](./GPS-AGNSS.md) - GPS AGNSS Research
- [GPS-NTRIP-PROXY.md](./GPS-NTRIP-PROXY.md) - NTRIP Base Station
- [OGN-SETUP.md](./OGN-SETUP.md) - OGN/FLARM Setup
- [DRAGONSYNC.md](./DRAGONSYNC.md) - Remote ID Drohnen
- [LESSONS-LEARNED.md](./LESSONS-LEARNED.md) - Troubleshooting
- [CHANGELOG.md](./CHANGELOG.md) - System-Änderungen
- [MAINTENANCE-HISTORY.md](./MAINTENANCE-HISTORY.md) - Wartungs-Historie

### GitHub Resources
- [resources/README.md](./resources/README.md) - Quectel PDFs & GitHub-Projekte
- [raspberry-pi-adsb-docs](https://github.com/jleinenbach/raspberry-pi-adsb-docs) - Dieses Repo

---

## 🔍 GPS/GNSS Quick Reference

### Wichtige Befehle
```bash
# GPS Status
/usr/local/sbin/gps-status | jq '{fix: .fix, pps: .pps, ntrip: .ntrip}'

# PPS Synchronisation
chronyc sources -v | grep PPS
chronyc sourcestats | grep PPS

# NTRIP Base Station
systemctl status ntripcaster
ss -tn | grep :5000  # Clients

# GPS ohne NTRIP-Unterbrechung
# (NMEA-Zugriff NICHT möglich, str2str blockiert /dev/ttyAMA0)
```

### AGNSS Status
- **Implementiert:** ❌ Nein (24/7-Betrieb macht es unnötig)
- **Cold Start TTFF:** 60-90s (akzeptabel für Base Station)
- **Alternative:** ML1220 Backup Battery für Warm Start <5s
- **Dokumentation:** [GPS-AGNSS.md](./GPS-AGNSS.md)

### Wichtige Dateien
- `/etc/systemd/system/ntripcaster.service` - NTRIP Base Station
- `/etc/systemd/system/ntrip-proxy.service` - NTRIP Proxy (Port 5001)
- `/etc/chrony/chrony.conf` - NTP mit PPS
- GPS Position: 49.86625, 10.83948, 283m (RTK Fixed)

---

## 🐛 Troubleshooting Patterns

### Service hängt in "activating"
```bash
# AppArmor prüfen
sudo dmesg | grep "apparmor.*DENIED.*<servicename>"

# Wenn denied → Profil anpassen
sudo nano /etc/apparmor.d/<servicename>
sudo apparmor_parser -r /etc/apparmor.d/<servicename>
```

### Watchdog-Eskalation
```bash
# Eskalationen finden
ls /var/run/feeder-watchdog/*.given_up

# Service aufgegeben
grep "AUFGEGEBEN" /var/log/feeder-watchdog.log

# Claude übernimmt automatisch bei täglicher Wartung (07:00)
```

### USB-Probleme (RTL-SDR)
```bash
# USB-Statistiken
sudo dmesg | grep -i "usb\|disconnect" | tail -20

# RTL-SDR neu starten
sudo systemctl restart readsb
sudo systemctl restart ogn-rf-procserv
```

### Unterspannung
```bash
vcgencmd get_throttled
# 0x0     = OK
# 0x50000 = Unterspannung in Vergangenheit
# 0x50005 = Unterspannung JETZT! (kritisch)
```

---

## 🤖 Telegram Bot

```
/status  - System Health + Drohnen live
/stats   - Statistiken (ADS-B, OGN, Remote ID)
/log     - Letzte Wartung
/errors  - Fehleranalyse mit Claude
/flugzeug <hex> - Flugzeugdetails
/service [name] - Service-Status
/gps     - GPS/RTK Status
/do <text> - Schnelle Anweisung
/wartung - Volle Wartung
```

---

## 📊 Monitoring URLs

### Lokal
- ADS-B: http://192.168.1.21/tar1090/
- Graphs: http://192.168.1.21/graphs1090/
- OGN Status: http://localhost:8081/status.html
- DragonSync: http://localhost:8088/drones

### Online
- ADSBexchange: https://globe.adsbexchange.com/?icao=<hex>
- FlightAware: https://flightaware.com/
- adsb.fi: https://adsb.fi/
- OGN Live: http://live.glidernet.org/receiver-status/?id=SteGau

---

## 🔐 Security Checks

```bash
# CVEs
debsecan --suite bookworm --only-fixed

# Lynis Suggestions
sudo cat /var/log/lynis-report.dat | grep "^suggestion"

# rkhunter Warnings
sudo grep -i "warning" /var/log/rkhunter.log

# apt-listbugs
cat /etc/apt/preferences.d/apt-listbugs
```

---

## 🗂️ Wichtige Log-Dateien

```bash
# Services
journalctl -u <service> --since "1 hour ago"

# Watchdog
/var/log/feeder-watchdog.log

# Claude Wartung
/var/log/claude-maintenance/response-$(date +%Y-%m-%d).log

# Telegram Bot
/var/log/telegram-bot.log

# /do Queue
/var/log/do-queue-worker.log

# SD Health
/var/log/sd-health.log
```

---

## 🚨 Emergency Commands

### System hängt
```bash
# Nur falls SSH noch funktioniert
sudo reboot
```

### Service komplett kaputt
```bash
# Vollständiger Reset (nur im Notfall!)
sudo systemctl stop <service>
sudo rm -rf /var/cache/<service>/*
sudo systemctl start <service>
```

### GPS nach Reboot kein Fix
```bash
# Warte 2-3 Minuten (Cold Start ohne AGNSS)
watch -n 5 'chronyc sources | grep PPS'

# Falls nach 5min kein Fix
sudo systemctl restart ntripcaster chronyd
```

---

## 📖 Weitere Dokumentation

### System-spezifisch
- FEEDS.md - Feed-Konfiguration & Update-Prozeduren
- MONITORING.md - Monitoring & Alerting
- ATOMS3-FIRMWARE.md - AtomS3 Firmware-Flash

### Protokolle
- ADS-B: Mode-S, Beast, SBS1
- OGN/FLARM: APRS über glidernet.org
- Remote ID: ASTM F3411-22a (BLE/WiFi)
- NTRIP: RTCM3 RTK Corrections
- PAIR: Quectel proprietary (GPS AGNSS)

---

**Letzte Aktualisierung:** 2026-02-04
