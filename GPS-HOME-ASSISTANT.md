# GPS Base Station → Home Assistant Integration

**Status:** ✅ Aktiv seit 2026-02-03
**MQTT Broker:** 192.168.1.21:1883 (Home Assistant)

---

## Übersicht

Der Raspberry Pi GPS Base Station publiziert Stratum 1 Zeitserver- und NTRIP-Status via MQTT an Home Assistant. Die Sensoren erscheinen automatisch via **MQTT Discovery**.

```
┌─────────────────────┐
│  GPS PPS (GPIO 18)  │
│  LC29H RTK Module   │
└─────────┬───────────┘
          │
┌─────────▼───────────┐     ┌──────────────────┐     ┌─────────────────┐
│     chronyd         │────▶│ gps-mqtt-        │────▶│ Home Assistant  │
│  Stratum 1 Server   │     │   publisher      │MQTT │   (4 Sensoren)  │
└─────────────────────┘     └──────────────────┘     └─────────────────┘
┌─────────────────────┐
│   ntripcaster       │
│  RTCM Base Station  │
└─────────────────────┘
```

---

## Home Assistant Sensoren

### Automatisch via MQTT Discovery verfügbar:

| Sensor | Entity ID | Beschreibung | Einheit |
|--------|-----------|--------------|---------|
| **GPS Stratum** | `sensor.gps_stratum` | Chrony Stratum-Level (sollte 1 sein) | - |
| **GPS PPS Offset** | `sensor.gps_pps_offset` | PPS-Zeitversatz (Sub-Mikrosekunden-Genauigkeit) | Nanosekunden |
| **GPS Reference** | `sensor.gps_reference` | Referenz-Zeitquelle (sollte PPS sein) | - |
| **NTRIP Server** | `sensor.ntrip_server` | NTRIP Base Station Status | ON/OFF |

**Device Name:** ADS-B Feeder GPS Base Station
**Model:** Waveshare LC29H RTK
**Manufacturer:** Quectel

---

## Service

**Name:** `gps-mqtt-publisher.service`
**Skript:** `/usr/local/sbin/gps-mqtt-publisher`
**Update-Intervall:** 60 Sekunden
**User:** pi

### Status prüfen

```bash
systemctl status gps-mqtt-publisher
journalctl -u gps-mqtt-publisher -f
```

### MQTT Topics

```
homeassistant/sensor/adsb_feeder_gps/+/config   # Discovery (retain)
gps/adsb_feeder_gps/state                       # State Updates (60s)
```

### Beispiel State Payload

```json
{
  "ref_id": "PPS",
  "stratum": 1,
  "offset_ns": -177.0,
  "pps_samples": 31,
  "pps_freq_skew": 22.0,
  "pps_offset_ns": -157.0,
  "ntrip_active": true,
  "timestamp": "2026-02-03T17:54:32.123456"
}
```

---

## Lovelace Dashboard

### Entities Card

```yaml
type: entities
title: GPS Base Station
entities:
  - entity: sensor.gps_stratum
    name: Stratum Level
  - entity: sensor.gps_pps_offset
    name: PPS Offset
  - entity: sensor.gps_reference
    name: Reference Source
  - entity: sensor.ntrip_server
    name: NTRIP Server
```

### Glance Card

```yaml
type: glance
title: GPS Status
entities:
  - sensor.gps_stratum
  - sensor.gps_pps_offset
  - sensor.ntrip_server
```

---

## Automationen

### Alert bei GPS-Problemen

```yaml
automation:
  - alias: "GPS Base Station Stratum Warning"
    trigger:
      - platform: numeric_state
        entity_id: sensor.gps_stratum
        above: 1
        for: '00:05:00'
    action:
      - service: notify.telegram
        data:
          message: "⚠️ GPS Base Station: Stratum {{ states('sensor.gps_stratum') }} (erwartet: 1)"

  - alias: "GPS PPS Offset Warning"
    trigger:
      - platform: template
        value_template: "{{ states('sensor.gps_pps_offset') | float | abs > 1000 }}"
        for: '00:05:00'
    action:
      - service: notify.telegram
        data:
          message: "⚠️ GPS PPS Offset zu hoch: {{ states('sensor.gps_pps_offset') }}ns"

  - alias: "NTRIP Server Down"
    trigger:
      - platform: state
        entity_id: sensor.ntrip_server
        to: 'OFF'
        for: '00:05:00'
    action:
      - service: notify.telegram
        data:
          message: "⚠️ NTRIP Server offline!"
```

