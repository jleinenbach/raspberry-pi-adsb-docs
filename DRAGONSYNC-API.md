# DragonSync HTTP API

**Port:** 8088
**Host:** 127.0.0.1 (nur localhost)
**Typ:** Read-Only REST API
**Auth:** Keine (nur LAN-Zugriff)

---

## Übersicht

DragonSync bietet eine minimale HTTP API für Status-Abfragen und Drohnen-Tracking ohne externe Dependencies (nur Python stdlib).

```
┌─────────────────────────────────────────────────┐
│  DragonSync API (Port 8088)                     │
├─────────────────────────────────────────────────┤
│  GET /status       → System Health              │
│  GET /drones       → Aktive Drohnen             │
│  GET /signals      → Signal Alerts (FPV etc.)   │
│  GET /config       → Sanitized Config           │
│  GET /update/check → Git Update Status          │
└─────────────────────────────────────────────────┘
```

**Implementierung:** `/home/pi/DragonSync/api/api_server.py`
**Rate Limiting:** 100 Requests / 60 Sekunden pro IP

---

## Endpoints

### 1. GET /status - System Status

**Beschreibung:** WarDragon System Health (CPU, Memory, GPS, Temps)

**⚠️ WICHTIG:** Diese Stats sind für mobile WarDragon S3R Kits mit PlutoSDR!
Auf unserem stationären System sind alle Werte 0 (kein PlutoSDR/Zynq vorhanden).

**Request:**
```bash
curl http://localhost:8088/status
```

**Response:**
```json
{
    "uid": "wardragon-unknown",
    "lat": 0.0,
    "lon": 0.0,
    "alt": 0.0,
    "cpu_usage": 0.0,
    "memory_total": 0.0,
    "memory_available": 0.0,
    "disk_total": 0.0,
    "disk_used": 0.0,
    "temperature": 0.0,
    "uptime": 0.0,
    "pluto_temp": "N/A",
    "zynq_temp": "N/A",
    "speed": 0.0,
    "track": 0.0,
    "gps_fix": false,
    "time_source": "",
    "gpsd_time_utc": "",
    "last_update_time": 1770140966.334711
}
```

**Fields:**
| Field | Beschreibung | Einheit |
|-------|--------------|---------|
| uid | System Identifier | - |
| lat/lon/alt | GPS-Position | °/°/m |
| cpu_usage | CPU-Auslastung | % |
| memory_total/available | RAM | MB |
| disk_total/used | Speicher | MB |
| temperature | System-Temperatur | °C |
| uptime | Betriebszeit | Sekunden |
| pluto_temp | PlutoSDR-Temperatur | °C |
| zynq_temp | Zynq FPGA-Temperatur | °C |
| speed | Geschwindigkeit (GPS) | m/s |
| track | Kurs (GPS) | ° |
| gps_fix | GPS hat Fix | bool |
| time_source | Zeit-Quelle | string |

---

### 2. GET /drones - Aktive Drohnen

**Beschreibung:** Liste aller aktuell erkannten Drohnen (Remote ID)

**Request:**
```bash
curl http://localhost:8088/drones
```

**Response (keine Drohnen):**
```json
{
    "drones": []
}
```

**Response (mit Drohnen):**
```json
{
    "drones": [
        {
            "uid": "drone-48A2E6F12345",
            "uas_id": "EU-ABC123456789",
            "lat": 49.867,
            "lon": 10.840,
            "hae": 125.5,
            "speed_horizontal": 12.3,
            "speed_vertical": -0.5,
            "heading": 235.0,
            "pilot_lat": 49.866,
            "pilot_lon": 10.839,
            "rssi": -65,
            "last_seen": 1770141234.567,
            "protocol": "ble",
            "mac": "48:A2:E6:F1:23:45"
        }
    ]
}
```

**Fields:**
| Field | Beschreibung |
|-------|--------------|
| uid | Eindeutige ID (MAC-basiert) |
| uas_id | EU Remote ID (Seriennummer) |
| lat/lon | Drohnen-Position (WGS84) |
| hae | Höhe über Ellipsoid (MSL) |
| speed_horizontal | Horizontale Geschwindigkeit (m/s) |
| speed_vertical | Vertikale Geschwindigkeit (m/s, negativ=sinken) |
| heading | Flugrichtung (0-360°) |
| pilot_lat/pilot_lon | Piloten-Position |
| rssi | Signal-Stärke (dBm) |
| last_seen | Letztes Update (Unix Timestamp) |
| protocol | Erkennungs-Protokoll (ble/wifi) |
| mac | MAC-Adresse des Senders |

---

### 3. GET /signals - Signal Alerts

**Beschreibung:** FPV-Drohnen-Signale (5.8GHz Video) und andere RF-Signale

**⚠️ HINWEIS:** Erfordert zusätzliche SDR-Hardware (nicht installiert)

**Request:**
```bash
curl http://localhost:8088/signals
```

**Response:**
```json
{
    "signals": []
}
```

**Use Case:** WarDragon S3R mit PlutoSDR kann FPV-Video-Signale (5.8GHz) erkennen, die KEINE Remote ID haben (ältere Drohnen, Racing-Drohnen).

---

### 4. GET /config - Sanitized Config

**Beschreibung:** Aktuelle Konfiguration (ohne Secrets)

