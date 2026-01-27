# tar1090 in Home Assistant einbinden (hass_ingress)

## Voraussetzungen
- Home Assistant mit HACS
- Nabu Casa (für externen Zugriff)
- tar1090 läuft auf Pi unter `http://adsb-feeder.internal/tar1090/`

## Installation

### 1. hass_ingress installieren
HACS → Integrations → "Ingress" suchen → Download → HA neu starten

### 2. Integration hinzufügen (WICHTIG!)
Einstellungen → Geräte & Dienste → Integration hinzufügen → "Ingress" suchen

**Bei der Konfiguration wird nach dem Modus gefragt:**

| Modus | Beschreibung |
|-------|--------------|
| **YAML** (empfohlen) | Konfiguration über configuration.yaml |
| **Agent** | Erfordert separaten Ingress-Agent-Server (undokumentiert!) |

**Wähle "YAML"!** Der Agent-Modus fragt nach einer URL wie `ha-ingress:8080`, aber dieser Agent-Server ist weder dokumentiert noch im Repository verfügbar.

### 3. configuration.yaml
```yaml
ingress:
  tar1090:
    title: "ADS-B Radar"
    icon: mdi:airplane
    url: http://adsb-feeder.internal/tar1090/
    work_mode: ingress
    ui_mode: normal
```

### 4. Aktivieren
Entwicklerwerkzeuge → YAML → Ingress neu laden

## Ergebnis
- "ADS-B Radar" erscheint in HA-Sidebar
- Funktioniert lokal + via Nabu Casa

## Falls Darstellungsprobleme
```yaml
ingress:
  tar1090:
    title: "ADS-B Radar"
    icon: mdi:airplane
    url: http://adsb-feeder.internal/tar1090/
    work_mode: ingress
    ui_mode: normal
    rewrite:
      - mode: body
        match: '/tar1090/'
        replace: './'
```

## Links
- https://github.com/lovelylain/hass_ingress
- Pi tar1090: http://adsb-feeder.internal/tar1090/
