# System-Monitoring & Schedules

## Schedules (Cron/Timer)

### Täglich
| Zeit | Task | Beschreibung |
|------|------|--------------|
| 00:22 | lynis | Security Audit |
| 02:41 | AIDE | File Integrity Check |
| ~03:00 | rkhunter | Rootkit Scan |
| 03:30 | autogain | Gain-Optimierung (12h Periode) |
| 06:00 | sd-health-check | SD-Karten-Monitoring |
| 06:55 | daily-summary | Telegram-Zusammenfassung |
| 07:00 | claude-wartung | Automatische Systemwartung |
| 15:30 | autogain | Gain-Optimierung (12h Periode) |
| stündlich | debsecan | CVE-Check |

### Alle 5/10 Minuten
| Intervall | Task | Beschreibung |
|-----------|------|--------------|
| 5 min | feeder-watchdog | Prüft alle 16 Services |
| 10 min | wartungs-watchdog | Prüft Claude-Wartung auf Hänger |

### Wöchentlich (Sonntag)
| Zeit | Task |
|------|------|
| 03:00 | config-backup |
| 04:00 | dns-fallback-update |
| 05:00 | TheAirTraffic Update-Check |
| 05:15 | airplanes.live Update-Check |
| 05:30 | RadarBox Update-Check |
| 05:45 | Plane Finder Update-Check |
| 06:00 | OGN DDB Update |

### Bei Events
- **Shutdown:** Logs auf persistenten Speicher sichern
- **Wartung 07:00:** wiedehopf-Tools Update-Check

---

## Watchdog-System

### feeder-watchdog (alle 5 min)
**Prüft:**
- Dependencies: NetworkManager, chronyd, dbus, systemd-udevd
- Network: Internet (ping 8.8.8.8)
- Hardware: RTL-SDR USB
- 16 Feeder-Services (siehe CLAUDE.md)
- Data quality: Flugzeuge + Nachrichten
- Signal: Übersteuerung (>0 dB)

**Backoff:** 5min → 10min → 20min → 40min → 80min → 160min → Eskalation (~5h)

**Telegram:**
- Bei Störung erkannt: Sofortige Warnung
- Bei Reparatur: Bestätigung
- Bei 3. Fehlversuch: Kritische Warnung
- Bei Eskalation: Alarm + Hinweis auf Claude-Wartung

### wartungs-watchdog (alle 10 min)
**Prüft:**
- Wartung hängt? (>20 Min Laufzeit)
- Heartbeat veraltet? (>10 Min)
- Fehler in Logs?
- Verwaiste Lock-Datei?

**Bei Problem:** Diagnose-Claude wird gestartet

**Heartbeat:** `/var/run/claude-respond.heartbeat`
**Cooldown:** 30 Min nach Diagnose

---

## SD-Karten-Monitoring
*Samsung MAX Endurance*

**Skript:** `/usr/local/sbin/sd-health-check`
**Timer:** Täglich 06:00

**Funktionen:**
- Tägliche Schreibstatistik (MB seit Boot)
- I/O-Fehler-Erkennung aus dmesg
- Telegram-Warnung bei >5GB/Tag oder I/O-Fehlern

**Daten:**
- `/var/lib/sd-health/stats.dat`
- `/var/lib/sd-health/history.log`

**Prüfen:**
```bash
sudo /usr/local/sbin/sd-health-check status
dmesg | grep -iE 'mmcblk.*error|mmc0.*timeout'
```

---

## Zeitsynchronisation
*Kritisch für MLAT-Genauigkeit*

**Daemon:** chronyd
**Config:** `/etc/chrony/chrony.conf`

**Zeitquellen (Priorität):**
1. PTB Stratum-1 (ptbtime1-3.ptb.de) mit NTS
2. OPNsense Router (Fallback)
3. debian.pool.ntp.org (Notfall)

**Erwartete Werte:**
| Metrik | Gut | Problematisch |
|--------|-----|---------------|
| System Offset | <1 ms | >10 ms |
| Stratum | 2 | >4 |

**Prüfen:** `chronyc sources` und `chronyc tracking`

---

## MLAT-Hub (2026-01-26)
*Dedupliziert MLAT-Ergebnisse von 4 Clients*

**Service:** `mlathub.service` (zweite readsb-Instanz)
**Config:** `/etc/systemd/system/mlathub.service`

### Ports
| Port | Richtung | Beschreibung |
|------|----------|--------------|
| 39004 | Input | Beast von MLAT-Clients |
| 39005 | Output | Beast (für Debugging) |
| → 30104 | Output | An readsb (dedupliziert) |

### Verbundene Clients
| Client | Konfiguration |
|--------|---------------|
| adsbexchange-mlat | `/etc/default/adsbexchange` |
| adsbfi-mlat | `/etc/default/adsbfi` |
| airplanes-mlat | `/etc/default/airplanes` |
| piaware (fa-mlat-client) | `/etc/piaware.conf` |

