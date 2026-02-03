# WICHTIGE KORREKTUREN & ERGÄNZUNGEN (2026-02-03)

**⚠️ Die ursprüngliche Dokumentation enthielt Fehler, die über GPIO-Scans korrigiert wurden:**

## 🔴 KRITISCHE PIN-KORREKTUR

**PPS IST AUF GPIO 18, NICHT GPIO 4!**

| Pin | FALSCH (alte Doku) | KORREKT (via GPIO-Scan) |
|-----|------------|---------|
| PPS | GPIO 4 (Pin 7) | **GPIO 18 (Pin 12)** |
| Reset | GPIO 18 (Pin 12) | Unbekannt (nicht genutzt) |

**Diagnose-Methode:** GPIO-Scan mit Pull-Up auf allen Pins (2-27), wechselnde Pegel = Signal-Pin gefunden!

**Waveshare Schaltplan war irreführend!** Die physische Hardware sendet PPS auf GPIO 18.

## config.txt Korrektur

```bash
# FALSCH:
dtoverlay=pps-gpio,gpiopin=4

# KORREKT:
dtoverlay=pps-gpio,gpiopin=18,assert_falling_edge
```

**Essentiell:** `assert_falling_edge` für GPS PPS (100ms Puls auf fallender Flanke)

## chrony Konfiguration

```conf
# GPS sendet 100ms Puls → offset 0.102 kompensiert
refclock PPS /dev/pps0 refid PPS poll 4 prefer offset 0.102
```

**Ohne offset:** PPS zeigt +101ms und wird als "unusable" markiert!

## PPS braucht Pull-Up (Open-Drain!)

```bash
# In /boot/firmware/config.txt ODER via pinctrl:
sudo pinctrl set 18 pu
```

**Symptom ohne Pull-Up:** GPIO permanent auf LOW trotz blinkender PPS-LED am HAT!

---

## RTK Base Station Realität

**❌ KEIN echter "Hybrid Mode" möglich!**

Die LC29H **Base-Variante (BA)** unterdrückt im **Fixed Mode** (nach Survey-In) NMEA komplett:

| Modus | NMEA | RTCM | Grund |
|-------|------|------|-------|
| Rover | ✅ Ja | ❌ Nein | Navigation |
| Base (Survey-In) | ✅ Ja | ⚠️ Teilweise | Noch nicht Fixed |
| **Base (Fixed)** | **❌ Nein** | **✅ Ja** | **Firmware-Design!** |

**Warum?**
- Single UART (Waveshare HAT leitet nur UART 1 weiter)
- RTCM braucht 4,7 kbps Bandbreite
- NMEA würde RTCM-Buffer blockieren
- Base-Position ist statisch → NMEA unnötig

## Position trotzdem verfügbar!

**RTCM Message 1005** enthält Base Station Position (ECEF Koordinaten):

```bash
# Installiere pyrtcm:
pip3 install --user pyrtcm

# Extrahiere Position:
/usr/local/sbin/gps-tools/extract_base_position.py
```

**Output:** Lat/Lon/Alt in ECEF-Format (konvertierbar zu WGS84)

---

## NTRIP: Caster vs. Server

**Verwechslung kostet Stunden Debugging!**

```bash
# FALSCH (Server sendet AN Caster):
str2str -in serial://ttyAMA0:115200 -out ntrips://:password@:5000/BASE

# KORREKT (Caster empfängt Rover):
str2str -in serial://ttyAMA0:115200 -out ntripc://:5000/BASE
```

| Typ | Rolle | Verwendung |
|-----|-------|------------|
| `ntrips` | NTRIP Server | Sendet zu öffentlichem Caster |
| `ntripc` | NTRIP Caster | Eigener Server, Rover verbinden sich |

**Port 5000 nach außen öffnen** für Rover-Zugriff (Router/Firewall)!

---

## Stratum 1 Zeitserver

**✅ Trotz fehlendem NMEA funktioniert PPS perfekt!**

```bash
# PPS-Test:
sudo ppstest /dev/pps0

# Chrony Status:
chronyc sources -v
# Erwarte: #* PPS (Stern = aktiv)

chronyc tracking
# Erwarte: Reference ID: PPS, Stratum: 1
```

