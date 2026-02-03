# NTRIP Source Table Proxy

**Problem gelöst:** NTRIP-Client-Apps (Lefebure, SW Maps, RTKLIB) können Mountpoint nicht finden weil str2str fast leere Source Table sendet.

**Status:** ✅ Produktiv seit 2026-02-03

---

## 🎯 Das Problem

### str2str sendet leere Source Table

```bash
printf "GET / HTTP/1.0\r\n\r\n" | nc localhost 5000

# Antwort von str2str:
SOURCETABLE 200 OK
Server: RTKLIB 2.4.3 b34
Connection: close
Content-Length: 27

STR;BASE;        ← Fast leer! Keine Metadaten!
ENDSOURCETABLE
```

**Symptom in NTRIP-Client-Apps:**
- Lefebure NTRIP Client: "Network connection dropped" oder "No streams found"
- SW Maps: Mountpoint-Liste bleibt leer
- RTKLIB: Kann BASE nicht auswählen

---

## ✅ Die Lösung: Transparent Proxy

```
┌──────────────────────────────────────────────────┐
│ NTRIP Client (Lefebure, SW Maps, RTKLIB)        │
│ Port 5001                                        │
└─────────────┬────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────┐
│ ntrip-proxy (Python, Port 5001)                 │
│                                                  │
│ GET / → Vollständige Source Table senden        │
│ GET /BASE → 1:1 transparent zu str2str          │
└─────────────┬────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────┐
│ ntripcaster (str2str, Port 5000)                │
│ GPS UART → RTCM → NTRIP Stream                  │
└──────────────────────────────────────────────────┘
```

---

## 📋 Source Table Format

**Vollständige NTRIP-konforme Source Table:**

```
SOURCETABLE 200 OK
Server: RTKLIB 2.4.3 b34
Date: 2026/02/03 10:00:00 UTC
Connection: close
Content-Type: text/plain
Content-Length: 139

STR;BASE;Stegaurach;RTCM 3.2;1005(10),1077(1),1087(1),1097(1);2;GPS+GLO+GAL;SNIP;DEU;49.87;10.84;0;0;sNTRIP;none;N;N;560;
ENDSOURCETABLE
```

**Felder erklärt:**
```
STR = Stream Entry
BASE = Mountpoint Name
Stegaurach = Station Name
RTCM 3.2 = Format
1005(10) = Message 1005, alle 10 Sekunden
1077(1),1087(1),1097(1) = GPS/GLO/GAL MSM7, jede Sekunde
2 = Carrier (L1+L2)
GPS+GLO+GAL = GNSS-Systeme
SNIP = Caster Software
DEU = Land (Deutschland)
49.87;10.84 = Lat/Lon (Dezimalgrad)
0;0 = NMEA (nicht vorhanden)
sNTRIP = Protokoll
none = Authentication
N;N = Fee/Encryption
560 = Bitrate (bytes/s)
```

---

## 🔧 Installation & Konfiguration

### Service-Unit

`/etc/systemd/system/ntrip-proxy.service`:

```ini
[Unit]
Description=NTRIP Source Table Proxy
After=network.target ntripcaster.service
Requires=ntripcaster.service

[Service]
Type=simple
User=pi
ExecStart=/usr/local/sbin/ntrip-proxy
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Python-Skript

`/usr/local/sbin/ntrip-proxy`:

**Architektur:**
- Liest HTTP-Request komplett (bis `\r\n\r\n`)
- Routet basierend auf Request-Line:
  - `GET / ` → Sendet vollständige Source Table + schließt
  - `GET /BASE` → Leitet RAW REQUEST 1:1 zu str2str weiter (transparent proxy)

**Kritische Implementation-Details:**
1. **Source Table:** `Connection: close` Header + sofort schließen
2. **Transparent Proxy:** RAW Request byteweise weiterleiten, KEINE Modifikation!
3. **Bidirektional:** Zwei Threads für upstream→client und client→upstream

---

## 📱 Client-Konfiguration

### Lefebure NTRIP Client

```
Settings → NTRIP Settings
┌────────────────────────────────────┐
│ Host: 192.168.1.135                │
│ Port: 5001         ← Proxy!        │
│                                    │
│ [Get Source Table]                 │
│ → ☑ BASE - Stegaurach (RTCM 3.2)  │
│                                    │
│ Username: (leer)                   │
│ Password: (leer)                   │
│ Send GGA: OFF                      │
└────────────────────────────────────┘
```

### SW Maps

```
GNSS Settings → NTRIP Settings
┌────────────────────────────────────┐
│ Address: 192.168.1.135             │
│ Port: 5001                         │
│ Mountpoint: BASE                   │
│ User/Pass: (leer)                  │
└────────────────────────────────────┘
```

**WICHTIG:** Port 5001 (Proxy) statt 5000 (direkt zu str2str)!

---

## 🐛 Troubleshooting

### "Network connection dropped"

**Ursache:** App hat keinen GPS-Fix

**Lösung:**
1. Gehe NACH DRAUSSEN (GPS braucht Sicht zu Satelliten)
2. Warte bis "Standalone" Position im Client erscheint (30-60s)
3. DANN erst NTRIP verbinden

**Hintergrund:** Lefebure schließt NTRIP-Verbindung nach 30s wenn kein GPS-Fix vorhanden.

### "No streams found"

**Ursache:** Client verbindet zu Port 5000 statt 5001

**Lösung:** Port 5001 in Client-Einstellungen verwenden!

### Proxy sendet 0 bytes bei GET /BASE

**Ursache:** HTTP-Request wurde modifiziert statt 1:1 weitergeleitet

**Lösung:** RAW Request byteweise weiterleiten:
```python
# ✅ RICHTIG:
upstream.sendall(raw_request)

