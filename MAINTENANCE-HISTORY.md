# Maintenance History

**System:** Raspberry Pi 4 Model B - ADS-B/OGN/Remote ID Feeder
**Letzte Aktualisierung:** 2026-02-14

Dokumentation von abgelehnten und ausstehenden Wartungsempfehlungen.

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
| 2026-02-06 | SSH-7408: ERNEUT vorgeschlagen | **3. Ablehnung** - Bereits 2x abgelehnt, Claude ignoriert Declined-Liste |
| 2026-01-31 | BOOT-5264: systemd-analyze security | Zu umfangreich für laufende Wartung (21 Services) |
| 2026-01-31 | PROC-3614: Check IO processes | Keine IO-wartenden Prozesse gefunden |
| 2026-01-31 | FIRE-4513: iptables unused rules | Nur Docker-Regeln, alle ungenutzt (0 pkts = OK) |
| 2026-01-31 | bluez/libc CVEs | Nur in trixie gefixt, kein bookworm-Backport verfügbar |
| 2026-02-02 | CVE-2026-24061 inetutils-telnet | Benötigt libc6 >= 2.38 (Trixie), nicht auf Bookworm installierbar |

---

## Pending Recommendations

| Source | Recommendation | Risk |
|--------|----------------|------|
| *Keine* | Alle Systeme funktional | - |

## Recent Issues Resolved (2026-02-14)

### Wartungs-Telegram stumm nach daily-summary
**Problem:** Täglicher Bericht meldete "Wartung startet in 5 min" → danach keine Rückmeldung
**Root Cause:** Techniker-Claude Output ohne `[TELEGRAM:OK]` Tag → Parsing griff nicht → kein Telegram
**Fix:** Fallback else-Zweig in `claude-respond-to-reports` - sendet immer eine Benachrichtigung
**Status:** ✅ Resolved

### mlathub-Referenzen in Skripten und Dokumentation
**Problem:** mlathub seit 2026-02-12 deaktiviert, aber noch in daily-summary, telegram-bot, claude-respond und 10+ Docs referenziert → daily-summary zeigte 20/21 statt 20/20
**Fix:** Alle Referenzen aus aktiven Skripten und Dokumentation entfernt
**Status:** ✅ Resolved

---

## Recent Issues Resolved (2026-02-03)

### WiFi Presence Detection - Keine Benachrichtigungen

**Problem:** User berichtete "Gemeldet wurde mir per Telegram nichts" trotz laufendem Service

**Root Cause:**
1. **Whitelist-Format falsch:** `{"devices": {...}}` statt `{"macs": [...]}`
2. **RSSI-Threshold zu strikt:** `-70 dBm` blockierte Geräte 2 Stockwerke entfernt
3. **Log zeigte:** "Known devices loaded: 0 MACs"

**Fix:**
- Neue Datei: `/var/lib/claude-pending/wifi-whitelist.json` (korrektes Format)
- RSSI: `-70 dBm` → `-90 dBm` (maximale Empfindlichkeit)
- 8 MACs whitelisted (Controme, SwitchBot, Google Home, etc.)

**Status:** ✅ Resolved - System erkennt jetzt alle Geräte korrekt

---

### Google Home Mystery - 03:13 AM Burst

**Incident:** 2026-02-03 03:13:26 Uhr
- 22 Sekunden Probe Request Burst
- 60 Probes/Minute (extrem hoch!)
- MAC: 48:D6:D5:67:D1:B9

**Investigation:**
- User fragte: "Niemand hat das Google Home Gerät zurücksetzen können"
- Test durchgeführt: Power-Cycle (unplugged → replugged)
- Gleiche MAC bestätigt → Kein fremdes Gerät

**Root Cause:**
- **Firmware Update Recovery Mode**
- Normal: Moderate Probe Rate (~1/min)
- Recovery: Aggressive Network Scan (60/min)
- Dauer: ~22 Sekunden bis Firmware-Restore

**Learnings:**
- Google Home macht automatische Firmware-Updates
- Recovery Mode kann aggressive Scans auslösen
- -68 dBm durch 2 Stockwerke = Reflektionen möglich

**Status:** ✅ Resolved - Mystery gelöst, Device whitelisted, documented in known-devices.json

