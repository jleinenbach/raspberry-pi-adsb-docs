# OGN Hardware-Integration - Runbook

**Datum:** 2026-01-29
**Hardware:** RTL-SDR Blog V4 + Bingfu 3dBi Antenne (868 MHz)
**Ziel:** FLARM/OGN-Empfang aktivieren + Upload zu glidernet.org

---

## ✅ Vorbereitung (bereits komplett)

- ✅ rtl_ogn v0.3.2 installiert (`/opt/rtlsdr-ogn/`)
- ✅ ogn2dump1090 installiert (`/opt/ogn2dump1090/`)
- ✅ SteGau.conf konfiguriert (Device=1, 868.8 MHz, 2.0 MHz Samplerate)
- ✅ readsb Port 30008 (SBS-Jaero-In) konfiguriert
- ✅ tar1090 OGN-Label="OGN" konfiguriert
- ✅ OGN-DDB 34.171 Einträge (wöchentliches Update)
- ✅ Services erstellt: rtl-ogn.service, ogn2dump1090.service
- ✅ ognrange V2 vorbereitet (`/home/pi/ognrange/`)

---

## Phase 1: Hardware-Aufbau (15 Minuten)

### Schritt 1.1: Antenne vorbereiten
```bash
# Komponenten:
# - Bingfu 3dBi Magnetfuß-Antenne
# - 90mm Metallplatte (Groundplane)
# - 3m RG174-Kabel
```

**Aufbau:**
1. Metallplatte (90mm) auf Fensterbank legen
2. Magnetfuß der Antenne auf Platte platzieren
3. Antenne vertikal ausrichten
4. **Mindestens 30cm horizontal** von ADS-B-Antenne entfernt

**Warum Metallplatte?**
- 868 MHz → λ/4 = ~8.6 cm
- 90mm = ideale Groundplane-Größe
- Verbessert Empfang erheblich

### Schritt 1.2: Kabel verlegen
- 3m RG174 vom Fenster zum Raspberry Pi
- Kabel nicht knicken oder quetschen
- Abstand zu Stromkabeln halten (Interferenz)

### Schritt 1.3: RTL-SDR V4 NOCH NICHT anstecken!
⚠️ **Wichtig:** Erst Software prüfen, dann Hardware anstecken

---

## Phase 2: Pre-Flight Checks (5 Minuten)

### Schritt 2.1: Aktuelle USB-Situation prüfen
```bash
lsusb | grep RTL
# Sollte NUR FlightAware Pro Stick Plus zeigen
```

**Erwartetes Ergebnis:**
```
Bus 001 Device 004: ID 0bda:2838 Realtek Semiconductor Corp. RTL2838 DVB-T
```

### Schritt 2.2: rtl-ogn Konfiguration verifizieren
```bash
grep -E "Device|CenterFreq|SampleRate|Gain" /opt/rtlsdr-ogn/SteGau.conf
```

**Erwartetes Ergebnis:**
```
  Device      = 1;           # RTL-SDR device index (0=ADS-B, 1=OGN)
  SampleRate  = 2.0;         # [MHz] 2MHz for FLARM+OGN+FANET+PilotAware
  CenterFreq = 868.8;        # [MHz] captures FLARM/OGN/FANET/PilotAware
  Gain       = 40.0;         # [dB] start conservative, adjust later
```

### Schritt 2.3: readsb OGN-Port prüfen
```bash
grep "30008" /etc/default/readsb
```

**Erwartetes Ergebnis:**
```
--net-sbs-jaero-in-port 30008
```

### Schritt 2.4: Service-Status vor Hardware
```bash
systemctl is-enabled rtl-ogn ogn2dump1090
# Beide: disabled (OK, werden gleich enabled)

systemctl status readsb | head -3
# Sollte aktiv sein
```

---

## Phase 3: Hardware anschließen (2 Minuten)

### Schritt 3.1: RTL-SDR V4 einstecken
1. RTL-SDR V4 mit Antennenkabel verbinden
2. V4 in USB-Port einstecken (idealerweise USB 2)
3. 10 Sekunden warten

### Schritt 3.2: Device-Erkennung prüfen
```bash
lsusb | grep RTL
# Sollte ZWEI Geräte zeigen
```

