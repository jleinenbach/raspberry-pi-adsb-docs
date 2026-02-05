# System Maintenance Assistant

**Raspberry Pi 4 Model B** | Debian 12 (bookworm)
**Standort:** 49.86625, 10.83948 | 283m

> **Quick Start:** `~/docs/QUICKREF.md` ⚡ - Schnelle Referenz für häufige Befehle
>
> **Dokumentation:** `~/docs/FEEDS.md` | `~/docs/MONITORING.md` | `~/docs/OGN-SETUP.md` | `~/docs/HOME-ASSISTANT.md` | `~/docs/DRAGONSYNC.md` | `~/docs/DRAGONSYNC-API.md` | `~/docs/ATOMS3-FIRMWARE.md` | `~/docs/PRESENCE-DETECTION.md` | `~/docs/GPS-NTRIP-PROXY.md` | `~/docs/GPS-AGNSS.md` | `~/docs/GPS-HOME-ASSISTANT.md`
>
> **Historie:** `~/docs/CHANGELOG.md` | `~/docs/MAINTENANCE-HISTORY.md` | `~/docs/LESSONS-LEARNED.md`
>
> **Resources:** `~/docs/resources/` - Quectel PDFs & GitHub-Projekte

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

# Services (29 Services nach Kategorie)
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
# DragonSync (2)
systemctl is-active dragonsync atoms3-proxy
# Alert Services (3)
systemctl is-active aircraft-alert-notifier ogn-balloon-notifier drone-alert-notifier
# GPS Services (4)
systemctl is-active ntripcaster ntrip-proxy chronyd gps-mqtt-publisher
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

## Apt-Pinning: bookworm + trixie Mix (BEABSICHTIGT!)

**⚠️ WICHTIG:** Das System hat trixie-Quellen in `/etc/apt/sources.list`, aber das ist NICHT "teilweise migriert"!

**Status:** ✅ Stabiles Pinning für einzelnes Paket

**Konfiguration:** `/etc/apt/preferences.d/01-cert-pinning`
```bash
# Prioritäten
bookworm:         900  # Standard (hoch)
trixie:            50  # Ignoriert (niedrig)
ca-certificates:  990  # Ausnahme (höchste)
```

**Installierte trixie-Pakete:**
- `ca-certificates` (20250419) - Einziges Paket aus trixie
  - **Grund:** Let's Encrypt Root CA Bug in bookworm (20230311)
  - **Seit:** 2024-10-xx (siehe CHANGELOG.md)

**Prüfung:**
```bash
# Pinning-Status
apt-cache policy | grep -A2 "bookworm\|trixie"

# Trixie-Pakete auflisten (sollte nur ca-certificates sein)
dpkg -l | awk '/^ii/ {print $2}' | xargs -I {} sh -c \
  'apt-cache policy {} 2>/dev/null | grep -q "^\*\*\*.*trixie" && echo {}'
```

**Bei Wartung:**
- ✅ **Ignoriere Warnungen** über "trixie APT-Quellen"
- ✅ **Prüfe Pinning-Konfiguration** in `/etc/apt/preferences.d/01-cert-pinning`
- ❌ **NICHT fragen** ob System zurück zu bookworm migriert werden soll

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
| `/status` | System Health + Drohnen live |
| `/stats` | Statistiken (ADS-B: aktuell + seit Start, MLAT, OGN: /min /h /12h, Remote ID: aktuell + 24h) |
| `/log` | Letzte Wartung |
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

---

## Zwei-Claude-Architektur
```
User ←→ Sekretär-Claude (nur Read/Grep) ←→ Techniker-Claude (Bash/Edit)
```

**Sekretär:** Validiert User-Input, blockiert gefährliche Befehle
**Techniker:** Führt genehmigte Wartung aus

---

## MLAT-Hub (2026-01-26)
Dedupliziert MLAT-Ergebnisse von 4 Clients bevor sie an readsb gehen.

**Was ist MLAT?** Multilateration berechnet Positionen von Mode-S-Flugzeugen (ohne ADS-B)
durch Vergleich der Empfangszeiten mehrerer Empfänger. Die Berechnung erfolgt auf den
**externen MLAT-Servern**, nicht lokal.

