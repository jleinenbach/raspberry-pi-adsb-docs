# GPS & GNSS Resources

**Zweck:** Offline-Kopien wichtiger Dokumentation für schnellen Zugriff

---

## Quectel LC29H Documentation

### AGNSS Application Note (V1.0, 792KB)
**Datei:** `Quectel_LC29H_AGNSS_Application_Note_V1.0.pdf`
**Quelle:** [Waveshare Wiki](https://files.waveshare.com/wiki/LC29H(XX)-GPS-RTK-HAT/Quectel_L89_R2.0&LC29H&LC79H_AGNSS_Application_Note_V1.0.pdf)
**Heruntergeladen:** 2026-02-04

**Inhalt:**
- PAIR Protocol Specification (Quectel proprietary)
- EPO Download & Upload Prozedur
- MediaTek EPO Server Credentials (vendor/project/device_id)
- Binary Mode Configuration (`$PMTK253`)
- AGNSS Flash EPO Format
- TTFF Benchmarks mit/ohne AGNSS

**Wichtigste Seiten:**
- PAIR Command Reference
- EPO Binary Protocol
- Server URLs & Authentication

---

### Hardware Design Guide (V1.3, 1.7MB)
**Datei:** `Quectel_LC29H_Hardware_Design_V1.3.pdf`
**Quelle:** [Quectel Forums](https://forums.quectel.com/uploads/short-url/u7fE3GaEAynRmZ3J7ihhjXrwxTF.pdf)
**Heruntergeladen:** 2026-02-04

**Inhalt:**
- LC29H Hardware Specifications
- UART/I2C/SPI Interfaces
- PPS Output Configuration
- Power Supply Requirements
- Antenna Design Guidelines
- RTK Positioning Modes
- ML1220 Backup Battery Circuit

**Wichtigste Seiten:**
- Pin Definitions
- Electrical Characteristics
- PPS Timing Specifications

---

## GitHub Reference Projects

### LC29H Implementations

| Projekt | Beschreibung | URL |
|---------|--------------|-----|
| lc29h-driver | C Driver für LC29H | https://github.com/CyKibb/lc29h-driver |
| LC29H_RTK_Server | RTK Caster | https://github.com/mctainsh/LC29H_RTK_Server |
| platformio-quectel-examples | EPO Binary Protocol Code | https://github.com/Wiz-IO/platformio-quectel-examples |
| GPS-Hat-for-Raspberry-Pi | Waveshare HAT mit Quectel PDFs | https://github.com/sbcshop/GPS-Hat-for-Raspberry-Pi |

### AGNSS Tools

| Projekt | Beschreibung | URL |
|---------|--------------|-----|
| MediaTek-GPS-Utils | Python EPO Loader (MT3333/MT3339) | https://github.com/DashSight/MediaTek-GPS-Utils |
| PyGPSClient | Linux GNSS GUI mit LC29H Support | https://github.com/semuconsulting/PyGPSClient |

### RTK Base Station

| Projekt | Beschreibung | URL |
|---------|--------------|-----|
| RTKBase | Web-GUI für RTK Base Station | https://github.com/Stefal/rtkbase |
| RTKLIB | Industry Standard GNSS Library | https://github.com/tomojitakasu/RTKLIB |

### PPS/Stratum 1

| Projekt | Beschreibung | URL |
|---------|--------------|-----|
| pi5-timeserver-gps-pps | Raspberry Pi als Stratum 1 | https://github.com/parlaynu/pi5-timeserver-gps-pps |
| RPi-GPS-PPS-StratumOne | GPS PPS + NTP Setup | https://github.com/beta-tester/RPi-GPS-PPS-StratumOne |

---

## Wichtige Links

### Offizielle Quectel-Ressourcen
- [Quectel LC29H Product Page](https://www.quectel.com/product/gnss-lc29h/)
- [Quectel Forums](https://forums.quectel.com/)
- [Quectel Technical Support](mailto:support@quectel.com)

### MediaTek EPO Server
- **Public:** http://epodownload.mediatek.com/EPO.DAT ❌ (Nicht LC29H-kompatibel)
- **Vendor:** http://wpepodownload.mediatek.com/EPO.DAT?vendor=XXX&project=YYY&device_id=ZZZ ✅ (Credentials nötig)

### Community
- [awesome-gnss](https://github.com/barbeau/awesome-gnss) - Curated GNSS Resources
- [RTKLIB.com](https://www.rtklib.com/) - RTKLIB Documentation

---

## Lokale Dokumentation

| Datei | Beschreibung |
|-------|--------------|
| [GPS-AGNSS.md](../GPS-AGNSS.md) | AGNSS Implementation Guide für LC29H |
| [GPS-NTRIP-PROXY.md](../GPS-NTRIP-PROXY.md) | NTRIP Base Station Setup |
| [LESSONS-LEARNED.md](../LESSONS-LEARNED.md) | GPS/AGNSS Troubleshooting |

---

**Hinweis:** Diese Ressourcen wurden im Rahmen des AGNSS-Versuchs (2026-02-04) gesammelt. Obwohl AGNSS für unsere 24/7 Base Station nicht implementiert wurde, dient die Dokumentation als Referenz für zukünftige GPS-Projekte.