**Erwartetes Ergebnis:**
```
Bus 001 Device 004: ID 0bda:2838 Realtek Semiconductor Corp. RTL2838 DVB-T  # ADS-B
Bus 001 Device 005: ID 0bda:2838 Realtek Semiconductor Corp. RTL2838 DVB-T  # OGN (NEU)
```

### Schritt 3.3: Device-Index ermitteln
```bash
rtl_test -t
```

**Erwartetes Ergebnis:**
```
Found 2 device(s):
  0:  Realtek, RTL2838UHIDIR, SN: 00001090  ← FlightAware Pro Stick Plus (ADS-B)
  1:  Realtek, RTL2838UHIDIR, SN: 00000868  ← RTL-SDR V4 (OGN)
```

✅ **Device 1 = OGN** (wie in SteGau.conf konfiguriert)

⚠️ **Falls Device-Reihenfolge anders:**
```bash
# SteGau.conf anpassen:
sudo nano /opt/rtlsdr-ogn/SteGau.conf
# Device = X;  (richtigen Index eintragen)
```

---

## Phase 4: Services aktivieren (5 Minuten)

### Schritt 4.1: rtl-ogn starten
```bash
sudo systemctl enable rtl-ogn
sudo systemctl start rtl-ogn
```

### Schritt 4.2: Logs prüfen (erste 60 Sekunden kritisch)
```bash
journalctl -u rtl-ogn -f
```

**Erwartete Log-Meldungen:**
```
rtl-ogn[xxxxx]: Starting OGN receiver...
rtl-ogn[xxxxx]: Device #1: RTL-SDR V4
rtl-ogn[xxxxx]: Frequency: 868.8 MHz
rtl-ogn[xxxxx]: Gain: 40.0 dB
rtl-ogn[xxxxx]: Connecting to APRS: aprs.glidernet.org:14580
rtl-ogn[xxxxx]: APRS login successful
rtl-ogn[xxxxx]: [timestamp] OGN>APRS: Position beacon sent
```

**Erfolg-Indikator:**
- "APRS login successful" erscheint
- Keine Fehler wie "Device not found" oder "Permission denied"

**Bei Fehlern:**
| Fehler | Lösung |
|--------|--------|
| "Device not found" | Device-Index in SteGau.conf prüfen |
| "Permission denied" | `sudo usermod -aG plugdev pi && reboot` |
| "Already in use" | readsb nutzt falsches Device: `/etc/default/readsb` prüfen |

### Schritt 4.3: ogn2dump1090 starten
```bash
sudo systemctl enable ogn2dump1090
sudo systemctl start ogn2dump1090
```

### Schritt 4.4: ogn2dump1090 Logs prüfen
```bash
journalctl -u ogn2dump1090 -f
```

**Erwartete Log-Meldungen:**
```
ogn2dump1090[xxxxx]: Connecting to APRS: aprs.glidernet.org
ogn2dump1090[xxxxx]: Connecting to readsb: 127.0.0.1:30008
ogn2dump1090[xxxxx]: Filter: r/49.866/10.839/100  (100km Radius)
ogn2dump1090[xxxxx]: [timestamp] APRS: FLR123456>OGFLR (Position received)
ogn2dump1090[xxxxx]: [timestamp] SBS: Sent to readsb:30008
```

**Erfolg-Indikator:**
- APRS-Pakete werden empfangen
- "Sent to readsb:30008" erscheint
- Keine "Connection refused"

---

## Phase 5: Verifizierung (10 Minuten)

### Schritt 5.1: tar1090 Karte prüfen
```bash
# Browser öffnen: http://pi:8080 oder http://192.168.1.x:8080
```

**Was zu erwarten:**
- Bei **lokalem OGN-Empfang:** Tracks mit "OGN"-Label (sofort sichtbar, falls Segelflugzeuge in der Luft)
- Bei **Online-OGN via APRS:** Tracks anderer OGN-Stationen im 100km-Radius (immer verfügbar)

**Unterscheidung:**
| Quelle | Label | Farbe | Präfix |
|--------|-------|-------|--------|
| Lokaler 868 MHz Empfang | "OGN" | Violett | `~FLR...` |
| Online APRS (andere Stationen) | "OGN" | Violett | `~OGN...` |

