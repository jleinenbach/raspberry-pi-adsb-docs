# System Maintenance Assistant

**Raspberry Pi 4 Model B** | Debian 12 (bookworm)
**Standort:** 49.86625, 10.83948 | 283m

> **Dokumentation:** `~/docs/FEEDS.md` | `~/docs/MONITORING.md` | `~/docs/OGN-SETUP.md` | `~/docs/HOME-ASSISTANT.md` | `~/docs/DRAGONSYNC.md` | `~/docs/ATOMS3-FIRMWARE.md` | `~/docs/PRESENCE-DETECTION.md` | `~/docs/GPS-NTRIP-PROXY.md`
> 
> **Historie:** `~/docs/CHANGELOG.md` | `~/docs/MAINTENANCE-HISTORY.md` | `~/docs/LESSONS-LEARNED.md`

## 🛩️ Drei parallele Luftverkehrs-Empfänger

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. ADS-B (1090 MHz)          - Verkehrsflugzeuge               │
│    RTL-SDR → readsb → Upload Feeds + MLAT + tar1090           │
│    ✅ Aktiv | 9 Upload Feeds | MLAT mit 4 Servern             │
├─────────────────────────────────────────────────────────────────┤
│ 2. OGN/FLARM (868 MHz)       - Segelflugzeuge & Gleitschirme  │
│    RTL-SDR V4 → ogn-rf-procserv → Port 50010                  │
│                  ↓                                              │
│              ogn-decode-procserv → glidernet.org (APRS)        │
│                  ↓                                              │
│              ogn2dump1090 (APRS) → readsb → tar1090           │
│    ✅ Aktiv | Station "SteGau" online | procServ-überwacht   │
├─────────────────────────────────────────────────────────────────┤
│ 3. Remote ID (BLE)           - Drohnen                         │
│    AtomS3 → atoms3-proxy → DragonSync → Home Assistant        │
│    ✅ Aktiv | Lokal (kein öffentliches Drohnen-Tracking)      │
└─────────────────────────────────────────────────────────────────┘

Wichtig: ADS-B und OGN werden an Community-Netzwerke hochgeladen.
         Remote ID bleibt lokal (Datenschutz/Rechtslage).
```

---

## MANDATORY: Status-Abfrage

**Trigger:** "Status", "Systemzustand", "Was steht an?", "Wartung", "Health"

```bash
# Errors 24h + CVEs
journalctl -p err --since "24 hours ago" --no-pager | grep -v "^--" | tail -30
debsecan --suite bookworm --only-fixed 2>/dev/null | head -30

# Security Tools
sudo cat /var/log/lynis-report.dat | grep "^suggestion" | head -25
sudo grep -i "warning" /var/log/rkhunter.log 2>/dev/null | tail -10

# Wartungsergebnis + Watchdog
sudo cat /var/log/claude-maintenance/response-$(date +%Y-%m-%d).log 2>/dev/null | tail -60
sudo tail -20 /var/log/feeder-watchdog.log 2>/dev/null

# Services (21 Services nach Kategorie)
# Core ADS-B
systemctl is-active readsb
# Upload Feeds (9)
systemctl is-active piaware fr24feed adsbexchange-feed adsbfi-feed opensky-feeder theairtraffic-feed rbfeeder airplanes-feed pfclient
# MLAT Services (4)
systemctl is-active mlathub adsbexchange-mlat adsbfi-mlat airplanes-mlat
# Web Services (3)
systemctl is-active tar1090 graphs1090 adsbexchange-stats
# OGN Services (3)
systemctl is-active ogn-rf-procserv ogn-decode-procserv ogn2dump1090
# DragonSync
systemctl is-active dragonsync
# Hardware
lsusb | grep -i RTL