```
adsbexchange-mlat ─┐
adsbfi-mlat ───────┼──► mlathub:39004 ──► readsb:30104
airplanes-mlat ────┤    (dedupliziert)
piaware-mlat ──────┘
```

| Komponente | Details |
|------------|---------|
| Service | `mlathub.service` (zweite readsb-Instanz) |
| Input | Port 39004 (Beast) |
| Output | Port 39005 (Beast), → readsb:30104 |
| Konfiguration | `/etc/systemd/system/mlathub.service` |

### Wie funktioniert die Deduplizierung?
Der mlathub (readsb) wählt **NICHT** das genaueste Ergebnis - er nimmt das **neueste gültige**:

| Prüfung | Beschreibung |
|---------|--------------|
| Zeitstempel | Neuere Daten ersetzen ältere |
| speed_check | Position physikalisch möglich? (Distanz/Zeit plausibel) |
| Quellenhierarchie | ADS-B > MLAT > TIS-B (aber MLAT vs MLAT = gleichwertig) |

**Nicht implementiert:** Genauigkeitsvergleich, Gewichtung, Mittelwertbildung.

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

### Timer-Service Health Check (2026-02-03)
**Problem:** Timer-basierte Services (systemd oneshot mit Timer) können "leise crashen":
- Exit Code 0 (erfolgreich) trotz Fehlern im Journal
- `systemctl --failed` zeigt NICHTS an
- `journalctl -p err` zeigt NICHTS an (Permission denied ist kein error-level)
- Service läuft alle X Minuten erneut und crasht jedes Mal

**Beispiel:** do-queue-worker crashte alle 2 Minuten mit "Permission denied", aber war unsichtbar für normale Monitoring-Tools.

**Lösung:** `check_timer_services()` in `claude-respond-to-reports`
```bash
# Scannt ALLE Timer-basierten Services auf Problem-Indikatoren:
# - "permission denied"
# - "error.*failed"
# - "cannot"
# - "unable to"
# - "not found"

# Integration in täglicher Wartung (07:00)
# Ausgabe im REPORT_DATA vor "CORE SERVICES STATUS"
```

**Was wird geprüft:**
1. Alle aktiven systemd Timers finden (`systemctl list-timers`)
2. Für jeden Timer den zugehörigen Service finden (`.timer` → `.service`)
3. Letzte 50 Journal-Einträge scannen (unabhängig vom Log-Level)
4. Problem-Indikatoren suchen (auch bei Exit 0)
5. Exit-Code und Timestamp des letzten Laufs anzeigen

**Testergebnis (2026-02-03):**
- ✅ Hätte do-queue-worker Permission denied erkannt
- ✅ Jetzt integriert in tägliche Wartung
- ✅ Erkennt "leise crashende" Services zuverlässig

---


---

## 🔄 Koordination zwischen Reparatur-Mechanismen

### Problem: Race Conditions zwischen automatischen Systemen

**Vorher:** Drei unabhängige Reparatur-Mechanismen ohne Koordination:
1. **systemd Auto-Restart** (sofort bei Crash)
2. **feeder-watchdog** (alle 5min, exponentielles Backoff)
3. **claude-respond-to-reports** (täglich 07:00 + Eskalationen)

**Folge:** Mechanismen störten sich gegenseitig:
- Watchdog repariert → Claude startet parallel neu
- Claude baut Services um → Watchdog mischt sich ein
- Boot: Watchdog startet zu früh → False Positives

### Lösung: Intelligente Koordination (2026-02-03)

#### 1. Boot-Grace-Period im Watchdog

**Problem:** Watchdog läuft 2min nach Boot, aber Services brauchen länger:
- ogn-rf: 10-15min FFTW Benchmarking
- Dependencies: chronyd, gpsd, Netzwerk brauchen Zeit