**Falls KEINE OGN-Tracks sichtbar:**
```bash
# 1. Prüfe ob überhaupt Segelflugzeuge fliegen:
#    https://live.glidernet.org (Bamberg-Bereich ansehen)

# 2. Prüfe readsb Verbindungen:
ss -tn | grep 30008
# Sollte ogn2dump1090-Verbindung zeigen

# 3. Prüfe readsb Logs:
journalctl -u readsb --since "5 minutes ago" | grep -i "jaero\|ogn"
```

### Schritt 5.2: live.glidernet.org Registrierung
```bash
# Nach ~5 Minuten sollte Station "SteGau" erscheinen:
# https://live.glidernet.org/
# 1. Receivers Layer aktivieren (oben rechts)
# 2. Auf Bamberg-Region zoomen
# 3. Nach "SteGau" suchen
```

**Erwartetes Ergebnis:**
- Station "SteGau" auf Karte sichtbar
- Position: 49.86625, 10.83948
- Status: Online (grün)
- Coverage: Noch keine Daten (erst nach 24h)

**Falls Station NICHT erscheint:**
```bash
# APRS-Beacon prüfen:
journalctl -u rtl-ogn --since "10 minutes ago" | grep -i "position beacon\|aprs"

# APRS-Callsign verifizieren:
grep "Call =" /opt/rtlsdr-ogn/SteGau.conf
# Sollte: Call = "SteGau";
```

### Schritt 5.3: Protokoll-Statistiken
```bash
# Welche Protokolle wurden in letzter Stunde empfangen?
journalctl -u rtl-ogn --since "1 hour ago" | grep -oE "FNT|PAW|OGN|FLR|ICA" | sort | uniq -c
```

**Mögliche Ergebnisse:**
```
  23 FLR    # FLARM (Segelflugzeuge)
   5 OGN    # OGN-Tracker
   2 FNT    # FANET (Gleitschirme)
   0 PAW    # PilotAware (UK, hier unwahrscheinlich)
```

---

## Phase 6: Integration ins Monitoring (15 Minuten)

### Schritt 6.1: Service-Listen erweitern (3 Dateien!)

**❗ WICHTIG:** Alle drei Dateien synchron halten!

#### 1. feeder-watchdog
```bash
sudo sed -i 's/FEEDERS="/FEEDERS="rtl-ogn ogn2dump1090 /' /usr/local/sbin/feeder-watchdog

# Verifizieren:
grep "^FEEDERS=" /usr/local/sbin/feeder-watchdog
```

#### 2. telegram-bot-daemon
```bash
# OGN-Services zu passender Kategorie hinzufügen:
sudo nano /usr/local/sbin/telegram-bot-daemon

# In Zeile ~272: OGN_SERVICES hinzufügen:
# local OGN_SERVICES="rtl-ogn ogn2dump1090"

# In /status Ausgabe ergänzen (Zeile ~360):
# ${ogn_icon} OGN Services (${ogn_ok}/${ogn_total})
```

#### 3. claude-respond-to-reports
```bash
sudo nano /usr/local/sbin/claude-respond-to-reports

# In Zeile ~100: OGN_SERVICES hinzufügen:
# OGN_SERVICES="rtl-ogn ogn2dump1090"

# Service-Check-Loop erweitern:
# for svc in $OGN_SERVICES; do
#     FEEDER_STATUS="$FEEDER_STATUS  $svc: $(systemctl is-active $svc 2>/dev/null)\n"
# done
```

### Schritt 6.2: Telegram-Bot /stats erweitern
```bash
sudo nano /usr/local/sbin/telegram-bot-daemon

# In handle_stats() Funktion ergänzen:
# OGN-Empfang der letzten Stunde
OGN_COUNT=$(journalctl -u rtl-ogn --since "1 hour ago" | grep -c "APRS\|Position" || echo 0)
```

### Schritt 6.3: Service-Zählung aktualisieren
**Neue Service-Zählung: 18 → 20 Services**

| Kategorie | Services | Anzahl |
|-----------|----------|--------|
| Core ADS-B | readsb | 1 |
| Upload Feeds | piaware, fr24feed, ... | 9 |
| MLAT Services | mlathub, adsbexchange-mlat, ... | 4 |
| Web Services | tar1090, graphs1090, adsbexchange-stats | 3 |
| DragonSync | dragonsync | 1 |
| **OGN Services (NEU)** | **rtl-ogn, ogn2dump1090** | **2** |
| **GESAMT** | | **20** |

