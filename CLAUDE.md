# System Maintenance Assistant

**Raspberry Pi 4 Model B** | Debian 12 (bookworm)
**Standort:** 49.86625, 10.83948 | 283m

> **Dokumentation:** `~/docs/FEEDS.md` | `~/docs/MONITORING.md` | `~/docs/OGN-SETUP.md` | `~/docs/HOME-ASSISTANT.md` | `~/docs/DRAGONSYNC.md`

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
│    AtomS3 → zmq-decoder → DragonSync → Home Assistant         │
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

## Declined Recommendations
*NICHT erneut vorschlagen!*

| Datum | Item | Grund |
|-------|------|-------|
| 2026-01-16 | USB-1000: USB storage deaktivieren | User will USB behalten |
| 2026-01-16 | AUTH-9282: Password expiration | User: NIEMALS |
| 2026-01-16 | AUTH-9262: PAM password strength | User will nicht |
| 2026-01-16 | FILE-6310: Separate Partitionen | Nicht ohne Reinstall |
| 2026-01-16 | DEB-0880: fail2ban | System nur im LAN |
| 2026-01-18 | SSH-7408: X11/Agent/TCP Forwarding | User: Nein |
| 2026-01-18 | BANN-7126/7130: Login Banner | User: Nein |
| 2026-01-19 | smartmontools | Nicht sinnvoll für SD-Karten |
| 2026-01-25 | KRNL-5788: Kernel-Update | Bereits auf neuestem Stand (6.12.62) |
| 2026-01-25 | LOGG-2154: External Logging | Übertrieben für LAN-System |
| 2026-01-25 | ACCT-9622: Process Accounting | Ressourcenintensiv für Pi |
| 2026-01-25 | ACCT-9628: auditd | Ressourcenintensiv für Pi |
| 2026-01-25 | CONT-8104: Docker Warnings | ARM-spezifisch, nicht änderbar |
| 2026-01-30 | SSH-7408: MaxSessions/TCPKeepAlive | Schränkt SSH-Client-Funktionalität ein |

---

## Pending Recommendations
| Source | Recommendation | Risk |
|--------|----------------|------|
| - | *Keine offenen Empfehlungen* | - |

---

## Implemented Changes (Gruppiert)

### Security & Hardening (2026-01-16 bis 2026-01-25)
- SSH hardening, Protocols disabled, Core dumps off, UMASK 027
- Kernel Security Hardening (`/etc/sysctl.d/99-security.conf`)
- AppArmor für: readsb, piaware, rbfeeder, pfclient, airplanes-feed
- Systemd Hardening: autogain1090 (9.6→4.6), readsb (9.2→6.7)
- Security Tools: debsecan, lynis, aide, rkhunter, apt-listbugs
- apt-listbugs: Blockiert unattended-upgrades bei kritischen Bugs
- STRG-1846: Firewire-Module geblacklistet (`/etc/modprobe.d/blacklist-firewire.conf`)
- HRDN-7222: Compiler (gcc/g++) nur für root zugänglich
- PKGS-7370: debsums wöchentliche Integritätsprüfung aktiviert

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
- ZMQ-Decoder für ESP32 (`zmq-decoder.service`)
- MQTT → Home Assistant Discovery
- udev-Regel für AtomS3 (`/dev/remoteid`)
- FAA RID Lookup-Datenbank
- **Datenfluss:** AtomS3 (BLE) → zmq-decoder → DragonSync → Home Assistant (nur MQTT, lokal)

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
- **Aircraft Alert System (2026-01-30):** Telegram-Benachrichtigungen für interessante Flugzeuge
  - **Service:** `aircraft-alert-notifier.service` - Überwacht alle 10s readsb aircraft.json
  - **6 Alert-Typen:** Militär tief & nah, Extrem tief, Emergency (7700/7600/7500), Schnelle Tiefflieger, Hubschrauber nah, Laut & nah
  - **Hubschrauber-Radius:** 9km (2x Entfernung Heckenweg → Klinikum Bamberg Bruderwald ~4.5km)
  - **Benachrichtigungen:** Vollständig metrisch (m/km/h) + imperial (ft/kt/nm), mit Begründung, Himmelsrichtung, Steig/Sinkrate
  - **Deduplizierung:** Pro Alert-Typ & Flugzeug individueller Cooldown (5min-1h)
  - **Militär-Erkennung:** Deutsche ICAO-Range 3C-3F, Squawk-Erklärungen (7700=Notfall, 7600=Funkausfall, 7500=Entführung)
