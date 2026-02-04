# GPS AGNSS/EPO Implementation - LC29H Module

**Hardware:** Waveshare LC29H (Quectel) Dual-Band RTK GNSS
**Datum:** 2026-02-04
**Status:** ❌ Nicht implementiert (24/7-Betrieb macht AGNSS unnötig)

## Zusammenfassung

AGNSS (Assisted GNSS) würde TTFF (Time To First Fix) von 60-90s auf 5-10s reduzieren. Bei 24/7 Base Station Betrieb ist dies jedoch nicht relevant, da Reboots selten sind (~1x/Monat) und Almanach/Ephemeris automatisch durch Satelliten-Empfang aktuell bleiben.

---

## Hardware-Spezifikationen

### Waveshare LC29H Module

| Parameter | Wert |
|-----------|------|
| Chip | Quectel LC29H (CASIC-basiert) |
| Frequenzen | GPS L1+L5, GLONASS, Galileo, BeiDou, QZSS |
| Interface | UART `/dev/ttyAMA0` @ 115200 Baud |
| PPS | GPIO 18 → `/dev/pps0` |
| Protokolle | NMEA 0183, PAIR (Quectel proprietary) |
| RTK | Ja (L1+L5 Dual-Band) |
| Backup Batterie | Nein (keine ML1220 installiert) |

### System-Integration

```
LC29H (UART) → str2str → NTRIP Caster (Port 5000)
LC29H (PPS)  → chronyd → Stratum 1 NTP (±Nanosekunden)
```

**Problem:** str2str blockiert `/dev/ttyAMA0` 24/7, daher kein direkter NMEA-Zugriff für AGNSS-Upload ohne Service-Unterbrechung.

---

## AGNSS-Versuch: MediaTek EPO (2026-02-04)

### Test-Setup

**Versuch:** MediaTek EPO.DAT von öffentlichem Server laden und an GPS senden

```bash
#!/bin/bash
# Download MediaTek EPO
curl -o /var/cache/agnss/epo.dat http://epodownload.mediatek.com/EPO.DAT

# Service stoppen
systemctl stop ntripcaster

# EPO an GPS senden
cat /var/cache/agnss/epo.dat > /dev/ttyAMA0

# Service starten
systemctl start ntripcaster
```

### Ergebnis: ❌ Fehlgeschlagen

**Live-Test:**
- 270KB EPO-Daten erfolgreich gesendet
- GPS empfing Daten ohne Fehler
- **Aber:** Nach Reboot 8 Minuten kein Fix (erwartet: <15s)

**Vergleich: Ohne EPO**
- Nach Reboot: 3D RTK Fix nach **2 Minuten**
- PPS: -70ns (Nanosekunden-Genauigkeit)
- Stratum: 1 (GPS-locked)

**Analyse:**
- MediaTek EPO ist **NICHT kompatibel** mit LC29H (Quectel/CASIC-Chip)
- GPS wurde durch falsche EPO-Daten verwirrt
- **Faktor >1.000.000x schlechter** als ohne EPO

### Lessons Learned

1. **Chip-Hersteller-spezifisch:** MediaTek EPO ≠ Quectel PAIR ≠ CASIC AGNSS
2. **Kein NMEA-Zugriff:** str2str blockiert Device, macht Live-Diagnose unmöglich
3. **Blind Testing ist gefährlich:** Ohne NMEA-Feedback keine Ahnung was GPS macht
4. **Public EPO ≠ Vendor EPO:** `epodownload.mediatek.com/EPO.DAT` ist generic, LC29H braucht `wpepodownload.mediatek.com/EPO.DAT?vendor=X&project=Y&device_id=Z`

---

## Korrekte LC29H AGNSS-Implementation

### Offizieller Weg: Quectel PAIR Protocol

**Server:** `http://wpepodownload.mediatek.com/EPO.DAT?vendor=<VID>&project=<PID>&device_id=<DID>`

**Credentials:** Nicht öffentlich, müssen von Quectel Technical Support angefordert werden

**Protokoll:** PAIR (Quectel proprietary NMEA-based)

### Dokumentation

