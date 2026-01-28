# OGN/FLARM Setup (Open Glider Network)
*Hardware bestellt 2026-01-21 - Software vorbereitet, wartet auf Hardware*

## Was ist OGN?
Das Open Glider Network trackt Segelflugzeuge, Gleitschirme, Drohnen und andere Luftfahrzeuge auf 868 MHz (Europa). Diese sind **nicht** über ADS-B sichtbar.

### Unterstützte Protokolle (alle gleichzeitig!)
| Protokoll | Frequenz | Typische Nutzer |
|-----------|----------|-----------------|
| **FLARM** | 868.2-868.4 MHz | Segelflugzeuge, Helikopter, Motorflugzeuge |
| **OGN-Tracker** | 868.2-868.4 MHz | Günstige FLARM-Alternative |
| **FANET/FANET+** | 868.2 MHz | Gleitschirme (Skytraxx, Naviter, XC Tracer) |
| **PilotAware** | 869.525 MHz | UK-basiertes System |

**Wichtig:** Mit `SampleRate=2.0` und `CenterFreq=868.8` werden **alle** Protokolle gleichzeitig empfangen!

### Lokale Relevanz
- **EDQA (Bamberg-Breitenau)**: Segelflugplatz ~15 km entfernt
- **Nicht im OGN-Netzwerk**: Stand 2026-01-20 keine OGN-Abdeckung für dieses Gebiet
- **Potenzial**: Lokaler OGN-Empfänger würde Lücke schließen

### Community-Upload zum Open Glider Network

**✅ rtl_ogn sendet automatisch an glidernet.org!**

```
RTL-SDR (868 MHz) → rtl_ogn → APRS → glidernet.org
                         ↓
                   ogn2dump1090 → readsb:30008 → tar1090 (lokal)
```

**Was wird hochgeladen?**
- Position, Höhe, Geschwindigkeit von Segelflugzeugen/Gleitschirmen
- FLARM-IDs (pseudonymisiert)
- Receiver-Status und Coverage

**Wo sichtbar?**
- **Live-Tracking:** http://live.glidernet.org/
- **Receiver-Karte:** https://www.glidernet.org/ (zeigt alle OGN-Stationen)
- **Coverage-Map:** Zeigt Empfangsreichweite deiner Station

**Konfiguration:**
- Bereits in `/opt/rtlsdr-ogn/SteGau.conf` konfiguriert
- Station-ID: Aus Lat/Lon generiert (automatisch)
- Server: `aprs.glidernet.org:14580` (Standard)

**Privacy:** FLARM-IDs werden mit `~` Präfix pseudonymisiert und können nicht zu realen Personen zurückverfolgt werden.

---

## Hardware (bestellt)
| Komponente | Produkt | Preis | Status |
|------------|---------|-------|--------|
| SDR-Stick | RTL-SDR Blog V4 | ~40€ | Bestellt |
| Antenne | Bingfu 3dBi Magnetfuß + 3m RG174 | ~25€ | Bestellt |
| Groundplane | Metallplatte 90mm (Rauchmelder-Basis) | - | Vorhanden |
| **Gesamt** | | **~65€** | |

**Hinweis:** Die aktuelle ADS-B-Antenne (1090 MHz) ist NICHT für 868 MHz geeignet.

### USB-Port Situation
| Port | Gerät | Frequenz |
|------|-------|----------|
| USB 1 | FlightAware Pro Stick Plus | 1090 MHz (ADS-B) |
| USB 2 | RTL-SDR Blog V4 | 868 MHz (OGN) - **geplant** |
| USB 3-4 | Frei | - |

---

## Software (vorbereitet)
| Komponente | Pfad | Status |
|------------|------|--------|
| rtl_ogn v0.3.2 | `/opt/rtlsdr-ogn/` | Installiert |
| Konfiguration | `/opt/rtlsdr-ogn/SteGau.conf` | Erstellt |
| ogn2dump1090 | `/opt/ogn2dump1090/` | Installiert |
| python-ogn-client | pip3 | Installiert |
| rtl-ogn-wrapper | `/usr/local/sbin/rtl-ogn-wrapper` | Erstellt (2026-01-25) |
| rtl-ogn.service | `/etc/systemd/system/` | Erstellt (disabled) |
| ogn2dump1090.service | `/etc/systemd/system/` | Erstellt (disabled) |
| readsb OGN-Port | Port 30008 | Konfiguriert |
| tar1090 OGN-Label | "OGN" | Konfiguriert |
| OGN DDB | `/var/lib/ogn-ddb/ogn-ddb.csv` | 34.171 Einträge |
| DDB Update Script | `/usr/local/sbin/ogn-ddb-update` | Wöchentlich So 06:00 |