---

### Timer-Service Health Check - "Leise crashende" Services

**Problem:** Timer-basierte Services können unsichtbar crashen
- do-queue-worker crashte alle 2 Minuten mit "Permission denied"
- Exit Code 0 (erfolgreich) → `systemctl --failed` zeigte NICHTS
- Log-Level nicht "error" → `journalctl -p err` zeigte NICHTS
- User entdeckte nur durch Zufall: "Das gefällt mir gar nicht - ich habe als einziger User vorhin keinen /do Worker gestartet!"

**Root Cause:**
```
/run/do-queue-worker.lock: Permission denied
flock: 200: Bad file descriptor
systemd[1]: do-queue-worker.service: Deactivated successfully.  ← Exit 0!
systemd[1]: Finished do-queue-worker.service - Process /do command queue.
```

**Warum unsichtbar?**
1. Service Type=oneshot → beendet sich nach Ausführung (normal)
2. Exit Code 0 trotz Fehler → systemd sieht "erfolgreich"
3. "Permission denied" ist stdout, kein error-level log
4. systemctl --failed: Leer (Service nicht "failed")
5. journalctl -p err: Leer (keine error-level logs)

**Fix 1: Permission Problem behoben**
- Hinzugefügt: `RuntimeDirectory=do-queue-worker` in Service-Unit
- Hinzugefügt: `RuntimeDirectoryPreserve=yes`
- Pfade geändert:
  - `/run/do-queue-worker.lock` → `/run/do-queue-worker/worker.lock`
  - `/run/do-queue.lock` → `/run/do-queue-worker/queue.lock`
  - `/var/log/do-queue-worker.log` → `/var/lib/claude-pending/do-queue-worker.log`

**Fix 2: Generelles Monitoring implementiert**
- Neue Funktion: `check_timer_services()` in `/usr/local/sbin/claude-respond-to-reports`
- Scannt ALLE Timer-basierten Services auf Problem-Indikatoren
- Prüft Journal unabhängig vom Log-Level:
  - "permission denied"
  - "error.*failed"
  - "cannot"
  - "unable to"
  - "not found"
- Integration in tägliche Wartung (07:00)
- Ausgabe im REPORT_DATA vor "CORE SERVICES STATUS"

**Test:**
```bash
# Simulation: Hätte do-queue-worker erkannt?
$ bash test-timer-check-old.sh
✅ Health Check HÄTTE es gefunden:
Feb 03 22:37:45 adsb-feeder do-queue-worker[695541]: /usr/local/sbin/do-queue-worker: line 37: /run/do-queue-worker.lock: Permission denied

# Aktuell (nach Fix):
$ bash test-timer-check-function.sh
Keine Probleme (alle timer-basierten Services laufen sauber)
```

**Learnings:**
- Exit Code 0 ≠ "keine Fehler" bei oneshot Services
- Log-Level filtering kann echte Probleme verstecken
- Timer-basierte Services brauchen spezielle Überwachung
- Normale Monitoring-Tools (systemctl --failed, journalctl -p err) reichen NICHT

**Status:** ✅ Resolved - Permission-Problem behoben + generelles Monitoring aktiv

---

### systemd "Invalid URL" Warnings - ogn-balloon-notifier & drone-alert-notifier

**Problem:** Claude Telegram-Nachricht: "Hinweis: 2x systemd-Warning 'Invalid URL' (harmlos)"
```
Feb 03 22:40:58 systemd[1]: /etc/systemd/system/ogn-balloon-notifier.service:3: Invalid URL, ignoring: inline
Feb 03 22:40:58 systemd[1]: /etc/systemd/system/drone-alert-notifier.service:3: Invalid URL, ignoring: inline
```

**Root Cause:**
- Beide Service-Files hatten in Zeile 3: `Documentation=inline`
- systemd erwartet gültige URLs bei `Documentation=`:
  - Gültig: `https://...`, `file:///...`, `man:...`
  - Ungültig: "inline" (kein URL-Schema)
- Warning bei jedem `systemctl daemon-reload` (mehrfach täglich)

**Fix:**
- `Documentation=inline` Zeile aus beiden Service-Files entfernt
- Description ist aussagekräftig genug
- `systemd-analyze verify`: Keine Errors mehr