**Resultat:** Sub-Nanosekunden-Genauigkeit (±356ns, Offset +2.8ns)

---

## Zusammenfassung

**Funktioniert:**
- ✅ PPS auf GPIO 18 → Stratum 1 Zeitserver
- ✅ RTCM-Stream via NTRIP Caster (Port 5000)
- ✅ Position via RTCM Message 1005

**Funktioniert NICHT:**
- ❌ Echter Hybrid Mode (NMEA + RTCM gleichzeitig)
- ❌ gpsd (kann nur NMEA, kein reines RTCM)

**Lessons Learned:**
- GPIO-Scan rettet falsche Dokumentation
- Base-Firmware != Rover-Firmware
- Pull-Up essentiell bei Open-Drain
- NTRIP: Caster ≠ Server!

---

# Handbuch: Waveshare LC29H Hybrid RTK Master

**Raspberry Pi 4 Model B** | Waveshare LC29H(XX) GPS RTK HAT
**Ziel:** NTRIP-Server für externe Geräte (Rover) + Lokale GPS-Nutzung (gpsd)

---

## Teil 1: Hardware & Pin-Belegung

Das Modul wird auf die GPIO-Leiste gesteckt. Hier ist die physische Belegung für Debugging und Verständnis.

| Funktion | HAT Pin | RPi Physical Pin (Board) | RPi GPIO (BCM) | Beschreibung |
| --- | --- | --- | --- | --- |
| **VCC** | 5V | **Pin 2 oder 4** | - | Stromversorgung |
| **GND** | GND | **Pin 6, 9, etc.** | - | Masse |
| **TX** | RXD | **Pin 8** | **GPIO 14** | Pi sendet Befehle an GPS |
| **RX** | TXD | **Pin 10** | **GPIO 15** | GPS sendet Daten an Pi |
| **PPS** | PPS | **Pin 7** | **GPIO 4** | Zeitpuls (Sekundentakt) |
| **RST** | RST | **Pin 12** | **GPIO 18** | Hardware Reset (High-Aktiv) |

---

## Teil 2: Systemvorbereitung (OS Ebene)

Bevor wir konfigurieren, muss der Raspberry Pi vorbereitet werden.

**1. Serielle Konsole deaktivieren**
Das OS darf nicht in den GPS-Port "hineinreden".

* `sudo raspi-config`
* `Interface Options` → `Serial Port`
* Login Shell: **No**
* Serial Port Hardware: **Yes**
* Reboot: `sudo reboot`

**2. Software installieren**
Wir benötigen `gpsd` (für lokale Position) und `rtklib` (für den NTRIP Server).

```bash
sudo apt-get update
sudo apt-get install python3-serial gpsd gpsd-clients rtklib
```

---

## Teil 3: Die Konfiguration (Der "Master-Reset")

Dies ist der kritische Teil. Wir führen einen **Factory Reset** durch, erhöhen die Bandbreite auf **460800 Baud** (zwingend nötig für Hybrid-Betrieb) und aktivieren NMEA und RTCM in der korrekten Reihenfolge.

Erstellen Sie die Datei `setup_gps.py`:
`nano setup_gps.py`

Kopieren Sie diesen Code (er enthält alle notwendigen PAIR-Befehle und Checksummen):

