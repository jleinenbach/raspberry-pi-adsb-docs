# Raspberry Pi ADS-B/OGN/Drone Receiver Documentation

**System:** Raspberry Pi 4 Model B | Debian 12 (bookworm)  
**Location:** 49.86625°N, 10.83948°E | 283m ASL

## 📚 Documentation Files

| File | Description |
|------|-------------|
| [FEEDS.md](FEEDS.md) | ADS-B Feeder configuration (16 services) |
| [MONITORING.md](MONITORING.md) | System monitoring & automation + **Hardware diagnostics** |
| [VOLTAGE-MONITORING.md](VOLTAGE-MONITORING.md) | **USB voltage monitoring implementation & testing** |
| [OGN-SETUP.md](OGN-SETUP.md) | OGN/FLARM receiver setup |
| [OGN-HARDWARE-INTEGRATION.md](OGN-HARDWARE-INTEGRATION.md) | OGN Hardware integration runbook (9 phases) |
| [DRAGONSYNC.md](DRAGONSYNC.md) | Drone detection via Remote ID |
| [HOME-ASSISTANT.md](HOME-ASSISTANT.md) | Home Assistant integration |
| [HARDWARE-DIAGNOSE-2026-01-29.md](HARDWARE-DIAGNOSE-2026-01-29.md) | RTL-SDR & Power supply diagnostics report |
| [ATOMS3-TROUBLESHOOTING-2026-01-30.md](ATOMS3-TROUBLESHOOTING-2026-01-30.md) | **AtomS3 USB & Firmware repair guide** |
| [CLAUDE-TEMPLATE.md](CLAUDE-TEMPLATE.md) | Template for AI-assisted maintenance |
| [scripts/](scripts/) | Monitoring & automation scripts + systemd units |
| [voltage-monitoring-examples.sh](voltage-monitoring-examples.sh) | Example code for USB voltage monitoring |

## 🛩️ Active Services (21 Total)

### ADS-B Feeders (17 Services)
- **Primary Decoder:** readsb
- **Upload Feeds (9):** piaware, fr24feed, adsbexchange, adsb.fi, opensky, theairtraffic, rbfeeder, airplanes.live, pfclient
- **MLAT Services (3):** adsbexchange-mlat, adsbfi-mlat, airplanes-mlat (direkt zu readsb:30104)
- **Web Services (3):** tar1090, graphs1090, adsbexchange-stats

### OGN/FLARM (3 Services - ✅ Active)
- **ogn-rf-procserv** - RF receiver (868 MHz, R828D tuner)
- **ogn-decode-procserv** - APRS decoder → glidernet.org
- **ogn2dump1090** - SBS feed to tar1090
- **Station:** SteGau (live on http://live.glidernet.org/)

### Drone Detection (1 Service - ✅ Operational)
- **DragonSync** + AtomS3 ESP32 receiver
- BLE + WiFi Remote ID detection
- Home Assistant integration via MQTT

## 🔧 System Maintenance

- **Daily:** Automated security checks & updates (07:00)
- **Monitoring:** feeder-watchdog (5min), wartungs-watchdog (10min)
- **Backups:** Weekly config backup, SD health checks
- **Security:** AppArmor profiles, lynis, rkhunter, debsecan

## 📊 Key Stats

- **Services:** 20 systemd services (17 ADS-B, 3 OGN, 1 DragonSync)
- **Upload Feeds:** 9 ADS-B feeders + 1 OGN (glidernet.org)
- **MLAT:** 3 MLAT clients → direct to readsb:30104
- **Hardware:** 2× RTL-SDR (1090 MHz ADS-B + 868 MHz OGN V4), ESP32 AtomS3 (BLE Remote ID)
- **Security:** Hardened kernel, AppArmor (9 profiles), systemd sandboxing, voltage monitoring
- **Automation:** Claude AI-assisted maintenance via Telegram
- **Monitoring:** RTL-SDR driver validation, USB power supply monitoring, 5min watchdog

## 🔗 Related Repositories

- [ha-opendroneid](https://github.com/jleinenbach/ha-opendroneid) - Home Assistant Drone Detection Integration

---

*This documentation is maintained automatically and manually for a Raspberry Pi receiver station.*