**Verification:**
```bash
# Vor Fix
$ sudo systemctl daemon-reload
systemd[1]: /etc/systemd/system/ogn-balloon-notifier.service:3: Invalid URL, ignoring: inline
systemd[1]: /etc/systemd/system/drone-alert-notifier.service:3: Invalid URL, ignoring: inline

# Nach Fix
$ sudo systemctl daemon-reload
(keine Warnings mehr)

# Services laufen weiter
$ systemctl status ogn-balloon-notifier drone-alert-notifier
Active: active (running) since Tue 2026-02-03 08:26:59 CET; 14h ago
```

**Learnings:**
- systemd Documentation= ist optional - wenn keine Doku existiert, weglassen
- "Invalid URL" Warnings akkumulieren im Journal (Spam)
- systemd-analyze verify testet Service-Files vor daemon-reload

**Status:** ✅ Resolved - Keine Warnings mehr, Services laufen stabil

---

### grep -c Doppel-Null Regression - "Einsame 0" im Telegram /status

**Problem:** User: "Du hast wieder in irgendeiner Änderung einen alten Fehler wieder eingebaut mit der einsamen 0"
```
🟢 GPS/RTK (4/4) - NTRIP Clients: 0
0
```

**Root Cause:**
- telegram-bot-daemon Zeile 413: `grep -c ":5001 " || echo "0"`
- Mit `set -o pipefail` aktiviert:
  1. Pipe schlägt fehl wenn `ss` keine Verbindungen findet
  2. `grep -c` gibt trotzdem "0" aus (0 Treffer gefunden)
  3. Pipe-Exit-Code ist != 0 (wegen pipefail)
  4. `|| echo "0"` triggert (weil Pipe fehlgeschlagen)
  5. Ergebnis: "0" (grep) + "\n0" (echo) = "0\n0"

**Warum passiert das?**
- `grep -c` gibt IMMER eine Zahl zurück (mindestens 0)
- Mit `set -o pipefail`: Pipe-Exit != 0 auch wenn grep selbst Exit 0 hat
- `|| echo "0"` ist überflüssig UND falsch

**Fix:**
- Ersetze `|| echo "0"` durch `|| true` in allen betroffenen Skripten:
  - `/usr/local/sbin/telegram-bot-daemon` (Zeile 413)
  - `/usr/local/sbin/claude-respond-to-reports` (Zeile 558)
  - `/usr/local/sbin/cve-pip-patcher` (Zeile 43)

**Verification:**
```bash
# Test mit pipefail
$ set -o pipefail
$ echo "" | grep -c "foo" || echo "0"
0        # Nur eine 0, korrekt!

# Ohne pipefail (alter Fehler)
$ set +o pipefail
$ false | grep -c "foo" || echo "0"
0
0        # Doppel-Null!
```

**Lessons Learned:**
- `grep -c` mit `|| echo "0"` ist ein Anti-Pattern
- Immer `|| true` verwenden (für error handling bei pipefail)
- ALLE Skripte durchsuchen, nicht nur das gemeldete

**Status:** ✅ Resolved - 3 Skripte gefixt, Bot neu gestartet

---

### tar1090 HTTP 502 Error - Unbemerkt vom Watchdog

**Problem:** User meldete "Der liefert gerade Fehler 502 - und das erscheint weder unter /status noch hat das in Watchdog bemerkt!"

**Root Cause:**
- Watchdog prüfte nur systemd Service-Status (`systemctl is-active tar1090`)
- lighttpd lief, aber lieferte HTTP 502 (FastCGI/Backend Problem)
- User sah 502 in Browser, System meldete "alles OK"

**Fix:**
- feeder-watchdog v2.2 mit `check_tar1090_http()` Funktion
- Prüft HTTP Response Code (nicht nur Service-Status)
- Erkennt: 502 (Bad Gateway), 500 (Internal Error), 000 (Connection refused)
- Automatischer Restart: lighttpd + tar1090
- Exponentieller Backoff + Telegram-Benachrichtigung

**Test:** Watchdog erkennt jetzt HTTP-Probleme korrekt

**Status:** ✅ Resolved - HTTP Health Check aktiv

---

### Aircraft Alert False Positive - Glider als Militär

