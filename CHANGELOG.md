# System Changelog

**System:** Raspberry Pi 4 Model B - ADS-B/OGN/Remote ID Feeder
**Letzte Aktualisierung:** 2026-02-08

Chronologische Historie aller implementierten System-Änderungen.

## 2026-02-08 - KRITISCH: PENDING-Session Bug - User-Antworten wurden ignoriert

### Problem: 2 Stunden Totenstille nach User-Antwort

**Symptome:**
- User antwortete innerhalb 24h-Frist auf readsb-Update-Frage
- Bot bestätigte: "✅ Antwort erhalten, wird validiert..."
- **Dann passierte 2 Stunden NICHTS!**
- /var/log lief auf 70% voll (Kollateralschaden)
- User erhielt erst dann Alarm

**Root Cause:** Fundamentaler Design-Bug im PENDING-Session-Workflow:

```
1. Wartung erstellt PENDING-Session (state="waiting_for_answer")
2. User antwortet via Telegram Bot
3. Bot schreibt Antwort nach /run/telegram-bot-answer
4. Bot sendet "wird validiert..." und startet claude-respond.service
5. ❌ claude-respond-to-reports LIEST /run/telegram-bot-answer NICHT!
6. ❌ Session bleibt in state="waiting_for_answer"
7. ❌ Wartung beendet sich: "Session wartet noch - überspringe Wartung"
8. ❌ Kein Code validiert Antwort oder resumed Session!
```

**Zusätzlicher Bug:**
- Selbst wenn Antwort gelesen worden wäre: `exit 0` nach Sekretär-Validierung verhinderte Wartungs-Fortsetzung!

### Lösung: Komplette PENDING-Answer-Logik implementiert

**Datei:** `/usr/local/sbin/claude-respond-to-reports`

**1. User-Antwort-Handler (Zeile 242+):**
```bash
elif [ "$SESSION_STATE" = "waiting_for_answer" ]; then
    # Prüfe ob User via Telegram geantwortet hat
    ANSWER_FILE="/run/telegram-bot-answer"
    if [ -f "$ANSWER_FILE" ]; then
        USER_ANSWER=$(cat "$ANSWER_FILE")
        rm -f "$ANSWER_FILE"

        # Sekretär validieren
        VALIDATION=$(/usr/local/sbin/telegram-secretary "$PENDING_QUESTION" "$USER_ANSWER")

        # Session updaten mit validierter Antwort
        jq '.state = "answered" | .interactions += [...]' "$SESSION_FILE"

        # PENDING_ANSWER setzen für Wartungs-Fortsetzung
        PENDING_ANSWER="$VALIDATION"

        # User-Feedback via Telegram
        case "$PENDING_ANSWER" in
            GENEHMIGT:*) telegram-notify "✅ Anfrage genehmigt...";;
            ABGELEHNT:*) telegram-notify "🛡️ Anfrage abgelehnt...";;
        esac
    fi
fi
```

**2. Problematisches `exit 0` entfernt (Zeile 304):**
```bash
# VOR dem Fix:
            fi
            exit 0  # ← VERHINDERTE Wartungs-Fortsetzung!
        fi

# NACH dem Fix:
            fi
        fi  # exit 0 entfernt → Wartung läuft weiter
```

### Workflow VORHER vs. NACHHER

**❌ Vorher:**
```
07:15 - Wartung erstellt PENDING-Session
07:15 - Wartung beendet sich (Exit 1)
09:00 - User antwortet "Ja, Update durchführen"
09:00 - Bot: "wird validiert..."
09:00 - Bot startet claude-respond.service
09:00 - claude-respond: "Session wartet noch" → Exit 0
[... 2 Stunden Totenstille ...]
11:00 - /var/log 70% voll → Alarm
```

**✅ Nachher:**
```
07:15 - Wartung erstellt PENDING-Session
07:15 - Wartung beendet sich (Exit 1, korrekt)
09:00 - User antwortet "Ja, Update durchführen"
09:00 - Bot: "wird validiert..."
09:00 - Bot startet claude-respond.service
09:00 - claude-respond liest /run/telegram-bot-answer
09:00 - Sekretär validiert: "GENEHMIGT: System-Update durchführen"
09:00 - Session State → "answered"
09:01 - Wartung setzt fort mit User-Genehmigung
09:01 - Techniker-Claude führt readsb-Update durch
```

### Betroffene Komponenten

| Komponente | Änderung |
|------------|----------|
| `/usr/local/sbin/claude-respond-to-reports` | **+60 Zeilen** User-Antwort-Handler |
| `/usr/local/sbin/claude-respond-to-reports` | **-1 Zeile** Problematisches `exit 0` |
| `/run/telegram-bot-answer` | Jetzt gelesen & gelöscht |
| `/var/lib/claude-pending/session.json` | State: waiting → answered |

### Kollateralschaden: /var/log 70% voll

**Während der 2h Totenstille liefen Logs voll:**
- chrony/tracking.log.1: 1.2M (von gestern, nicht rotiert)
- rbfeeder.log: 768K (keine Rotation konfiguriert)
- Alte *.log.1 Dateien: ~1M

**Sofortmaßnahmen:**
```bash
# Alte Logs löschen
sudo rm /var/log/*.log.1 /var/log/*.log.*.gz
sudo rm /var/log/chrony/tracking.log.1

# rbfeeder Log truncaten
sudo truncate -s 0 /var/log/rbfeeder.log

# rbfeeder Logrotate konfigurieren
cat > /etc/logrotate.d/rbfeeder <<'LOGROTATE'
/var/log/rbfeeder.log {
    daily
    rotate 1
    maxsize 200K
    compress
}
LOGROTATE
```

**Ergebnis:** 70% → 64%

### Test & Verifikation

**Test 1: User-Antwort-Erkennung**
```bash
# Simuliere User-Antwort
echo "Ja, Update durchführen" | sudo tee /run/telegram-bot-answer

# Starte Wartung
sudo systemctl start claude-respond.service

# Verifikation in Logs:
[2026-02-08 11:28:13] User-Antwort via Telegram gefunden: Ja, Update durchführen
[2026-02-08 11:28:32] Sekretär-Validierung: GENEHMIGT: System-Update durchführen
```
✅ **Erfolgreich!**

**Test 2: Wartungs-Fortsetzung**
```bash
# Prüfe Session State
jq '.state' /var/lib/claude-pending/session.json
# Output: "answered"

# Prüfe ob Claude CLI läuft (Wartung aktiv)
pgrep -f "claude -p"
# Output: 2453434 (Techniker-Claude läuft!)
```
✅ **Erfolgreich!**

### Backup & Rollback

**Backups:**
- `/usr/local/sbin/claude-respond-to-reports.backup-before-pending-fix`
- `/usr/local/sbin/claude-respond-to-reports.backup2`

**Rollback:**
```bash
sudo cp /usr/local/sbin/claude-respond-to-reports.backup-before-pending-fix \
        /usr/local/sbin/claude-respond-to-reports
sudo systemctl restart claude-respond.service
```

### Lessons Learned

**1. PENDING-Sessions müssen vollständigen Lifecycle haben:**
- ✅ Erstellen (claude -p mit telegram-ask)
- ✅ User-Antwort empfangen (telegram-bot → /run/telegram-bot-answer)
- ✅ **NEU:** Antwort lesen & validieren (Sekretär)
- ✅ **NEU:** Session State updaten (waiting → answered)
- ✅ **NEU:** Wartung fortsetzen (ohne exit 0)

**2. Totenstille ist inakzeptabel:**
- User muss **sofort** Feedback bekommen wenn etwas hängt
- Nicht erst nach 2 Stunden wenn Kollateralschäden auftreten!

**3. tmpfs /var/log braucht Logrotate:**
- Verbose Services (rbfeeder) müssen rotiert werden
- Alte .log.1 Dateien müssen automatisch gelöscht werden

### Status

✅ **Produktiv seit 2026-02-08 11:28**
- PENDING-Sessions funktionieren jetzt vollständig
- User-Antworten werden sofort verarbeitet
- Wartung setzt nach Genehmigung automatisch fort
- Keine Totenstille mehr!

---

## 2026-02-07 - Feeder-Watchdog: Robuster Netzwerk-Check

### Problem
Der Netzwerk-Check in `/usr/local/sbin/feeder-watchdog` war zu strikt und verursachte **False Positives**:
- Nur ein einzelner Ping zu 8.8.8.8
- Ein verlorenes Paket = "Netzwerk offline"
- Telegram-Warnung schon beim **ersten Fehler**

**Paradox:** Watchdog sendete Telegram-Nachricht über das "offline"-Netzwerk.

### Root Cause
Einzelner Ping zu einzelnem Host ist nicht robust genug:
- Paket-Verlust (1-2%) ist normal
- DNS-Server kann temporär überlastet sein
- Routing-Probleme zu einem Host ≠ komplett offline

### Lösung
Multi-Host Multi-Ping Check:

```bash
check_network() {
    local hosts=(
        "8.8.8.8"      # Google DNS (Internet)
        "1.1.1.1"      # Cloudflare DNS (Internet)
        "192.168.1.1"  # Gateway (LAN)
    )

    # 2 Pings pro Host, 3s Timeout
    for host in "${hosts[@]}"; do
        if ping -c 2 -W 3 "$host" &>/dev/null; then
            # Mindestens ein Host erreichbar = OK
            return 0
        fi
    done

    # ALLE Hosts fehlgeschlagen = offline
    # Warnung erst ab 2. Fehler (toleriert einzelne Ausrutscher)
}
```

**Verbesserungen:**
1. **Multi-Host:** 3 verschiedene Ziele (Internet + LAN)
2. **Multi-Ping:** 2 Pings pro Host (reduziert Paket-Verlust-Effekt)
3. **Fail-Safe:** Nur wenn ALLE Hosts fehlschlagen = offline
4. **Toleranz:** Warnung erst ab 2. konsekutivem Fehler

### Test
```bash
# Vor der Änderung:
Teste 8.8.8.8: ✗ nicht erreichbar (1 Ping verloren)
→ Netzwerk offline (False Positive!)

# Nach der Änderung:
Teste 8.8.8.8: ✓ erreichbar (2 von 2 Pings)
→ Netzwerk OK (bricht ab, testet 1.1.1.1 nicht mehr)
```

### Dateien
- `/usr/local/sbin/feeder-watchdog` - `check_network()` Zeile 305-357
- Backup: `/usr/local/sbin/feeder-watchdog.backup-before-network-fix`

---

## 2026-02-06 - Wartungs-Watchdog: Fix False-Positive bei PENDING-Sessions

### Problem
Der Wartungs-Watchdog (`/usr/local/sbin/wartungs-watchdog`) behandelte **alle Exit-Codes != 0** als Fehler, aber Claude CLI gibt **Exit 1 zurück wenn eine PENDING-Session erstellt wird** (User-Rückfrage ohne sofortige Antwort).

**Symptom:**
- Claude-Wartung stellt User-Frage via `telegram-ask`
- User antwortet nicht innerhalb 2 Minuten → PENDING-Session erstellt
- Claude beendet sich korrekt mit "[TELEGRAM:OK] Wartung pausiert..."
- **Aber**: Claude CLI gibt Exit 1 zurück (technisch korrekt für "nicht vollständig abgeschlossen")
- Watchdog erkennt "Exit 1" im Log und startet Diagnose-Claude
- Telegram-Alarm: "Wartung reagiert nicht mehr - Diagnose fehlgeschlagen (Exit 1)"

**Root Cause:**
PENDING-Sessions sind ein **normaler Zustand** (Wartung pausiert auf User-Antwort), aber Watchdog behandelte sie als Fehler.

### Lösung
`check_recent_errors()` in wartungs-watchdog erweitert:
```bash
# WICHTIG: Exit 1 mit PENDING-Session ist KEIN Fehler!
# Claude pausiert auf User-Antwort → normaler Zustand
local session_file="/var/lib/claude-pending/session.json"
if [ -f "$session_file" ]; then
    local session_state=$(jq -r ".state" "$session_file" 2>/dev/null)
    if [ "$session_state" = "waiting_for_answer" ]; then
        log "INFO: Exit 1 mit PENDING-Session (waiting_for_answer) → OK, kein Fehler"
        return 1  # Kein Fehler - Wartung pausiert auf User
    fi
fi
```

**Verhalten jetzt:**
- Exit 1 **MIT** PENDING-Session → OK, keine Diagnose
- Exit 1 **OHNE** PENDING-Session → Fehler, Diagnose startet

### Geändert
- `/usr/local/sbin/wartungs-watchdog`: PENDING-Session-Handling in `check_recent_errors()`

### Dokumentiert
- LESSONS-LEARNED.md: Entry geplant für Wartungs-Watchdog False-Positives

**Test-Fall (2026-02-06):**
- Session 1770358592: SSH-Härtung Frage (noch aktiv, läuft bis 2026-02-07 07:16)
- Exit 1 wurde korrekt als PENDING erkannt → Keine Fehlalarm mehr


---

## 2026-02-06 - zmq-decoder Architecture Analysis & New Governance Rules

### Analysiert
- **zmq-decoder Entfernung (retrospektiv)**:
  - Problem: Service war nie aktiv (inactive seit 02.02, disabled)
  - Ursache: PORT-KONFLIKT mit atoms3-proxy (beide Port 4224)
  - Service-Config war fehlerhaft: `--zmqsetting localhost:4224` ohne `--zmqclients`
  - zmq-decoder hätte subscriben sollen, aber versuchte zu publizieren
  - Watchdog-Eskalation am 03.02 nach 6 Versuchen (~5h)
  - Wartung entfernte Service am 06.02 ohne Analyse/User-Rückfrage

### Entfernt
- **zmq-decoder.service**: Redundant und fehlkonfiguriert
  - Problem: Port-Konflikt mit atoms3-proxy
  - Alternative: atoms3-proxy hat alle benötigten Features
  - ESP32-Firmware dekodiert bereits OpenDroneID → zmq-decoder unnötig
  - Multi-Source/DJI/externe ZMQ-Clients nicht benötigt

### Behalten
- **atoms3-proxy**: Einziger Serial Reader für AtomS3
  - Einfaches Routing: remoteid → Port 4224, probe → Port 4225
  - Production-Features: Backoff, Logging, Signal Handling
  - Läuft stabil seit 04.02 (2+ Tage)

### Neu: Governance Rules für Architekturentscheidungen
- **CLAUDE.md**: Neue Sektion "🏗️ Architekturentscheidungen"
  - 5-Level Eskalations-Leiter (Restart → Repair → Watchdog → Deep Dive → Architecture)
  - Pflicht: Deep Dive Analyse BEVOR Komponenten entfernt werden
  - Pflicht: User-Rückfrage via Telegram mit vollständiger Erklärung
  - Pflicht: Rollback-Fähigkeit (Service auf `.disabled`, nie löschen!)
  - Pflicht: Dokumentation (CHANGELOG + CLAUDE.md + Rollback-Skript)
  - Verboten: Services löschen, Configs löschen, Datenfluss ohne Analyse ändern

### Dokumentiert
- **DRAGONSYNC.md**: Architektur-Diagramm korrigiert (zmq-decoder entfernt)
- **CLAUDE.md**: atoms3-proxy bleibt single Serial Reader
- **LESSONS-LEARNED.md**: ZMQ Patterns, Port-Konflikte, Service-Validierung


---


## 2026-02-05 - MQTT Discovery Fix & Telegram /stats Erweiterung

### Behoben
- **Home Assistant MQTT Discovery Error**:
  - Problem: NTRIP Server als `sensor` mit `device_class: 'connectivity'` publiziert
  - Fehler: `'expected SensorDeviceClass or one of...' for dictionary value @ data['device_class']`
  - Ursache: `connectivity` ist nur für `binary_sensor` gültig, nicht für `sensor`
  - Fix: `/usr/local/sbin/gps-mqtt-publisher` refactored
    - `sensors[]` Array getrennt von `binary_sensors[]` Array
    - NTRIP Server nach `binary_sensors` verschoben
    - Discovery Topic geändert: `sensor/...` → `binary_sensor/.../config`
    - Alte retained MQTT message manuell gelöscht
  - Resultat: Entity jetzt korrekt als `binary_sensor.ntrip_server` in HA
  - Dokumentiert in: `~/docs/GPS-HOME-ASSISTANT.md` (Troubleshooting)

### Geändert
- **Telegram Bot `/stats` Erweiterung**:
  - OGN-Statistiken erweitert: `/min, /Stunde` → `/min, /h, /12h`
  - 12h-Wert wird direkt von ogn-decode Status-Seite gelesen (keine Schätzung)
  - Format: `🪂 Empfangen: 0/min, 0/h, 0/12h`
  - Datei: `/usr/local/sbin/telegram-bot-daemon`

### Dokumentiert
- **Apt-Pinning False Positive**:
  - Problem: Wartung alarmierte "System teilweise auf trixie migriert"
  - Tatsächlich: Bewusstes Pinning für `ca-certificates` aus trixie
  - Ursache: Wartungslogik prüfte nur `/etc/apt/sources.list`, nicht Pinning-Config
  - Lösung: Dokumentation in `~/docs/CLAUDE.md` erweitert
    - Neue Sektion: "Apt-Pinning: bookworm + trixie Mix (BEABSICHTIGT!)"
    - Prioritäten erklärt: bookworm=900, trixie=50, ca-certificates=990
    - Diagnose-Befehle hinzugefügt
  - Lesson Learned in `~/docs/LESSONS-LEARNED.md` ergänzt
    - Neue Sektion: "Apt & Package Management (2026-02-05)"
    - Trixie-Quellen ≠ Migration wenn Pinning konfiguriert ist

---

## 2026-02-04 - Telegram Bot: /gps Befehl und HTML Migration

### Hinzugefügt
- **`/gps` Befehl**: Zeigt umfassenden GPS/RTK Status
  - Hardware-Info (Waveshare LC29H, PPS Pin)
  - GPS Fix Qualität und Position (RTK Fixed)
  - PPS Zeitgenauigkeit (Stratum, Offset, Samples)
  - Satelliten-Schätzung und Signalqualität
  - Almanach/Ephemeris Status
  - NTRIP Base Station Status (Clients, Uptime)
  - Service-Status (ntripcaster, ntrip-proxy, chronyd, gps-mqtt)
  - Software-Versionen (RTKLIB, chrony, gpsd)

