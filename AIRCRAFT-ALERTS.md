# Aircraft Alert System

Telegram-Benachrichtigungssystem für interessante Flugzeuge im Umkreis von Stegaurach.

## Übersicht

Zwei unabhängige Services überwachen den Luftraum:

1. **aircraft-alert-notifier** - ADS-B basierte Alerts (6 Typen)
2. **ogn-balloon-notifier** - APRS-basierte Heißluftballon-Erkennung

## 1. Aircraft Alert Notifier

### Service Details

| Parameter | Wert |
|-----------|------|
| **Service** | `aircraft-alert-notifier.service` |
| **Skript** | `/usr/local/sbin/aircraft-alert-notifier` |
| **Datenquelle** | `/run/readsb/aircraft.json` (lokal, alle 10s) |
| **State-File** | `/var/lib/claude-pending/aircraft-alert-state.json` |
| **User** | pi |

### Alert-Typen

#### 🚁 Militär Tief & Nah
- **Bedingung:** Deutsche ICAO (3C-3F) + <3000ft + <20km
- **Cooldown:** 1 Stunde
- **Warum:** Bundeswehr/NATO Tiefflüge, Transall, Eurofighter, etc.

#### ✈️ Extrem Tief
- **Bedingung:** <1000ft (300m) + <15km
- **Cooldown:** 30 Minuten
- **Warum:** Ungewöhnlich niedrig - Start/Landung oder Problem

#### 🚨 Emergency
- **Bedingung:** Squawk 7700/7600/7500 + <100km
- **Cooldown:** 5 Minuten
- **Warum:** Notfall-Transponder
  - 7700 = General Emergency (Notfall)
  - 7600 = Radio Failure (Funkausfall)
  - 7500 = Hijacking (Entführung)

#### ⚡ Schneller Tiefflieger
- **Bedingung:** <5000ft (1500m) + >400kt + <50km
- **Cooldown:** 30 Minuten
- **Warum:** Jets auf Tiefflug

#### 🚁 Hubschrauber nah
- **Bedingung:** Kategorie H* + <9km (5nm)
- **Cooldown:** 1 Stunde
- **Warum:** Krankenhaus-Verkehr (Klinikum Bamberg Bruderwald)
- **Berechnung:** 2x Entfernung Heckenweg 8 → Klinikum (~4.5km)

#### 🔊 Laut & Nah
- **Bedingung:** <5000ft + <10km + >250kt
- **Cooldown:** 30 Minuten
- **Warum:** Kombiniert tief + nah + schnell = LAUT!

### Beispiel-Benachrichtigung

```
⚡ Schneller Tiefflieger
━━━━━━━━━━━━━━━━━━━━
Grund: Über 400kt unter 5000ft innerhalb 50km

✈️ Kennung: GAF123
   ICAO: 3E8A2F

📏 Höhe: 1200m (3937ft)
⚡ Geschwindigkeit: 740km/h (400kt)
📍 Entfernung: 28.5km (15.4nm)
🧭 Richtung: 245° (SW)

⬇️ Sinkt: 360m/min (1181fpm)
🛩️ Typ: Klein (7-34t)
🎖️ Deutsches Militär (ICAO 3C-3F)

⏰ Zeit: 19:45:30
```

### Informationen in Benachrichtigungen

| Feld | Format | Erklärung |
|------|--------|-----------|
| **Grund** | Text | Warum wurde der Alert ausgelöst |
| **Kennung** | Callsign oder [ICAO] | Flugnummer oder Hex-Code |
| **ICAO** | 6-stelliger Hex-Code | Eindeutige Flugzeug-ID |
| **Höhe** | m (ft) | Metrisch + Imperial |
| **Geschwindigkeit** | km/h (kt) | Metrisch + Knoten |
| **Entfernung** | km (nm) | Kilometer + Nautische Meilen |
| **Richtung** | Grad (Himmelsrichtung) | 0-360° + N/NO/O/SO/S/SW/W/NW |
| **Steig/Sink** | m/min (fpm) | ⬆️ Steigt / ⬇️ Sinkt / ➡️ Horizontal |
| **Typ** | Kategorie-Name | A0-A7, B0-B4, C0-C3, H |
| **Squawk** | Code + Bedeutung | 7700 = 🚨 NOTFALL, etc. |
| **Militär** | Indikator | 🎖️ bei ICAO 3C-3F |