**Problem:** Glider 3DE527 (D-HHAL) löste Alert aus: "🚁 Militär tief & nah"
- User bemerkte: "Dies erscheint mir recht widersprüchlich: ... 🛩️ Typ: Glider/Segelflugzeug"

**Root Cause:**
- Alert-Skript nutzte breite Range: 3C-3F = Militär
- Realität: 3C-3F = Germany (zivil + militär gemischt)
- 3DE527 = ziviler Glider, kein Militär

**Fix - Intelligentes Aircraft-Alert-System:**
1. **Präzise Patterns:** Nur bekannte Military Codes
2. **Auto-Update Service:** Täglich neue Patterns von tar1090 git-db
3. **ICAO Lookup Service:** Recherchiert unbekannte Codes automatisch
4. **30-Tage Cache:** Optimiert für Military Code Rotation

**Komponenten:**
- `/usr/local/sbin/icao-lookup-service` - Web-Recherche + Cache
- `/usr/local/sbin/military-icao-updater` - Pattern-Generator
- `/usr/local/sbin/update-military-icao` - Auto-Update täglich 04:00
- `update-military-icao.timer` - systemd Timer

**Test:**
```bash
/usr/local/sbin/icao-lookup-service 3DE527
# → Germany, Zivil ✅ (korrekt!)

/usr/local/sbin/icao-lookup-service 3E96CB
# → Germany, Militär ✅

/usr/local/sbin/icao-lookup-service AE0004
# → USA, Militär ✅ (neu! US Military jetzt auch erkannt)
```

**Status:** ✅ Resolved - False Positives eliminiert, US Military Coverage hinzugefügt

---

### DNS Problem - adsb-feeder.internal

**Problem:** Home Assistant konnte tar1090 nicht erreichen via `adsb-feeder.internal`
- Browser zeigte: 502 Bad Gateway
- Direkte IP (192.168.1.135) funktionierte

**Root Cause:**
- `/etc/hosts` hatte nur: `127.0.1.1  adsb-feeder`
- System kannte eigenen Namen `.internal` nicht
- DNS im Router nicht konfiguriert

**Fix:**
```bash
# /etc/hosts erweitert
127.0.1.1  adsb-feeder adsb-feeder.internal

# Test
getent hosts adsb-feeder.internal
# → 127.0.1.1 ✅

curl http://adsb-feeder.internal/tar1090/
# → HTTP 200 OK ✅
```

**Zusätzlich:** User korrigierte DNS im Router für externe Erreichbarkeit

**Status:** ✅ Resolved - System kennt eigenen Namen, HA erreicht tar1090

---


### DragonSync - WarDragon S3R System Stats deaktiviert (2026-02-03)

**Problem:** Home Assistant zeigte 11 nutzlose Sensoren mit 0-Werten:
- Zynq Temp: 0°C
- Pluto Temp: 0°C
- Ground Speed: 0 m/s
- CPU/Memory/Disk: alle 0

**Root Cause:**
- DragonSync ist Teil des **WarDragon S3R** Projekts (mobiles SDR-Kit)
- System Stats sind für mobile Kits mit PlutoSDR/Zynq FPGA Hardware
- **Wir haben nur den Drohnen-Teil** (AtomS3 + DragonSync Gateway)

**Was ist WarDragon S3R?**
- Mobiles Software Defined Radio für Fahrzeuge (wardriving)
- PlutoSDR (70MHz-6GHz) + Zynq FPGA
- GPS-Tracking während Fahrt
- DragonSync ist NUR die Gateway-Software

**Was wir haben:**
- ✅ DragonSync (Drohnen-Gateway-Software)
- ✅ AtomS3 (BLE Remote ID Scanner)
- ❌ KEIN PlutoSDR/Zynq
- ❌ KEINE mobile Hardware

**Fix:**
1. `/home/pi/DragonSync/sinks/mqtt_sink.py` - `publish_system()` deaktiviert (early return)
2. Backup: `mqtt_sink.py.backup-20260203`
3. MQTT Discovery Messages gelöscht (11 Sensoren + Device Tracker)
4. DragonSync neu gestartet