# apt-listbugs: Blockierte Pakete wegen kritischer Bugs?
cat /etc/apt/preferences.d/apt-listbugs 2>/dev/null | grep -v "^#" | head -10
```

**Format:**
```
## System Status [DATUM]
### Current Issues / New Recommendations / Pending / Verification
```

**Danach:** CLAUDE.md aktualisieren (Declined/Pending/Implemented)

---

## 📋 Wartungs-Historie

Siehe `~/docs/MAINTENANCE-HISTORY.md` für:
- **Declined Recommendations** - Abgelehnte Empfehlungen (nicht erneut vorschlagen)
- **Pending Recommendations** - Ausstehende Wartungsarbeiten

---

## 📝 System-Änderungen

Siehe `~/docs/CHANGELOG.md` für vollständige Historie aller implementierten Änderungen:
- Security & Hardening
- Service-Konfigurationen
- Monitoring & Automation
- Hardware-Integration (OGN, GPS, Remote ID)
- Skript-Audits & Fixes

---

## Telegram Bot
**Bot:** @adsb_feeder_alerts_bot | **Daemon:** `systemctl status telegram-bot`

| Befehl | Beschreibung |
|--------|--------------|
| `/help` | Zeigt Hilfe zu allen verfügbaren Befehlen |
| `/status` | System Health + Drohnen live |
| `/stats` | Statistiken (ADS-B, OGN/FLARM, Remote ID) |
| `/log` | Letzte Wartung |
| `/errors [1h\|24h\|7d]` | Intelligente Fehleranalyse mit Claude + interaktive Buttons |
| `/flugzeug <hex>` | Flugzeugdetails (ICAO hex → Registration, Typ, Live-Daten, tar1090 Link) |
| `/service [name]` | Service-Status (ohne Parameter: Liste mit Ampeln, mit Parameter: Details) |
| `/gps` | GPS/RTK Status (Hardware, PPS, Satelliten, Almanach, NTRIP, Services) |
| `/frage` | Zeigt offene Fragen von Claude (Zwei-Claude-Architektur) |
| `/do <text>` | Queue-Anweisung (auch bei aktiver Session) |
| `/wartung` | Volle Wartung (~5min) |
| `/abbrechen` | Session abbrechen |

### Lock-Mechanismen (2026-01-30)
- **Bot-Instance-Lock:** PID-File verhindert mehrere Bot-Instanzen (`/var/run/telegram-bot.pid`)
- **Command-Lock:** Pro-Befehl Lock verhindert Doppel-Verarbeitung innerhalb 3 Sekunden (`/var/run/telegram-command.lock.$cmd`)
- **Array-basierte Updates:** Keine Subshell-Probleme mehr bei Update-Verarbeitung

### /do Queue-System
```
/do Befehl → Blacklist-Check → Queue → Timer (2min) → Sekretär → Techniker → Telegram
```

**Dateien:**
- `/var/lib/claude-pending/do-queue.json` - Queue-Speicher
- `/usr/local/sbin/do-queue-worker` - Verarbeitung (User: pi)
- `do-queue-worker.timer` - Alle 2 Minuten

**Logs:** `/var/log/do-queue-worker.log`

**Wichtig:** `/home/pi/.claude/` muss User `pi` gehören (nicht root)!

### /errors - Intelligente Fehleranalyse (2026-02-04)
**Status:** ✅ Produktiv

Claude-gestützte Fehleranalyse mit interaktiven Buttons für schnelle Diagnose und Reparatur.

**Architektur:**
```
/errors → Backend (error-troubleshooter) → journalctl + Claude
                         ↓
         JSON (summary, problems, raw_output)
                         ↓
         Telegram Inline Keyboard (5 Buttons)
                         ↓
         Callback Query → Aktionen
```

**Backend:** `/usr/local/sbin/error-troubleshooter`
- `analyze <timeframe>` - Sammelt Errors via journalctl, analysiert mit Claude
- `check-service <name>` - Service Health Check
- `usb-stats` - USB-Statistiken (Disconnects, Geräte)
- `restart-service <name>` - Service-Neustart

**Buttons:**
1. **🔍 Details anzeigen** - Zeigt vollständige Claude-Analyse
2. **🔧 Automatisch reparieren** - Startet Wartung mit Fokus auf erkannte Fehler
3. **📊 Service-Check** - Prüft readsb Service-Status
4. **📈 USB-Statistik** - Zeigt USB-Disconnects letzte 24h
5. **❌ Abbrechen** - Beendet Interaktion

**Intelligente Klassifikation:**
- ✅ **Keine Errors:** "System läuft stabil"
- 🟢 **Harmlose Errors:** Erkennt collectd RRD timing, FFTW benchmarking
- 🔴 **Echte Probleme:** Zeigt Top 3 Probleme mit Buttons für Aktionen

**Kontext-Speicherung:** `/run/telegram-errors-context.json` (für Callback-Buttons)

**Claude-Prompt:** Analysiert Errors kurz und prägnant, ignoriert bekannte harmlose Warnungen

### /flugzeug - Flugzeugdetails nachschlagen (2026-02-04)
**Status:** ✅ Produktiv

Schnelle Flugzeugabfrage via ICAO hex mit Stammdaten und Live-Tracking.

**Backend:** `/usr/local/sbin/aircraft-lookup`
- Sucht in readsb aircraft.json (Live-Daten)
- Sucht in tar1090 aircraft.csv (Stammdaten: Registration, Typ, Beschreibung)
- Generiert tar1090 Direkt-Link

**Ausgabe:**
```
✈️ Flugzeug 3c6444

Stammdaten
📋 Registration: D-AIBD
🛩️ Typ: A319 - AIRBUS A-319