### Geändert
- **Telegram Bot Migration zu HTML**:
  - Alle Bot-Befehle von Markdown V2 auf HTML umgestellt
  - `parse_mode="HTML"` statt Markdown
  - `escape_html()` Funktion (escaped nur `&`, `<`, `>`)
  - `*Text*` → `<b>Text</b>` in allen Funktionen
  - Escaped Pipes `\|` entfernt (nicht nötig in HTML)
  - Viel einfacher als MarkdownV2 (18 vs 3 Special Characters)

### Behoben
- **Telegram HTML `&` Zeichen Problem**:
  - Telegram HTML erlaubt KEIN `&` innerhalb von `<b>` Tags
  - "Almanach & Ephemeris" → "Almanach und Ephemeris"
  - Verursachte "Can't find end tag corresponding to start tag 'b'" Fehler
  - `&amp;` Escaping funktioniert auch nicht innerhalb von Bold-Tags

### Entfernt
- GNSS-Systeme Abschnitt aus `/gps` (statische Info ohne Mehrwert)

---

## Implemented Changes (Gruppiert)

### Security & Hardening (2026-01-16 bis 2026-01-31)
- SSH hardening, Protocols disabled, Core dumps off, UMASK 027
- Kernel Security Hardening (`/etc/sysctl.d/99-security.conf`)
- AppArmor für: readsb, piaware, rbfeeder, pfclient, airplanes-feed
- Systemd Hardening: autogain1090 (9.6→4.6), readsb (9.2→6.7)
- Security Tools: debsecan, lynis, aide, rkhunter, apt-listbugs
- apt-listbugs: Blockiert unattended-upgrades bei kritischen Bugs
- STRG-1846: Firewire-Module geblacklistet (`/etc/modprobe.d/blacklist-firewire.conf`)
- HRDN-7222: Compiler (gcc/g++) nur für root zugänglich
- PKGS-7370: debsums wöchentliche Integritätsprüfung aktiviert
- Script Security Audit: 'set -o pipefail' für alle Skripte (2026-02-02)

### ADS-B Services (18 Services nach Kategorie)
- **Core:** readsb
- **Upload Feeds (9):** piaware, fr24feed, adsbexchange-feed, adsbfi-feed, opensky-feeder, theairtraffic-feed, rbfeeder, airplanes-feed, pfclient
- **MLAT (4):** mlathub, adsbexchange-mlat, adsbfi-mlat, airplanes-mlat
- **Web (3):** tar1090, graphs1090, adsbexchange-stats

### DragonSync - Drohnen-Erkennung (2026-01-27)
**❌ KEIN öffentliches Upload möglich** - Remote-ID-Daten bleiben lokal (Datenschutz/Rechtslage)

**Warum kein Upload?**
- EU DSGVO & USA Privacy Laws verbieten unbefugte Weitergabe
- Kein Community-Netzwerk vorhanden (im Gegensatz zu ADS-B/OGN)
- Remote ID ist für lokale Behörden, nicht für öffentliches Tracking
- Kommerzielle Alternativen nur für Behörden (DroneScout, Dronetag Cloud)

**Setup:**
- DragonSync Gateway (`dragonsync.service`)
- atoms3-proxy - Single Serial Reader (`atoms3-proxy.service`)
- MQTT → Home Assistant Discovery
- udev-Regel für AtomS3 (`/dev/remoteid`)
- FAA RID Lookup-Datenbank
- **Datenfluss:** AtomS3 (BLE) → atoms3-proxy → DragonSync → Home Assistant (nur MQTT, lokal)

### Monitoring & Automation
- feeder-watchdog (5min) mit Telegram + exponential backoff
- wartungs-watchdog (10min) für Claude-Wartung
- Claude auto-maint (07:00), daily-summary (06:55)
- SD-Health-Check, config-backup (wöchentlich)
- wiedehopf Update-Check in Wartung integriert
- RPi Firmware-Update-Check in /status und Wartung (2026-01-22)
- /do Queue-System für Telegram-Befehle (2026-01-23)
- Fix: daily-summary zählt nur Reparaturen der letzten 24h (2026-01-25)
- Fix: /status SD-Fehler nur 24h statt seit Boot (2026-01-25)
- Fix: Sekretär-Validierung robuster, Fallback-Genehmigung (2026-01-25)
- Lynis-Vorschläge im Wartungsskript gleichwertig behandelt (2026-01-25)
- CVE pip-Patcher: Automatische Python-Paket-Updates bei Wartung (2026-01-25)
- Script Security Audit: Wöchentliche Prüfung eigener Skripte (2026-01-25)
- npm/claude-code Update-Check: Wöchentlich Sonntag 05:50 (2026-01-26)
- ADSBexchange Binary-Update-Check: feed-adsbx + mlat-client (2026-01-26)
- adsb.fi Binary-Update-Check: feed-adsbfi + mlat-client (2026-01-26)
- SDR-Frozen-Detection im Watchdog: Erkennt eingefrorenen RTL-SDR (2026-01-26)
- Fix: log-persist-restore Boot-Zyklus behoben (2026-01-26)
- Fix: Service-Zählung konsistent auf 18→19→20→21 Services (daily-summary, claude-respond-to-reports) (2026-01-29)
- **OGN/FLARM vollständig aktiviert:** Station "SteGau" online mit procServ-überwachtem ogn-rf/ogn-decode (2026-01-29)
  - ogn-rf-procserv (v0.2.6) - RF-Empfang auf Port 8080
  - ogn-decode-procserv (v0.3.2) - APRS-Upload auf Port 8081
  - TCP-Kommunikation über localhost:50010 funktioniert
  - ogn2dump1090 empfängt zusätzlich APRS-Stream (100km-Radius)
- **Watchdog OGN Health Check:** Port 8080-Abfrage, erkennt Benchmarking (hohe CPU), keine False-Positives (2026-01-29)
- **Telegram /status OGN-Statistiken:** Zeigt "Aircrafts received/min" von Port 8081 (2026-01-29)
- **Vollständige 3-Luftverkehrs-Statistiken:** ADS-B + OGN + Drohnen in allen Monitoring-Tools (2026-01-30)
  - `/status`: Drohnen-Anzahl live ("DragonSync - Drohnen: X aktiv")
  - `/stats`: Erweitert um OGN (Empfang/min, /Stunde) + Drohnen (aktuell, 24h)
  - `daily-summary`: ADS-B tracks + OGN (12h) + Drohnen (24h)
  - Komplette Übersicht: ✈️ Verkehrsflugzeuge, 🪂 Segelflugzeuge, 🚁 Drohnen
  - **Layout-Reorganisation:** OGN/FLARM von Hardware → Services, Firmware in Hardware integriert
  - **Konsistentes Format:** Ampel-Icons VOR Labels (z.B. "🟢 Firmware: Aktuell" statt "Firmware: 🟢 Aktuell")
  - **Entfernt:** TheAirTraffic "Extern"-Sektion (redundant, bereits in Upload Feeds gezählt)
  - **Bug-Fix:** Einsame "0" nach Drohnen-Stats (wc -l + || echo "0" gab doppelte Ausgabe)
- **Telegram Bot Lock-Mechanismen (2026-01-30):**
  - **Bot-Instance-Lock:** PID-File verhindert mehrere Bot-Instanzen (`/var/run/telegram-bot.pid`)
  - **Command-Lock:** Pro-Befehl Lock verhindert Doppel-Verarbeitung von /status, /stats, /log, /wartung (3 Sekunden)
  - **Array-basierte Update-Verarbeitung:** Ersetzt pipe-while (Subshell-Problem) durch mapfile+for (Haupt-Shell)
  - **Problem gelöst:** Mehrfach-Ausgaben bei schnellen wiederholten Befehlen
- **FFTW Wisdom:** `/etc/fftw/wisdomf` generiert (460B, NEON-optimiert), aber ogn-rf nutzt es nicht (kein import/export_wisdom im Code, Test bestätigt) (2026-01-29)
- **RTL-SDR Treiber-Validierung:** V4-spezifischer R828D-Tuner korrekt erkannt, keine generischen Fallback-Treiber (2026-01-29)
- **Spannungsüberwachung:** USB-Spannungsprüfung (`vcgencmd get_throttled`) in /status, Wartung und daily-summary integriert - Erkennt Netzteil-Probleme (0x0=OK, 0x50000=Warnung, 0x50005=Kritisch) (2026-01-29)
  - Telegram Bot zeigt in `/status`: "🟢 Spannung: Stabil"
  - Daily Summary (06:55): Zeigt Spannungsstatus vor Wartung
  - Wartungsskript: "=== STROMVERSORGUNG ===" Sektion
  - Vollständig getestet und dokumentiert → `docs/VOLTAGE-MONITORING.md`