---

## NTP Time Sync

Home Assistant kann den Pi als Stratum 1 NTP-Server nutzen:

```yaml
# configuration.yaml
time:
  - platform: ntp
    servers:
      - 192.168.1.135  # Raspberry Pi GPS Base Station
```

**Vorteil:** Mikrosekunden-genaue Zeit statt öffentliche NTP-Server (Millisekunden)

---

## Monitoring

Der Service wird **nicht** automatisch von feeder-watchdog überwacht.

**Grund:** GPS/MQTT ist optional und kritischer Ausfall würde bereits durch HA-Automationen erkannt.

**Status in Telegram /status:** Noch nicht integriert (optional möglich)

---

## Troubleshooting

### Sensoren erscheinen nicht in Home Assistant

**Check 1: Service läuft?**
```bash
systemctl status gps-mqtt-publisher
# Sollte: active (running)
```

**Check 2: Discovery Messages gesendet?**
```bash
journalctl -u gps-mqtt-publisher -n 20 | grep "Published discovery"
# Sollte: 4x "Published discovery: GPS ..."
```

**Check 3: MQTT Broker erreichbar?**
```bash
mosquitto_pub -h 192.168.1.21 -p 1883 -t "test" -m "ping"
# Sollte: kein Fehler
```

**Check 4: Discovery Messages im Broker?**
```bash
mosquitto_sub -h 192.168.1.21 -p 1883 -t "homeassistant/sensor/adsb_feeder_gps/+/config" -C 1
# Sollte: JSON mit sensor config
```

**Fix:**
```bash
sudo systemctl restart gps-mqtt-publisher
# In Home Assistant: Developer Tools → MQTT → Listen to "gps/#"
```

### PPS Offset zu hoch

**Normal:** -1000ns bis +1000ns (<1 Mikrosekunde)
**Warnung:** >10000ns (>10 Mikrosekunden)
**Problem:** >100000ns (>100 Mikrosekunden)

**Ursachen:**
- GPS hat keinen Fix (keine Satelliten)
- PPS-Kabel nicht angeschlossen
- Chrony noch nicht synchronisiert (warten 5-10 Minuten)

**Check:**
```bash
chronyc tracking
chronyc sources -v
```

### NTRIP Server zeigt OFF

```bash
systemctl status ntripcaster
# Falls inactive:
sudo systemctl start ntripcaster
```

---

## Updates

### Service-Update

```bash
# Neues Skript deployen
sudo nano /usr/local/sbin/gps-mqtt-publisher
sudo chmod +x /usr/local/sbin/gps-mqtt-publisher

# Service neu starten
sudo systemctl restart gps-mqtt-publisher
journalctl -u gps-mqtt-publisher -f
```

### MQTT Broker wechseln

```bash
sudo nano /usr/local/sbin/gps-mqtt-publisher
# Ändere: MQTT_BROKER = "neue.ip.adresse"

sudo systemctl restart gps-mqtt-publisher
```

---

## Integration mit anderen Services

### ESPHome GPS Module

Falls du ESPHome-Geräte mit GPS hast, können diese den NTRIP-Server nutzen:

```yaml
# ESPHome Config
gps:
  - platform: ublox
    uart_id: gps_uart
    ntrip:
      host: 192.168.1.135
      port: 5000
      mountpoint: "BASE"
      password: "pw123"
```

### Node-RED

```json
{
  "id": "mqtt-in",
  "type": "mqtt in",
  "topic": "gps/adsb_feeder_gps/state",
  "broker": "192.168.1.21",
  "name": "GPS Status"
}
```

---

## Referenzen

- GPS Setup: `~/docs/GPS-SETUP.md`
- GPS RTK Hybrid: `~/docs/GPS-RTK-HYBRID-SETUP.md`
- DragonSync MQTT: `~/docs/DRAGONSYNC.md` (ähnliches Pattern)
- Home Assistant MQTT Discovery: https://www.home-assistant.io/integrations/mqtt/#discovery