Live-Daten 🟢
📞 Callsign: DLH123
📏 Höhe: 37000 ft (11278 m)
🚀 Speed: 450 kt (833 km/h)
🧭 Track: 285°
📍 Position: 49.123, 10.456
⏱ Gesehen: vor 5s
📊 Messages: 1234
📡 RSSI: -15.2 dB
🔢 Squawk: 1234
🟢 Emergency: none

🔗 tar1090 öffnen
```

**Features:**
- Automatische Normalisierung (Groß-/Kleinschreibung, 0x-Prefix)
- Validierung (6 hexadezimale Zeichen)
- Zeigt "Aktuell nicht sichtbar" wenn Flugzeug außer Reichweite
- Emergency-Anzeige (🟢 normal, 🔴 emergency)
- Metrische + imperiale Einheiten (ft/m, kt/km/h)

**Verwendung:**
- `/flugzeug 3c6444` - Deutsche Lufthansa
- `/flugzeug 4082e7` - British Airways
- ICAO hex aus tar1090 kopieren

### /service - Service-Diagnose (2026-02-04)
**Status:** ✅ Produktiv

Schnelle Service-Übersicht oder detaillierte Diagnose einzelner Services.

**Backend:** `/usr/local/sbin/service-info`
- Liest systemd Service-Status, Uptime, Restarts, Logs
- Gibt JSON zurück für Telegram-Formatierung

**Zwei Modi:**

**1. Ohne Parameter: Liste aller Services**
```
/service

→ Zeigt alle 29 Services nach Kategorie mit Ampeln:
🟢 aktiv | 🔴 failed | ⚫ inactive | 🟡 activating

Kategorien:
- Core (readsb)
- Upload Feeds (9 Services)
- MLAT (4 Services)
- Web (3 Services)
- OGN/FLARM (3 Services)
- DragonSync (2 Services)
- Alerts (3 Services)
- GPS/RTK (4 Services)
```

**2. Mit Parameter: Detaillierte Service-Info**
```
/service readsb

→ Detaillierte Diagnose:
🔧 Service: readsb

Status
🟢 Status: active
🟢 Enabled: enabled
🆔 PID: 985714
⏱ Uptime: 5h 15m
🔄 Restarts: 0
💾 Memory: 45 MB (falls verfügbar)
📊 Tasks: 9

Letzte Logs
[Letzte 10 Log-Zeilen]
```

**Features:**
- **Status-Icons:** 🟢 active, 🔴 failed, ⚫ inactive, 🟡 activating
- **Uptime-Format:** Automatisch d/h/m je nach Dauer
- **Memory/Tasks:** Anzeige falls von systemd erfasst
- **Problem-Diagnose:** Result + Exit Code bei Fehlern
- **Log-Auszug:** Letzte Zeilen für schnelle Diagnose

**Verwendung:**
- `/service` - Komplette Übersicht mit Ampeln
- `/service readsb` - Details zu readsb
- `/service piaware` - Details zu piaware
- Service-Namen ohne .service Extension

### /gps - GPS/RTK Status (2026-02-04)
**Status:** ✅ Produktiv

Umfassender GPS-Status ohne NMEA-Zugriff (GPS-Device durch str2str blockiert).

**Backend:** `/usr/local/sbin/gps-status`
- Sammelt GPS-Informationen non-invasiv (kein Service-Stop)
- Daten aus chrony (PPS), systemd (Services), heuristische Satelliten-Schätzung
- Gibt vollständiges JSON mit allen GPS-Metriken zurück

**Datenquellen:**
```
chrony (PPS)     → Zeitgenauigkeit, Stratum, Offset, Samples
systemd          → Service-Status (ntripcaster, ntrip-proxy, chronyd, gps-mqtt)
ntripcaster      → Client-Anzahl, Uptime
Heuristik        → Satelliten-Schätzung basierend auf PPS-Qualität
Konfiguration    → RTK Fixed Position (49.86625, 10.83948, 283m)
```

**Ausgabe:**
```
🛰 GPS/RTK Status

Hardware
📡 Waveshare LC29H (Dual-Band RTK GNSS)
🔌 /dev/ttyAMA0 (GPIO UART)
⚡ PPS: /dev/pps0 (GPIO 18)

GPS Fix
📍 Fix: 3D
🎯 Qualität: RTK Fixed
📊 PDOP: excellent

Position (RTK Fixed)
🌍 49.86625, 10.83948
📏 283 m

PPS Zeitgenauigkeit 🟢
⚡ Stratum: 1 (GPS-locked)
⏱ Offset: +0ns (sub-nanosecond)
📈 Samples: 19
🕐 System Time: 0.000000155 seconds

Satelliten
🛰 Schätzung: 12-20 visible (Multi-GNSS: GPS+GLO+GAL+BDS)
📶 Signalqualität: excellent (sub-nanosecond)

