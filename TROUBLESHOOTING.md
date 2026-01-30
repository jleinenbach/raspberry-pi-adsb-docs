# Troubleshooting & Fixes

## tmpfs /var/log Überlauf (2026-01-30)

### Problem

```
Symptom: "write error: No space left on device"
Ursache: AIDE schrieb 28MB Logs auf tmpfs /var/log (50MB Limit)
Folge:  Watchdog konnte nicht mehr loggen → Crash (Exit Code 5)
```

**Timeline:**
```
21:00-22:00  AIDE loggt massiv → /var/log/aide/ (28MB)
             tmpfs füllt sich: 23MB → 50MB (100%)
22:08        Watchdog: "echo: write error: No space left on device"
             Watchdog crasht mit Exit Code 5
```

**Betroffene Komponenten:**
- AIDE (28MB Logs)
- kern.log (12MB)
- syslog (6.4MB)
- Watchdog (konnte nicht mehr schreiben)

### Root Cause

**Zwei Bugs:**

1. **Watchdog behandelt "activating" als Fehler**
   - Services im Status "activating" (0-10 Sek beim Start) wurden als defekt betrachtet
   - Watchdog startete sie sofort neu ("Reparatur")
   - Services die sich selbst heilen wurden gestört

2. **AIDE loggt massiv auf tmpfs**
   - 75MB Datenbank + täglicher Check
   - Logs nach /var/log/aide/ (tmpfs, 50MB Limit!)
   - Keine Log-Rotation

### Fix 1: Watchdog - "activating" tolerieren

**Code-Änderung in `/usr/local/sbin/feeder-watchdog`:**

```bash
# NEU: "activating" ist OK (normaler Übergangszustand)
if [ "$STATUS" = "activating" ]; then
    # Nur beim ersten Mal loggen (kein Spam)
    if [ ! -f "$FAIL_DIR/$svc.activating_seen" ]; then
        log "INFO: $svc ist activating - warte auf selbständige Aktivierung"
        touch "$FAIL_DIR/$svc.activating_seen"
    fi
    return 0  # NICHT eingreifen!
else
    # Wenn nicht mehr activating, lösche Marker
    rm -f "$FAIL_DIR/$svc.activating_seen"
fi
```

**Verhalten:**
- `active` → OK, Service läuft
- `activating` → OK, warten (kein Restart!)
- `failed`, `inactive`, etc. → Reparaturversuch mit exp. Backoff

### Fix 2: AIDE minimieren (Option B+C)

**Neue Konfiguration `/etc/aide/aide.conf`:**

```
# Nur kritische System-Verzeichnisse (Option B)
/bin, /sbin, /usr/bin, /usr/sbin, /usr/local/bin, /usr/local/sbin
/etc/passwd, /etc/shadow, /etc/group, /etc/sudoers
/etc/ssh/sshd_config, /etc/systemd/system
/boot

# Log-Pfad geändert (Option C)
ALT: /var/log/aide/ (tmpfs)
NEU: /var/lib/aide/log/ (SD-Karte)

# Loglevel
log_level=warning
report_level=changed_attributes

# Check-Frequenz
ALT: /etc/cron.daily/aide
NEU: /etc/cron.weekly/aide

# Log-Rotation
maxsize 1M
rotate 4 weeks
```

**Ergebnis:**
- Datenbank: 75MB → 574 Bytes (130x kleiner!)
- Überwachte Einträge: Tausende → 13 kritische Pfade
- Checksums: Alle Hashes → SHA256 only
- Log-Speicherort: tmpfs → SD-Karte
- Frequenz: Täglich → Wöchentlich

**Patch in `/usr/share/aide/bin/dailyaidecheck`:**
```bash
# Zeile 70
ALT: LOGDIR="/var/log/aide"
NEU: LOGDIR="/var/lib/aide/log"
```

**Log-Rotation `/etc/logrotate.d/aide`:**
```
/var/lib/aide/log/aide.log {
    weekly
    rotate 4
    maxsize 1M
    compress
}
```

### Lessons Learned

| Problem | Lösung |
|---------|--------|
| tmpfs /var/log voll | NIEMALS große Logs auf tmpfs (50MB Limit!) |
| AIDE auf embedded Systems | Minimieren oder deaktivieren |
| Watchdog vs. "activating" | Übergangszustände tolerieren, nicht sofort eingreifen |
| Python Services Logging | `logging.basicConfig(stream=sys.stdout)` für systemd journal |
| File-Logging auf tmpfs | Nur für temporäre kleine Logs; große Logs → /var/lib/ |

### Verification

```bash
# tmpfs Auslastung prüfen
df -h /var/log

# AIDE Größe
sudo ls -lh /var/lib/aide/
# Sollte sein: aide.db ~600 Bytes

# Watchdog Log
sudo journalctl -u feeder-watchdog --since "1 hour ago" | grep activating
# Sollte sein: "INFO: ... ist activating - warte auf selbständige Aktivierung"

# Services die "activating" waren
systemctl list-units --state=activating
# Sollte leer sein (nach paar Sekunden)
```

### Prevention

1. **tmpfs /var/log:** Nur kleine, temporäre Logs
2. **Große Logs:** → /var/lib/, /var/cache/ oder externe Speicher
3. **AIDE auf Raspberry Pi:** Minimalistische Konfiguration
4. **Watchdog:** Grace-Period für Startup-States
5. **Log-Rotation:** Immer mit maxsize konfigurieren