### Prüfbefehle
```bash
# Service-Status
systemctl status mlathub

# Anzahl verbundener Clients (sollte 4 sein)
ss -tnp | grep ':39004.*ESTAB' | wc -l

# Verbindung zu readsb
ss -tnp | grep 'readsb.*30104.*ESTAB'

# Journal
journalctl -u mlathub --since "10 minutes ago"
```

### Abhängigkeiten
- Startet nach: `readsb.service`
- Gebunden an: `readsb.service` (stoppt wenn readsb stoppt)

---

## Systemd Service Hardening

**Drop-in Locations:**
- `/etc/systemd/system/autogain1090.service.d/hardening.conf`
- `/etc/systemd/system/readsb.service.d/hardening.conf`

**Security Scores:**
| Service | Vorher | Nachher |
|---------|--------|---------|
| autogain1090 | 9.6 UNSAFE | 4.6 OK |
| readsb | 9.2 UNSAFE | 6.7 MEDIUM |

**Prüfen:**
```bash
systemd-analyze security autogain1090.service | tail -1
systemd-analyze security readsb.service | tail -1
```

**Wichtig:** ReadWritePaths braucht existierende Pfade (sonst NAMESPACE-Fehler)

---

## Hardware-Diagnose & Spannungsüberwachung

### RTL-SDR Treiber-Validierung

**Zweck:** Prüft ob der korrekte V4-spezifische Treiber installiert ist (nicht Generic-Fallback)

**Test-Befehl:**
```bash
rtl_test -d 1 -t
```

**Was zu prüfen ist:**
| Check | Erwarteter Output | Bedeutung |
|-------|-------------------|-----------|
| Tuner-Chip | `Found Rafael Micro R828D tuner` | ✅ V4-spezifischer Treiber |
| Device-Name | `RTLSDRBlog, Blog V4` | ✅ Nicht Generic RTL2832U |
| Serial | `SN: 00000001` | Device-Index korrekt |

**Fehlerhafte Ausgabe:**
```
Found Realtek RTL2832U (Generic)
Found Rafael Micro R820T tuner  ← FALSCH! (R820T statt R828D)
```

**Bei falschem Treiber:**
1. RTL-SDR V4 vom falschen USB-Port entfernen
2. Korrekte Installation: https://github.com/rtlsdrblog/rtl-sdr-blog
3. Blacklist Generic-Treiber falls nötig

**Diagnose-Skript:** `/tmp/voltage-check-function.sh` (Beispiel)

---

### USB-Spannungsüberwachung (vcgencmd)

**Zweck:** Erkennt Netzteil-Probleme, USB-Überlastung und defekte Kabel

**Check-Befehl:**
```bash
vcgencmd get_throttled
```

**Hex-Code-Interpretation:**
| Hex-Wert | Icon | Status | Bedeutung | Aktion |
|----------|------|--------|-----------|--------|
| `0x0` | 🟢 | Stabil | Keine Probleme | - |
| `0x10000` | 🟡 | War niedrig | Unterspannung in Vergangenheit | Netzteil prüfen |
| `0x50000` | 🟡 | War niedrig | Unterspannung + Throttling | Netzteil prüfen |
| `0x1` | 🔴 | KRITISCH | Unterspannung JETZT! | Sofort Netzteil tauschen |
| `0x50005` | 🔴 | KRITISCH | Unterspannung + Throttling JETZT | Sofort Netzteil tauschen |

**Bit-Bedeutung:**
- **Bit 0** (`& 0x1`): Aktuell Unterspannung (unter 4.63V)
- **Bit 16** (`& 0x10000`): Jemals Unterspannung seit Boot

**Beispiel-Code:**
```bash
throttled=$(vcgencmd get_throttled | cut -d= -f2)
throttled_dec=$((throttled))
bit0=$((throttled_dec & 0x1))
bit16=$((throttled_dec & 0x10000))

if [ "$throttled" = "0x0" ]; then
    echo "🟢 Stabil"
elif [ "$bit0" -eq 1 ]; then
    echo "🔴 Unterspannung JETZT!"
elif [ "$bit16" -ne 0 ]; then
    echo "🟡 Unterspannung in Vergangenheit"
fi
```

**Überwacht in:**
- `/usr/local/sbin/telegram-bot-daemon` → `/status` Hardware-Sektion
- `/usr/local/sbin/claude-respond-to-reports` → Stromversorgungs-Check
- `/usr/local/sbin/daily-summary` → System-Status

**Output-Format in den verschiedenen Skripten:**

**1. Telegram Bot (`/status` Befehl):**
```
*Hardware*
✅ SDR | 🌡 47.2°C | 📡 -25dB
🟢 Spannung: Stabil                    ← Spannungsüberwachung
🟢 OGN/FLARM (3/3) - Empfang: 0/0
```

**2. Daily Summary (06:55 Uhr vor Wartung):**
```
*System*
⏱ Uptime: 2 days, 3 hours
💾 RAM: 45%
🌡 Temp: 47.2°C
🟢 Spannung: Stabil                    ← Spannungsüberwachung
```