GNSS-Systeme
🌐 GPS(L1+L5), GLONASS, Galileo, BeiDou, QZSS

Almanach & Ephemeris
📅 Almanach: valid
📡 Ephemeris: current
🌐 A-GPS: not configured (24/7 operation)

NTRIP Base Station 🟢
👥 Clients: 0
⏱ Uptime: 23h 5m

Services
🟢 ntripcaster
🟢 ntrip-proxy
🟢 chronyd
🟢 gps-mqtt-publisher

Software
📦 RTKLIB str2str: installed
⏰ chrony: 4.3
📍 gpsd: 3.22
```

**Features:**
- **Non-Invasive:** Kein GPS-Device-Zugriff nötig (str2str blockiert /dev/ttyAMA0)
- **PPS-basiert:** Zeitgenauigkeit im Nanosekunden-Bereich
- **Satelliten-Heuristik:** Schätzung basierend auf PPS-Qualität (LC29H Dual-Band: 12-20 Satelliten)
- **Multi-GNSS:** GPS L1+L5, GLONASS, Galileo, BeiDou, QZSS
- **Almanach-Status:** Inferiert aus PPS Stratum 1 (bei 24/7 Betrieb automatisch aktuell)
- **NTRIP-Monitoring:** Base Station Status, Client-Anzahl, Uptime
- **Service-Übersicht:** Alle 4 GPS-relevanten Services mit Status-Icons

**Limitierungen:**
- **Keine direkte Satelliten-Zählung:** GPS-Device durch str2str blockiert, Schätzung via PPS-Qualität
- **Keine Satelliten-Details:** Elevation, Azimuth, SNR nicht verfügbar ohne Device-Zugriff
- **Kein echter A-GPS:** LC29H unterstützt AGNSS, aber nicht konfiguriert (nicht nötig bei 24/7 Betrieb)

**Technische Details:**
- **Waveshare LC29H:** Dual-Band RTK GNSS (L1+L5)
- **PPS-Pin:** GPIO 18 (/dev/pps0) für Nanosekunden-Zeitsync
- **GPS-Device:** /dev/ttyAMA0 (115200 Baud, belegt durch str2str)
- **RTK Position:** Fixed Base Station (49.86625, 10.83948, 283m)
- **Stratum 1:** Direkt GPS-synchronisiert (beste NTP-Qualität)

**Verwendung:**
- `/gps` - Vollständiger GPS-Status

---

## Zwei-Claude-Architektur
```
User ←→ Sekretär-Claude (nur Read/Grep) ←→ Techniker-Claude (Bash/Edit)
```

**Sekretär:** Validiert User-Input, blockiert gefährliche Befehle
**Techniker:** Führt genehmigte Wartung aus

---

## MLAT-Hub (2026-01-26, Fixed 2026-02-12)
Dedupliziert MLAT-Ergebnisse von 4 Clients bevor sie an readsb gehen.

**Was ist MLAT?** Multilateration berechnet Positionen von Mode-S-Flugzeugen (ohne ADS-B)
durch Vergleich der Empfangszeiten mehrerer Empfänger. Die Berechnung erfolgt auf den
**externen MLAT-Servern**, nicht lokal.

```
adsbexchange-mlat ─┐
adsbfi-mlat ───────┼──► mlathub:39004 ──► readsb:30107
airplanes-mlat ────┤    (dedupliziert)     (remote=1 ✓)
piaware-mlat ──────┘
```

| Komponente | Details |
|------------|---------|
| Service | `mlathub.service` (zweite readsb-Instanz) |
| Input | Port 39004 (Beast von MLAT-Clients) |
| Output | Port 30107 (Beast zu readsb, **Outbound-Connector**) |
| Konfiguration | `/etc/systemd/system/mlathub.service` |

**WICHTIG (2026-02-12 Fix):** mlathub muss als **Outbound-Connector** zu readsb verbinden,
damit Nachrichten als `remote=1` markiert werden. Nur dann erkennt readsb den MAGIC_MLAT_TIMESTAMP
(0xFF004D4C4154) und setzt `SOURCE_MLAT` für Positionen im JSON-mlat-Array.

### Wie funktioniert die Deduplizierung?
Der mlathub (readsb) wählt **NICHT** das genaueste Ergebnis - er nimmt das **neueste gültige**:

| Prüfung | Beschreibung |
|---------|--------------|
| Zeitstempel | Neuere Daten ersetzen ältere |
| speed_check | Position physikalisch möglich? (Distanz/Zeit plausibel) |
| Quellenhierarchie | ADS-B > MLAT > TIS-B (aber MLAT vs MLAT = gleichwertig) |

**Nicht implementiert:** Genauigkeitsvergleich, Gewichtung, Mittelwertbildung.

### Warum erscheinen MLAT-Positionen nur sporadisch?
MLAT-Positionen erscheinen im tar1090 MLAT-Filter **NUR** wenn:
1. **Mode-S-only Flugzeuge** (ohne ADS-B) in Reichweite sind
2. Diese von **mehreren Empfängern** in der Region gesehen werden
3. Der MLAT-Server erfolgreich eine Position berechnet hat
4. **Keine bessere Position** vorhanden ist (ADS-B wird immer bevorzugt)

Die MLAT-Clients empfangen ~12-30 pos/min, aber diese sind meist für Flugzeuge mit ADS-B
(zur Redundanz). Im JSON erscheinen nur Positionen für Mode-S-only Flugzeuge.

### Was verbessert MLAT-Genauigkeit wirklich?
| Faktor | Einfluss | Lokal umsetzbar? |
|--------|----------|------------------|
| Mehr Empfänger in Region | ⬆️⬆️⬆️ | Nein (Community) |
| Geografische Verteilung | ⬆️⬆️ | Nein |
| GPS-Zeitsync (PPS) | ⬆️⬆️ | Ja (Hardware ~50€) |
| Besserer Empfang | ⬆️ | Bereits optimiert |

**Diagnose:**
```bash
# Verbindungen prüfen
ss -tnp | grep 39004
# Service-Status
systemctl status mlathub
```

---

## DragonSync - Drohnen-Erkennung (2026-01-27)
**✅ Betriebsbereit** - AtomS3 geflasht mit drone-mesh-mapper Firmware (esp32s3-dual-rid.bin)

Erkennt Drohnen via WiFi/Bluetooth Remote ID (EU-Pflicht seit 2024) und sendet an Home Assistant.

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ AtomS3 (ESP32)  │────▶│  zmq-decoder    │────▶│   DragonSync    │
│ Remote ID Recv. │USB  │  Port 4224      │ZMQ  │   → MQTT → HA   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

| Komponente | Details |
|------------|---------|
| Service | `dragonsync.service` (läuft dauerhaft) |
| Service | `zmq-decoder.service` (enabled, startet automatisch) |
| Config | `/home/pi/DragonSync/config.ini` |
| GPS | `/home/pi/DragonSync/gps.ini` (statisch) |
| MQTT | 192.168.1.21:1883 → Home Assistant |
| API | http://localhost:8088/drones |
| udev | `/dev/remoteid` → AtomS3 |

### Home Assistant Entities
DragonSync erstellt automatisch via MQTT Discovery:
- `device_tracker.drone_<id>` - Drohnen-Position
- `device_tracker.pilot_<id>` - Piloten-Position
- `sensor.drone_<id>_*` - Höhe, Geschwindigkeit, RSSI

### AtomS3 Hardware
**Angeschlossen und betriebsbereit** → `~/docs/DRAGONSYNC.md`

| Detail | Wert |
|--------|------|
| Chip | ESP32-S3 (QFN56) rev 0.2 |
| MAC | 48:27:e2:e3:fa:a8 |
| Firmware | drone-mesh-mapper esp32s3-dual-rid.bin |
| USB | `/dev/remoteid` → `/dev/ttyACM0` |

```bash
# Status prüfen:
ls -la /dev/remoteid
systemctl status zmq-decoder dragonsync
curl -s http://localhost:8088/drones | python3 -m json.tool
```

### Diagnose
```bash
# DragonSync Status
systemctl status dragonsync
curl -s http://localhost:8088/status | python3 -m json.tool