```bash
# daily-summary Service-Liste erweitern:
sudo nano /usr/local/sbin/daily-summary
# SERVICE_TOTAL=18 → SERVICE_TOTAL=20
# for svc in ... rtl-ogn ogn2dump1090; do
```

---

## Phase 7: AppArmor-Profil (10 Minuten)

### Schritt 7.1: Profil erstellen
```bash
sudo tee /etc/apparmor.d/usr.local.sbin.rtl-ogn > /dev/null <<'EOF'
#include <tunables/global>

/usr/local/sbin/rtl-ogn-wrapper {
  #include <abstractions/base>

  # Binaries
  /usr/local/sbin/rtl-ogn-wrapper r,
  /opt/rtlsdr-ogn/rtlsdr-ogn ix,
  /opt/rtlsdr-ogn/ogn-rf ix,
  /opt/rtlsdr-ogn/ogn-decode ix,

  # Configuration
  /opt/rtlsdr-ogn/SteGau.conf r,

  # USB-Geräte (RTL-SDR)
  /dev/bus/usb/** rw,
  /sys/bus/usb/devices/ r,
  /sys/devices/** r,

  # Netzwerk (APRS)
  network inet stream,
  network inet dgram,

  # Logs
  /var/log/rtl-ogn.log w,

  # Temp
  /tmp/** rw,
}
EOF
```

### Schritt 7.2: Profil aktivieren
```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.local.sbin.rtl-ogn
sudo aa-enforce /usr/local/sbin/rtl-ogn-wrapper

# Service neu starten mit AppArmor
sudo systemctl restart rtl-ogn

# Prüfen auf DENIED-Meldungen:
sudo dmesg | grep -i "apparmor.*DENIED.*rtl-ogn"
```

**Bei DENIED-Meldungen:**
```bash
# Profil in Complain-Mode setzen (temporär):
sudo aa-complain /usr/local/sbin/rtl-ogn-wrapper

# Fehlende Pfade identifizieren und zu Profil hinzufügen
```

---

## Phase 8: Dokumentation aktualisieren (5 Minuten)

### Schritt 8.1: CLAUDE.md
```bash
nano /home/pi/CLAUDE.md

# Unter "Implemented Changes" → "Monitoring & Automation" ergänzen:
# - OGN/FLARM Empfänger aktiviert (rtl-ogn, ogn2dump1090) (2026-01-29)
# - ognrange V2 vorbereitet (Coverage-Analyse) (2026-01-29)

# Service-Zählung aktualisieren:
# ### ADS-B Services (18 Services nach Kategorie) → (20 Services)
# ### OGN Services (2) (NEU)
# rtl-ogn, ogn2dump1090
```

### Schritt 8.2: OGN-SETUP.md
```bash
nano /home/pi/docs/OGN-SETUP.md

# Status-Zeile ändern:
# *Hardware bestellt 2026-01-21 - Software vorbereitet, wartet auf Hardware*
# ↓
# ✅ **AKTIV seit 2026-01-29** - Hardware installiert, Upload zu glidernet.org läuft

# Alle TODO-Checkboxen abhaken:
# - [x] Watchdog erweitern
# - [x] Wartungsskript erweitern
# - [x] AppArmor-Profil erstellen
# - [x] Telegram-Bot /stats erweitern
# - [x] CLAUDE.md aktualisieren
```

### Schritt 8.3: GitHub-Commit
```bash
cd /home/pi/docs
git add OGN-SETUP.md OGN-HARDWARE-INTEGRATION.md
git commit -m "OGN/FLARM Empfänger aktiviert (RTL-SDR V4)

Hardware-Integration abgeschlossen:
- rtl-ogn + ogn2dump1090 Services laufen
- Upload zu glidernet.org aktiv
- Integration in tar1090 (OGN-Label)
- ognrange V2 vorbereitet
- Service-Zählung: 18 → 20

Station SteGau registriert auf live.glidernet.org

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git push
```

---

## Phase 9: Finale Verifikation (5 Minuten)

### Checkliste
- [ ] `systemctl status rtl-ogn` → aktiv
- [ ] `systemctl status ogn2dump1090` → aktiv
- [ ] tar1090: OGN-Tracks sichtbar (falls Segelflugzeuge fliegen)
- [ ] live.glidernet.org: Station "SteGau" online
- [ ] feeder-watchdog überwacht OGN-Services
- [ ] Telegram /status zeigt OGN-Services
- [ ] AppArmor: Keine DENIED-Meldungen
- [ ] CLAUDE.md aktualisiert
- [ ] docs auf GitHub gepusht