**3. Wartungsskript (claude-respond-to-reports):**
```
=== STROMVERSORGUNG ===
Throttled: 0x0 (🟢 Stabil)
```

**Test der Integration:**
```bash
# 1. Telegram Bot (simuliert)
vcgencmd get_throttled
# Erwartete Ausgabe: throttled=0x0

# 2. Daily Summary manuell ausführen
sudo /usr/local/sbin/daily-summary

# 3. Wartung (zeigt Stromversorgungs-Sektion)
# Wird automatisch um 07:00 ausgeführt oder mit /wartung
```

**Häufige Ursachen:**
| Problem | Symptom | Lösung |
|---------|---------|--------|
| Schwaches Netzteil | `0x50000` bei Last | Offizielles RPi 4 Netzteil (5.1V/3A, USB-C) |
| USB-Überlastung | `0x10000` sporadisch | RTL-SDR an USB 3.0 Port (blau) |
| Defektes Kabel | `0x1` trotz gutem Netzteil | USB-C Kabel mit E-Mark Chip |
| Zu viele USB-Geräte | Throttling bei Aktivität | Powered USB Hub verwenden |

**Wichtig:** RTL-SDR Blog V4 sollte IMMER an USB 3.0 Port (blau) betrieben werden!

**Vollständiger Diagnose-Bericht:**
```bash
echo "=== RTL-SDR Treiber ==="
rtl_test -d 1 -t

echo -e "\n=== Stromversorgung ==="
vcgencmd get_throttled

echo -e "\n=== USB-Devices ==="
lsusb | grep -iE 'RTL|SDR|0BDA:2838|0BDA:2832'

echo -e "\n=== Temperatur ==="
vcgencmd measure_temp
```

**Beispiel-Output (OK):**
```
=== RTL-SDR Treiber ===
Device 1: RTLSDRBlog, Blog V4, SN: 00000001
Found Rafael Micro R828D tuner

=== Stromversorgung ===
throttled=0x0

=== USB-Devices ===
Bus 002 Device 002: ID 0bda:2832 Realtek RTL2832U (RTL-SDR Blog V4)
Bus 001 Device 003: ID 0bda:2838 Realtek RTL2838UHIDIR

=== Temperatur ===
temp=45.6'C
```

**Bei Problemen:**
1. Netzteil-Check: Offizielles RPi 4 Netzteil? (5.1V/3A)
2. USB-Port-Check: V4 an USB 3.0? (blau, nicht schwarz)
3. Kabel-Check: USB-C mit E-Mark Chip?
4. Last-Check: Andere USB-Geräte entfernen zum Testen

---

## Logs
| Pfad | Inhalt |
|------|--------|
| `/var/log/claude-maintenance/` | Wartung + Diagnose |
| `/var/log/wartungs-watchdog.log` | Wächter-Prüfungen |
| `/var/log/feeder-watchdog.log` | Feeder-Checks |
| `/var/log/lynis-report.dat` | Security Audit |
| `/var/log/rkhunter.log` | Rootkit Scan |
| `/var/log/aide/` | File Integrity |

---

## apt-listbugs (Paket-Sicherheit)
*Blockiert automatische Installation von Paketen mit kritischen Debian-Bugs*

**Konfiguration:**
- `/etc/apt/apt.conf.d/10apt-listbugs` - Hook für dpkg
- `/etc/apt/apt.conf.d/05apt-listbugs-auto` - Automatischer Modus (`-n`)

**Verhalten:**
- Prüft vor jeder Installation auf critical/grave/serious Bugs
- Bei Bugs gefunden: Installation wird abgebrochen
- Gepinnte Pakete: `/etc/apt/preferences.d/apt-listbugs`

**Prüfbefehle:**
```bash
# Blockierte Pakete anzeigen
cat /etc/apt/preferences.d/apt-listbugs 2>/dev/null

# Manuell Bugs für Paket prüfen
apt-listbugs list PAKETNAME

# Timer für Pin-Cleanup
systemctl status apt-listbugs.timer
```

**Severities:** critical, grave, serious (Release-kritisch)

---

## Custom Scripts
| Skript | Beschreibung |
|--------|--------------|
| claude-respond-to-reports | Techniker-Claude (Wartung) |
| wartungs-watchdog | Wächter-Claude |
| telegram-secretary | Sekretär-Claude (Validierung) |
| telegram-ask | User-Fragen |
| telegram-notify | Benachrichtigungen |
| telegram-bot-daemon | Bot für Befehle |
| feeder-watchdog | Service-Monitoring |
| daily-summary | Tägliche Zusammenfassung |
| log-persist | Log-Persistenz für tmpfs |
| update-dns-fallback | DNS Fallback Updates |
| sd-health-check | SD-Karten-Monitoring |
| ogn-ddb-update | OGN Database Update |

Alle in `/usr/local/sbin/`