# MQTT testen
mosquitto_sub -h 192.168.1.21 -t 'dragonsync/#' -v

# ZMQ Verbindung (wenn AtomS3 angeschlossen)
ss -tnlp | grep 4224
```

### Monitoring
- Telegram /status: Service-Status + Live-Drohnenanzahl ("DragonSync - Drohnen: X aktiv")
- Telegram /stats: Drohnen aktuell + Letzte 24h (unique MACs)
- daily-summary: Drohnen 24h (unique MACs aus journalctl)
- feeder-watchdog: Überwacht dragonsync + zmq-decoder Services
- API: http://localhost:8088/drones (Echtzeit-Daten)

---

## Self-Healing Regeln

### OHNE Rückfrage reparieren
- Feeder-Services nicht laufend → restart
- Services nach Updates kaputt → repair
- CVE fixes verfügbar → apt upgrade
- Broken symlinks/permissions → fix

### MIT Rückfrage
- wiedehopf-Updates (readsb, tar1090, graphs1090)
- Neue AppArmor-Profile
- Wesentliche Config-Änderungen

### Nur melden
- Hardware-Probleme (SDR nicht erkannt)
- Netzwerk-Probleme
- Unbekannte Security-Warnungen

### AppArmor-Diagnose (IMMER bei Dienststörungen!)
```bash
sudo dmesg --since "10 minutes ago" | grep "apparmor.*DENIED.*[dienstname]"
```
Symptome: Service hängt in `activating`, Funktionen fehlen

### Watchdog-Eskalationen (Priorität!)
```bash
grep -E "ESKALATION|AUFGEGEBEN" /var/log/feeder-watchdog.log
```
→ Tiefe Diagnose, nicht nur restart

### Spannungsüberwachung (USB/Netzteil)
```bash
vcgencmd get_throttled
```
**Hex-Code-Interpretation:**
- `0x0` = 🟢 **OK** - Keine Probleme
- `0x50000` oder `0x10000` = 🟡 **Warnung** - Unterspannung in Vergangenheit
- `0x50005` oder `0x1` = 🔴 **Kritisch** - Unterspannung JETZT!

**Bit-Bedeutung:**
- Bit 0 (`& 0x1`): Aktuell Unterspannung
- Bit 16 (`& 0x10000`): Jemals Unterspannung seit Boot

**Überwacht in:**
- Telegram `/status` (Hardware-Sektion)
- `claude-respond-to-reports` (Stromversorgungs-Sektion)
- `daily-summary` (System-Sektion)

**Ursachen für Unterspannung:**
- Schwaches Netzteil (<3A bei Pi 4)
- USB-Überlastung (zu viele Geräte)
- Defektes USB-C-Kabel
- RTL-SDR an USB 2.0 Port (sollte USB 3.0 sein)

---

## Drei getrennte Luftverkehrs-Datenströme

**Das System empfängt drei verschiedene Arten von Luftfahrzeugen:**

### 1. ADS-B (1090 MHz) - Bemannte Flugzeuge
```
RTL-SDR (1090 MHz) → readsb → Upload Feeds + MLAT → tar1090
```
**Was:** Verkehrsflugzeuge, Business Jets, Militär (mit Transponder)
**Reichweite:** 200-400 km
**Upload an:** FlightAware, ADSBexchange, adsb.fi, OpenSky, TheAirTraffic, etc.
**MLAT:** Ja (Position ohne ADS-B berechenbar)

### 2. OGN/FLARM (868 MHz) - Segelflugzeuge & Gleitschirme
```
Upload: RTL-SDR V4 → ogn-rf → ogn-decode → glidernet.org (APRS)
                              (VirusPilot ARM64 Build)
                                      ↓