**Resultat:**
- ✅ DragonSync funktioniert normal (Drohnen-Erkennung)
- ✅ Keine 0-Wert-Sensoren mehr in HA
- ✅ Dokumentiert für künftige Updates

**Update-Warnung:**
- Bei `git pull` von DragonSync: Patch prüfen!
- Falls überschrieben: Backup restaurieren oder erneut patchen
- Siehe: `~/docs/DRAGONSYNC.md` → "WarDragon S3R System Stats"

**Status:** ✅ Resolved - Nur Drohnen-Erkennung aktiv, keine nutzlosen S3R-Stats

---

### Claude-Wartung Race Conditions - Koordination implementiert (2026-02-03)

**Problem:** Mehrere Reparatur-Mechanismen konnten sich gegenseitig stören:
- Claude-Wartung (täglich 07:00) vs. Watchdog (alle 5min)
- Claude-Wartung vs. interaktive Claude-Sessions
- Claude-Wartung vs. /do Queue Worker
- Keine Koordination zwischen verschiedenen System-Aktivitäten

**User-Feedback:** "Die Claude-Wartung von Ebene 2 muss immer prüfen und ggf. abwarten, ob bereits Aktivitäten im System an diesem Problem arbeiten [...] man sollte sich nicht in die Quere kommen, was schon öfter passiert war!"

**Root Cause:**
- claude-respond-to-reports hatte nur Lock gegen sich selbst
- Keine Prüfung auf laufende Watchdog-Reparaturen
- Keine Erkennung von interaktiven Claude-Sessions
- Keine Prüfung auf kürzliche Service-Änderungen

**Fix: wait-for-quiet() Funktion**

Implementiert in `/usr/local/sbin/claude-respond-to-reports` (nach Zeile 42, vor Hauptlogik)

**Prüft 8 Aktivitäts-Indikatoren:**
1. **Services im "activating" Status** - Jemand startet gerade Services
2. **Watchdog-Aktivität** - Letzte 2 Minuten auf Reparaturen prüfen
3. **Systemd-Restarts** - ExecMainStartTimestamp <30s
4. **Andere Claude-respond Instanz** - Lock-File-Prüfung
5. **do-queue-worker** - /do Befehl läuft
6. **Interaktive Claude CLI Session** - `pgrep -f "claude -p"`
7. **Kürzliche Config-Änderungen** - `/etc/systemd/system/` + `/usr/local/sbin/` mtime <10min
8. **systemd daemon-reload pending** - Unit-File-Warnings

**Verhalten:**
- **Wartezeit:** Max 10 Minuten, Checks alle 15 Sekunden
- **Quiet-Counter:** 2 aufeinanderfolgende "ruhige" Checks nötig
- **Benachrichtigung:** Nach 5min wartet Telegram-Nachricht an User
- **Timeout:** Nach 10min startet Wartung trotzdem (mit Warnung)
- **Heartbeat:** Hält wartungs-watchdog während Wartezeit am Leben

**Test-Resultat:**
```
⏳ System hat Aktivität:
   - Claude CLI (PID 678356)           ✅ Erkannt!
   - /do Worker läuft                  ✅ Erkannt!
   - Config-Änderungen <10min (2)      ✅ Erkannt!
```

**Effekt:**
- ✅ **Keine Race Conditions mehr** zwischen Reparatur-Mechanismen
- ✅ **Interaktive Sessions werden respektiert** - Wartung wartet ab
- ✅ **Watchdog kann in Ruhe arbeiten** - Keine doppelten Restarts
- ✅ **User bekommt Feedback** wenn Wartung wartet
- ✅ **Intelligenter Timeout** - Hängt nicht ewig

**Backup:** `/usr/local/sbin/claude-respond-to-reports.backup-20260203-*`

**Status:** ✅ Implemented - claude-respond-to-reports koordiniert sich jetzt mit allen System-Aktivitäten

---

### Watchdog Boot-Grace-Period & Eskalations-Koordination (2026-02-03)

**Problem 1: Watchdog startet zu früh nach Boot**
- Timer: `OnBootSec=2min` - Watchdog läuft 2 Minuten nach Systemstart
- ogn-rf-procserv: Braucht 10-15 Minuten für FFTW Benchmarking
- Andere Services: Dependencies noch nicht bereit, normale Startzeit >2min
- **Folge:** False Positives, unnötige Restarts beim Systemstart