### Konfiguration SteGau.conf (Schlüsselparameter)
```
SampleRate  = 2.0;        # 2 MHz für FLARM+OGN+FANET+PilotAware
CenterFreq  = 868.8;      # Alle Protokolle gleichzeitig erfassen
```

### ogn2dump1090 config.py
```python
aprs_subscribe_filter = "r/49.866/10.839/100"  # 100km Radius
                                                # → Auch Online-OGN-Daten!
```
**Bonus:** ogn2dump1090 empfängt auch APRS-Daten von `aprs.glidernet.org` - damit sieht man auch Flugzeuge, die von anderen OGN-Empfängern in der Nähe erfasst werden!

---

## Antennen-Platzierung
```
        Fenster (Richtung Fluggebiet)
            │
    ┌───────┴───────┐
    │   OGN 868 MHz │  ← Bingfu 3dBi Magnetfuß
    │       │       │
    │   ┌───┴───┐   │
    │   │Magnet │   │
    │   ├───────┴───┤
    │   │  90mm     │  ← Metallplatte (Groundplane)
    │   │  Platte   │
    │   └───────────┘
    │
    │    30+ cm horizontal
    │   ←─────────────→
    │                    ADS-B Antenne (Besenstiel)
```

**Warum diese Anordnung:**
- 3dBi = breiter vertikaler Winkel (~50°) - gut für Segelflugzeuge direkt über dem Standort
- Fenster = weniger Dämpfung bei 868 MHz
- 30+ cm horizontal = vermeidet Interferenz zwischen den Antennen
- Magnetfuß braucht Metallplatte als Groundplane (λ/4 ≈ 8.6 cm, 90mm ist ideal)

---

## Sensor-Fusion Architektur
```
┌─────────────────────────────────────────────────────────────┐
│  FA Pro Stick Plus       RTL-SDR V4                        │
│  (1090 MHz + LNA)        (868 MHz)                         │
│      │                       │                              │
│      ▼                       ▼                              │
│   readsb                  rtl_ogn ──────► glidernet.org    │
│      │                       │            (APRS Upload)     │
│      │                       ▼                              │
│      │               ogn2dump1090                          │
│      │                   │                                  │
│      │                   │ + Online-OGN (Bonus!)           │
│      │                   ▼ SBS/Jaero (Port 30008)          │
│      └────────────► readsb ◄─────┘                         │
│                         │                                   │
│                         ▼                                   │
│                      tar1090                                │
│                    ┌────┴────┐                              │
│                 ADS-B      OGN                              │
│                (normal)  (Label)                            │
└─────────────────────────────────────────────────────────────┘

Dual-Upload-Architektur:
- ADS-B → FlightAware, ADSBexchange, adsb.fi, etc. (9 Feeds)
- OGN → glidernet.org (APRS)
- Beide zusammen in tar1090 visualisiert
```

**Repository:** https://github.com/b3nn0/ogn2dump1090

---

## OGN-Adressen und MLAT-Korrelation

**Adress-Typen im OGN-Protokoll:**
| Type | Code | Präfix in readsb | MLAT-Korrelation |
|------|:----:|:----------------:|:----------------:|
| ICAO | 1 | - | Automatisch |
| FLARM | 2 | `~` | Separater Track |
| OGN | 3 | `~` | Separater Track |
| Random | 0 | `~` | Separater Track |

**Das `~` Präfix (non-ICAO Marker):**
- Mit `~`: readsb behandelt als "non-ICAO" → keine Kollision mit echten Flugzeugen
- Ohne `~`: readsb behandelt als echte ICAO → verschmilzt mit MLAT/ADS-B Daten

**Praktische Bedeutung:**
- Motorflugzeuge mit Mode-S + FLARM: ADS-B/MLAT-Track (ICA-Adresse)
- Segelflugzeuge nur mit FLARM: Separater OGN-Track (~FLARM-ID)

---

## Datenqualität

**1. Positions-Jitter:**
- ADS-B: Glatte Tracks, sekündliche Updates
- FLARM: Springende Positionen, 3-10s Updates (einfachere GPS-Chips)