```python
import serial
import time
import subprocess
import sys

# --- KONFIGURATION ---
PORT = '/dev/serial0'
TARGET_BAUD = 460800  # Hochgeschwindigkeit für Hybrid-Modus

# --- HILFSFUNKTIONEN ---
def set_linux_baud(baud):
    """Zwingt den Linux-Treiber auf die gewünschte Baudrate"""
    print(f"   [Linux] Setze Port auf {baud} Baud...")
    subprocess.run(["stty", "-F", PORT, str(baud), "raw", "-echo"])
    time.sleep(0.5)

def send_cmd(ser, cmd_str):
    """Berechnet Checksumme und sendet Befehl"""
    checksum = 0
    for char in cmd_str:
        checksum ^= ord(char)
    full_cmd = f"${cmd_str}*{checksum:02X}\r\n"
    print(f"   [Send] {full_cmd.strip()}")
    ser.write(full_cmd.encode())
    ser.flush()
    time.sleep(0.2)

# --- ABLAUF ---
print("=== SCHRITT 1: Vorbereitung ===")
# Stoppe störende Dienste
subprocess.run("sudo systemctl stop gpsd gpsd.socket rtkbase", shell=True)

print("\n=== SCHRITT 2: Factory Reset (Suche Modul) ===")
# Wir wissen nicht, auf welcher Baudrate das Modul gerade steht. Wir probieren alle.
found = False
for baud in [460800, 115200, 9600]:
    try:
        set_linux_baud(baud)
        with serial.Serial(PORT, baud, timeout=1) as ser:
            # Sende Reset-Befehl
            # PAIR001: Factory Reset (Löscht alles, setzt Baud auf 115200)
            send_cmd(ser, "PAIR001")
            print(f"   -> Reset gesendet bei {baud} Baud. Warte auf Reboot...")
            found = True
            break
    except:
        pass

if not found:
    print("FEHLER: Modul nicht gefunden. Ist es angeschlossen?")
    sys.exit(1)

time.sleep(2) # Wartezeit für Reboot des Chips

print("\n=== SCHRITT 3: Baudrate erhöhen ===")
# Nach Reset ist das Modul IMMER auf 115200
set_linux_baud(115200)
with serial.Serial(PORT, 115200, timeout=1) as ser:
    # PAIR002: Setze Baudrate
    send_cmd(ser, f"PAIR002,{TARGET_BAUD}")

print("   -> Warte auf Umschaltung...")
time.sleep(1)
set_linux_baud(TARGET_BAUD)

# Ab hier kommunizieren wir mit 460800 Baud
with serial.Serial(PORT, TARGET_BAUD, timeout=1) as ser:
    print("\n=== SCHRITT 4: NMEA aktivieren (Hybrid-Teil 1) ===")
    # WICHTIG: Erst NMEA aktivieren, bevor der RTCM-Datenstrom den Kanal flutet!
    # PAIR062: Output Rate setzen (0=GGA, 4=RMC, 2=GSA, Rate=1)
    send_cmd(ser, "PAIR062,0,1") # GGA (Position)
    send_cmd(ser, "PAIR062,4,1") # RMC (Zeit/Datum)
    send_cmd(ser, "PAIR062,2,1") # GSA (Satellitenstatus)

    print("\n=== SCHRITT 5: RTCM aktivieren (Hybrid-Teil 2) ===")
    # PAIR430: RTCM Message aktivieren
    # 1005: Station Info, 1074: GPS, 1084: GLONASS, 1094: Galileo, 1124: BeiDou
    msgs = ["1005", "1074", "1084", "1094", "1124", "1230"]
    for msg in msgs:
        send_cmd(ser, f"PAIR430,{msg},1")

    print("\n=== SCHRITT 6: Survey-In starten (Basis-Setup) ===")
    # PAIR432: Mode 1 (Survey-In), 600 Sekunden, 2 Meter Genauigkeit
    send_cmd(ser, "PAIR432,1,600,2000")

    print("\n=== SCHRITT 7: Speichern ===")
    # PAIR513: Save to Flash
    send_cmd(ser, "PAIR513")

print("\n✅ KONFIGURATION ABGESCHLOSSEN.")
print("Das Modul beginnt nun mit dem Survey-In (Dauer: ca. 10 Min).")
```

**Ausführen:**
`sudo python3 setup_gps.py`

---

## Teil 4: Dienste einrichten (Dauerbetrieb)

Jetzt, da die Hardware konfiguriert ist, richten wir die Software ein, die beim Booten startet.

### A. GPSD (Lokal)

Wir müssen `gpsd` zwingen, die **460800 Baud** zu nutzen und **nicht** schreibend auf das Gerät zuzugreifen (damit er unsere Konfiguration nicht zerstört).

1. `sudo nano /etc/default/gpsd`
2. Inhalt ersetzen:

```bash
START_DAEMON="true"
USBAUTO="false"
DEVICES="/dev/serial0"
# -n: Sofort verbinden
# -G: Netzwerkzugriff erlauben
# -b: Read-Only (WICHTIG!)
# -s 460800: Baudrate fixieren
GPSD_OPTIONS="-n -G -b -s 460800"
```

