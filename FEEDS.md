# ADS-B Feed-Konfiguration & Credentials

> **Hinweis:** Dieses Dokument behandelt nur **ADS-B (1090 MHz)** Upload Feeds.
> OGN/FLARM (868 MHz) und Remote ID (BLE) Daten bleiben lokal - siehe `OGN-SETUP.md` und `DRAGONSYNC.md`.

## Standort (Antennenposition)
- **Breitengrad:** 49.86625
- **Längengrad:** 10.83948
- **Höhe ü.NN:** 283 m / 928 ft
- **Betreiber:** jens.leinenbach@gmail.com

---

## Feed-Dienste

### FlightAware (piaware)
- **Config:** automatisch via piaware-config
- **MLAT:** Aktiv (Rückkanal → readsb:30104)

### Flightradar24 (fr24feed)
- **Config:** /etc/fr24feed.ini

### ADS-B Exchange
- **Config:** /etc/default/adsbexchange
- **MLAT:** Aktiv (Rückkanal → readsb:30104)

### adsb.fi
- **Config:** /etc/default/adsbfi
- **MLAT:** Aktiv (Rückkanal → readsb:30104)

### OpenSky Network
- **Username:** jens.leinenbach@gmail.com
- **Serial:** -1408045137
- **Config:** /etc/openskyd/conf.d/10-debconf.conf

### TheAirTraffic
- **UUID:** 1aa453a6-284b-4a0a-9d26-73986acbd05a
- **Username:** jens76-stegaurach
- **Config:** /etc/default/theairtraffic
- **Server:** feed.theairtraffic.com:30004
- **MLAT:** Netzwerkweit offline (Server `feed.theairtraffic.com:31090` verweigert Verbindung)
- **MLAT-Client:** ✅ Gefixt (2026-02-15, `modes_reader.c` Python 3.11 Patch)
- **Statistik:** https://theairtraffic.com/myip
- **Update:** `cd /usr/local/share/theairtraffic/git && sudo bash update.sh`
- **Letztes Update:** 2026-02-15 (Feed-Binary unverändert, MLAT-Client neu gebaut)

### airplanes.live
- **UUID:** eeb47104-3dff-48a5-9ce0-11c208bd41d9
- **Username:** jens76-stegaurach
- **Config:** /etc/default/airplanes
- **Server:** feed.airplanes.live:30004 (Feed), :31090 (MLAT)
- **MLAT:** Aktiv (60+ Peers, Rückkanal → readsb:30104)
- **Statistik:** https://airplanes.live/myfeed/
- **Update:** `sudo bash /usr/local/share/airplanes/git/update.sh`

### RadarBox (AirNav)
- **Sharing Key:** 159c2ba57f9f0ea6622963eecbf248d1
- **Serial:** EXTRPI706711
- **Config:** /etc/rbfeeder.ini
- **MLAT:** Aktiv (Server-seitig)
- **Statistik:** https://www.airnavradar.com/coverage
- **Update:** `sudo apt update && sudo apt upgrade rbfeeder`

### Plane Finder
- **Sharecode:** 696e4040117e9
- **Config:** /etc/pfclient-config.json
- **MLAT:** Aktiv (Server-seitig)
- **Statistik:** https://planefinder.net/sharing/receiver.html
- **Update:** Download von client.planefinder.net + `dpkg -i`

---

## MLAT-Architektur (direkt ohne Hub)
**Status:** ✅ Option 1 aktiv seit 2026-02-12

### Was ist MLAT?
Multilateration berechnet Positionen von Flugzeugen **ohne ADS-B** (nur Mode-S Transponder).
Die Berechnung erfolgt auf den **MLAT-Servern** durch Vergleich der Empfangszeiten (TDOA)
von mehreren Empfängern - **nicht lokal**.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  DEIN EMPFÄNGER              MLAT-SERVER              ANDERE EMPFÄNGER  │
│       │                          │                          │           │
│  Mode-S Signal              Berechnet Position         Mode-S Signal    │
│  + Zeitstempel ────────────────►├◄──────────────────── + Zeitstempel   │
│       │                    (TDOA-Triangulation)             │           │
│       │                          │                          │           │
│       ◄──────────────────────────┘                          │           │
│  MLAT-Ergebnis                                               │           │
│  (berechnete Position)                                       │           │
└─────────────────────────────────────────────────────────────────────────┘
```

### Lokale Architektur (2026-02-12)
```
  ┌─────────────────────────────────────────────────────────────┐
  │  MLAT-Server (extern)                                       │
  │    adsbexchange.com ─┐                                      │
  │    adsb.fi ──────────┤  berechnen Positionen                │
  │    airplanes.live ───┤  senden Ergebnisse zurück            │
  │    FlightAware ──────┘                                      │
  └──────────────────────────────────┬──────────────────────────┘
                                     │
                                     ▼
  ┌─────────────────────────────────────────────────────────────┐
  │  LOKAL                                                      │
  │                                                             │
  │  adsbexchange-mlat ──┐                                      │
  │  adsbfi-mlat ────────┼──► readsb:30104 (remote=1 ✓)        │
  │  airplanes-mlat ─────┤                                      │
  │  piaware-mlat ───────┘                                      │
  │                                    │                        │
  │                                    ▼                        │
  │                               tar1090                       │
  │                          (zeigt MLAT-Positionen)            │
  │                                                             │
  │  RadarBox ────► Nur auf radarbox.com (kein Rückkanal)      │
  │  PlaneFinder ─► Nur auf planefinder.net (kein Rückkanal)   │
  └─────────────────────────────────────────────────────────────┘