**2. Höhendifferenz:**
| Quelle | Höhentyp | Referenz |
|--------|----------|----------|
| ADS-B | Flight Level | 1013.25 hPa |
| FLARM/OGN | GPS-Höhe | WGS84 Ellipsoid |

Differenz kann 50-100m betragen! Geoid-Korrektur Deutschland: ~48m

---

## Implementierungsschritte (wenn Hardware da)

### Phase 1: Hardware aufbauen
```bash
# 1. Antenne am Fenster platzieren (Magnetfuß auf 90mm Metallplatte)
# 2. RTL-SDR V4 NICHT anstecken bis Software bereit
```

### Phase 2: RTL-SDR V4 anschließen & testen
```bash
# V4 einstecken
lsusb | grep RTL
# Sollte 2x RTL-SDR zeigen

# Device-Index ermitteln
rtl_test -t
# Device 0: FA Pro Stick Plus (ADS-B) - NICHT ÄNDERN
# Device 1: V4 (OGN) ← diesen Index merken!
```

### Phase 3: Services aktivieren
```bash
sudo systemctl enable rtl-ogn ogn2dump1090
sudo systemctl start rtl-ogn ogn2dump1090

# Prüfen
journalctl -u rtl-ogn -f
```

### Phase 4: Verifizieren
```bash
# Services laufen?
systemctl status rtl-ogn ogn2dump1090

# Auf tar1090 Karte: OGN-Label sichtbar?
# http://pi:8080

# Auf OGN-Karte registriert?
# https://live.glidernet.org
```

### Phase 5: Integration
- [ ] Watchdog erweitern (`/usr/local/sbin/feeder-watchdog`)
- [ ] Wartungsskript erweitern (`/usr/local/sbin/claude-respond-to-reports`)
- [ ] AppArmor-Profil für rtl-ogn erstellen
- [ ] Telegram-Bot `/stats` um OGN-Statistiken erweitern
- [ ] CLAUDE.md "Implemented Changes" aktualisieren

### Phase 6: Optional - Smartphone-Tracking via PureTrack
```bash
# Nur wenn gewünscht: PureTrack Pro für zusätzliche Smartphone-Tracker
# 1. Account erstellen: https://puretrack.io/
# 2. Pro-Abo (~5€/Monat)
# 3. API-Token generieren
# 4. Integration in Monitoring einbauen
```

---

## Feeds/Aggregatoren
| Dienst | URL | Beschreibung |
|--------|-----|--------------|
| Open Glider Network | live.glidernet.org | Haupt-Aggregator |
| Flightradar24 | flightradar24.com | Erhält OGN automatisch |
| WeGlide | weglide.org | Segelflug-Tracking |

**WICHTIG:** Kein separater FR24-FLARM-Feed nötig - OGN leitet automatisch weiter.

---

## FANET & Gleitschirm-Tracking

### Was ist FANET?
FANET (Flying Ad-hoc Network) ist ein Ad-hoc-Funknetzwerk für Gleitschirme und Hängegleiter. Geräte wie **Skytraxx**, **Naviter Oudie**, **XC Tracer** nutzen FANET+ und werden automatisch vom OGN-Empfänger erfasst.

### FANET-Adressen in der OGN-DDB
```bash
# Gleitschirme in der Datenbank (AIRCRAFT_TYPE=6)
grep ",6'" /var/lib/ogn-ddb/ogn-ddb.csv | wc -l
```

### APRS-Präfixe (wie ogn2dump1090 sie empfängt)
| Präfix | Protokoll | Beispiel |
|--------|-----------|----------|
| `FNT` | FANET | `FNT11189E>OGNFNT` |
| `PAW` | PilotAware | `PAW404BF0>OGPAW` |
| `OGN` | OGN-Tracker | `OGN2D4072>OGNTRK` |
| `ICA` | FLARM (ICAO) | `ICA3D24FE>OGFLR` |
| `FLR` | FLARM (non-ICAO) | `FLR123456>OGFLR` |

---

## Smartphone-basierte Tracking-Netzwerke

Manche Gleitschirmflieger nutzen **nur Smartphones** ohne FANET-Hardware. Diese erscheinen nicht auf 868 MHz, aber können über APIs abgerufen werden.