### B. NTRIP Server (Für SW Maps / Rover)

Wir erstellen einen Dienst, der die Daten von `gpsd` nimmt und als NTRIP-Stream bereitstellt.

1. `sudo nano /etc/systemd/system/ntripcaster.service`
2. Inhalt einfügen:

```ini
[Unit]
Description=NTRIP Caster Service (RTKLIB)
After=gpsd.service

[Service]
# Holt Daten von gpsd (localhost:2947) und stellt sie als NTRIP Server bereit
# Port: 5000
# Mountpoint: /BASE
# Passwort: pw123
ExecStart=/usr/bin/str2str -in ntrp://localhost:2947 -out ntripsvr://:pw123@:5000/BASE
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
```

3. Dienste aktivieren und starten:

```bash
sudo systemctl daemon-reload
sudo systemctl enable ntripcaster
sudo systemctl restart gpsd
sudo systemctl start ntripcaster
```

---

## Teil 5: Verbindung testen

### Test 1: Lokale NMEA-Daten

Geben Sie `gpsmon` ein.

* **Erwartung:** Sie sehen oben Koordinaten (Lat/Lon) und Zeit. Unten im Fenster sehen Sie Textzeilen mit `$GNGGA` und dazwischen `RTCM3`.

### Test 2: Rover Verbindung (SW Maps)

Nehmen Sie Ihr Android Handy.

1. **App:** SW Maps öffnen.
2. **Instrument:** NTRIP Connection.
3. **Einstellungen:**
* **IP:** `192.168.x.x` (IP des Pi)
* **Port:** `5000`
* **Mountpoint:** `BASE`
* **Password:** `pw123`

4. **Connect:**
* Der Balken muss grün werden ("Connected").
* GPS Status muss nach einiger Zeit auf **DGPS** oder **Float/Fix** springen (sobald der Survey-In des Pi abgeschlossen ist).

---

## Zusammenfassung der Befehls-Logik

Wann muss welcher Befehl gesendet werden?

1. **Reset (`PAIR001`):** Nur einmalig ganz am Anfang, wenn das System unsauber läuft. Setzt alles auf Werkseinstellung (115200 Baud, nur NMEA).
2. **Baudrate (`PAIR002`):** Sofort nach Reset. Zwingend **460800**, sonst "verschluckt" sich der NMEA-Stream am RTCM-Stream.
3. **NMEA Enable (`PAIR062`):** Zwingend **bevor** RTCM aktiviert wird.
4. **RTCM Enable (`PAIR430`):** Aktiviert den Basis-Modus.
5. **Save (`PAIR513`):** Speichert alles im Flash. Danach überlebt die Konfiguration auch einen Stromausfall.

---

## Troubleshooting

### Kein NMEA nach Konfiguration

**Problem:** `gpsmon` zeigt nur binäre RTCM-Daten, keine NMEA-Sentences

**Lösung:** NVRAM wurde nicht neu geladen. Optionen:

1. **PAIR650 + Pi Reboot:**
```bash
sudo systemctl stop gpsd gpsd.socket
sudo python3 << 'EOF'
import serial
import time

def nmea_checksum(sentence):
    data = sentence.strip('$').split('*')[0]
    checksum = 0
    for char in data:
        checksum ^= ord(char)
    return f"{checksum:02X}"

ser = serial.Serial('/dev/serial0', 460800, timeout=2)
cmd = "PAIR650"
full_cmd = f"${cmd}*{nmea_checksum(cmd)}\r\n"
ser.write(full_cmd.encode('ascii'))
time.sleep(1)
ser.close()
print("GPS entering Backup Mode...")
EOF
sudo reboot
```

2. **Hardware Reset Button:**
- Drücke RESET-Taster auf GPS HAT (2-3 Sekunden)
- Warte 120 Sekunden für GPS-Boot
- Prüfe mit `gpsmon`

3. **Vollständige Power-Cycle:**
- GPS HAT vom 40-Pin-Header abziehen
- 30 Sekunden warten
- HAT wieder aufstecken
- 120 Sekunden warten
- Prüfe mit `gpsmon`

### NTRIP Server verbindet nicht

**Problem:** SW Maps zeigt "Connection refused" oder "Timeout"