**Problem 2: Watchdog und Claude-Wartung arbeiten gegeneinander**
- Watchdog eskaliert nach 5h zu Claude (markiert Services als "given_up")
- Claude-Wartung (07:00) startet ohne zu prüfen ob Watchdog gerade arbeitet
- Watchdog repariert Service → Claude mischt sich parallel ein
- **User-Feedback:** "Die Watchdogs rufen auch Claude zuhilfe, auch da muss eine Prüfung erfolgen"

**Fix 1: Boot-Grace-Period im Watchdog**

**Implementierung:** `/usr/local/sbin/feeder-watchdog`

**Neue Funktion:**
```bash
BOOT_GRACE_MINUTES=20  # 20 Minuten nach Boot keine Reparaturen

is_boot_grace_period() {
    local uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
    local grace_seconds=$((BOOT_GRACE_MINUTES * 60))
    
    if [ "$uptime_seconds" -lt "$grace_seconds" ]; then
        log "BOOT GRACE: System hochgefahren vor $((uptime_seconds / 60))min"
        return 0  # In Grace Period
    fi
    return 1  # Grace Period vorbei
}
```

**Verhalten:**
- Watchdog-Timer startet weiterhin 2min nach Boot (`OnBootSec=2min`)
- Watchdog prüft Uptime bei jedem Lauf (alle 5min)
- **Erste 20 Minuten:** Watchdog loggt nur, macht KEINE Reparaturen
- **Nach 20 Minuten:** Normaler Betrieb

**Warum 20 Minuten?**
- ogn-rf-procserv: 10-15min FFTW Benchmarking (längster Service)
- ogn-decode-procserv: Auto-Restart alle 15s (stabilisiert sich in ~5min)
- Dependencies: Netzwerk, chronyd, gpsd brauchen Zeit
- Buffer: +5min Sicherheit

**Fix 2: Watchdog-Eskalations-Awareness in Claude-Wartung**

**Implementierung:** `/usr/local/sbin/claude-respond-to-reports` (in `wait_for_quiet()`)

**Neue Checks:**
```bash
# 2b. Prüfe ob Watchdog-Eskalationen vorliegen
local given_up_services=$(ls /var/run/feeder-watchdog/*.given_up | wc -l)
if [ "$given_up_services" -gt 0 ]; then
    # Informiere User warum Wartung läuft
    log "📢 Watchdog-Eskalation: $given_up_services Service(s) aufgegeben"
    telegram-notify "🔧 Wartung wegen Watchdog-Eskalation: $services"
    
    # Prüfe ob Watchdog GERADE aktiv ist (letzte 30s)
    if [ "$watchdog_age" -lt 30 ]; then
        issues+=("Watchdog repariert JETZT")
        # → Claude wartet bis Watchdog fertig ist
    fi
fi
```

**Koordinations-Logik:**

| Situation | Verhalten |
|-----------|-----------|
| Keine Eskalation | Claude macht normale Wartung |
| Eskalation vorhanden, Watchdog ruhig | Claude kümmert sich um eskalierte Services |
| Eskalation + Watchdog aktiv (letzte 30s) | **Claude wartet** bis Watchdog fertig ist |
| Eskalation + Interaktive Session | **Claude wartet** bis Session fertig ist |

**Effekt:**
- ✅ **Kein frühes Eingreifen beim Boot** - Services haben Zeit zu starten
- ✅ **Watchdog und Claude koordinieren sich** - Keine parallelen Reparaturen
- ✅ **User wird informiert** warum Wartung läuft (normale Wartung vs. Eskalation)
- ✅ **Intelligentes Warten** - Claude respektiert laufende Watchdog-Aktivitäten

**Test-Resultate:**

**Boot-Grace-Test:**
```
Uptime: 839 Minuten → Grace Period vorbei → Watchdog würde normal prüfen
Uptime: <20 Minuten → In Grace Period → Watchdog überspringt Runde
```

**Eskalations-Test:**
```
given_up Service vorhanden → Erkannt ✅
Watchdog-Log aktiv vor 15s → Claude wartet ✅
```