### Aircraft Categories (ICAO)

| Code | Beschreibung | Gewicht/Art |
|------|--------------|-------------|
| A0 | Leicht | <7t |
| A1 | Klein | 7-34t |
| A2 | Groß | 34-136t |
| A3 | Schwer | >136t |
| A4 | Hochleistung | Hochgeschwindigkeit |
| A5 | Schwer Rotorcraft | Schwere Hubschrauber |
| A6 | Rotorcraft | Leichte Hubschrauber |
| A7 | Glider | Segelflugzeug |
| B0 | Balloon | Ballon |
| B1 | Parachute | Fallschirm |
| B2 | Hang Glider | Hängegleiter |
| B3 | Paraglider | Gleitschirm |
| B4 | Drachen | Drache |
| C0 | Space Vehicle | Raumfahrzeug |
| C1 | Ultralight | Ultraleichtflugzeug |
| C2 | UAV | Drohne |
| C3 | Space | Weltraum |
| H* | Helicopter | Hubschrauber (alle) |

### Deutsche Militär-ICAO-Adressen

Deutschland hat den ICAO-Adressbereich **3C0000 - 3FFFFF** zugewiesen (262.144 Adressen).

**Militär-Rotation:** Das Militär rotiert 24-bit-Adressen häufig aus Sicherheitsgründen (OPSEC).

**Beispiele:**
- Airbus A400M: 3E9808, 3F62FC, 3F447A
- Lockheed P-3C Orion: 3FBAA3
- Airbus A310: 3E8B02

## 2. OGN Balloon Notifier

### Service Details

| Parameter | Wert |
|-----------|------|
| **Service** | `ogn-balloon-notifier.service` |
| **Skript** | `/usr/local/sbin/ogn-balloon-notifier` |
| **Datenquelle** | APRS-Stream von glidernet.org:14580 |
| **Filter** | r/49.866/10.839/100 (100km Radius) |
| **State-File** | `/var/lib/claude-pending/ogn-balloon-state.json` |
| **User** | pi |

### OGN Aircraft Type 11 (Balloon)

**OGN (Open Glider Network)** nutzt FLARM-Transponder zur Kollisionsvermeidung und Tracking.

**Type Codes:**
- 0: Unknown, 1: Glider, 2: Tow Plane, 3: Helicopter
- 4: Parachute, 5: Drop Plane, 6: Hang Glider, 7: Paraglider
- 8: Powered Aircraft, 9: Jet, 10: UFO
- **11: Balloon** ← Dieser Typ wird überwacht
- 12: Airship, 13: UAV, 14: Static Object

### Alert-Konfiguration

- **Reichweite:** 100km Radius um Stegaurach (49.866, 10.839)
- **Cooldown:** 4 Stunden pro Ballon
- **Cleanup:** State-File wird alle 24h aufgeräumt

### Realität: Wenig Empfang zu erwarten

**Warum so wenige Ballons?**
- Keine Transponder-Pflicht für Heißluftballons in Deutschland (außer in Class C/D)
- Meiste Hobby-Ballons fliegen OHNE FLARM
- Nur kommerzielle Ballonfahrt-Unternehmen oder Ballons nahe Flughäfen haben FLARM

**Wann fliegen Ballons?**
- Nur bei ruhigem Wetter (Windgeschwindigkeit <15 km/h)
- Früh morgens oder abends (ruhigere Luft)
- Frühling bis Herbst (Hauptsaison)

## Verwaltung

### Status prüfen

