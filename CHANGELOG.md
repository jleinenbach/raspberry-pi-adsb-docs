# System Changelog

**System:** Raspberry Pi 4 Model B - ADS-B/OGN/Remote ID Feeder
**Letzte Aktualisierung:** 2026-02-04

Chronologische Historie aller implementierten System-Änderungen.

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