**Request:**
```bash
curl http://localhost:8088/config
```

**Response (gekürzt):**
```json
{
    "tak": {
        "host": "",
        "port": null,
        "protocol": null,
        "multicast_addr": "239.2.3.1",
        "multicast_port": 6969,
        "enable_multicast": false
    },
    "api": {
        "enabled": true,
        "host": "127.0.0.1",
        "port": 8088
    },
    "mqtt": {
        "enabled": true,
        "host": "192.168.1.21",
        "port": 1883,
        "retain": true
    },
    "drones": {
        "max_drones": 70,
        "max_verified_drones": 50,
        "max_unverified_drones": 20,
        "inactivity_timeout": 120.0
    }
}
```

**Nützlich für:** Debugging, Konfiguration verifizieren

---

### 5. GET /update/check - Git Update Status

**Beschreibung:** Prüft ob DragonSync Updates verfügbar sind (GitHub)

**Request:**
```bash
curl http://localhost:8088/update/check
```

**Response:**
```json
{
    "ok": true,
    "branch": "main",
    "local_head": "e923c2203ca4804d7e91d1b90f0953944b4556a1",
    "remote_head": "1a88a8d61b156ff6dc1fb7a64616dc1f49f0e9c9",
    "update_available": true
}
```

**Fields:**
| Field | Beschreibung |
|-------|--------------|
| ok | Update-Check erfolgreich |
| branch | Git Branch |
| local_head | Aktueller Commit (lokal) |
| remote_head | Neuester Commit (GitHub) |
| update_available | Update verfügbar? |

**⚠️ WARNUNG:** Vor `git pull` beachten: Unser Patch in `mqtt_sink.py`!
Siehe: `~/docs/DRAGONSYNC.md` → "WarDragon S3R System Stats - DEAKTIVIERT"

---

## Rate Limiting

**Limit:** 100 Requests / 60 Sekunden pro IP
**Response bei Überschreitung:** HTTP 429 Too Many Requests

```json
{
    "error": "rate limit exceeded"
}
```

**Header:**
```
Retry-After: 60
```

---

## Verwendung

### Curl

```bash
# Aktive Drohnen
curl -s http://localhost:8088/drones | python3 -m json.tool

# Status mit jq formatiert
curl -s http://localhost:8088/status | jq .

# Nur Drohnen-Anzahl
curl -s http://localhost:8088/drones | jq '.drones | length'
```

### Python

```python
import requests

# Drohnen abfragen
response = requests.get("http://localhost:8088/drones")
drones = response.json()["drones"]

for drone in drones:
    print(f"Drohne: {drone['uas_id']} @ {drone['lat']},{drone['lon']}")
```

### Home Assistant REST Sensor

```yaml
# configuration.yaml
sensor:
  - platform: rest
    name: Active Drones
    resource: http://192.168.1.135:8088/drones
    value_template: "{{ value_json.drones | length }}"
    scan_interval: 10
```

**⚠️ Aber:** Home Assistant bekommt Drohnen bereits via MQTT Discovery!
API ist redundant für HA - nutze stattdessen die MQTT-Entities.

---

## Sicherheit

### Network ACL

**Aktuell:** API hört auf `127.0.0.1` (nur localhost)

**Um API im LAN verfügbar zu machen:**
```ini
# /home/pi/DragonSync/config.ini
api_host = 0.0.0.0
```

**⚠️ Warnung:** Keine Authentifizierung! Nur in trusted LAN verwenden.

### Port-Firewall

```bash
# UFW: API nur für lokales Subnet
sudo ufw allow from 192.168.1.0/24 to any port 8088

# Oder: API nur localhost (Standard)
api_host = 127.0.0.1  # in config.ini
```

---

## Test-Skript

**Datei:** `/usr/local/sbin/test-dragonsync-api`

```bash
#!/bin/bash
# Teste alle DragonSync API Endpoints

curl -s http://localhost:8088/status | python3 -m json.tool
curl -s http://localhost:8088/drones | python3 -m json.tool
curl -s http://localhost:8088/signals | python3 -m json.tool
curl -s http://localhost:8088/config | python3 -m json.tool
curl -s http://localhost:8088/update/check | python3 -m json.tool
```

---

## Troubleshooting

### API antwortet nicht

```bash
# Service läuft?
systemctl status dragonsync

# Port offen?
ss -tlnp | grep 8088

# Logs
journalctl -u dragonsync -f | grep API
```

### Connection refused

**Problem:** API hört nur auf 127.0.0.1, du versuchst von anderem Gerät

**Lösung:** `api_host = 0.0.0.0` in config.ini

### Update-Check zeigt update_available: true

**Vorsicht:** Vor `git pull` beachten:
1. Unser Patch in `mqtt_sink.py` geht verloren!
2. Backup vorhanden: `mqtt_sink.py.backup-20260203`
3. Nach Update: Patch erneut anwenden
4. Dokumentation: `~/docs/DRAGONSYNC.md`

---

## Referenzen

- DragonSync GitHub: https://github.com/alphafox02/DragonSync
- API Source Code: `/home/pi/DragonSync/api/api_server.py`
- System-Dokumentation: `~/docs/DRAGONSYNC.md`
- WarDragon Projekt: https://wardragon.army/