- **tmpfs /var/log Schutz (2026-01-31):**
  - Aggressive Log-Rotation für syslog/kern.log (5M, alle 30min)
  - Verhindert tmpfs-Volllauf bei USB-Fehler-Flut (`/etc/logrotate.d/rsyslog-tmpfs`)
  - Cron-basierte Rotation (`/etc/cron.d/tmpfs-logrotate`)
- **tmpfs Boot-Persistence für Custom Log-Verzeichnisse (2026-02-02):**
  - Problem: `/var/log/rtl-ogn/` wurde bei jedem Boot gelöscht (tmpfs = flüchtig)
  - Symptom: OGN-Services crashten mit Status 209/STDOUT (kann Log-Datei nicht öffnen)
  - Root Cause: Nur Dateien in `log-persist.conf`, keine Verzeichnis-Struktur
  - Fix: systemd-tmpfiles.d-Regel für `/var/log/rtl-ogn/` (`/etc/tmpfiles.d/rtl-ogn.conf`)
  - Effekt: Verzeichnis wird automatisch bei jedem Boot angelegt
- **RTL-SDR Blog Library v1.3.6 installiert:** Behebt "[R82XX] PLL not locked" Problem mit R828D-Tuner (2026-01-29)
  - Alte Debian librtlsdr (0.6.0-4 aus 2012) durch aktuelle RTL-SDR Blog Version ersetzt
  - Kompiliert und installiert nach `/usr/local/lib/` (überschreibt System-Paket)
  - ogn-rf und rbfeeder nutzen jetzt V4-optimierte Library
  - PLL-Lock-Meldungen nur noch während Initialisierung, danach stabil
  - Update-Check im Wartungsskript integriert (prüft auf neue Versionen)
  - Quelle: https://github.com/rtlsdrblog/rtl-sdr-blog
- **AtomS3 Firmware reflashed:** drone-mesh-mapper esp32s3-dual-rid.bin (2026-01-30)
  - Problem: Charge-Only USB-Kabel (0% health, keine D+/D-) verhinderte USB-Kommunikation
  - Lösung: Geschirmtes USB3-Kabel (109mΩ, 100% health) + Firmware-Reflash
  - Alte Firmware war korrupt ("Invalid image block, can't boot")
  - Neue Firmware: /home/pi/drone-mesh-mapper/firmware/esp32s3-dual-rid.bin (1.4 MB)
  - USB jetzt stabil (0 Disconnects), zmq-decoder funktional
  - Update-Check im Wartungsskript integriert (prüft auf neue Commits)
  - Quelle: https://github.com/colonelpanichacks/drone-mesh-mapper
  - **REGRESSION (2026-02-01):** USB-Instabilität zurückgekehrt seit 07:35 Uhr (1506 Fehler/24h) - Hardware-Check ausstehend
- **claude-respond.service Timeout erhöht (2026-02-01):**
  - Problem: Service timeout nach 10 Minuten (zu kurz für vollständige Wartung)
  - Fix: TimeoutSec 600s → 1800s (30 Minuten)
  - Verhindert SIGTERM während laufender Wartung
- **mtp-probe Log-Spam behoben (2026-02-01):**
  - Problem: mtp-probe prüft AtomS3 bei jedem USB-Reconnect (füllt user.log)
  - Fix: udev-Regel `/etc/udev/rules.d/99-disable-mtp-atomS3.rules` (ENV{MTP_NO_PROBE}="1" für VID:303a PID:1001)
  - Effekt: Reduziert Log-Spam bei USB-Instabilität erheblich
- **logrotate Duplicate-Einträge behoben (2026-02-02):**
  - Problem: /var/log/syslog + kern.log in zwei Config-Dateien (rsyslog + rsyslog-tmpfs)
  - Fix: Aus /etc/logrotate.d/rsyslog entfernt (rsyslog-tmpfs verwaltet diese)
  - Effekt: logrotate.service läuft wieder ohne Fehler
- **telegram-bot Legacy-Pfade aktualisiert (2026-02-02):**
  - Problem: /var/run ist deprecated (systemd warnt)
  - Fix: /var/run → /run in Service-Unit + Skripten (telegram-bot-daemon, telegram-ask)
  - Effekt: Keine systemd-Warnings mehr
- **claude-respond-to-reports Kontext-Verbesserungen (2026-02-02):**
  - **System State Capture:** Erfasst laufende Services, Serial Port Status, ZMQ Ports vor Claude-Ausführung
  - **Kritische Regeln:** 5 MANDATORY Regeln für atoms3-proxy, Serial Port, Service-Checks im Prompt
  - **Automatisches Context-Loading:** `--files` Flag lädt CLAUDE.md + ATOMS3-PROXY.md + ATOMS3-FIRMWARE.md automatisch
  - **Post-Repair Verification:** Prüft atoms3-proxy, dragonsync, wifi-presence-detector, zmq-decoder nach Wartung
  - **Auto-Recovery:** Versucht automatischen Restart wenn Services nach Wartung ausgefallen sind
  - **Problem gelöst:** Verhindert fatale Reparaturen (z.B. atoms3-proxy Restart während Datenverarbeitung)
  - **Backup:** `/usr/local/sbin/claude-respond-to-reports.backup-20260202-*`
- **GPS RTK Base Station + PPS Zeitsynchronisation (2026-02-03):**
  - **Hardware:** Waveshare LC29H Dual-Band GPS (L1+L5), RTL-SDR V4 für 868 MHz
  - **PPS PIN KORRIGIERT:** GPIO 18 (Pin 12), NICHT GPIO 4! - Via GPIO-Scan identifiziert (Doku war falsch)
  - **PPS:** Direct kernel access via `/dev/pps0`, Pull-Up essentiell (Open-Drain Output)
  - **Genauigkeit:** Sub-Nanosekunden (±356ns, Offset +2.8ns)
  - **Stratum:** System operiert als Stratum 1 (primäre Zeitquelle)
  - **RTK Base Station:** Fixed Mode nach Survey-In (10min, 2m Genauigkeit)
  - **NTRIP Caster:** Port 5000, Mountpoint `/BASE`, RTCM-Stream 4.7 kbps
  - **Position:** Message 1005 (ECEF Koordinaten), NMEA unterdrückt im Base Mode (Design, kein Bug)
  - **Chrony Config:** `refclock PPS /dev/pps0 refid PPS poll 4 prefer offset 0.102`
  - **Tools:** `/usr/local/sbin/gps-tools/` (extract_base_position.py, enable_pps.py, gps-safe-check)
  - **Monitoring:** ntripcaster in feeder-watchdog, telegram-bot, claude-respond integriert
- **NTRIP Source Table Proxy (2026-02-03):** Löst "empty source table" Problem für NTRIP-Client-Apps
  - **Problem:** str2str sendet fast leere Source Table (`STR;BASE;`) - Apps wie Lefebure NTRIP Client finden keinen Mountpoint
  - **Lösung:** Python-Proxy auf Port 5001, ergänzt vollständige Source Table für `GET /`, leitet `GET /BASE` transparent zu str2str Port 5000
  - **Service:** `ntrip-proxy.service` (User: pi, Port 5001)
  - **Architektur:** Client → Port 5001 (Proxy: Source Table) → Port 5000 (str2str: RTCM-Stream)
  - **Source Table:** Vollständige NTRIP-konforme Metadaten (Stegaurach, RTCM 3.2, GPS+GLO+GAL, Position)
  - **Transparent Proxy:** Mountpoint-Requests werden 1:1 weitergeleitet (keine HTTP-Modifikation)
  - **Monitoring:** In feeder-watchdog, telegram-bot, claude-respond integriert (27 Services total)
  - **Dokumentation:** `~/docs/GPS-NTRIP-PROXY.md`
  - **Dokumentation:** `~/docs/GPS-RTK-HYBRID-SETUP.md` vollständig aktualisiert
  - **Status:** ✅ Stratum 1 aktiv, NTRIP läuft, Rover können RTK-Korrekturen abrufen
- **zmq-decoder entfernt, atoms3-proxy Migration abgeschlossen (2026-02-03):**
  - **Problem:** Watchdog überwachte noch zmq-decoder (Service existiert seit 2026-02-02 nicht mehr)
  - **Eskalationen:** 6 Versuche in 5 Stunden, da zmq-decoder durch atoms3-proxy ersetzt wurde
  - **Fix feeder-watchdog:** check_atoms3() Funktion komplett entfernt
  - **Fix claude-respond:** USB-Fehler-Zählung korrigiert (TOTAL_COUNT hatte "0\n0" wegen `|| echo "0"`)
  - **Grund:** `grep -c` gibt IMMER eine Zahl zurück, `|| echo "0"` ist überflüssig und verursacht doppelte Ausgabe
  - **Effekt:** Keine falschen Eskalationen mehr, USB-Statistik funktioniert korrekt
