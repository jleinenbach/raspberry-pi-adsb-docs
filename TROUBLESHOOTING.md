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

---

## AppArmor blockiert /usr/local/lib/ (2026-01-30)

### Problem

```
Symptom: Services crashen mit Exit Code 127
Ursache: AppArmor blockiert /usr/local/lib/librtlsdr.so.0.6git
Auslöser: AIDE-Neuinitialisierung (aide --init)
```

**Timeline:**
```
22:08  tmpfs /var/log voll → AIDE minimiert → aide --init
22:30  Alle Services wieder aktiv
22:50  readsb crasht plötzlich mit Exit Code 127
       "error while loading shared libraries: librtlsdr.so.0"
22:51  Kaskaden-Fehler: rbfeeder, pfclient, piaware → Exit Code 127
22:56  OGN Services crashen mit Exit Code 209 (STDOUT)
```

**Betroffene Services:**
- readsb (Core - alle anderen hängen davon ab!)
- rbfeeder, pfclient, piaware (RTL-SDR Library)
- ogn-rf-procserv, ogn-decode-procserv (Log-Verzeichnis fehlt)
- Insgesamt: 23 Services offline

### Root Cause

**Zwei separate Probleme:**

1. **AppArmor blockiert /usr/local/lib/**
   ```
   dmesg: apparmor="DENIED" operation="open"
          name="/usr/local/lib/librtlsdr.so.0.6git"
   ```
   - AppArmor-Profile erlauben nur `/usr/lib/` und `/lib/`
   - RTL-SDR Blog Library liegt aber in `/usr/local/lib/`
   - Nach AIDE-Init wurde vermutlich AppArmor neu geladen

2. **tmpfs-Cleanup löscht Log-Verzeichnisse**
   ```
   Exit Code 209: Failed to set up standard output: No such file or directory
   ```
   - `/var/log/rtl-ogn/` Verzeichnis wurde gelöscht (tmpfs-Cleanup)
   - OGN Services brauchen `StandardOutput=append:/var/log/rtl-ogn/*.log`

### Fix 1: AppArmor-Profile patchen

**Betroffene Profile:**
```bash
/etc/apparmor.d/usr.bin.readsb
/etc/apparmor.d/usr.bin.rbfeeder
/etc/apparmor.d/usr.bin.pfclient
/etc/apparmor.d/usr.bin.piaware
```

**Patch:**
```bash
# Füge nach "/lib/aarch64-linux-gnu/** mr," ein:
/usr/local/lib/** mr,
```

**Skript zum Patchen aller Profile:**
```bash
for profile in /etc/apparmor.d/usr.bin.{readsb,rbfeeder,pfclient,piaware}; do
  if [ -f "$profile" ]; then
    if ! grep -q "/usr/local/lib/\*\* mr," "$profile"; then
      sudo sed -i '/\/lib\/aarch64-linux-gnu\/\*\* mr,/a\  \/usr\/local\/lib\/\*\* mr,' "$profile"
      echo "✓ Gepatcht: $profile"
    fi
  fi
done

# AppArmor-Profile neu laden
sudo apparmor_parser -r /etc/apparmor.d/usr.bin.{readsb,rbfeeder,pfclient,piaware}

# Services neu starten
sudo systemctl restart readsb rbfeeder pfclient piaware
```

### Fix 2: OGN Log-Verzeichnis persistent machen

**Problem:** `/var/log/rtl-ogn/` liegt auf tmpfs und wird gelöscht

**Lösung:**
```bash
# Verzeichnis erstellen und Permissions setzen
sudo mkdir -p /var/log/rtl-ogn
sudo chown pi:adm /var/log/rtl-ogn
sudo chmod 750 /var/log/rtl-ogn

# Services neu starten
sudo systemctl restart ogn-rf-procserv ogn-decode-procserv
```

**Permanent machen (tmpfiles.d):**
```bash
# /etc/tmpfiles.d/ogn-logs.conf
d /var/log/rtl-ogn 0750 pi adm -
```

### Lessons Learned

| Problem | Lösung |
|---------|--------|
| Custom Libraries in /usr/local/lib | AppArmor-Profile müssen explizit `/usr/local/lib/** mr,` erlauben |
| Exit Code 127 | Library/Binary nicht gefunden → `ldd /usr/bin/binary` prüfen, AppArmor-Logs checken |
| Exit Code 209 | systemd STDOUT-Setup failed → Log-Verzeichnis fehlt |
| tmpfs /var/log Cleanup | Kritische Log-Dirs mit tmpfiles.d persistent machen |
| AIDE init Side-Effects | Nach AIDE-Init alle Library-abhängigen Services neu starten + AppArmor prüfen |
| ldconfig nach Library-Install | Nach Installation in /usr/local/lib immer `ldconfig` ausführen |
| AppArmor-Diagnose | `sudo dmesg | grep apparmor.*DENIED` zeigt blockierte Zugriffe |

### Verification

```bash
# AppArmor blockiert nichts mehr
sudo dmesg --since "10 minutes ago" | grep "apparmor.*DENIED"
# Sollte leer sein

# Alle Services laufen
systemctl is-active readsb rbfeeder pfclient piaware mlathub
systemctl is-active ogn-rf-procserv ogn-decode-procserv ogn2dump1090
# Alle sollten "active" sein

# RTL-SDR Library ist erreichbar
ldd /usr/bin/readsb | grep librtlsdr
# Sollte zeigen: /usr/local/lib/librtlsdr.so.0

# Log-Verzeichnis existiert
ls -ld /var/log/rtl-ogn
# drwxr-x--- 2 pi adm
```

### Prevention

1. **AppArmor-Profile:** Bei custom Libraries immer `/usr/local/lib/** mr,` einbauen
2. **tmpfs-Verzeichnisse:** Kritische Dirs mit tmpfiles.d persistent machen
3. **Nach AIDE-Init:** Alle Services neu starten + AppArmor-Logs prüfen
4. **ldconfig:** Nach jeder Library-Installation in /usr/local/lib ausführen
5. **Monitoring:** AppArmor-DENIED-Logs in Wartung integrieren