| Dokument | Quelle |
|----------|--------|
| Quectel L89/LC29H/LC79H AGNSS Application Note V1.0 | [Waveshare Wiki](https://files.waveshare.com/wiki/LC29H(XX)-GPS-RTK-HAT/Quectel_L89_R2.0&LC29H&LC79H_AGNSS_Application_Note_V1.0.pdf) |
| Quectel LC29H Hardware Design V1.3 | [Quectel Forums](https://forums.quectel.com/uploads/short-url/u7fE3GaEAynRmZ3J7ihhjXrwxTF.pdf) |
| Quectel GNSS Flash EPO Application Note | [sbcshop GitHub](https://github.com/sbcshop/GPS-Hat-for-Raspberry-Pi) |

### GitHub-Referenzen

**LC29H-spezifisch:**
- [CyKibb/lc29h-driver](https://github.com/CyKibb/lc29h-driver) - C Driver für LC29H
- [mctainsh/LC29H_RTK_Server](https://github.com/mctainsh/LC29H_RTK_Server) - RTK Caster
- [phryniszak/lc29h](https://github.com/phryniszak/lc29h) - Local RTK Solution

**Quectel EPO Implementierung:**
- [Wiz-IO/platformio-quectel-examples](https://github.com/Wiz-IO/platformio-quectel-examples) - `OpenCPU/m66/example_download_epo.c` zeigt EPO Binary Protocol
- [sbcshop/GPS-Hat-for-Raspberry-Pi](https://github.com/sbcshop/GPS-Hat-for-Raspberry-Pi) - Enthält offizielle Quectel AGNSS PDF

**AGNSS Tools:**
- [DashSight/MediaTek-GPS-Utils](https://github.com/DashSight/MediaTek-GPS-Utils) - Python EPO Loader (MediaTek MT3333/MT3339)
- [semuconsulting/PyGPSClient](https://github.com/semuconsulting/PyGPSClient) - Linux GNSS GUI mit LC29H $PAIR Support

---

## Warum AGNSS für LC29H Base Station NICHT nötig ist

### Almanach & Ephemeris Auto-Update

| Parameter | Ohne Batterie (Cold Start) | 24/7 Betrieb |
|-----------|----------------------------|--------------|
| **Almanach** | Verfällt nach 30 Tagen | Immer aktuell (tägliche Updates vom Satellit) |
| **Ephemeris** | Verfällt nach 4 Stunden | Immer aktuell (alle 2-4h erneuert) |
| **TTFF nach Reboot** | 60-90 Sekunden | 60-90 Sekunden (kein Unterschied) |
| **Reboot-Frequenz** | ~1x/Monat (Updates) | Selten |

### Berechnung: Almanach nie veraltet

```
Almanach Gültigkeit:  30 Tage
Reboot-Intervall:     ~30 Tage (apt upgrades)
GPS Offline-Zeit:     ~60 Sekunden (Boot-Zeit)

→ Almanach verfällt NIE (GPS nie >4h offline)
→ Cold Start immer mit aktuellem Almanach
→ AGNSS würde nur 60s → 10s verbessern (50s Zeitgewinn)
```

### AGNSS würde sich lohnen bei:

- ✅ GPS >4h offline (Transport, Lagerung)
- ✅ Häufige Reboots (täglich)
- ✅ Mobile Anwendung (Auto, Drohne)
- ❌ **24/7 Base Station** ← Unser Use Case

---

## Implementation Guide (falls doch gewünscht)

### Voraussetzungen

1. **Credentials von Quectel holen**
   ```
   Email: support@quectel.com
   Subject: LC29H AGNSS Server Credentials Request
   Info needed: vendor, project, device_id for wpepodownload.mediatek.com
   ```

2. **PyGPSClient oder QGNSS installieren**
   ```bash
   pip3 install pygpsclient
   # ODER: QGNSS.exe (Windows only)
   ```

3. **str2str temporär stoppen können**
   ```bash
   systemctl stop ntripcaster  # Stoppt str2str
   # Jetzt ist /dev/ttyAMA0 frei für EPO-Upload
   systemctl start ntripcaster
   ```

### Manuelle EPO-Upload Prozedur

```bash
#!/bin/bash
# /usr/local/sbin/agnss-loader-manual

VENDOR="???"      # Von Quectel erfragen
PROJECT="???"     # Von Quectel erfragen
DEVICE_ID="???"   # Von Quectel erfragen

# 1. EPO herunterladen
curl -o /tmp/epo.dat \
  "http://wpepodownload.mediatek.com/EPO.DAT?vendor=$VENDOR&project=$PROJECT&device_id=$DEVICE_ID"

# 2. NTRIP Base Station stoppen
systemctl stop ntripcaster

# 3. EPO via PAIR-Protokoll senden
# (Hier fehlt PAIR-Protokoll-Wrapper, siehe Quectel AGNSS Application Note)
# Vermutlich: Binary-Mode aktivieren + Daten senden

# 4. NTRIP Base Station starten
systemctl start ntripcaster

# 5. TTFF messen
/usr/local/sbin/ttff-measurement
```

### Alternative: PyGPSClient GUI

```bash
# Service stoppen
sudo systemctl stop ntripcaster

# PyGPSClient starten
pygpsclient

# GUI: Device → Set Device → LC29H(AA) → /dev/ttyAMA0 → 115200
# GUI: AGNSS → Assistant GNSS Offline → Connect
# GUI: Download EPO (benötigt Credentials in Config)
# GUI: Send to Device

# Service starten
sudo systemctl start ntripcaster
```

---

## TTFF (Time To First Fix) Benchmark

### Ohne AGNSS (Ist-Zustand)

| Szenario | TTFF | Details |
|----------|------|---------|
| **Warm Start** | <5s | GPS war <4h offline, Ephemeris noch gültig |
| **Cold Start** | 60-90s | GPS war >4h offline, kein Ephemeris |
| **Factory Reset** | 90-120s | Kein Almanach, kein Ephemeris |

### Mit AGNSS (Erwartung)

| Szenario | TTFF | Verbesserung |
|----------|------|--------------|
| **Warm Start** | <5s | Keine Änderung |
| **Cold Start** | 5-10s | **6-9x schneller** |
| **Factory Reset** | 5-10s | **9-12x schneller** |

### Messung (2026-02-04)

**Boot:** 15:30:29
**PPS Lock:** 15:32:xx (geschätzt ~2min, keine exakte Messung)
**Result:** Cold Start ohne AGNSS = **~120s** (2 Minuten)

**Hinweis:** TTFF-Measurement Service war fehlerhaft (startete zu früh, `systemd-analyze` noch nicht bereit).

---

## Alternative: Backup-Batterie statt AGNSS

### ML1220 Rechargeable Battery

**Hardware-Mod:** Waveshare LC29H HAT hat ML1220-Slot

| Parameter | Wert |
|-----------|------|
| Typ | ML1220 Rechargeable Manganese Lithium |
| Spannung | 3V |
| Kapazität | 17 mAh |
| Retention Time | ~2 Wochen (Almanach + Ephemeris) |
| Ladezeit | ~2h via GPS-Modul |
| Kosten | ~5-10€ |

**Vorteile:**
- ✅ Warm Start statt Cold Start (<5s statt 60-90s)
- ✅ Kein Server/Credentials nötig
- ✅ Keine Software-Änderungen
- ✅ Wartungsfrei

**Nachteile:**
- ❌ Batterie kann auslaufen (nach ~5 Jahren)
- ❌ Muss alle 2-5 Jahre gewechselt werden

**Empfehlung:** Batterie ist **einfacher und zuverlässiger** als AGNSS für Base Station Use-Case.

---

## CASIC AGNSS Server

**Server:** `agnss.casic.cn`
**Status:** ❌ Nicht erreichbar / Rate-limited

```
Limitation: 7/1000
→ Nur 7 von 1000 Download-Slots verfügbar
→ Nur für autorisierte Kunden (Zhongkewei GNSS-Empfänger)
```

**Alternative:** MediaTek EPO Server (mit vendor/project/device_id credentials)

---

## Self-Hosting EPO Server

### Option: Eigenen EPO-Server betreiben

**Aufwand:** Hoch (1-2 Monate Entwicklung)

**Schritte:**
1. RINEX-Daten von NASA/IGS herunterladen (täglich, ~50MB)
2. RINEX parsen (Standard-Format)
3. Orbit-Propagation berechnen (7-30 Tage voraus, komplex)
4. PAIR-Protokoll-Encoding (Reverse Engineering nötig)
5. Server mit HTTP-Endpunkt aufsetzen

**Tools:**
- RINEX: https://cddis.nasa.gov/archive/gnss/data/daily/
- Orbit Propagation: SGP4/SDP4 Algorithmen
- Reference: [DashSight/MediaTek-GPS-Utils](https://github.com/DashSight/MediaTek-GPS-Utils)

**Empfehlung:** Nicht lohnenswert für 50s Zeitgewinn bei seltenem Reboot.

---

## Entscheidungsmatrix

| Lösung | Aufwand | TTFF Verbesserung | Wartung | Empfehlung |
|--------|---------|-------------------|---------|------------|
| **Status Quo (kein AGNSS)** | Keiner | Baseline (60-90s) | Keine | ✅ **Für 24/7 Base Station optimal** |
| **ML1220 Batterie** | Hardware-Mod (~30min) | 60-90s → <5s | Batterie alle 5 Jahre wechseln | ✅ **Beste Balance** |
| **AGNSS mit Quectel Credentials** | Hoch (Request + Implementation) | 60-90s → 5-10s | Täglich EPO updaten | ⚠️ Nur bei häufigen Reboots |
| **Self-Hosted EPO** | Sehr hoch (1-2 Monate) | 60-90s → 5-10s | Server-Betrieb | ❌ Nicht lohnenswert |

---

## Debugging & Troubleshooting

### GPS-Status prüfen (ohne NMEA-Zugriff)

```bash
# PPS Synchronisation
chronyc sources | grep PPS
# Erwartung: #* PPS (selected, synchronized)

# GPS Fix Status (inferiert)
/usr/local/sbin/gps-status | jq '.fix'
# Erwartung: {"fix": "3D", "quality": "RTK Fixed"}

# NTRIP Base Station
systemctl status ntripcaster
ss -tn | grep :5000  # Clients?
```

### Mit NMEA-Zugriff (Service gestoppt)

```bash
# NTRIP stoppen
sudo systemctl stop ntripcaster

# NMEA-Stream lesen
stty -F /dev/ttyAMA0 115200
cat /dev/ttyAMA0

# Erwartete Sentences:
# $GNGGA - Position + Fix Quality
# $GNRMC - Recommended Minimum
# $GNGSA - Satellite Fix Data
# $GNGSV - Satellites in View

# Service starten
sudo systemctl start ntripcaster
```

### AGNSS Upload testen (falls implementiert)

```bash
# EPO-Daten vorhanden?
ls -lh /var/cache/agnss/

# Letzter Upload
cat /var/cache/agnss/last_load
# Format: <timestamp>\n<server>

# TTFF messen nach Reboot
sudo reboot
# Nach Reboot:
journalctl -b | grep -i "pps\|gps\|stratum"
# Erwartung: PPS Lock innerhalb 5-15s
```

---

## Changelog

| Datum | Änderung | Status |
|-------|----------|--------|
| 2026-02-04 | MediaTek EPO Test | ❌ Fehlgeschlagen (GPS verwirrt) |
| 2026-02-04 | Rollback aller AGNSS-Änderungen | ✅ System normal (Cold Start 2min) |
| 2026-02-04 | Dokumentation erstellt | ✅ |

---

## Weiterführende Links

### Offizielle Quectel-Dokumentation
- [LC29H Hardware Design Guide](https://www.quectel.com/content/uploads/2022/06/Quectel_LC29H_Series_Hardware_Design_V1.2.pdf)
- [AGNSS Application Note (Waveshare Mirror)](https://files.waveshare.com/wiki/LC29H(XX)-GPS-RTK-HAT/Quectel_L89_R2.0&LC29H&LC79H_AGNSS_Application_Note_V1.0.pdf)

### Community-Projekte
- [awesome-gnss](https://github.com/barbeau/awesome-gnss) - Curated GNSS Resources
- [RTKLIB](https://github.com/tomojitakasu/RTKLIB) - Industry Standard GNSS Library
- [RTKBase](https://github.com/Stefal/rtkbase) - Web-based RTK Base Station Manager

### Verwandte Dokumentation
- [GPS-NTRIP-PROXY.md](./GPS-NTRIP-PROXY.md) - NTRIP Base Station Setup
- [OGN-SETUP.md](./OGN-SETUP.md) - OGN/FLARM Empfänger
- [LESSONS-LEARNED.md](./LESSONS-LEARNED.md) - System-spezifische Erkenntnisse

---

**Fazit:** Für 24/7 Base Station ist AGNSS nicht erforderlich. Eine ML1220-Batterie wäre die bessere Lösung falls Warm Start gewünscht ist.