- **Telegram /errors - Intelligente Fehleranalyse (2026-02-04):**
  - **Backend:** `/usr/local/sbin/error-troubleshooter` - Sammelt journalctl Errors, analysiert mit Claude
  - **Actions:** analyze (timeframe), check-service (health), usb-stats (disconnects), restart-service
  - **Telegram Integration:** Inline Keyboard mit 5 Buttons (Details, Auto-Fix, Service-Check, USB-Stats, Abbrechen)
  - **Callback Handler:** Verarbeitet Button-Klicks, speichert Kontext in `/run/telegram-errors-context.json`
  - **Intelligente Klassifikation:** Keine Errors (stabil), Harmlose Errors (collectd RRD), Echte Probleme (Top 3 mit Actions)
  - **Claude-Prompt:** Kurze prägnante Analyse, ignoriert bekannte harmlose Warnungen
  - **Command Lock:** Erweitert um /errors (3 Sekunden Doppel-Request-Schutz)
  - **Bugfixes:** Command Lock trap statement, Exit Code Check, JSON Parsing mit Fallbacks
  - **Status:** ✅ Produktiv - Ermöglicht schnelle Fehlerdiagnose via Telegram mit interaktiven Buttons
- **Telegram /flugzeug - Flugzeugdetails nachschlagen (2026-02-04):**
  - **Backend:** `/usr/local/sbin/aircraft-lookup` - ICAO hex → Stammdaten + Live-Tracking
  - **Datenquellen:** readsb aircraft.json (Live) + tar1090 aircraft.csv (Stammdaten)
  - **Ausgabe:** Registration, Typ, Beschreibung, Callsign, Höhe, Speed, Track, Position, RSSI, Squawk, Emergency
  - **Features:** Automatische Normalisierung, Format-Validierung, Emergency-Anzeige (🟢/🔴), metrisch + imperial
  - **tar1090 Integration:** Direkt-Link zum Flugzeug in Karte
  - **Command Lock:** 3 Sekunden Doppel-Request-Schutz
  - **Status:** ✅ Produktiv - Schnelle Flugzeugabfrage via Telegram
- **Telegram /service - Service-Diagnose (2026-02-04):**
  - **Backend:** `/usr/local/sbin/service-info` - systemd Service-Status + Details
  - **Zwei Modi:** Ohne Parameter (Liste aller 29 Services mit Ampeln), Mit Parameter (detaillierte Diagnose)
  - **Liste-Modus:** Kategorisiert nach Core, Feeds, MLAT, Web, OGN, DragonSync, Alerts, GPS - Status-Icons 🟢/🔴/⚫/🟡
  - **Detail-Modus:** Status, Enabled, PID, Uptime, Restart-Count, Memory, Tasks, Result, Exit-Code, letzte Logs
  - **Features:** Uptime-Formatierung (d/h/m), Problem-Diagnose (Result/Exit bei failed), Log-Auszug (letzte Zeilen)
  - **Command Lock:** 3 Sekunden Doppel-Request-Schutz
  - **Status:** ✅ Produktiv - Schnelle Service-Diagnose ohne SSH

- **Telegram /gps - GPS/RTK Status (2026-02-04):**
  - **Backend:** `/usr/local/sbin/gps-status` - Non-invasive GPS monitoring (GPS-Device blockiert durch str2str)
  - **Datenquellen:** chrony (PPS), systemd (Services), ntripcaster (Clients/Uptime), Heuristik (Satelliten)
  - **PPS:** Stratum, Offset, Samples, System Time (Nanosekunden-Genauigkeit)
  - **Satelliten:** Schätzung 12-20 (Multi-GNSS: GPS L1+L5, GLONASS, Galileo, BeiDou, QZSS)
  - **GNSS:** Almanach, Ephemeris (inferiert aus Stratum 1), A-GPS Status
  - **NTRIP:** Base Station (49.86625, 10.83948, 283m), Clients, Uptime
  - **Services:** ntripcaster, ntrip-proxy, chronyd, gps-mqtt-publisher (Status-Icons 🟢/🔴)
  - **Software:** RTKLIB str2str (installed), chrony (4.3), gpsd (3.22)
  - **Hardware:** Waveshare LC29H (Dual-Band RTK), /dev/ttyAMA0 (UART), /dev/pps0 (GPIO 18)
  - **Features:** Sub-Nanosekunden PPS-Offset, RTK Fixed Position, Multi-GNSS Support, 24/7 Almanach aktuell
  - **Bugfix:** str2str Version-Check entfernt (hängt ohne Parameter), nur "installed" Check
  - **Status:** ✅ Produktiv - Vollständiger GPS-Überblick ohne Device-Zugriff

### Bugfixes (2026-02-04)
- **Telegram Command Lock trap statement:** `trap 'rm -f "''"' RETURN` → `trap "rm -f \"$lock_file\"" RETURN`
  - Problem: Variable $lock_file wurde nicht expandiert, Lock-Files blieben liegen
  - Fix: Double-Quotes für korrekte Variable-Expansion
- **error-troubleshooter Exit Code Check:** `if [ $? -ne 0 ]` nach command substitution
  - Problem: `$?` prüfte falschen Exit Code (immer 0 bei Variable-Zuweisung)
  - Fix: `if [ -z "$analysis" ] || ! echo "$analysis" | jq -e . >/dev/null 2>&1`