**Implementierung:**
```bash
BOOT_GRACE_MINUTES=20  # 20 Minuten nach Boot keine Reparaturen

is_boot_grace_period() {
    local uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
    local grace_seconds=$((BOOT_GRACE_MINUTES * 60))
    
    if [ "$uptime_seconds" -lt "$grace_seconds" ]; then
        log "BOOT GRACE: System hochgefahren vor $((uptime_seconds / 60))min"
        return 0  # In Grace Period
    fi
    return 1
}
```

**Verhalten:**
- Timer: `OnBootSec=2min` (Watchdog startet bei 2min)
- **Erste 20min:** Watchdog läuft, prüft NUR, macht KEINE Reparaturen
- **Nach 20min:** Normale Überwachung startet

**Effekt:** ✅ Keine False Positives beim Boot mehr

#### 2. wait_for_quiet() - Zentrale Koordination

**Problem:** Claude-Wartung startete ohne auf andere Aktivitäten zu warten

**Implementierung:** In `/usr/local/sbin/claude-respond-to-reports` (Zeile 43-167)

**Prüft 9 Aktivitäts-Indikatoren:**

| Check | Was wird erkannt | Wartezeit |
|-------|------------------|-----------|
| 1. Services activating | `systemctl list-units --state=activating` | Bis active |
| 2. Watchdog kürzlich aktiv | Log-Check <2min | 2min |
| **2b. Watchdog-Eskalationen** | `/var/run/feeder-watchdog/*.given_up` + aktiv <30s | 30s |
| 3. Systemd-Restarts | ExecMainStartTimestamp <30s | 30s |
| 4. Andere Claude-Wartung | Lock-File `/var/run/claude-respond.lock` | Bis fertig |
| 5. /do Queue Worker | `pgrep do-queue-worker` | Bis fertig |
| 6. Interaktive Claude Session | `pgrep "claude -p"` | Bis fertig |
| 7. Config-Änderungen | `/etc/systemd/`, `/usr/local/sbin/` mtime <10min | 10min |
| 8. systemd daemon-reload | Unit-File-Warnings | Bis reload |

**Verhalten:**
- **Max Wartezeit:** 10 Minuten
- **Quiet-Counter:** 2 aufeinanderfolgende "ruhige" Checks (je 15s)
- **User-Info:** Nach 5min Telegram-Benachrichtigung
- **Timeout:** Nach 10min Start trotzdem (mit Warnung)

**Besonderheit Watchdog-Eskalationen:**
```bash
if [ "$given_up_services" -gt 0 ]; then
    # Informiere User warum Wartung läuft
    telegram-notify "🔧 Wartung wegen Watchdog-Eskalation: $services"
    
    # Prüfe ob Watchdog GERADE aktiv ist
    if [ "$watchdog_age" -lt 30 ]; then
        issues+=("Watchdog repariert JETZT")
        # Claude wartet bis Watchdog fertig ist
    fi
fi
```

#### 3. Koordinations-Matrix

| Situation | systemd | Watchdog | Claude | Ergebnis |
|-----------|---------|----------|--------|----------|
| **Boot <20min** | 🟢 Normal | ⏸️ Überspringt | 🟢 Normal | ✅ Keine False Positives |
| **Boot >20min** | 🟢 Normal | 🟢 Überwacht | 🟢 Normal | ✅ Alle aktiv |
| **Service crashed** | 🔧 Restart (sofort) | 🟢 Wartet | 🟢 Wartet | ✅ systemd zuerst |
| **systemd failed** | ⏸️ Gibt auf | 🔧 Repair (5min) | 🟢 Wartet | ✅ Watchdog versucht |
| **Watchdog eskaliert** | ⏸️ - | 🚩 Aufgegeben | 🔧 Übernimmt | ✅ Claude repariert |
| **Watchdog aktiv <30s** | 🟢 Normal | 🔧 Repariert | ⏳ **Wartet** | ✅ Keine Doppel-Reparatur |
| **Interaktive Session** | 🟢 Normal | 🟢 Überwacht | ⏳ **Wartet** | ✅ Keine Störung |
| **Alle ruhig** | 🟢 Normal | 🟢 Überwacht | 🟢 Arbeitet | ✅ Koordiniert |