### Bekannte Apps mit Live-Tracking
| App | Beschreibung | API verfügbar? |
|-----|--------------|----------------|
| **XCTrack/XContest** | Sehr verbreitet, Wettbewerbe | Nur via PureTrack |
| **Gaggle** | Kostenlos, populär | Nein |
| **Flyskyhy** | iPhone, tausende Nutzer | Nein |
| **SportsTrackLive** | Multi-Sport | Nein |

### PureTrack API (kostenpflichtig)
[PureTrack](https://puretrack.io/) aggregiert Daten aus vielen Quellen und bietet eine [Traffic API](https://puretrack.io/help/api) für Pro-Nutzer:

```bash
# Beispiel: Flugzeuge im 50km Radius abrufen (benötigt API-Token)
curl -H "Authorization: Bearer $TOKEN" \
  "https://puretrack.io/api/traffic?lat=49.866&lon=10.839&r=50&t=5&o=63"
```
- `o=63` = Gleitschirme/Hängegleiter
- `t=5` = Letzte 5 Minuten
- Daten von OGN, FLARM, XContest, InReach, SPOT, etc.

**Kosten:** PureTrack Pro ~5€/Monat

### SafeSky (Aggregator)
[SafeSky](https://www.safesky.app/) aggregiert über 30 Datenquellen (ADS-B, FLARM, FANET, OGN, Apps).
- Bietet "SafeSky Inside" API für Entwickler
- Europäisches Bodenstation-Netzwerk
- Kostenlose App für Piloten

### Empfehlung für diesen Standort
1. **Primär:** OGN-Empfänger (FLARM + FANET) → Erfasst die meisten lokalen Flüge
2. **Optional:** PureTrack Pro API → Für Smartphone-only-Tracker

---

## Abdeckungskarte prüfen
```bash
curl -s "http://glidernet.org/api/receivers" | jq '.[] | select(.lat > 49 and .lat < 51 and .lon > 10 and .lon < 12)'
```
Oder visuell: https://live.glidernet.org → Empfänger-Layer aktivieren

---

## Integration nach Hardware-Installation

### Service-Listen aktualisieren (3 Dateien!)
Nach erfolgreicher Inbetriebnahme müssen **alle drei** Service-Listen erweitert werden:

```bash
# 1. Watchdog
sudo sed -i 's/FEEDERS="/FEEDERS="rtl-ogn ogn2dump1090 /' /usr/local/sbin/feeder-watchdog

# 2. Telegram-Bot
sudo sed -i 's/SERVICES="/SERVICES="rtl-ogn ogn2dump1090 /' /usr/local/sbin/telegram-bot-daemon

# 3. Wartungsskript
# In /usr/local/sbin/claude-respond-to-reports die Service-Liste erweitern
```

### Telegram-Bot `/stats` erweitern
OGN-Statistiken hinzufügen:
```bash
# OGN-Empfang der letzten Stunde
grep -c "APRS\|TELNET" /var/log/ogn2dump1090.log | tail -1
```

### AppArmor-Profil erstellen
```bash
# /etc/apparmor.d/usr.local.sbin.rtl-ogn
# Basierend auf bestehenden Profilen für readsb
```

### CLAUDE.md aktualisieren
```markdown
## Implemented Changes
### Feeds & MLAT (17 Services)  # +2
- rtl-ogn, ogn2dump1090 (NEU)
- readsb, tar1090, graphs1090, piaware, fr24feed
- ...
```

---

## Diagnose-Befehle

### OGN-Empfang prüfen
```bash
# Lokaler Empfang (868 MHz)
journalctl -u rtl-ogn --since "5 minutes ago" | grep -E "FLARM|OGN|FANET|PAW"

# APRS-Upstream (Online-Daten)
journalctl -u ogn2dump1090 --since "5 minutes ago" | grep "APRS"

# Auf tar1090 Karte
# http://pi:8080 → OGN-Label sollte bei Flugzeugen erscheinen
```

### Protokoll-Statistiken
```bash
# Welche Protokolle wurden empfangen?
journalctl -u rtl-ogn --since "1 hour ago" | grep -oE "FNT|PAW|OGN|FLR|ICA" | sort | uniq -c
```

### Reichweite prüfen
```bash
# Auf live.glidernet.org:
# 1. "Receivers" Layer aktivieren
# 2. Nach "SteGau" suchen
# 3. Reichweiten-Statistiken ansehen
```