```

**Warum direkt ohne mlathub?**
- ✅ `remote=1` garantiert (INBOUND-Verbindungen zu readsb)
- ✅ MAGIC_MLAT_TIMESTAMP bleibt erhalten → korrekte MLAT-Erkennung
- ✅ Einfachere Architektur, weniger Fehlerquellen
- ✅ readsb dedupliziert selbst (nimmt neueste Position per Zeitstempel)
- ℹ️ Theoretisch 4x gleiche Position möglich (in der Praxis selten, da Server meist unterschiedliche Flugzeuge tracken)

### Was verbessert MLAT-Genauigkeit wirklich?
| Faktor | Einfluss | Lokal umsetzbar? |
|--------|----------|------------------|
| **Mehr Empfänger** in der Region | ⬆️⬆️⬆️ Mehr Triangulationspunkte | Nein (Community) |
| **Geografische Verteilung** der Empfänger | ⬆️⬆️ Bessere Winkel | Nein |
| **GPS-Zeitsync mit PPS** | ⬆️⬆️ Präzisere Zeitstempel (<1µs) | Ja (~50€ GPS-Modul) |
| **Besserer Empfang** (Gain/Antenne) | ⬆️ Mehr Signale erkannt | Bereits optimiert |
| **Eigener MLAT-Server** | ⬆️ Volle Kontrolle | Sehr komplex |

### Prüfbefehle
```bash
# MLAT-Dienste Status
systemctl is-active adsbexchange-mlat adsbfi-mlat airplanes-mlat piaware

# MLAT-Verbindungen zu readsb (sollte 4 zeigen)
ss -tn | grep ':30104.*ESTAB' | wc -l

# MLAT-Daten in aircraft.json
python3 -c "import json; data=json.load(open('/run/readsb/aircraft.json')); mlat=[p for p in data['aircraft'] if p.get('mlat')]; print(f'MLAT: {len(mlat)} Flugzeuge')"

# MLAT-Client Aktivität
sudo journalctl -u adsbexchange-mlat --since "5 minutes ago" | grep "Results:"
```

---

## Software-Quellen

### Haupt-Decoder (wiedehopf)
| Software | Binary | Git-Repo |
|----------|--------|----------|
| readsb | `/usr/bin/readsb` | `/usr/local/share/adsb-wiki/readsb-install/git` |
| tar1090 | `/usr/local/share/tar1090/` | `/usr/local/share/tar1090/git` |
| graphs1090 | `/usr/share/graphs1090/` | `/usr/share/graphs1090/git` |

**Update:** `sudo bash /usr/local/share/tar1090/git/install.sh`

### Feed-Client Binaries
```
/usr/bin/readsb (wiedehopf) ← HAUPT-DECODER
    │
    │ Port 30005 (beast output)
    ↓
feed-adsbx, feed-adsbfi, feed-theairtraffic, feed-airplanes → Aggregatoren
rbfeeder, pfclient → Aggregatoren
```

| Feed-Client | Update |
|-------------|--------|
| ADSBexchange | `sudo bash /usr/local/share/adsbexchange/git/update.sh` |
| adsb.fi | `sudo bash /usr/local/share/adsbfi/git/update.sh` |
| TheAirTraffic | `sudo bash /usr/local/share/theairtraffic/git/update.sh` |
| airplanes.live | `sudo bash /usr/local/share/airplanes/git/update.sh` |
| RadarBox | `sudo apt update && sudo apt upgrade rbfeeder` |
| Plane Finder | Download .deb + `dpkg -i` |

**ACHTUNG:** Die `readsb_version` in Feed-Client-Verzeichnissen = Fork-Version, nicht `/usr/bin/readsb`!

---

## Antennen-Setup
| Eigenschaft | ADS-B (1090 MHz) |
|-------------|------------------|
| Antenne | 60 cm Collinear |
| Montage | Besenstiel (160 cm) in Sonnenschirmständer |
| Standort | Indoor, unter Dach |
| RTL-SDR | FlightAware Pro Stick Plus (Filter + LNA) |