- **OGN Balloon Notifier (2026-01-30):** Telegram-Benachrichtigungen für Heißluftballons
  - **Service:** `ogn-balloon-notifier.service` - APRS-Stream von glidernet.org
  - **Filter:** OGN Type 11 (Balloon) innerhalb 100km Radius Stegaurach
  - **Deduplizierung:** Max. 1x pro Ballon alle 4 Stunden
  - **Hinweis:** Meiste Hobby-Ballons haben kein FLARM - nur kommerzielle/Flughafen-nahe Ballons sichtbar

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

### System
- zram swap, tmpfs /var/log, Log-Persistenz
- NTP: PTB Stratum-1 mit NTS
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

## Telegram Bot
**Bot:** @adsb_feeder_alerts_bot | **Daemon:** `systemctl status telegram-bot`

| Befehl | Beschreibung |
|--------|--------------|
| `/status` | System Health + Drohnen live |
| `/stats` | Statistiken (ADS-B, OGN/FLARM, Remote ID) |
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

## Überwachte Services (23 + zmq-decoder)
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

### DragonSync (1)
dragonsync

### Alert Services (2)
aircraft-alert-notifier, ogn-balloon-notifier

**Sonderfall:** `zmq-decoder` wird separat überwacht (nur wenn `/dev/remoteid` existiert)

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

## Lessons Learned