# ❌ FALSCH:
upstream.sendall(f"GET {path} HTTP/1.1\r\n{headers}\r\n\r\n")
```

str2str akzeptiert nur original Request!

---

## 📊 Monitoring

### Service-Status

```bash
systemctl status ntrip-proxy ntripcaster
```

### Live-Logs

```bash
sudo journalctl -u ntrip-proxy -f
```

**Erfolgreiche Verbindung:**
```
[192.168.1.123:xxxxx] GET / HTTP/1.1
[192.168.1.123:xxxxx] → Source Table
[192.168.1.123:xxxxx] → Source Table sent, closed

[192.168.1.123:yyyyy] GET /BASE HTTP/1.1
[192.168.1.123:yyyyy] → TRANSPARENT proxy to upstream
[192.168.1.123:yyyyy] → Connected, forwarding 165 bytes UNMODIFIED
[192.168.1.123:yyyyy] → Request forwarded, starting bidirectional proxy
[192.168.1.123:yyyyy] upstream→client transferred 182400 bytes, closing
```

**RTCM-Stream:** ~5 kbps = ~5000 bytes/s, nach 1 Minute ~300 KB übertragen

### Telegram Bot

```
/status

GPS/RTK (2/2) - NTRIP Clients: 1
```

**Bedeutung:**
- `2/2` = ntripcaster + ntrip-proxy beide aktiv
- `NTRIP Clients: 1` = Ein Rover verbunden auf Port 5001

---

## 🔧 Wartung & Updates

### Source Table aktualisieren

Position oder Station-Name ändern:

```python
# In /usr/local/sbin/ntrip-proxy
SOURCE_TABLE_CONTENT = b"STR;BASE;NewName;RTCM 3.2;...;N;N;560;\r\nENDSOURCETABLE\r\n"
```

Nach Änderung:
```bash
sudo systemctl restart ntrip-proxy
```

### Logs prüfen

```bash
# Letzte Verbindungen
sudo journalctl -u ntrip-proxy --since "1 hour ago" | grep "GET /"

# Übertragene Bytes
sudo journalctl -u ntrip-proxy --since "1 hour ago" | grep "transferred"
```

---

## 🎯 Performance

**Erwartete Werte:**
- Source Table Request: <100ms, sofort geschlossen
- Mountpoint Connection: Dauerhaft offen
- RTCM-Stream: ~5 kbps (4500-5500 bytes/s)
- Latency: <10ms (localhost Proxy)

**Ressourcen:**
- RAM: ~10 MB (Python + 2 Threads pro Client)
- CPU: <1% idle, <2% mit aktiven Clients

---

## 📚 Referenzen

- **NTRIP Protocol:** [BKG NTRIP Documentation](https://igs.bkg.bund.de/ntrip/documentation)
- **str2str Manual:** `str2str --help`
- **Source Table Format:** RTCM-NTRIP 2.0 Specification

---

## ✅ Zusammenfassung

| Komponente | Port | Funktion | Client |
|------------|------|----------|--------|
| **ntripcaster** | 5000 | str2str RTCM-Stream | Für direkten Zugriff (keine Source Table) |
| **ntrip-proxy** | 5001 | Source Table Proxy | **Für NTRIP-Client-Apps** ✅ |

**Empfehlung:** Nutze Port 5001 für alle NTRIP-Clients (Lefebure, SW Maps, RTKLIB).

**RTK-Genauigkeit:**
- Standalone: 3-5m
- DGPS: ~1m (nach NTRIP Connect)
- RTK Float: 20-50cm (nach 30-60s)
- **RTK Fixed: 1-2cm** (nach 2-5 Minuten) ✅
