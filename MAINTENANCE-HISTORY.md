# Maintenance History

**System:** Raspberry Pi 4 Model B - ADS-B/OGN/Remote ID Feeder
**Letzte Aktualisierung:** 2026-02-03

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

