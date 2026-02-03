# Aircraft Alert System - Optionale Erweiterungen

## Aktueller Status
✅ Alle 4 Komponenten implementiert und funktional
✅ tar1090 HTTP Check im Watchdog
✅ Auto-Update Service (täglich 04:00)
✅ ICAO Lookup Service mit 30-Tage Cache
✅ Web-Lookup mit ADSBexchange Integration

## Mögliche Erweiterungen

### 1. Automatische ICAO Lookup Integration
**Status:** Optional - Aktuell CLI-Tool
**Beschreibung:** aircraft-alert-notifier ruft automatisch icao-lookup-service auf bei:
- Unbekannten Codes (nicht in Military Patterns)
- Codes die Alert-Kriterien erfüllen

**Implementierung:**
```python
def check_and_lookup_unknown(hex_code):
    if not is_known_pattern(hex_code):
        subprocess.run(["/usr/local/sbin/icao-lookup-service", hex_code])
```

### 2. Erweiterte Web-Recherche
**Status:** Basic Implementation vorhanden
**Beschreibung:** Mehr Datenquellen für präzisere Ergebnisse:
- FlightRadar24 API
- OpenSky Network Database
- ADS-B.NL Military Database Scraping
- Claude CLI mit --web für komplexe Recherchen

### 3. Alle Europäischen Military Codes
**Status:** Basis vorhanden (ranges.json hat alle)
**Beschreibung:** Erweitere Patterns für:
- Frankreich (3A-3B)
- UK (40-43)
- Italien (38-39)
- Spanien (73)
- Niederlande (48, 4B)
- Belgien (44)
- Polen (49)

**Umsetzung:** military-icao-updater bereits vorbereitet

### 4. Aircraft Type Database
**Status:** TODO
**Beschreibung:** Lokale Datenbank für Flugzeugtypen:
- ICAO Type Codes (B738, A320, etc.)
- Common Names (Boeing 737-800, Airbus A320)
- Military Designations (Eurofighter, F-16, etc.)

### 5. /status Integration
**Status:** TODO
**Beschreibung:** tar1090 HTTP Status in Telegram /status zeigen:
```
🌐 tar1090 HTTP: 🟢 200 OK
   Letzte Prüfung: 15:24:30
```

## Test-Cases

### Test 1: Ziviler Glider (bereits getestet)
```bash
/usr/local/sbin/icao-lookup-service 3DE527
# → Germany, Zivil, Glider D-HHAL (wenn ADSBexchange Daten hat)
```

### Test 2: Deutsches Militär
```bash
/usr/local/sbin/icao-lookup-service 3E96CB
# → Germany, Militär, Eurofighter (aus ranges.json)
```

### Test 3: US Military
```bash
/usr/local/sbin/icao-lookup-service AE0004
# → USA, Militär (aus ranges.json)
```

### Test 4: Unbekannter Europäischer Code
```bash
/usr/local/sbin/icao-lookup-service 400ABC
# → UK, Status unbekannt (ICAO Range Inference)
```

## Dateien-Übersicht

| Datei | Beschreibung | Backup |
|-------|--------------|--------|
| `/usr/local/sbin/icao-lookup-service` | ICAO Recherche Service | - |
| `/usr/local/sbin/update-military-icao` | Update-Skript | - |
| `/usr/local/sbin/military-icao-updater` | Pattern-Generator | - |
| `/usr/local/sbin/feeder-watchdog` | v2.2 mit tar1090 HTTP Check | `.backup-*` |
| `/var/lib/claude-pending/military-icao-patterns.py` | Auto-generierte Patterns | Auto-Update |
| `/var/lib/claude-pending/icao-lookup-cache.json` | 30-Tage Cache | Auto-Cleanup |
| `/var/log/military-icao-update.log` | Update-Service Log | Auto-Rotation |

## Wartung

### Manuelle Pattern-Updates
Wenn neue German Military Codes bekannt werden:
```bash
# Editiere /usr/local/sbin/aircraft-alert-notifier
GERMAN_MILITARY_PATTERNS = [
    # Füge neue Codes hinzu
    "3eXXXX",  # Beschreibung
]
sudo systemctl restart aircraft-alert-notifier
```

### Manual ICAO Lookup
```bash
/usr/local/sbin/icao-lookup-service HEXCODE
# → JSON Output + Telegram Benachrichtigung
```

### Cache löschen (bei Bedarf)
```bash
rm /var/lib/claude-pending/icao-lookup-cache.json
# → Alle Codes werden neu recherchiert
```

### Update-Service manuell ausführen
```bash
sudo /usr/local/sbin/update-military-icao
# → Aktualisiert Patterns sofort
```

## Lessons Learned

1. **tar1090 git-db Update:** Schlägt fehl (Permission/Git-Probleme), aber ranges.json ist trotzdem aktuell
2. **Pattern-Präzision:** Breite Ranges (3E, 3F) verursachen False Positives → spezifische Patterns nötig
3. **30-Tage Cache:** Perfekt für Military Code Rotation (2-3x/Jahr)
4. **ADSBexchange Database:** Gute Quelle für Registrierungen, aber nicht alle Codes verfügbar
5. **ICAO Range Allocation:** Zuverlässiger Fallback für Land-Erkennung