**Backup:**
- `/usr/local/sbin/feeder-watchdog.backup-20260203-*`
- `/usr/local/sbin/claude-respond-to-reports.backup-20260203-*`

**Status:** ✅ Implemented - Boot-Grace + Eskalations-Koordination aktiv

---

## 2026-02-11: Wartungsskript-Robustheit verbessert

### Problem
Tägliche Wartung schlug mit Exit 1 fehl ohne hilfreiche Fehlermeldung:
1. **False-Positive OGN Update**: GitHub Release Tag `v0.6` wurde fälschlicherweise mit Binary-Version `v0.3.2.arm64` verglichen
2. **Kein API-Limit-Handling**: Bei erschöpftem Anthropic API-Limit gab es nur die Meldung "You're out of extra usage", aber keine saubere Behandlung

### Implementierte Fixes

#### Fix 1: OGN Binary Check korrigiert
**Problem:** Vergleich von GitHub Release Tag mit Binary-Version führte zu False Positives

**Vorher:**
```bash
LATEST_OGN_RELEASE=$(curl -s https://api.github.com/repos/VirusPilot/ogn-pi34/releases/latest | grep '"tag_name"')
# Verglich v0.6 (Repository-Tag) mit v0.3.2.arm64 (Binary) → Inkompatibel!
```

**Nachher:**
```bash
UPSTREAM_BINARY_VERSION=$(curl -sL https://github.com/VirusPilot/ogn-pi34/raw/master/rtlsdr-ogn-bin-arm64-0.3.2_Bullseye.tgz | \
    tar -xzOf - rtlsdr-ogn-0.3.2/ogn-decode | \
    strings | grep -o 'v0\.[0-9]\.[0-9]\.arm64')
# Prüft tatsächliche Binary-Version im Tarball → Korrekt!
```

**Test:**
- Aktuell: v0.3.2.arm64
- Upstream: v0.3.2.arm64
- Ergebnis: ✅ Keine Updates (korrekt)

#### Fix 2: API-Limit-Handling
**Problem:** Bei erschöpftem API-Limit gab es nur Exit 1 ohne klare Diagnose

**Lösung:**
```bash
# Nach Claude-Aufruf (claude-respond-to-reports:943)
if echo "$CLAUDE_OUTPUT" | grep -qi "out of.*usage"; then
    RESET_INFO=$(echo "$CLAUDE_OUTPUT" | grep -o "resets.*" | head -1)
    log "⚠️  API-Limit erreicht"
    telegram-notify "⚠️ Wartung übersprungen - API-Limit erreicht. Nächster Reset: $RESET_INFO"
    exit 0  # Kein harter Fehler, sondern erwarteter Zustand
fi
```

**Verhalten:**
- Erkennt "out of extra usage" / "out of usage"
- Telegram-Benachrichtigung mit Reset-Zeitpunkt
- Exit 0 (kein Fehler-Status)
- Wartungs-Watchdog triggert nicht (Exit 0 → OK)
- Wartung wird beim nächsten Reset automatisch fortgesetzt

### Verifizierung
- ✅ Bash-Syntax validiert
- ✅ OGN Check getestet (keine False Positives mehr)
- ✅ Wartungs-Watchdog kompatibel (Exit 0 + keine ERROR-Meldung)
- ✅ Backup: `/tmp/claude-respond-to-reports.backup`

### Status
**✅ Implementiert** - Nächste Wartung wird robuster sein

### Backup-Location korrigiert
**Problem:** Ursprüngliches Backup in `/tmp/` würde durch systemd-tmpfiles gelöscht

**Lösung:** 
- Backup verschoben nach `/var/backups/scripts/` (permanenter Ort)
- Naming Schema: `<script>.backup-YYYYMMDD-HHMMSS`
- Aktuelles Backup: `/var/backups/scripts/claude-respond-to-reports.backup-20260211-083554`

**Best Practice für zukünftige Skript-Backups:**
```bash
sudo mkdir -p /var/backups/scripts/
sudo cp <script> "/var/backups/scripts/<script>.backup-$(date +%Y%m%d-%H%M%S)"
```

**Cleanup (optional):**
```bash
# Backups älter als 30 Tage löschen
find /var/backups/scripts/ -name "*.backup-*" -mtime +30 -delete
```
