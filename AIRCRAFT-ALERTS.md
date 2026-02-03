# Aircraft Alert System - Intelligente ICAO-Code-Erkennung

**System:** Raspberry Pi 4 Model B - ADS-B Feeder
**Letzte Aktualisierung:** 2026-02-03
**Status:** ✅ Vollständig implementiert und aktiv

---

## Übersicht

Automatisches Benachrichtigungssystem für interessante Flugzeuge mit intelligenter ICAO-Code-Recherche.

### Features

1. **Präzise Military-Erkennung** - Nur bekannte Patterns, keine False Positives
2. **Auto-Update** - Täglich neue Military Patterns von tar1090 git-db
3. **ICAO Lookup Service** - Recherchiert unbekannte Codes automatisch
4. **30-Tage Cache** - Optimiert für Military Code Rotation (2-3x/Jahr)
5. **tar1090 HTTP Monitor** - Erkennt 502 Errors automatisch

---

## Architektur

\`\`\`
┌─────────────────────────────────────────────────────────────────┐
│                    Intelligentes Alert-System                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  readsb aircraft.json (10s Check)                              │
│         ↓                                                       │
│  aircraft-alert-notifier (Filter)                              │
│         ↓                                                       │
│  ┌──────────────┬──────────────┬──────────────┐               │
│  │ Military?    │ Extremely    │ Emergency    │               │
│  │ (Patterns)   │ Low?         │ Squawk?      │  ...6 Alerts  │
│  └──────┬───────┴──────┬───────┴──────┬───────┘               │
│         │              │              │                        │
│         ├──────────────┴──────────────┤                        │
│         │ Unbekannter ICAO Code?      │                        │
│         ↓                              ↓                        │
│  icao-lookup-service           Telegram Alert                  │
│         ↓                                                       │
│  ┌──────────────┬──────────────┐                              │
│  │ tar1090      │ ADSBexchange │ Web-Lookup                   │
│  │ ranges.json  │ Database     │                              │
│  └──────┬───────┴──────┬───────┘                              │
│         │              │                                       │
│         └──────┬───────┘                                       │
│                ↓                                                │
│         30-Tage Cache                                          │
│                ↓                                                │
│         Telegram Report                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
\`\`\`

---

## Alert-Kriterien

**Datei:** \`/usr/local/sbin/aircraft-alert-notifier\`
**Check-Interval:** 10 Sekunden

| Alert | Kriterium | Cooldown | Range |
|-------|-----------|----------|-------|
| **Militär tief & nah** | German Military < 3000ft | 1h | <10km (5.4nm) |
| **Extrem tief** | Beliebig < 1000ft | 30min | <10km (5.4nm) |
| **Emergency** | Squawk 7700/7600/7500 | 5min | <100km (54nm) |
| **Schneller Tiefflieger** | >400kt < 5000ft | 30min | <50km (27nm) |
| **Hubschrauber nah** | Category H* | 1h | <9km (5nm) |
| **Laut & Nah** | >250kt < 5000ft | 30min | <10km (5.4nm) |

---

## Komponenten

### 1. ICAO Lookup Service
\`/usr/local/sbin/icao-lookup-service\`

- **30-Tage Cache** für Military Code Rotation
- **Lokale Erkennung** via tar1090 ranges.json (32 Ranges)
- **Web-Lookup** mit ADSBexchange Database
- **Fallback:** ICAO Range Allocation

### 2. Military Pattern Generator
\`/usr/local/sbin/military-icao-updater\`

Generiert aus tar1090 ranges.json:
\`\`\`python
US_MILITARY_PATTERNS = ['ad', 'ae', 'af']
GERMAN_MILITARY_PATTERNS = ['33', '35', '36', '37', '3a', '3b', '3e', '3f']
\`\`\`

### 3. Auto-Update Service
\`update-military-icao.timer\` - Täglich 04:00 Uhr

1. Aktualisiert tar1090 git-db
2. Regeneriert Military Patterns
3. Restart aircraft-alert-notifier

### 4. tar1090 HTTP Check
feeder-watchdog v2.2

- Erkennt HTTP 502 Errors
- Automatischer Restart lighttpd + tar1090

---

## Verwendung

### Manual ICAO Lookup
\`\`\`bash
/usr/local/sbin/icao-lookup-service HEXCODE

# Beispiele:
/usr/local/sbin/icao-lookup-service 3DE527  # Glider
/usr/local/sbin/icao-lookup-service AE0004  # US Military
\`\`\`

### Update Patterns
\`\`\`bash
# Automatisch täglich 04:00, oder manuell:
sudo /usr/local/sbin/update-military-icao
\`\`\`

---

## Datenquellen

| Quelle | URL | Beschreibung |
|--------|-----|--------------|
| **tar1090 git-db** | https://github.com/wiedehopf/tar1090-db | 32 Military Ranges |
| **ADS-B.NL** | https://www.ads-b.nl/index.php?pageno=118 | Live Military Tracking |
| **ADSBexchange** | https://www.adsbexchange.com/database/contribute/ | Aircraft Database |

---

## Testen

\`\`\`bash
# Test 1: Ziviler Glider (war vorher falsch als Militär)
/usr/local/sbin/icao-lookup-service 3DE527
# → Germany, Zivil ✅

# Test 2: Deutsches Militär  
/usr/local/sbin/icao-lookup-service 3E96CB
# → Germany, Militär ✅

# Test 3: US Military (neu!)
/usr/local/sbin/icao-lookup-service AE0004
# → USA, Militär ✅
\`\`\`

---

## Logs

\`\`\`bash
/var/log/military-icao-update.log           # Update-Service
/var/log/feeder-watchdog.log                # tar1090 HTTP Check
/var/lib/claude-pending/icao-lookup-cache.json  # Cache
journalctl -u aircraft-alert-notifier       # Alert Service
\`\`\`

---

Siehe \`~/docs/AIRCRAFT-ALERT-TODO.md\` für zukünftige Erweiterungen.