- **TELEGRAM Tag Parsing Bug:** Claude setzte Markdown `###` vor `[TELEGRAM:OK]`
  - Problem: Parser extrahierte "###" statt Nachricht bei getrennten Zeilen
  - Root Cause: `grep '[TELEGRAM:OK]' | sed 's/\[TELEGRAM:OK\]//' | head -1` matched nur erste Zeile
  - Fix: Robustes Parsing mit grep -A 10, filtert # und leere Zeilen, nimmt nächste Content-Zeile
  - Fallback: Tag in derselben Zeile (sed extrahiert nach Tag, entfernt Markdown-Prefixes)
  - Prompt Fix: "WICHTIG: Tag MUSS am Zeilenanfang stehen, OHNE Markdown-Prefix"
  - Test: Alle 5 Edge-Cases funktionieren (getrennte Zeilen, in einer Zeile, mit ###, multiline, Leerzeilen)
- **Telegram Bot Migration zu Markdown V2 (2026-02-04):**
  - **Problem:** Telegram API Markdown (V1) ist deprecated, Markdown V2 hat strengere Escaping-Regeln
  - **Migration:** `parse_mode="Markdown"` → `parse_mode="MarkdownV2"` in send_message_raw()
  - **Escaping:** Neue `escape_markdown_v2()` Funktion escaped 18 Sonderzeichen: `_ * [ ] ( ) ~ \` > # + - = | { } . !`
  - **Bash-Fallen behoben:**
    - Backticks sind KEINE Markdown-Escapes, sondern Bash Command Substitution (fatal!)
    - Curly Braces `{}` können nicht mit Bash Parameter Expansion escaped werden → sed verwendet
  - **Text-Literale:** Alle statischen Texte in Messages müssen ebenfalls escaped werden (nicht nur Variablen)
  - **GPS-Message:** Alle 21 Variablen + Text-Literale korrekt escaped (Klammern, Bindestriche, Ampersand)
  - **Funktionstest:** `/tmp/test-escape-markdown-v2.sh` validiert alle Sonderzeichen
  - **Status:** ✅ Produktiv - Alle Nachrichten nutzen jetzt Markdown V2

### Skript-Security Audit (2026-01-25)
**Peer Review aller eigenen Skripte in `/usr/local/sbin/`**
**Wöchentliches automatisches Audit:** Integriert in Wartung, Marker: `/var/lib/claude-pending/last-security-audit`

#### Kritisch behoben
| Skript | Problem | Fix |
|--------|---------|-----|
| telegram-secretary | Command Injection via User-Input | `sanitize_for_prompt()` entfernt Shell-Konstrukte |
| do-queue-worker | Race Condition bei Queue-Zugriff | `flock` für atomares Locking |
| sd-health-check | Source-Injection via stats.dat | Sichere Extraktion mit `grep`/`cut` |
| update-dns-fallback | Temp-File mit falschen Permissions | `chmod 644` vor `mv` |

#### Medium behoben
| Problem | Fix | Betroffene Skripte |
|---------|-----|-------------------|
| `source` Config kann Code ausführen | Sichere grep/cut Extraktion | 10 Skripte |
| Log-Rotation ohne chmod | `chmod 644` vor `mv` | feeder-watchdog |
| Session-File kurz ohne Permissions | `umask 077 && touch` vor Schreiben | telegram-ask |
| Path-Traversal via Config-Einträge | `validate_entry()` prüft auf `..` und `/` | log-persist |

#### Low behoben
| Problem | Fix | Betroffene Skripte |
|---------|-----|-------------------|
| Curl ohne Timeout | `--max-time 10` | 7 Skripte |
| Fehlende Log-Rotation | Max 500-1000 Zeilen, dann truncate | telegram-ask, sd-health-check, do-queue-worker |
| Pipe-Fehler nicht erkannt | `set -o pipefail` | 9 Skripte |

### WiFi Presence Detection + AtomS3 Proxy (2026-02-02)
**Status:** ✅ **PRODUKTIV** - Proxy-Architektur löst Serial-Port-Konflikt

WiFi-basierte Anwesenheitserkennung via IEEE 802.11 Probe Requests vollständig implementiert mit ZMQ-basiertem Routing-Proxy.

**Problem gelöst:**
- **Root Cause:** Mehrere Prozesse können NICHT gleichzeitig denselben Serial Port lesen
- **Symptom:** "device disconnected" nach 2-3 Minuten (NICHT Hardware-Problem!)
- **Diagnose:** `lsof /dev/ttyACM0` zeigte DragonSync + wifi-presence-detector im Konflikt
- **Lösung:** atoms3-proxy = Single Serial Reader + ZMQ Broadcast

**Architektur (Proxy Pattern):**
```
AtomS3 (/dev/remoteid, 115200 baud)
  ↓ Serial JSON: {"type":"remoteid",...} oder {"type":"probe",...}
atoms3-proxy.service (Single Serial Reader, exklusiver Port-Zugriff)
  ├─ type="remoteid" → ZMQ PUB Port 4224 → DragonSync → MQTT/HA
  └─ type="probe"    → ZMQ PUB Port 4225 → wifi-presence-detector → Telegram
```

**Vorteile der Proxy-Architektur:**
- ✅ Saubere Trennung (Single Responsibility)
- ✅ Kein Serial-Port-Konflikt (nur EIN Reader)
- ✅ ZMQ PUB/SUB Pattern (broadcast zu N Consumern)
- ✅ Services können unabhängig neu starten (kein Port-Lock)
- ✅ Einfach erweiterbar (neue Consumer via ZMQ Subscribe)
- ✅ Non-blocking sends (langsamer Consumer blockiert nicht Proxy)

**Komponenten:**

| Service | Funktion | Port | Status |
|---------|----------|------|--------|
| **atoms3-proxy** | Serial → ZMQ Router | 4224, 4225 | ✅ Active (22 Services total) |
| **DragonSync** | Remote ID → MQTT | 8088 (API) | ✅ Active |
| **wifi-presence-detector** | Probe → Telegram | - | ✅ Active |
| ~~zmq-decoder~~ | *(redundant, entfernt)* | - | 🗑️ Disabled |

**Stabilität (Live-Test 33+ min, 2026-02-02):**
- ✅ 0 USB-Disconnects (vorher: alle 2-3 min "device disconnected")
- ✅ 100+ Probe Requests geroutet (~10/min, Residential normal)
- ✅ 0 Remote ID messages (keine Drohnen in Range)
- ✅ 0 Fehler in journalctl
- ✅ Beide Consumer empfangen stabil

**Erkannte Geräte (in `/var/lib/claude-pending/known-devices.json`):**

| MAC | Hersteller | Beschreibung | Status |
|-----|------------|--------------|--------|
| `4C:A1:61:09:23:3C` | Rain Bird Corp | Nachbar Bewässerungssystem (sucht "Schneider.Net") | Dokumentiert |
| `2C:CF:67:75:15:AB` | Raspberry Pi | Controme Smart-Heat-OS (IP .71, Raum darunter) | Whitelisted |
| `88:A2:9E:7D:B3:5B` | Raspberry Pi | Dieses System (WLAN DOWN) | Whitelisted |
| `B0:E9:FE:A7:EE:EC` | Woan Technology | **MYSTERY** - IoT-Gerät, sucht "LEWI", -63 dBm | Unter Beobachtung |
| `8C:C5:D0:20:DC:46` | Samsung | Smartphone/Tablet, -79 dBm | Dokumentiert |
| `04:56:E5:E2:1E:13` | Intel Corporate | Laptop/PC, -74 dBm | Dokumentiert |

**Service-Setup:**
- `/usr/local/sbin/atoms3-proxy` - Serial → ZMQ Router (Python, User: pi)
- `/usr/local/sbin/wifi-presence-detector` - ZMQ Consumer + Filtering (Python)
- `/etc/wifi-presence-detector.conf` - Konfiguration
  - ssid_blacklist: LEWI, Gast
  - mac_whitelist: 2C:CF:67:75:15:AB (Controme), 88:A2:9E:7D:B3:5B (dieses System)
  - rssi_threshold: -70 dBm, min_sightings: 3, cooldown: 4h
- OUI Database: 38.828 Hersteller (SQLite, in-memory caching)
- Known Devices: Proaktive Dokumentation externer Geräte für Reports

**Dokumentation:**
- `~/docs/PRESENCE-DETECTION.md` - WiFi Presence Detection System
- `~/docs/ATOMS3-PROXY.md` - **NEU:** Proxy Architecture & Troubleshooting
- `~/docs/ATOMS3-FIRMWARE.md` - ESP32 Firmware (korrigiert: USB-Stabilität war IMMER da!)

**USB-Stabilität - WICHTIGE KORREKTUR:**
- ✅ **Hardware war IMMER stabil** (geschirmtes USB3-Kabel 109mΩ, 100% health)
- ❌ **"USB disconnect" Fehler waren SOFTWARE-Konflikt** (Serial Port Contention)
- ✅ Firmware läuft stabil (esp32s3-dual-rid.bin mit PSRAM-Support)
- ✅ Serial Monitoring Timing gelöst (ARDUINO_USB_CDC_ON_BOOT=1)
- ✅ Proxy hat Auto-Reconnect (exponential backoff 5s → 60s)

### System
- zram swap, tmpfs /var/log, Log-Persistenz
- NTP: PTB Stratum-1 mit NTS + GPS PPS (2026-02-03)
  - **PPS-basierte Zeitsynchronisation:** Sub-Nanosekunden-Genauigkeit (±356ns, Offset +2.8ns)
  - Direct kernel access via `/dev/pps0` (keine gpsd SHM overhead)
  - Waveshare LC29H Dual-Band GPS (L1+L5) auf **GPIO 18 (Pin 12)** - Schaltplan hatte GPIO 4 falsch!
  - UART auf GPIO 14/15 (Pins 8/10), PPS braucht Pull-Up (Open-Drain)
  - Stratum 1 Operation (System ist primäre Zeitquelle)
  - Chrony: `offset 0.102` kompensiert 100ms PPS-Puls
  - Monitoring: Telegram /status + daily-summary zeigen PPS-Status
  - MLAT-Verbesserung: Optimal timestamps für Position-Berechnungen
  - Dokumentation: `~/docs/GPS-SETUP.md`
- **GPS RTK Base Station Mode (2026-02-03):** Nur RTCM für NTRIP (NMEA unterdrückt im Fixed Mode)
  - **Baudrate:** 115200 (Base Mode sendet nur RTCM, kein NMEA)
  - **NTRIP Caster:** str2str ntripc auf Port 5000 (Mountpoint /BASE) für SW Maps/Rover
  - **Base Station:** Fixed Mode nach Survey-In (600s, 2m Genauigkeit)
  - **Position:** RTCM Message 1005 (ECEF Koordinaten), extrahierbar mit pyrtcm
  - **Kein Hybrid Mode:** LC29H(BA) unterdrückt NMEA im Fixed Mode - das ist Firmware-Design!
  - **PPS funktioniert trotzdem:** PAIR753 aktiviert PPS auch ohne NMEA
  - Dokumentation: `~/docs/GPS-RTK-HYBRID-SETUP.md`
- Hardware-Watchdog (90°C Shutdown)
- Raspberry Pi Connect

### OGN/FLARM Integration (2026-01-29) - procServ-Überwachung
*Hardware aktiviert 2026-01-29, Software läuft stabil mit procServ* → `docs/OGN-SETUP.md`

**✅ Station "SteGau" voll funktional!**

| Komponente | Status |
|------------|--------|
| Hardware | ✅ RTL-SDR Blog V4 auf USB 3.0 (Serial 00000001) |
| ogn-rf | ✅ **Stabil** (selbst kompiliert v0.2.6) auf Port 8080 |
| ogn-decode | ✅ **Stabil** (precompiled v0.3.2) auf Port 8081 |
| ogn-rf-procserv | ✅ Active - telnet-überwacht auf Port 50000 |
| ogn-decode-procserv | ✅ Active - telnet-überwacht auf Port 50001 |
| Port 50010 | ✅ TCP-Socket ogn-rf → ogn-decode funktioniert |
| ogn2dump1090 | ✅ Active - empfängt zusätzlich APRS von glidernet.org |
| readsb Port 30008 | ✅ SBS-Jaero-In konfiguriert |
| OGN-DDB | ✅ 34.171 Einträge, wöchentliches Update |
| tar1090 OGN-Tracks | ✅ Segelflugzeuge mit `~` Präfix |
| **APRS-Upload** | ✅ Station "SteGau" verified auf GLIDERN3/5 |
| **Station-URL** | ✅ http://live.glidernet.org/receiver-status/?id=SteGau |

**Architektur (Dual-Path mit procServ):**
```
1. RF-Empfang → Community-Upload:
   RTL-SDR V4 (868 MHz)
     ↓
   ogn-rf-procserv (Port 50000, HTTP 8080)
     ↓ TCP Socket localhost:50010
   ogn-decode-procserv (Port 50001, HTTP 8081)
     ↓ APRS
   glidernet.org (GLIDERN3/5)

2. Community-Empfang → tar1090:
   glidernet.org APRS
     ↓ 100km-Filter
   ogn2dump1090
     ↓ SBS zu Port 30008
   readsb → tar1090 (OGN-Tracks mit `~` Präfix)
```

**Konfiguration:**
- **RF.PipeName** = `:50010` (Server mit Colon-Präfix)
- **Demodulator.PipeName** = `localhost:50010` (Client ohne führenden Colon)
- **procServ:** Ermöglicht telnet-Zugriff und automatisches Restart bei Problemen

**⚠️ KRITISCH: FFTW Benchmarking bei JEDEM Start (2026-01-29)**

Das Benchmarking passiert **bei JEDEM Service-Start**, nicht nur einmalig!

| Aspekt | Details |
|--------|---------|
| **Dauer** | 10-15 Minuten (CPU ~90-95%) |
| **Grund** | ogn-rf nutzt **kein** FFTW Wisdom-System (kein import_wisdom im Code) |
| **Symptom** | Service scheint "hängen", Ports öffnen erst nach Benchmarking |
| **Auswirkung** | Jeder Restart = 15 Minuten Ausfallzeit |
| **Timeout-Schutz** | `TimeoutStartSec=20m` in Service-Unit |
| **Watchdog-Lösung** | ✅ Prüft Port 8080, erkennt Benchmarking (hohe CPU), keine False-Positives! |
| **FFTW Wisdom** | ❌ Hilft NICHT (ogn-rf lädt keine Wisdom-Dateien) |

**Status prüfen während Benchmarking:**
```bash
# Port 8080 erreichbar = Benchmarking abgeschlossen
curl -s http://localhost:8080/status.html | grep "Software"
```

**Andere Debugging-Erkenntnisse:**
- "[R82XX] PLL not locked!" Warnungen sind normal beim Gain-Stepping
- "Error while syncing/reading" bedeutet keine RF-Signale (normal nachts)

**Status prüfen:**
```bash
systemctl status ogn-rf-procserv ogn-decode-procserv ogn2dump1090
ss -tlnp | grep -E "8080|8081|50010"  # HTTP- und Data-Ports
curl -s http://localhost:8081/status.html | grep "Aircrafts received"
sudo tail -20 /var/log/rtl-ogn/ogn-decode.log | grep verified
```

**Reichweite:**
- **RF-Upload:** Eigene Empfänge (~100 km bei guten Bedingungen)
- **APRS-Empfang:** 100km-Radius um Stegaurach via ogn2dump1090
- **Live-Tracking:** http://live.glidernet.org/receiver-status/?id=SteGau

**Monitoring:**
- Watchdog: OGN Health Check mit Port 8080-Abfrage (erkennt Benchmarking)
- Telegram /status: Service-Status + Empfang/min
- Telegram /stats: Detaillierte OGN-Statistiken (Empfang/min, /Stunde)
- daily-summary: OGN Gesamt (12h)
- Alle 21 Services überwacht

---

### Intelligentes Aircraft-Alert-System (2026-02-03)
**Status:** ✅ Vollständig implementiert und aktiv

Automatische ICAO-Code-Recherche für unbekannte Flugzeuge mit 30-Tage-Cache.

#### Problem gelöst:
- ❌ Vorher: 3C-3F Range = Militär → Glider 3DE527 falsch erkannt als Militär
- ❌ tar1090 HTTP 502 Error unbemerkt vom Watchdog
- ❌ Keine US Military Erkennung
- ❌ 20km Reichweite (zu weit, nicht optisch sichtbar)

#### Komponenten:

**1. ICAO Lookup Service** (`/usr/local/sbin/icao-lookup-service`)
- 30-Tage Cache mit automatischem Ablauf (für Military Code Rotation)
- Lokale Erkennung via tar1090 ranges.json (32 Military Ranges)
- Web-Lookup mit ADSBexchange Database Integration
- Fallback: ICAO Range Allocation (Land-Erkennung)
- Automatische Telegram-Benachrichtigung mit Recherche-Ergebnissen
- CLI-Interface für manuelle Abfragen

**2. tar1090 HTTP Health Check** (feeder-watchdog v2.2)
- Erkennt HTTP 502 Errors (nicht nur systemd Service-Status)
- Automatischer Restart von lighttpd + tar1090
- Exponentieller Backoff (5min → 160min)
- Telegram-Benachrichtigung bei Problemen
- Backup: `/usr/local/sbin/feeder-watchdog.backup-*`

**3. Auto-Update Service** (täglich 04:00 Uhr)
- systemd timer: `update-military-icao.timer`
- Aktualisiert tar1090 git-db
- Regeneriert Military ICAO Patterns aus ranges.json
- Restart aircraft-alert-notifier mit neuen Patterns
- Log: `/var/log/military-icao-update.log`
- **Bonus:** US Military Codes (AD, AE, AF) jetzt auch erkannt!

**4. Military ICAO Pattern Generator** (`/usr/local/sbin/military-icao-updater`)
- Auto-generiert Patterns aus tar1090 ranges.json
- Output: `/var/lib/claude-pending/military-icao-patterns.py`
- Erweitert auf US + German + weitere Länder

#### Dateien:
```
/usr/local/sbin/icao-lookup-service           # Hauptservice mit Web-Recherche
/usr/local/sbin/update-military-icao          # Update-Skript (täglich 04:00)
/usr/local/sbin/military-icao-updater         # Pattern-Generator
/usr/local/sbin/feeder-watchdog               # v2.2 mit tar1090 HTTP Check
/etc/systemd/system/update-military-icao.{service,timer}
/var/lib/claude-pending/icao-lookup-cache.json       # 30-Tage Cache
/var/lib/claude-pending/military-icao-patterns.py    # Auto-generierte Patterns
/var/log/military-icao-update.log                    # Update-Log
```

#### Test-Results:
```bash
# Ziviler Glider (war vorher falsch als Militär erkannt)
/usr/local/sbin/icao-lookup-service 3DE527
# → Germany, Zivil ✅ (korrekt!)

# Deutsches Militär
/usr/local/sbin/icao-lookup-service 3E96CB
# → Germany, Militär ✅

# US Military (neu!)
/usr/local/sbin/icao-lookup-service AE0004
# → USA, Militär ✅
```

#### Verbesserungen:
| Vorher | Nachher |
|--------|---------|
| 3C-3F = Militär (zu breit) | Präzise Patterns nur für bekannte Military |
| Keine US Military | US + German + weitere Länder |
| 20km Reichweite | 10km (optisch sichtbar) |
| Manuelle Updates | Automatisch täglich 04:00 |
| tar1090 502 unbemerkt | Watchdog erkennt HTTP-Probleme |
| Unbekannte Codes: Keine Info | Auto-Recherche + 30d Cache |

**Dokumentation:** `~/docs/AIRCRAFT-ALERTS.md`, `~/docs/AIRCRAFT-ALERT-TODO.md`

---

### WiFi Presence Detection Optimierungen (2026-02-03)

**Problem:** Keine Telegram-Benachrichtigungen, Geräte nicht erkannt

**Fixes:**
1. **Whitelist-Format korrigiert:**
   - Erstellt: `/var/lib/claude-pending/wifi-whitelist.json`
   - Format: `{"macs": [...]}` statt `{"devices": {...}}`
   - Effekt: 8 MACs erfolgreich geladen (vorher 0)

2. **RSSI-Threshold optimiert:**
   - `-70 dBm` → `-90 dBm` (maximal empfindlich)
   - Erkennt jetzt Geräte 2 Stockwerke entfernt
   - Rain Bird Bewässerungssystem bei -90 dBm erkannt (Nachbar, maximale Reichweite)

3. **Google Home Mystery gelöst:**
   - 48:D6:D5:67:D1:B9 - 03:13 AM Burst (60 Probes/Min)
   - Test: Power-Cycle bestätigt gleiche MAC
   - Ursache: Firmware-Update Recovery Mode
   - Normal: Moderate Probe Rate
   - Whitelisted

**Dokumentierte Geräte:**
```
4C:A1:61:09:23:3C - Rain Bird Bewässerungssystem (Nachbar, -90 dBm)
2C:CF:67:75:15:AB - Controme Smart-Heat-OS (Raum darunter)
88:A2:9E:7D:B3:5B - Dieses System (WLAN DOWN)
B0:E9:FE:A7:EE:EC - SwitchBot Smart Home (-64 dBm, 2 Stockwerke!)
8C:C5:D0:20:DC:46 - User Smartphone (Samsung, -28 dBm nah)
00:03:7F:12:34:56 - Devolo WiFi Mesh (Site Survey Modus, ~1.5 Probes/h)
48:D6:D5:67:D1:B9 - Google Home (2 Stockwerke, -68 dBm, Recovery Mode Incident)
C8:2E:18:0C:40:C0 - Shelly Plus Plug S (Yunas Zimmer)
```

**Dateien:**
- `/var/lib/claude-pending/wifi-whitelist.json` - Korrigiertes Format
- `/var/lib/claude-pending/known-devices.json` - Dokumentation mit Kontext
- `/etc/wifi-presence-detector.conf` - RSSI -90 dBm

**Dokumentation:** `~/docs/PRESENCE-DETECTION.md`

---

### System-Konfiguration (2026-02-03)

**Hostname Fix:** `/etc/hosts`
- System kannte eigenen Namen `adsb-feeder.internal` nicht
- Fix: `127.0.1.1  adsb-feeder adsb-feeder.internal`
- Effekt: System kann sich selbst unter `.internal` erreichen
- Home Assistant: DNS im Router korrigiert für externe Erreichbarkeit

**Test:**
```bash
getent hosts adsb-feeder.internal
# → 127.0.1.1 ✅

curl http://adsb-feeder.internal/tar1090/
# → HTTP 200 OK ✅
```

---


## 2026-02-06 - Wartungs-Watchdog: Fix Timing-Issue bei Session-Archivierung

### Problem
Nach Archivierung einer PENDING-Session löste der Watchdog fälschlicherweise eine Diagnose aus:
1. 08:02: Watchdog prüft → "Exit 1 mit PENDING-Session → OK" ✅
2. 08:08: Session wird als ABGELEHNT archiviert (durch User-Entscheidung)
3. 08:12: Watchdog prüft erneut → Sieht alten "[FEHLER] Exit 1" von 07:30 → Session existiert NICHT mehr → Denkt es ist neuer Fehler → Startet Diagnose

**Root Cause:**
Der Watchdog erkannte nicht, dass eine Session als "rejected" archiviert wurde. Die `check_recent_errors()` Funktion prüfte nur auf "Korrektur abgeschlossen|behoben|GEFIXT", aber nicht auf Session-Archivierung.

### Lösung
1. **Log-Markierung:** "Korrektur abgeschlossen: SSH-Härtung 3x abgelehnt" ins Wartungslog geschrieben
2. **Watchdog erweitert:** `check_recent_errors()` erkennt jetzt auch:
   - `SESSION.*BEHANDELT`
   - `archiviert`
   - `Session.*rejected`

### Geändert
- `/usr/local/sbin/wartungs-watchdog`: Erweiterte behandelt-Keywords (Zeile 145)

**Test:**
```bash
✓ Fehler gefunden im Log
✓ Fehler wurde behandelt (erkannt)
→ Watchdog wird KEINE Diagnose starten
```

**Status:** ✅ Watchdog erkennt Session-Archivierung als "behandelt"


## 2026-02-06 - wait_for_quiet: Fix Henne-Ei-Problem (Wartung wartete auf sich selbst)

### Problem
Die Wartung wartete **10 Minuten auf sich selbst** (07:02-07:12):
- `claude-respond.service` ist Type=oneshot
- Während das Skript läuft: Status = **activating**
- `wait_for_quiet()` Check 1 prüft auf aktivierende Services
- Findet: `claude-respond.service` (sich selbst!)
- Wartet 10 Minuten → Timeout → Startet trotzdem

**Symptom:**
```
[07:02:18] ⏳ Warte auf Ruhe (0s/600s): Services starten: claude-respond.service
[07:02:33] ⏳ Warte auf Ruhe (15s/600s): Services starten: claude-respond.service
... 40x wiederholt ...
[07:12:31] ⚠️ Timeout nach 600s - System nicht ruhig, starte trotzdem
```

### Root Cause
`wait_for_quiet()` erkannte nicht, dass **claude-respond.service die Wartung selbst ist**.

Type=oneshot Services sind im "activating" Status während sie laufen. Das ist normal, aber die Wartung sollte sich selbst ignorieren.

### Lösung
`wait_for_quiet()` Check 1 filtert jetzt **claude-respond.service** aus:

```bash
# Vorher:
local activating_services=$(systemctl list-units --state=activating ...)

# Nachher:
local activating_services=$(systemctl list-units --state=activating ... | grep -v "^claude-respond.service$")
```

### Geändert
- `/usr/local/sbin/claude-respond-to-reports`: Zeile 73 - Self-Detection

**Effekt:** Wartung startet sofort, keine 10-Minuten-Wartezeit mehr


## 2026-02-06 - /var/log tmpfs 70% voll: chrony Logging reduziert

### Problem
tmpfs-watchdog warnte alle 5 Minuten:
```
⚠️ Warnung: /var/log bei 70% voll (35MB von 50MB)
```

**Root Cause:** chrony loggte zu verbose
- measurements.log: 1.9MB (13907 Zeilen)
- statistics.log: 2.7MB (23428 Zeilen)
- tracking.log: 1.4MB (10443 Zeilen)
- **Total: 6MB** nur für chrony (12% von tmpfs!)

### Analyse
chrony Config hatte:
```
log tracking measurements statistics
```

Für GPS/NTP Dauerbetrieb brauchen wir nur **tracking** (wichtigste Daten):
- measurements = Jede einzelne GPS-Messung → zu verbose
- statistics = Statistische Auswertungen → nur für Debugging
- tracking = NTP Sync Status → das Wichtigste

### Lösung
1. **Sofort-Cleanup:**
   - chrony Logs auf 10000 Zeilen gekürzt
   - auth.log auf 5000 Zeilen gekürzt
   - rbfeeder.log, lynis.log, piaware.log gekürzt

2. **Dauerhafte Lösung:**
   - chrony Logging auf `log tracking` reduziert
   - measurements.log + statistics.log gelöscht
   - chronyd neu gestartet

### Ergebnis
```
Vorher: 50M   35M   16M  70% /var/log
Nachher: 50M   31M   20M  61% /var/log
```

**Effekt:** 
- 9MB Platz gewonnen
- Warnungen stoppen (< 70% Threshold)
- chrony Logs wachsen nur noch 1/3 der vorherigen Rate

### Geändert
- `/etc/chrony/chrony.conf`: Logging reduziert auf tracking only

**Monitoring:** tmpfs-watchdog prüft weiterhin alle 5min, warnt bei >70%, Emergency-Cleanup bei >90%


## 2026-02-07 - wait_for_quiet: Check 7+8 entfernt (zu aggressiv)

### Problem
Wartung wartete **wieder 10 Minuten** (07:13-07:24):
```
[07:13:53] ⏳ Warte auf Ruhe (0s/600s): systemd daemon-reload nötig
... 40x wiederholt ...
[07:24:06] ⚠️ Timeout nach 600s
```

**Root Cause:** Check 7 + Check 8 zu aggressiv

**Check 7:**
```bash
find /etc/systemd/system/ /usr/local/sbin/ -type f -mmin -10
```
Problem: Prüft auch `/usr/local/sbin/` - aber das sind **Skripte**, keine Unit-Files!  
Skript-Änderungen brauchen **kein daemon-reload**.

Gestern: Mehrere Skripte geändert (wartungs-watchdog, claude-respond-to-reports, chrony.conf)  
→ Check 7 triggerte → Check 8 dachte daemon-reload nötig → 10min Wartezeit

**Check 8:**
```bash
systemctl status | grep -q "warning.*unit files"
```
Problem: Kann **false positives** geben, reagiert auf systemd Warnungen die nicht relevant sind.

### Lösung
**Beide Checks entfernt** (Zeilen 155-164)

`wait_for_quiet()` prüft jetzt nur noch auf **wirklich kritische** Aktivitäten:
1. ✅ Services im activating Status (außer sich selbst)
2. ✅ Watchdog aktiv (letzte 2min)
3. ✅ Watchdog-Eskalationen
4. ✅ Service-Restarts (letzte 30s)
5. ✅ Andere Claude-Instanz läuft
6. ✅ /do Queue Worker läuft
7. ❌ ~~Service-Configs geändert~~ (zu aggressiv)
8. ❌ ~~systemd daemon-reload nötig~~ (false positives)

### Geändert
- `/usr/local/sbin/claude-respond-to-reports`: Check 7+8 entfernt

**Effekt:** Wartung startet sofort, keine 10-Minuten-Wartezeiten mehr wegen Skript-Änderungen


## 2026-02-07 - Wartungs-Prompt: Telegram-Redundanz vermeiden

### Problem
Claude sendete **zwei Telegram-Nachrichten**:
1. **07:28** - Lange Nachricht via `telegram-notify` (während Wartung)
2. **07:29** - Kurze Nachricht via `[TELEGRAM:OK]` (am Ende)

**Root Cause:** Prompt war unklar
- Erlaubte telegram-notify für "Nachrichten ohne Rückfrage"
- Forderte [TELEGRAM:OK] am Ende
- Claude nutzte BEIDES → Redundante Nachrichten

### Lösung
Prompt klargestellt (Zeilen 676-680):

**Vorher:**
```
Für Nachrichten ohne Rückfrage:
  /usr/local/sbin/telegram-notify "Info-Nachricht"
  /usr/local/sbin/telegram-notify --success "Erfolg"
  /usr/local/sbin/telegram-notify --error "Fehler"
```

**Nachher:**
```
Für Zwischenmeldungen (SELTEN nutzen, nur bei langen Operationen):
  /usr/local/sbin/telegram-notify "Info-Nachricht"  # Nur für lange Updates

WICHTIG: Nutze telegram-notify nur für ZWISCHENMELDUNGEN bei langen Operationen!
Die FINALE Wartungszusammenfassung MUSS via [TELEGRAM:OK] am Ende erfolgen.
```

### Geändert
- `/usr/local/sbin/claude-respond-to-reports`: Prompt-Klarstellung (Zeilen 676-680)

**Effekt:** Claude wird nur noch EINE Telegram-Nachricht senden ([TELEGRAM:OK] am Ende), keine redundanten Zwischenmeldungen mehr