Empfang:                    ogn2dump1090 (100km-Filter)
                                      ↓
                            readsb:30008 → tar1090
```
**Was:** Segelflugzeuge, Motorsegler, Gleitschirme, Drachen
**Reichweite Upload:** ~100 km (eigene RF-Empfänge)
**Reichweite Empfang:** 100 km Radius (APRS-Filter)
**Upload:** ✅ **Station "SteGau" online und stabil** (VirusPilot ARM64 Binary)
**Lokal:** tar1090 Visualisierung (separate Tracks mit `~` Präfix)
**MLAT:** Nein (OGN nutzt eigenes APRS-Netzwerk)
**Status:** ✅ Aktiv (VirusPilot ARM64 Build löst Crash-Problem)
**Live-Karte:** http://live.glidernet.org/receiver-status/?id=SteGau
**Binary:** v0.3.2.arm64 (22. März 2024, VirusPilot/ogn-pi34)
**Fix-Datum:** 2026-02-10 (vorher: Crashes alle ~20s, jetzt stabil)

### 3. Remote ID (BLE/WiFi) - Drohnen
```
AtomS3 (BLE) → zmq-decoder → DragonSync → Home Assistant (MQTT)
ODER: ESPHome Proxy (BLE) → ha-opendroneid → Home Assistant (MQTT)
```
**Was:** Drohnen mit EU-Remote-ID-Pflicht (seit 2024)
**Reichweite:** ~500m (Bluetooth)
**Upload an:** ❌ **KEIN öffentliches Netzwerk verfügbar**
**Warum kein Upload?**
  - Datenschutz/Rechtslage: EU/USA verbieten unbefugte Weitergabe
  - Keine Community-Plattform (nur kommerzielle USS-Systeme für Behörden)
  - Kein Flugsicherungs-Bedarf (max. 120m Höhe)
**Lokal:** Home Assistant (MQTT), DragonSync (TAK/ATAK)
**Status:** ✅ Aktiv → `docs/DRAGONSYNC.md`

### Upload-Möglichkeiten im Vergleich

| Aspekt | ADS-B | OGN/FLARM | Remote ID |
|--------|-------|-----------|-----------|
| **Protokoll** | Mode-S/ADS-B (1090 MHz) | FLARM/FANET (868 MHz) | ASTM F3411 (BLE/WiFi) |
| **Adressierung** | ICAO 24-bit | FLARM-ID | UAS-ID |
| **Community-Upload** | ✅ FlightAware, ADSBexchange, etc. | ✅ **glidernet.org** | ❌ Rechtlich nicht erlaubt |
| **Upload-Methode** | Beast/SBS zu Feeds | APRS zu OGN-Servern | Keine öffentliche Plattform |
| **Live-Tracking** | ✅ Öffentlich sichtbar | ✅ live.glidernet.org | ❌ Nur lokale Behörden |
| **Zweck** | Flugsicherung | Kollisionsvermeidung Segelflug | Drohnen-Identifikation (Datenschutz) |

---

## Überwachte Services (28)
*Bot, Watchdog, Wartung müssen synchron sein und nach Kategorien trennen!*

### Core ADS-B (1)
readsb

### Upload Feeds (9)
piaware, fr24feed, adsbexchange-feed, adsbfi-feed, opensky-feeder, theairtraffic-feed, rbfeeder, airplanes-feed, pfclient

**Wichtig:** Diese Feeds empfangen NUR ADS-B-Daten (1090 MHz).

### MLAT Services (4)
mlathub, adsbexchange-mlat, adsbfi-mlat, airplanes-mlat

### Web Services (3)
tar1090, graphs1090, adsbexchange-stats

### OGN Services (3)
ogn-rf-procserv, ogn-decode-procserv, ogn2dump1090

### DragonSync (2)
dragonsync, atoms3-proxy

### Alert Services (3)
aircraft-alert-notifier, ogn-balloon-notifier, drone-alert-notifier

### GPS Services (3)
ntripcaster, ntrip-proxy, chronyd


**Sonderfall:** `wifi-presence-detector` wird separat überwacht (nur wenn atoms3-proxy läuft)

**Sync-Dateien:**
- `/usr/local/sbin/telegram-bot-daemon` → `SERVICES="..."`
- `/usr/local/sbin/feeder-watchdog` → `FEEDERS="..."` + `check_atoms3()`
- `/usr/local/sbin/claude-respond-to-reports` → `for svc in ...`

---

## CVE pip-Patcher

**Skript:** `/usr/local/sbin/cve-pip-patcher`
**Log:** `/tmp/cve-pip-patcher.log`
**Aufruf:** Automatisch bei jeder Wartung (`claude-respond-to-reports`)

### Funktionsweise
- Prüft Python-Pakete mit CVEs via debsecan
- **Auto-Modus** (Wartung): Patch-Updates automatisch, Major/Minor im Report
- **Claude-Wartung**: Bei Major/Minor-Updates prüft Claude Breaking Changes und führt sicher aus
- Prozedur im Wartungsskript: `CVE-PIP-UPDATE PROZEDUR`

### Überwachte Pakete
| Paket | Min-Fix-Version | Status |
|-------|-----------------|--------|
| aiohttp | 3.9.2 | ✓ Gefixt (3.13.3) |
| urllib3 | 1.26.18 | ✓ Gefixt (2.6.3) |
| requests | 2.32.0 | ✓ Gefixt (2.32.5) |
| pycryptodomex | 3.19.0 | ✓ Gefixt (3.23.0) |

### Neues Paket hinzufügen
In `/usr/local/sbin/cve-pip-patcher` Array `PYTHON_PACKAGES` erweitern:
```bash
"python3-PAKET:pip-name:min-fix-version"
```

---

## Checkliste: Neuen Feed hinzufügen
1. Installer + Koordinaten konfigurieren
2. **ALLE DREI** Service-Listen erweitern
3. Update-Check in `/etc/cron.d/` einrichten
4. AppArmor-Profil erstellen
5. CLAUDE.md + docs/FEEDS.md aktualisieren

---

## GitHub Repositories

### ha-opendroneid - Home Assistant Custom Integration
**Repository:** https://github.com/jleinenbach/ha-opendroneid
**Lokal:** `/home/pi/ha-opendroneid/`

Home Assistant Custom Integration zur Erkennung von Drohnen via BLE Remote ID (ASTM F3411-22a).

**Features:**
- BLE Remote ID Empfang über ESPHome Bluetooth Proxies
- DragonSync ZMQ Integration (Port 4224)
- Automatische device_tracker Entity-Erstellung für Drohnen
- Entity Cleanup nach konfigurierbarer Zeit (Standard: 30 Tage)
- Non-blocking ZMQ Operations (Executor-basiert)
- Platinum Quality Code Standards (ruff, mypy)

**Wichtige Commits (2026-01-28):**
- `57ab47c` - Konfigurierbare Entity-Cleanup (30 Tage)
- `3e178a3` - Fix blocking calls in event loop (ZMQ in Executor)

**Installation:**
```bash
cd /home/pi/ha-opendroneid
git pull
# In HA: HACS → Custom repositories → ha-opendroneid
```

### rtl-sdr-blog - RTL-SDR Blog V4 Treiber
**Repository:** https://github.com/rtlsdrblog/rtl-sdr-blog
**Lokal:** `/home/pi/rtl-sdr-blog/`
**Installiert:** v1.3.6 (kompiliert, `/usr/local/lib/`)

Modified Osmocom drivers mit Optimierungen für RTL-SDR Blog V3 und V4 Dongles.

**Warum nötig:**
- Debian librtlsdr (0.6.0-4) ist von 2012/2013, kennt RTL-SDR Blog V4 nicht
- R828D-Tuner (V4) braucht spezielle Initialisierung
- Alte Library verursacht "[R82XX] PLL not locked" Fehler
- V4-Library erkennt `Blog V4` und `R828D` explizit

**Features der V4-Library:**
- Korrekte R828D-Tuner-Initialisierung
- Verbesserte SNR-Performance
- Auto Direct Sampling
- Bias-T-Unterstützung (rtl_biast)

**Update-Check:**
- Automatisch im Wartungsskript (`claude-respond-to-reports`)
- Prüft auf neue GitHub-Releases
- Warnt bei verfügbaren Updates

**Update-Prozedur:**
```bash
cd ~/rtl-sdr-blog
git pull
cd build
sudo make clean
sudo cmake ../ -DINSTALL_UDEV_RULES=ON
sudo make -j4
sudo make install
sudo ldconfig
# Services neu starten: ogn-rf, ogn-decode, rbfeeder
```

### raspberry-pi-adsb-docs - System-Dokumentation
**Repository:** https://github.com/jleinenbach/raspberry-pi-adsb-docs
**Lokal:** `/home/pi/docs/`

Dokumentation und Monitoring-Skripte für das ADS-B Feeder System.

**Inhalte:**
- System-Dokumentation (FEEDS.md, MONITORING.md, DRAGONSYNC.md, etc.)
- Monitoring-Skripte (feeder-watchdog, wartungs-watchdog, etc.)
- Telegram-Bot-Integration
- Systemd Service Units

**Skripte (sanitized, keine Secrets):**
- `feeder-watchdog` - Überwacht 17 Feeder-Services
- `wartungs-watchdog` - Überwacht Claude-Wartung
- `claude-respond-to-reports` - Wartungsautomatisierung
- `telegram-bot-daemon` - Telegram-Bot für /status, /wartung, /do
- `telegram-secretary` - Validiert User-Input
- `do-queue-worker` - Verarbeitet /do Queue
- `sd-health-check` - SD-Karten-Gesundheit
- `telegram-notify` / `telegram-ask` - Helper

**Sync:**
```bash
# Docs aktualisieren
cd /home/pi/docs
git pull