---

## Troubleshooting

### Problem: "Device not found"
**Ursache:** Falscher Device-Index in SteGau.conf

**Lösung:**
```bash
rtl_test -t  # Index ermitteln
sudo nano /opt/rtlsdr-ogn/SteGau.conf  # Device = X anpassen
sudo systemctl restart rtl-ogn
```

### Problem: "Already in use"
**Ursache:** readsb nutzt beide RTL-SDR-Sticks

**Lösung:**
```bash
# readsb konfigurieren um nur Device 0 zu nutzen:
sudo nano /etc/default/readsb
# --device 0 hinzufügen

sudo systemctl restart readsb rtl-ogn
```

### Problem: Keine APRS-Verbindung
**Ursache:** Firewall oder DNS-Problem

**Lösung:**
```bash
# DNS testen:
nslookup aprs.glidernet.org

# Port testen:
nc -zv aprs.glidernet.org 14580

# Firewall-Regel (falls nötig):
sudo iptables -A OUTPUT -p tcp --dport 14580 -j ACCEPT
```

### Problem: OGN-Tracks nicht in tar1090
**Ursache:** readsb empfängt keine SBS-Daten von ogn2dump1090

**Lösung:**
```bash
# Verbindung prüfen:
ss -tn | grep 30008

# Manuell testen:
nc 127.0.0.1 30008
# Sollte SBS-Meldungen ausgeben (wenn ogn2dump1090 Daten hat)

# readsb Logs:
journalctl -u readsb | grep -i jaero
```

---

## Nächste Schritte (nach 1 Woche)

### 1. ognrange V2 finalisieren
```bash
# Mapbox Token besorgen und eintragen
# Node.js + Yarn installieren
# yarn install && yarn next build
# Services starten
```

### 2. Coverage-Analyse
- http://pi:3000 aufrufen
- Reichweiten-Karte ansehen
- Coverage-Gaps identifizieren
- Ggf. Antennen-Position optimieren

### 3. Gain-Optimierung
```bash
# Nach 1 Woche Betrieb: Gain anpassen
sudo nano /opt/rtlsdr-ogn/SteGau.conf
# Gain = 40.0 → 45.0 oder 50.0 (schrittweise erhöhen)
# Ziel: Maximale Reichweite ohne Überlastung

sudo systemctl restart rtl-ogn
```

### 4. Statistik-Monitoring
```bash
# Wöchentlicher Check:
# - Wie viele Flugzeuge empfangen?
# - Welche Protokolle dominant? (FLARM, OGN, FANET)
# - Maximale Reichweite?

journalctl -u rtl-ogn --since "1 week ago" | grep -E "FLR|OGN|FNT" | wc -l
```

---

## Erwartete Reichweite

| Flugzeug-Typ | Höhe | Erwartete Reichweite |
|--------------|------|---------------------|
| Segelflugzeug | 1000m AGL | ~50-80 km |
| Segelflugzeug | 2000m AGL | ~100-120 km |
| Gleitschirm | 500m AGL | ~20-40 km |
| Motorflugzeug | 3000m AGL | ~150+ km |

**Faktoren:**
- 868 MHz = niedrigere Reichweite als ADS-B (1090 MHz)
- 3dBi Antenne = breiter Empfangswinkel (gut für lokale Flugzeuge)
- Fensterplatzierung = Sichtlinie wichtig (weniger Dämpfung)
- Groundplane = essenziell für 868 MHz

---

## Zusammenfassung

Nach erfolgreicher Integration:
- ✅ OGN-Empfang auf 868 MHz aktiv
- ✅ Upload zu glidernet.org läuft automatisch
- ✅ Visualisierung in tar1090
- ✅ Monitoring via Watchdog + Telegram
- ✅ Station "SteGau" auf live.glidernet.org sichtbar
- ⏳ ognrange V2 wartet auf Mapbox Token + Node.js-Installation
- ⏳ Coverage-Analyse nach 1 Woche verfügbar

**Neue Service-Zählung: 20 Services**
(18 ADS-B/MLAT/Web/DragonSync + 2 OGN)