**Checks:**
```bash
# Ist ntripcaster aktiv?
systemctl status ntripcaster

# Lauscht Port 5000?
sudo ss -tlnp | grep 5000

# Firewall blockiert?
sudo iptables -L -n | grep 5000

# Test mit lokalem Client
echo -e "GET /BASE HTTP/1.0\r\n\r\n" | nc localhost 5000
```

### Survey-In dauert zu lange

**Problem:** Survey-In bleibt bei 0% stecken

**Ursachen:**
- Keine Satelliten-Sicht (Fenster, indoor)
- GPS-Antenne nicht angeschlossen
- Schlechtes Wetter (starke Bewölkung, Gewitter)

**Lösung:**
- GPS-Antenne auf Dach/Balkon mit freier Himmelssicht
- Warten auf besseres Wetter
- Survey-In Zeit erhöhen: `PAIR432,1,1200,2000` (20 Minuten statt 10)

### GPS komplett stumm (Notfall-Rettungsplan)

**Problem:** Das Gerät gibt keine Ausgabe mehr, egal was Sie tun.

**Ursache:** Meistens **nicht kaputt**, sondern in einem **"Baudraten-Niemandsland"** oder durch Software blockiert.

#### Schritt 1: Die "Blockierer" töten

Wenn `gpsd` oder Ihr NTRIP-Dienst noch im Hintergrund läuft, wirkt das Gerät für alle anderen Tools stumm.

```bash
sudo systemctl stop gpsd gpsd.socket rtkbase ntripcaster
sudo killall gpsd str2str
```

#### Schritt 2: Der Hardware-Reset (Der "Stromschlag")

Manchmal hängt sich der Mikrocontroller auf. Wir nutzen den Reset-Pin (GPIO 18) für einen harten Neustart.

Erstellen Sie `hard_reset.py`:

```python
import RPi.GPIO as GPIO
import time

# Pin Definition (Waveshare HAT Standard)
RESET_PIN = 18

GPIO.setmode(GPIO.BCM)
GPIO.setup(RESET_PIN, GPIO.OUT)

print("--- HARDWARE RESET ---")
print("1. Ziehe Reset auf HIGH (Reset aktiv)...")
GPIO.output(RESET_PIN, GPIO.HIGH)
time.sleep(0.5)

print("2. Ziehe Reset auf LOW (Normalbetrieb)...")
GPIO.output(RESET_PIN, GPIO.LOW)

print("3. Warte 2 Sekunden auf Boot...")
time.sleep(2)
print("Fertig. Das Gerät sollte jetzt neu gestartet sein.")

GPIO.cleanup()
```

**Ausführen:** `sudo python3 hard_reset.py`

#### Schritt 3: Der "Baudraten-Scanner" (Die Suche)

Das Hauptproblem: Wir wissen nicht, auf welcher Geschwindigkeit das Modul *jetzt gerade* sendet.

Erstellen Sie `find_baud.py`:

```python
import serial
import time
import subprocess
import sys

PORT = '/dev/serial0'
# Alle möglichen Geschwindigkeiten, die das Modul haben könnte
BAUD_RATES = [460800, 115200, 9600, 230400, 38400, 57600]

def set_linux_baud(baud):
    """Zwingt den Linux-Kernel auf die Baudrate"""
    subprocess.run(["stty", "-F", PORT, str(baud), "raw", "-echo"], check=False)

def try_communicating(baud):
    print(f"\nTeste Baudrate: {baud}...", end="", flush=True)
    set_linux_baud(baud)

    try:
        # Timeout sehr kurz setzen
        with serial.Serial(PORT, baud, timeout=0.5) as ser:
            # Wir senden einfach mal ein 'Enter', um den Buffer zu klären
            ser.write(b"\r\n")

            # Senden des Versions-Abfrage Befehls (Harmlos)
            # $PAIR003*3C ist "Get Software Version"
            msg = b"$PAIR003*3C\r\n"
            ser.write(msg)

            # Wir lauschen kurz
            start = time.time()
            buffer = b""
            while time.time() - start < 1.0:
                chunk = ser.read(ser.in_waiting or 1)
                if chunk:
                    buffer += chunk

            if len(buffer) > 0:
                print(f" ANTWORT ERHALTEN!")
                print(f"   Raw Data (Hex): {buffer[:20].hex()}")
                try:
                    print(f"   Text: {buffer.decode('ascii', errors='ignore').strip()}")
                except:
                    pass
                return True
            else:
                print(" Stille.")
                return False
    except Exception as e:
        print(f" Fehler: {e}")
        return False

print("=== SUCHE NACH VERSCHOLLENEM GPS MODUL ===")
found_baud = None

for baud in BAUD_RATES:
    if try_communicating(baud):
        found_baud = baud
        break

if found_baud:
    print(f"\n✅ TREFFER! Das Modul spricht auf {found_baud} Baud.")
    print("Nutze diese Baudrate für den nächsten Konfigurationsschritt.")
    print(f"Tipp: sudo stty -F /dev/serial0 {found_baud}")
else:
    print("\n❌ TOTALAUSFALL: Keine Antwort auf keiner Frequenz.")
```