### Bash-Fallen
| Problem | Lösung |
|---------|--------|
| `grep -c` bei 0 Treffern | `VAR=$(grep -c ... 2>/dev/null) \|\| true` |
| heredoc mit Variablen | `<< 'EOF'` = literal, `<< EOF` = expandiert |
| Log-Dateien lesen | Immer `sudo` für /var/log/* |
| `source` von Dateien | Nie! Stattdessen: `VAR=$(grep "^KEY=" file \| cut -d= -f2-)` |
| Temp-File Permissions | `chmod` VOR `mv`, nicht danach |
| Log-Rotation | `tail -n > tmp && chmod 644 tmp && mv tmp log` |
| Race Conditions | `flock` für atomare Operationen |
| curl hängt | Immer `--max-time 10` verwenden |
| **Pipe-while Subshell** | **`echo \| while` läuft in Subshell! Nutze `mapfile -t array < <(...)` + `for`** |
| **`wc -l` + `\|\| echo "0"`** | **Gibt doppelte "0" aus! `wc -l` gibt immer Zahl zurück, braucht kein Fallback** |
| **Lock-Files mit Befehlen** | **`$LOCK.$cmd` bei `/stats` → `/path/lock./stats` (ungültig)! Entferne `/` mit `${cmd#/}`** |
| **flock für atomare Locks** | **`exec 200>/lock` GLOBAL (nicht in Funktion)! FD muss bis Exit offen bleiben** |
| **systemd PIDFile** | **ExecStartPre=/bin/rm -f pidfile verhindert Stale-Locks bei Crash/Kill** |

### Systemspezifisch
| Erkenntnis | Kontext |
|------------|---------|
| Feed-Client ≠ Haupt-Decoder | `/usr/bin/readsb` vs. `feed-*` Binaries |
| AppArmor bei Störungen prüfen! | `dmesg \| grep apparmor.*DENIED` |
| Bot/Watchdog/Wartung synchron | Alle 3 Service-Listen aktualisieren + daily-summary! |
| Systemd: ReadWritePaths existieren | Sonst NAMESPACE-Fehler |
| ProtectSystem=strict vs full | strict braucht explizite /etc Pfade |
| `.claude/` muss pi gehören | Nach root-Ausführung: `chown -R pi:pi ~/.claude` |
| pip install auf Debian | `--user --break-system-packages` für PEP 668 |
| pip überschreibt apt | User-pip-Pakete haben Vorrang vor system-wide |
| **FFTW Benchmarking** | **Bei JEDEM Start 10-15min! Braucht TimeoutStartSec=20m** |
| Watchdog vs. langsame Starts | Watchdog kennt keine Grace-Period, False-Positives möglich |
| FFTW Wisdom nicht gespeichert | `/etc/fftw/` existiert nicht, daher Benchmarking wiederholt sich |
| **librtlsdr Debian-Paket veraltet** | **0.6.0-4 aus 2012, kennt V4 nicht! Nutze rtlsdr-blog stattdessen** |
| V4-Library nach /usr/local/ | Debian-Paket nach /lib/, `/usr/local/` hat Vorrang (ldconfig) |
| ldd zeigt Library-Links | `ldd /usr/bin/rbfeeder \| grep rtlsdr` prüft welche Version genutzt wird |
| Kompilierte Library = Dummy-Paket | Wenn Library selbst kompiliert: Dummy-deb für apt-Abhängigkeiten erstellen |
| **USB-Kabel testen!** | **Charge-Only Kabel (nur VCC+GND) verhindern USB-Kommunikation komplett** |
| USB Cable Health Check | BLE cableQU zeigt: Widerstand, Pin-Belegung, Shield-Qualität |
| ESP32 "Invalid image block" | Korrupte Firmware → Flash komplett löschen (erase_flash) vor Reflash |
| esptool write-flash | Immer mit `-z` (komprimiert) und `0x0` (Startadresse) flashen |
| drone-mesh-mapper Firmware | Lokal in `/home/pi/drone-mesh-mapper/firmware/*.bin`, kein GitHub Release |
| **Telegram Bot Mehrfachinstanzen** | **PID-Lock + Command-Lock essentiell! Alte Instanzen über Tage = gecachte alte Ausgaben** |
| **Bash Code-Caching** | **Bash lädt Skripte komplett beim Start! Änderungen nach Start = alter Code im Speicher** |
| Bot Lock-Files | PID: `/var/run/telegram-bot.pid`, Command: `/var/run/telegram-command.lock.$cmd` |

### Security Best Practices
| Pattern | Warum |
|---------|-------|
| `set -o pipefail` | Erkennt Fehler in Pipes (z.B. `cmd1 \| cmd2`) |
| Input-Sanitization | Entferne `$()`, Backticks, `${` aus User-Input |
| Path-Validierung | Prüfe auf `..` und absolute Pfade bei Config-Einträgen |
| Atomare Dateiops | `flock` oder `(umask 077 && touch file)` |
| Keine Secrets in Logs | Token/Passwörter nie in Fehlermeldungen |

### Telegram Bot Mehrfach-Antworten - Root Cause (2026-01-30)

**Problem:** 3-11 Antworten auf eine /stats Anfrage

**Root Causes (multiple):**
1. **flock ohne globalen FD**: `exec 200>` in Funktion → FD sofort geschlossen nach Funktions-Ende
2. **Bash Code-Caching**: Alte Bot-Prozesse mit altem Code im Speicher (Bash lädt Skript komplett beim Start)
3. **Command-Lock mit Slash**: `/var/run/telegram-command.lock./stats` ungültig (touch failed)

**Lösung:**
```bash
# FALSCH - FD in Funktion (wird geschlossen):
acquire_bot_lock() {
    exec 200>/var/run/telegram-bot.lock
    flock -n 200 || exit 1
}

# RICHTIG - Globaler FD (bleibt offen):
exec 200>/var/run/telegram-bot.lock  # GLOBAL vor acquire_bot_lock
acquire_bot_lock() {
    flock -n 200 || exit 1
}
```

**Weitere Fixes:**
- Command-Lock: `cmd_name="${cmd#/}"` entfernt führenden Slash
- Debug-Logging half zu verifizieren: Nur 1x handle_command, 1x send_message
- Process Substitution `mapfile -t < <(...)` erstellt Child-Prozess (normal, kein Bug)

### AtomS3R Upgrade - AtomS3 durch AtomS3R ersetzt (2026-01-30)

**Hardware-Upgrade:**
- Alt: AtomS3 (ESP32-S3, kein PSRAM)
- Neu: AtomS3R (ESP32-S3 + 8MB PSRAM)

**Details AtomS3R:**
- Chip: ESP32-S3-PICO-1 (LGA56) rev v0.2
- Flash: 8MB
- PSRAM: 8MB (eingebaut!)
- MAC: E4:B3:23:FA:93:F4
- Firmware: esp32s3-dual-rid.bin (1.4 MB)

**Änderungen:**
- udev-Regel: Serial Number spezifisch für AtomS3R
- /dev/remoteid → ttyACM0 (neuer MAC)
- zmq-decoder läuft auf neuem Gerät
- DragonSync unverändert (gleicher ZMQ-Port 4224)

**Vorteile:**
- Deutlich mehr Drohnen gleichzeitig trackbar
- Bessere Performance bei hoher Last
- Zukunftssicher für große Events