# Neue Skripte deployen (mit echten Tokens!)
cd /home/pi/docs/scripts
./install.sh
```

---

---

## 🎓 Troubleshooting-Referenz

Siehe `~/docs/LESSONS-LEARNED.md` für gesammelte Erkenntnisse:
- Bash-Fallen & Best Practices
- Systemspezifische Workarounds
- Security Best Practices
- Protokoll-Besonderheiten (NTRIP, APRS, ADS-B, Remote ID)
- Hardware-Debugging (ESP32, RTL-SDR, GPS)

---

## 💾 Backup Best Practices

### System-Skripte sichern
**WICHTIG:** Nutze `/var/backups/scripts/` statt `/tmp/` für Backups!

```bash
# ✅ KORREKT - Permanenter Ort
sudo mkdir -p /var/backups/scripts/
sudo cp /usr/local/sbin/<script> "/var/backups/scripts/<script>.backup-$(date +%Y%m%d-%H%M%S)"

# ❌ FALSCH - Wird durch systemd-tmpfiles gelöscht (nach ~10 Tagen)
sudo cp /usr/local/sbin/<script> /tmp/<script>.backup
```

### Warum /var/backups/?
- ✅ Standard-Location für System-Backups (dpkg, apt nutzen dies auch)
- ✅ Persistent (überlebt Reboots und tmpfiles cleanup)
- ✅ Root-owned, geschützt
- ✅ Zeitstempel im Dateinamen für klare Versionierung

### Backup-Cleanup (optional)
```bash
# Backups älter als 30 Tage automatisch löschen
find /var/backups/scripts/ -name "*.backup-*" -mtime +30 -delete
```

### Aktuelle Backups prüfen
```bash
ls -lh /var/backups/scripts/
```