**Ausführen:** `sudo python3 find_baud.py`

#### Analyse des Ergebnisses

**Szenario A: Der Scanner findet eine Baudrate (z.B. 460800 oder 9600)**

Super! Das Modul lebt.

1. Merken Sie sich die Baudrate
2. Gehen Sie zurück zu Teil 3 und führen Sie das Setup-Skript aus
3. **Wichtig:** Ändern Sie im Setup-Skript die gefundene Baudrate in der Zeile `for baud in [460800, 115200, 9600]:`

**Szenario B: Der Scanner findet NICHTS ("Totalausfall")**

Wenn trotz Hardware-Reset und Scanner absolute Stille herrscht, prüfen Sie die Hardware:

1. **LED-Check:** Leuchtet die rote `PWR` LED auf dem HAT?
   - *Nein:* Hardware-Defekt oder kein Strom
   - *Ja:* Gut

2. **PPS-LED:** Blinkt die gelbe/grüne PPS LED?
   - *Ja:* Das Modul hat GPS-Fix! Nur serielle Leitung ist tot → Baudraten-Problem oder defekter TX-Pin

3. **Sitzt der HAT richtig?** Drücken Sie den HAT fest auf die GPIO-Leiste

4. **Konsole prüfen:** `ls -l /dev/serial0` muss auf `ttyS0` oder `ttyAMA0` zeigen

#### Der letzte Ausweg (Blinde Factory Reset)

Wenn der Scanner nichts findet, versuchen wir einen "blinden" Factory Reset auf *allen* Frequenzen.

```python
# Fügen Sie dies in eine Datei 'blind_reset.py' ein
import serial, subprocess, time
PORT = '/dev/serial0'
RATES = [460800, 115200, 9600, 230400, 38400]

for baud in RATES:
    print(f"Sende Factory Reset auf {baud}...")
    subprocess.run(["stty", "-F", PORT, str(baud), "raw", "-echo"])
    try:
        with serial.Serial(PORT, baud, timeout=0.1) as ser:
            ser.write(b"$PAIR001*3B\r\n") # Reset Befehl
            time.sleep(0.2)
    except: pass

print("Versuch beendet. Warte 2s und teste dann mit 115200 Baud via 'cat /dev/serial0'")
```

**Ausführen:** `sudo python3 blind_reset.py`

Nach diesem Skript sollte das Modul auf 115200 Baud zurückgesetzt sein. Testen Sie:

```bash
sudo stty -F /dev/serial0 115200 raw -echo
sudo timeout 5 cat /dev/serial0
```

Wenn jetzt NMEA-Daten erscheinen (`$GNGGA`, `$GNRMC`), ist das Modul gerettet!

---

## Referenzen

- **Quectel LC29H Protocol Specification v1.1:** https://files.waveshare.com/wiki/LC29H(XX)-GPS-RTK-HAT/Quectel_LC29H&LC79H_Series_GNSS_Protocol_Specification_V1.1.pdf
- **Waveshare LC29H Wiki:** https://www.waveshare.com/wiki/LC29H(XX)_GPS/RTK_HAT
- **RTKLIB Manual:** http://www.rtklib.com/prog/manual_2.4.2.pdf
- **NTRIP Protocol:** https://www.use-snip.com/kb/knowledge-base/ntrip-rev1-versus-rev2/
