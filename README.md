# Raspberry Pi ADS-B/OGN/Drone Receiver Documentation

**System:** Raspberry Pi 4 Model B | Debian 12 (bookworm)  
**Location:** 49.86625°N, 10.83948°E | 283m ASL

## 📚 Documentation Files

| File | Description |
|------|-------------|
| [FEEDS.md](FEEDS.md) | ADS-B Feeder configuration (16 services) |
| [MONITORING.md](MONITORING.md) | System monitoring & automation |
| [OGN-SETUP.md](OGN-SETUP.md) | OGN/FLARM receiver setup |
| [DRAGONSYNC.md](DRAGONSYNC.md) | Drone detection via Remote ID |
| [HOME-ASSISTANT.md](HOME-ASSISTANT.md) | Home Assistant integration |
| [CLAUDE-TEMPLATE.md](CLAUDE-TEMPLATE.md) | Template for AI-assisted maintenance |

## 🛩️ Active Services

### ADS-B Feeders (16 Services)
- **Primary Decoder:** readsb + tar1090 + graphs1090
- **MLAT Hub:** Dedicated deduplication (4 clients → readsb)
- **Feeders:** piaware, fr24feed, adsbexchange, adsb.fi, opensky, theairtraffic, rbfeeder, airplanes.live, pfclient

### OGN/FLARM (Prepared)
- rtl_ogn + ogn2dump1090 (ready for hardware)

### Drone Detection (Operational)
- DragonSync + AtomS3 ESP32 receiver
- BLE + WiFi Remote ID detection
- Home Assistant integration via MQTT

## 🔧 System Maintenance

- **Daily:** Automated security checks & updates (07:00)
- **Monitoring:** feeder-watchdog (5min), wartungs-watchdog (10min)
- **Backups:** Weekly config backup, SD health checks
- **Security:** AppArmor profiles, lynis, rkhunter, debsecan

## 📊 Key Stats

- **Services:** 17+ systemd services
- **Feeds:** 16 ADS-B feeders active
- **MLAT:** 4 MLAT clients → centralized hub
- **Security:** Hardened kernel, AppArmor, systemd sandboxing
- **Automation:** Claude AI-assisted maintenance via Telegram

## 🔗 Related Repositories

- [ha-opendroneid](https://github.com/jleinenbach/ha-opendroneid) - Home Assistant Drone Detection Integration

---

*This documentation is maintained automatically and manually for a Raspberry Pi receiver station.*