```bash
# Aircraft Alerts
systemctl status aircraft-alert-notifier
sudo journalctl -u aircraft-alert-notifier -f

# Balloon Alerts
systemctl status ogn-balloon-notifier
sudo journalctl -u ogn-balloon-notifier -f
```

### Services steuern

```bash
# Stoppen
sudo systemctl stop aircraft-alert-notifier
sudo systemctl stop ogn-balloon-notifier

# Starten
sudo systemctl start aircraft-alert-notifier
sudo systemctl start ogn-balloon-notifier

# Neu starten
sudo systemctl restart aircraft-alert-notifier
sudo systemctl restart ogn-balloon-notifier
```

### State-Dateien prüfen

```bash
# Aircraft Alerts State
cat /var/lib/claude-pending/aircraft-alert-state.json | python3 -m json.tool

# Balloon Alerts State
cat /var/lib/claude-pending/ogn-balloon-state.json | python3 -m json.tool
```

### Alerts temporär deaktivieren

```bash
# Alle Alerts aus
sudo systemctl stop aircraft-alert-notifier ogn-balloon-notifier

# Wieder einschalten
sudo systemctl start aircraft-alert-notifier ogn-balloon-notifier
```

## Konfiguration anpassen

### Alert-Typen aktivieren/deaktivieren

Datei bearbeiten: `/usr/local/sbin/aircraft-alert-notifier`

```python
ALERTS = {
    "military_low": {
        "name": "🚁 Militär Tief & Nah",
        "enabled": True,  # ← auf False setzen zum Deaktivieren
        ...
    },
    ...
}
```

Nach Änderungen: `sudo systemctl restart aircraft-alert-notifier`

### Schwellwerte anpassen

Beispiel: Hubschrauber-Radius vergrößern

```python
"helicopter_near": {
    "check": lambda ac: (
        ac.get("category", "").startswith("H")
        and ac.get("r_dst", 999) < 8  # ← Ändern von 5nm (9km) auf 8nm (15km)
    ),
}
```

### Cooldown-Zeiten anpassen

```python
"military_low": {
    "cooldown": 3600,  # ← Sekunden (3600 = 1h)
}
```

Empfehlung:
- Emergency: 300s (5min) - wichtig!
- Extrem tief: 1800s (30min)
- Andere: 3600s (1h)

## Technische Details

### Datenfluss Aircraft Alerts

```
readsb → /run/readsb/aircraft.json (aktualisiert alle 1s)
    ↓
aircraft-alert-notifier (liest alle 10s)
    ↓
Alert-Prüfung (6 Typen parallel)
    ↓
Cooldown-Check (State-File)
    ↓
Telegram-Benachrichtigung
```

### Datenfluss Balloon Alerts

```
glidernet.org APRS-Server
    ↓
ogn-balloon-notifier (TCP Socket)
    ↓
Type 11 Filter (Balloon)
    ↓
Cooldown-Check (4h)
    ↓
Telegram-Benachrichtigung
```

### Performance

- **CPU-Last:** Minimal (<1% bei 10s-Intervall)
- **RAM:** ~15 MB pro Service
- **Netzwerk:** Balloon-Service ~1 KB/s (APRS-Stream)

## Quellen

- [ICAO 24-bit Address Allocation](https://www.kloth.net/radio/icao-id.php)
- [Germany ICAO Range 3C-3F](http://www.aerotransport.org/html/ICAO_hex_decode.html)
- [EUROCONTROL Military ADS-B](https://www.eurocontrol.int/sites/default/files/2024-05/eurocontrol-compendium-mode-s-ads-b-military.pdf)
- [OGN Aircraft Types](https://github.com/m000c400/OGN-Tracker/blob/master/README.md)
- [OGN APRS Protocol](http://wiki.glidernet.org/wiki:ogn-flavoured-aprs)
- [Klinikum Bamberg Bruderwald](https://www.sozialstiftung-bamberg.de/klinikum-bamberg/standorte/)