### Drei-Ebenen-Absicherung

```
┌─────────────────────────────────────────┐
│ Ebene 1: systemd Auto-Restart           │
│ - Restart=always: Sofort bei Crash      │
│ - Restart=on-failure: Bei Exit ≠ 0      │
│ - Reaktionszeit: Sekunden                │
└─────────────────────────────────────────┘
              ↓ (falls fehlschlägt)
┌─────────────────────────────────────────┐
│ Ebene 2: feeder-watchdog (alle 5min)    │
│ - Boot-Grace: 20min nach Start          │
│ - Exponentielles Backoff: 5→10→20→40min │
│ - Eskalation nach 5h → Claude            │
│ - Telegram-Benachrichtigungen            │
└─────────────────────────────────────────┘
              ↓ (nach 5h Versuchen)
┌─────────────────────────────────────────┐
│ Ebene 3: Claude-Wartung (07:00)         │
│ - wait_for_quiet(): Prüft 9 Indikatoren │
│ - Wartet auf Ruhe (max 10min)           │
│ - Intelligente Reparatur + Analyse       │
└─────────────────────────────────────────┘
```

### Dateien

| Datei | Funktion | Änderung |
|-------|----------|----------|
| `/usr/local/sbin/feeder-watchdog` | Watchdog mit Boot-Grace | `BOOT_GRACE_MINUTES=20`, `is_boot_grace_period()` |
| `/usr/local/sbin/claude-respond-to-reports` | Claude mit wait_for_quiet | `wait_for_quiet()` (Zeile 43-167) |
| `/var/run/feeder-watchdog/*.given_up` | Eskalations-Marker | Watchdog legt an, Claude prüft |
| `/var/run/claude-watchdog-escalation-aware` | Eskalations-Info-Marker | Claude legt einmalig an |

### Logs & Debugging

```bash
# Boot-Grace im Watchdog sehen
sudo grep "BOOT GRACE" /var/log/feeder-watchdog.log

# wait_for_quiet Aktivität
sudo grep "wait_for_quiet\|Warte auf Ruhe" /var/log/claude-maintenance/response-*.log

# Eskalationen prüfen
ls /var/run/feeder-watchdog/*.given_up 2>/dev/null

# Watchdog letzte Aktivität
sudo tail -50 /var/log/feeder-watchdog.log | grep -E "VERSUCH|OK|FEHLER"
```

### Test-Befehle

```bash
# Boot-Grace testen (simuliere kurze Uptime)
awk '{print int($1/60)}' /proc/uptime  # Aktuelle Uptime in Minuten

# Eskalation simulieren
sudo touch /var/run/feeder-watchdog/test-service.given_up
# Claude-Wartung würde erkennen und warten

# Cleanup
sudo rm /var/run/feeder-watchdog/test-service.given_up
```

**Status:** ✅ Alle drei Ebenen koordiniert seit 2026-02-03



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
                              (auto-restart alle 15s)
                                      ↓
Empfang:                    ogn2dump1090 (100km-Filter)
                                      ↓
                            readsb:30008 → tar1090
```
**Was:** Segelflugzeuge, Motorsegler, Gleitschirme, Drachen
**Reichweite Upload:** ~100 km (eigene RF-Empfänge)
**Reichweite Empfang:** 100 km Radius (APRS-Filter)
**Upload:** ✅ **Station "SteGau" trägt zur Community bei** (trotz ogn-decode-Crashes)
**Lokal:** tar1090 Visualisierung (separate Tracks mit `~` Präfix)
**MLAT:** Nein (OGN nutzt eigenes APRS-Netzwerk)
**Status:** ✅ Aktiv (Auto-Restart-Workaround für ARM64-Bugs)
**Live-Karte:** http://live.glidernet.org/receiver-status/?id=SteGau
**Besonderheit:** ogn-decode crasht nach ~10s, aber APRS-Upload funktioniert in dieser Zeit

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

## Überwachte Services (29)
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

### GPS Services (4)
ntripcaster, ntrip-proxy, chronyd, gps-mqtt-publisher


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
