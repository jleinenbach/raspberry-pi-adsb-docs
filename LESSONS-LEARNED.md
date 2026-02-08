# Lessons Learned

**System:** Raspberry Pi 4 Model B - ADS-B/OGN/Remote ID Feeder
**Letzte Aktualisierung:** 2026-02-07

Troubleshooting-Referenz und gesammelte Erkenntnisse aus System-Wartung.

---

## Lessons Learned

### Bash-Fallen
| Problem | Lösung |
|---------|--------|
| `grep -c` bei 0 Treffern | `VAR=$(grep -c ... 2>/dev/null)` - Kein `\|\| echo "0"` nötig! |
| heredoc mit Variablen | `<< 'EOF'` = literal, `<< EOF` = expandiert |
| Log-Dateien lesen | Immer `sudo` für /var/log/* |
| `source` von Dateien | Nie! Stattdessen: `VAR=$(grep "^KEY=" file \| cut -d= -f2-)` |
| Temp-File Permissions | `chmod` VOR `mv`, nicht danach |
| Log-Rotation | `tail -n > tmp && chmod 644 tmp && mv tmp log` |
| Race Conditions | `flock` für atomare Operationen |
| curl hängt | Immer `--max-time 10` verwenden |
| **Pipe-while Subshell** | **`echo \| while` läuft in Subshell! Nutze `mapfile -t array < <(...)` + `for`** |
| **`grep -c` + `\|\| echo "0"`** | **Gibt doppelte "0" aus bei `set -o pipefail`! grep gibt "0" aus, aber Pipe-Exit != 0 → `\|\| echo "0"` triggert → "0\\n0". FIX: `\|\| true` statt `\|\| echo "0"`** |
| **Architektur-Änderungen dokumentieren** | **Bei Service-Ersatz (zmq-decoder→atoms3-proxy): Watchdog, claude-respond, CLAUDE.md synchron updaten!** |
| **trap mit Variablen** | **`trap 'rm -f "''"' RETURN` expandiert NICHT! Nutze Double-Quotes: `trap "rm -f \\"$var\\"" RETURN`** |
| **$? nach command substitution** | **`local var=$(cmd); if [ $? -ne 0 ]` prüft IMMER 0 (Variable-Zuweisung)! FIX: `if [ -z "$var" ] \|\| ! validate "$var"`** |
| **Text-Parsing robustness** | **Bei Line-by-Line Parsing: Filter leere Zeilen, Markdown-Prefixes (###, **, *), trim whitespace. Nutze grep -A für multiline Context.** |

### Telegram Bot & HTML Formatting (2026-02-04)

**KRITISCH:** Telegram HTML ist NICHT Standard-HTML!

| Problem | Detail | Lösung |
|---------|--------|--------|
| **`&` in `<b>` Tags** | `<b>Text & Text</b>` → "Can't find end tag for 'b'" | Ersetze durch Text: "Text und Text" |
| **`&amp;` escaped** | `<b>Text &amp; Text</b>` → GLEICHER Fehler! | Auch Escaping hilft nicht! |
| **Workaround 1** | Bold-Tags aufteilen | `<b>Text</b> &amp; <b>Text</b>` ✅ |
| **Workaround 2** | `&` durch Wort ersetzen | "Almanach und Ephemeris" ✅ |
| **HTML vs MarkdownV2** | MarkdownV2: 18 Special Chars, HTML: nur 3 (`&<>`) | **HTML ist viel einfacher!** |
| **Escaping-Funktion** | `escape_html()` statt `escape_markdown_v2()` | `text="${text//&/&amp;}"` etc. |
| **`\|` in Markdown** | MarkdownV2 braucht `\|`, HTML nicht | In HTML: `|` direkt nutzen |
| **Backticks in Bash** | `` `$var` `` ist Command Substitution! | Nur für Markdown-Rendering, nicht in Bash! |
| **Debug-Strategie** | Bei HTML-Fehlern: Zeile für Zeile testen | Python-Skript mit incrementellem Build |
| **Telegram API Test** | Direkt mit curl testen, nicht über Bot | Schnelleres Debugging |

**Lesson:** Bei "Can't find end tag" Fehler - prüfe NICHT nur Tags, sondern auch **Zeichen INNERHALB** der Tags!

**Empfehlung:** HTML statt MarkdownV2 für alle Telegram-Bots verwenden.

### Systemspezifisch
| Erkenntnis | Kontext |
|------------|---------|
| Feed-Client ≠ Haupt-Decoder | `/usr/bin/readsb` vs. `feed-*` Binaries |
| AppArmor bei Störungen prüfen! | `dmesg \| grep apparmor.*DENIED` |
| Bot/Watchdog/Wartung synchron | Alle 3 Service-Listen aktualisieren + daily-summary! |
| Systemd: ReadWritePaths existieren | Sonst NAMESPACE-Fehler |
| ProtectSystem=strict vs full | strict braucht explizite /etc Pfade |
| `.claude/` muss pi gehören | Nach root-Ausführung: `chown -R pi:pi ~/.claude` |
| pip install auf Debian | `--user --break-system-packages` für PEP 668 |
| pip überschreibt apt | User-pip-Pakete haben Vorrang vor system-wide |
| **FFTW Benchmarking** | **Bei JEDEM Start 10-15min! Braucht TimeoutStartSec=20m** |
| Watchdog vs. langsame Starts | Watchdog kennt keine Grace-Period, False-Positives möglich |
| FFTW Wisdom nicht gespeichert | `/etc/fftw/` existiert nicht, daher Benchmarking wiederholt sich |
| **librtlsdr Debian-Paket veraltet** | **0.6.0-4 aus 2012, kennt V4 nicht! Nutze rtlsdr-blog stattdessen** |
| V4-Library nach /usr/local/ | Debian-Paket nach /lib/, `/usr/local/` hat Vorrang (ldconfig) |
| ldd zeigt Library-Links | `ldd /usr/bin/rbfeeder \| grep rtlsdr` prüft welche Version genutzt wird |
| Kompilierte Library = Dummy-Paket | Wenn Library selbst kompiliert: Dummy-deb für apt-Abhängigkeiten erstellen |
| **USB-Kabel testen!** | **Charge-Only Kabel (nur VCC+GND) verhindern USB-Kommunikation komplett** |
| USB Cable Health Check | BLE cableQU zeigt: Widerstand, Pin-Belegung, Shield-Qualität |
| ESP32 "Invalid image block" | Korrupte Firmware → Flash komplett löschen (erase_flash) vor Reflash |
| esptool write-flash | Immer mit `-z` (komprimiert) und `0x0` (Startadresse) flashen |
| drone-mesh-mapper Firmware | Lokal in `/home/pi/drone-mesh-mapper/firmware/*.bin`, kein GitHub Release |
| **Telegram Bot Mehrfachinstanzen** | **PID-Lock + Command-Lock essentiell! Alte Instanzen über Tage = gecachte alte Ausgaben** |
| Bot Lock-Files | PID: `/var/run/telegram-bot.pid`, Command: `/var/run/telegram-command.lock.$cmd` |
| **mtp-probe Log-Spam** | **Bei USB-Instabilität prüft mtp-probe jedes Reconnect → Tausende Einträge in user.log!** |
| mtp-probe deaktivieren | udev-Regel mit `ENV{MTP_NO_PROBE}="1"` für spezifisches VID:PID (ESP32: 303a:1001) |
| claude-respond Timeout | Wartung kann >10min dauern → TimeoutSec=1800 (30min) essentiell |
| **systemd Documentation= ungültige URL** | **systemd erwartet gültige URLs (https://, file://, man:), "inline" ist ungültig → Warning "Invalid URL, ignoring"** |
| systemd Documentation= entfernen | Wenn keine externe Doku existiert, Zeile einfach löschen - Description ist ausreichend |
| **ESP32-S3 USB CDC Flag** | **`ARDUINO_USB_CDC_ON_BOOT=1` (NICHT `ARDUINO_USB_CDC`!)** |
| ESP32 USB CDC Timing | USB CDC braucht 3-5s zum Enumerieren - Monitoring VOR Reset starten! |
| ESP32 Serial Monitoring | Python pyserial nutzen, `cat /dev/ttyACM0` ist unzuverlässig |
| ESP32 Serial.flush() | Kann blockieren - besser `delay(100)` nach Serial.println() |
| **Monitoring ≠ Hardware** | **Monitoring-Problem gelöst ≠ Hardware-Problem gelöst! USB disconnects bleiben trotz sichtbarem Output** |
| NimBLE vs Bluedroid | NimBLE spart ~370 KB Flash, ~15 KB RAM, stabiler für Scan-Only |
| ESP32 Dual-Core | WiFi/BLE-Stacks laufen IMMER auf Core 0, egal wo Tasks gepinnt sind |
| FreeRTOS Queues | Thread-safe zwischen Cores, aber Größe muss passen (testen!) |
| ESP32 Task Heartbeats | Volatile Counter essentiell für Task-Liveness-Check |
| **AtomS3 Firmware Docs** | **Vollständige Doku in `~/docs/ATOMS3-FIRMWARE.md`** |
| **tmpfs Log-Verzeichnisse** | **Service mit `StandardOutput=append:/var/log/foo/` braucht tmpfiles.d-Regel!** |
| tmpfiles.d für Custom Logs | `d /var/log/foo 0755 user group -` in `/etc/tmpfiles.d/foo.conf` |
| Status 209/STDOUT | Systemd kann STDOUT-Datei nicht öffnen → Verzeichnis fehlt! |
| tmpfs Boot Cleanup | `/var/log` wird bei jedem Boot komplett geleert (tmpfs-Mount) |
| log-persist vs tmpfiles | log-persist nur für wichtige Logs, tmpfiles für Verzeichnis-Struktur |
| **tmpfs Logs gefährlich** | **Services die nach /var/log/ schreiben brauchen Symlink nach /var/lib/** |
| tmpfs-Cleanup löscht alles | `/var/log/` ist tmpfs - Verzeichnisse symlinken: `/var/log/xyz → /var/lib/xyz/logs` |
| OGN Log-Verzeichnis fehlt | Nach tmpfs-Cleanup Services crashen (Status 209/STDOUT) - `/var/log/rtl-ogn/` muss persistieren |
| **log-persist rekursiver Bug** | **VERZEICHNISSE in log-persist.conf verursachen `/var/log/xyz/xyz/xyz/...` Rekursion!** |
| log-persist Best Practice | **NUR DATEIEN** in log-persist.conf! Verzeichnisse via Symlink → /var/lib/ persistent machen |
| **Claude CLI Permission-Flag** | **`--dangerously-skip-permissions` verboten als root! Nutze `--permission-mode acceptEdits`** |
| Claude CLI als root | Sicherheitsfeature: --dangerously-skip-permissions → "cannot be used with root/sudo privileges" → Exit 1 |
| Claude Permission Modes | acceptEdits, acceptAll, interactive, prompt - alle funktionieren als root (nur --dangerously-skip-permissions nicht!) |
| Command Substitution Output | Fehlermeldungen können bei `$()` verschwinden (Output leer, aber Exit Code korrekt) |
| systemd Service User | Kein `User=` Statement → Service läuft als root (Default) |
| tmpfs-Volllauf Hauptursache | AIDE/apt rekursive Verzeichnisse (46M+3M von 50M) - NICHT Notfall-Cleanup sondern Root Cause fixen! |
| **GPS Power-Cycle via UART** | **PAIR050 (Power ON), PAIR051 (Power OFF) für Software-Reset ohne Pi-Reboot** |
| GPS Power-Cycle Ergebnis | Befehle werden akzeptiert aber GPS antwortet nicht sofort - braucht Cold Start (5-15 min) |
| **GPS Cold Start Problem** | **Ohne Almanach/Ephemeris dauert erster Fix 5-15 Minuten (Satelliten-Download)** |
| GPS A-GPS fehlt | gpsd kann Almanach nicht automatisch bereitstellen - braucht Assisted-GPS oder Geduld |
| GPS Almanach-Quellen | CelesTrak (YUMA format), USCG Navigation Center - aber Format-Konvertierung nötig |
| **LC29H RTK Base Station Modus** | **RTCM104V3-Ausgabe ist NICHT Bug sondern Feature! GPS war als RTK Base Station konfiguriert** |
| **LC29H Base → Rover Wechsel** | **PAIR001 (Reset to Default), PAIR432,0 (Base aus), PQTMCFGRCVRMODE,W,1 (Rover), PAIR062 (NMEA), PQTMSAVEPAR** |
| **LC29H NVRAM nicht persistent** | **PAIR-Befehle werden akzeptiert ($PAIR012 ACK), aber Konfiguration wird NICHT sofort angewendet - braucht Power-Cycle** |
| **LC29H GPIO Reset unzureichend** | **GPIO 18 Reset lädt NVRAM NICHT neu - nur physischer Power-Cycle (HAT abziehen) funktioniert!** |
| **LC29H NVRAM-Reload Methode** | **PAIR650 (Backup Mode) + Pi Reboot ODER physisches HAT abziehen (30s) = einzige Methoden für NVRAM-Reload** |
| LC29H PAIR050/051 unzureichend | Software-Power-Cycle (PAIR050/051) lädt NVRAM NICHT neu - nur für Position-Reset |
| LC29H PAIR650 Backup Mode | GPS geht in Shutdown, läuft auf V_BCKP (Batterie) weiter ODER komplett aus (ohne Batterie) |
| **Pi Reboot OHNE PAIR650** | **Hilft NICHT! GPS läuft weiter auf 5V vom Pi, NVRAM wird nicht neu geladen** |
| Waveshare LC29H Batterie | ML1220 optional - OHNE: Cold Start (5-15min), MIT: Hot Start (<1min). NVRAM persistent in beiden Fällen! |
| LC29H NVRAM vs Backup Domain | NVRAM (Konfiguration) ist persistent auch ohne Batterie. V_BCKP nur für Ephemeris/Zeit/Position |
| Waveshare LC29H WAKEUP-Pin | Nicht auf GPIO gemappt, nur intern verbunden - für Wake-up aus Backup Mode |
| LC29H WAKEUP-Prozedur | Nach VCC-Restore: WAKEUP-Pin >10ms high ziehen (aber nur wenn extern zugänglich) |
| **Waveshare LC29H GPIO Reset** | **GPIO 18 (Pin 12) = GPS_RST, High-aktiv via Q1 Transistor - Software-Reset möglich!** |
| **Waveshare LC29H PPS Pin** | **GPIO 4 (Pin 7) = GPS_PPS, NICHT GPIO 18! Schaltplan zeigt korrekte Belegung** |
| LC29H GPIO Reset Methode | HIGH-Impuls auf GPIO 18 (100ms): `GPIO.output(18, HIGH)` → `sleep(0.1)` → `GPIO.output(18, LOW)` |
| **LC29H Pin-Belegung komplett** | **Pin 8/10: UART (GPIO 14/15), Pin 12: Reset (GPIO 18), Pin 7: PPS (GPIO 4), Pin 2/4: 5V, Pin 6/9/14/20/25: GND** |
| **GPIO-Pins einzeln abziehen** | **UNMÖGLICH! 40-Pin-Header ist Block - nur ganzes HAT abziehen praktikabel** |
| **LC29H Hybrid RTK Mode** | **460800 Baud ZWINGEND für NMEA + RTCM gleichzeitig! 115200 reicht NICHT (Buffer Overflow)** |
| **LC29H NMEA vor RTCM** | **NMEA (PAIR062) MUSS vor RTCM (PAIR430) aktiviert werden! Sonst "verschluckt" RTCM-Flood den NMEA-Stream** |
| **LC29H Factory Reset Baudrate** | **PAIR001 setzt IMMER auf 115200 zurück, egal welche Baudrate vorher war** |
| **LC29H Base Station vs Rover** | **Base Station Mode (PAIR432,1) blockiert NMEA komplett! Muss zu Rover Mode (PQTMCFGRCVRMODE,W,1) wechseln** |
| **LC29H PAIR-Befehle Reihenfolge** | **1. PAIR001 (Reset), 2. PAIR002 (Baud), 3. PAIR062 (NMEA), 4. PAIR430 (RTCM), 5. PAIR432 (Survey-In), 6. PAIR513 (Save)** |
| **LC29H PAIR513 vs PQTMSAVEPAR** | **PAIR513 = Quectel Standard, PQTMSAVEPAR = Airoha-spezifisch. Beide speichern NVRAM, aber PAIR513 universeller** |
| **LC29H Survey-In Parameter** | **PAIR432,1,600,2000 = Mode 1 (Survey-In), 600 Sekunden (10 min), 2000mm (2m Genauigkeit)** |
| **LC29H NTRIP Server Setup** | **str2str nimmt gpsd NMEA+RTCM → NTRIP Caster (Port 5000). SW Maps/Rover holen RTK-Korrekturen** |
| **LC29H Hybrid Mode Dokumentation** | **Vollständiges Handbuch: `~/docs/GPS-RTK-HYBRID-SETUP.md`** |
| **LC29H "stumm" (keine Ausgabe)** | **NICHT Hardware-Defekt! Meist Baudraten-Niemandsland oder gpsd/str2str blockiert Port** |
| **LC29H Notfall-Rettung** | **1. Services stoppen (gpsd/ntripcaster), 2. Hardware Reset (GPIO 18), 3. Baudraten-Scanner, 4. Blinder Factory Reset** |
| **LC29H Baudraten-Scanner** | **Probiert 460800/115200/9600/230400/38400/57600 durch mit PAIR003 (Version Query) bis Antwort kommt** |
| **LC29H Blinder Factory Reset** | **PAIR001 auf ALLEN Baudraten senden → Modul landet garantiert auf 115200** |
| **NIEMALS `cat` auf GPS-Port!** | **RTCM-Binärdaten (460800 Baud) crashen UI/Terminal! Immer safe_check.py verwenden (analysiert, gibt nicht aus)** |
| **GPS Safe Diagnose Tool** | **`safe_check.py` liest 1000 Bytes, prüft auf 0xD3 (RTCM) und $G (NMEA), gibt nur Status aus (HYBRID/NUR RTCM/NUR NMEA)** |
| **RTCM erkennen ohne Output** | **Byte 0xD3 = RTCM3 Start, $G = NMEA Start. Analyse im Code, nie raw ausgeben!** |
| **Pi Reboot NICHT nötig** | **`sudo fuser -k /dev/serial0` + `stty sane` + Hardware Reset (GPIO 18) = "Hot Reset" ohne Reboot** |
| **claude CLI --files deprecated** | **`--files` Option existiert nicht! Claude hat Read tool, braucht keine vorgeladenen Dateien** |
| **claude CLI --file für Cloud** | **`--file` ist für Cloud file_id:path, nicht für lokale Pfade** |
| **LC29H Base-Variante (BA) unterdrückt NMEA** | **Im Fixed Mode (nach Survey-In) sendet Base-Variante NUR RTCM, kein NMEA! Das ist Firmware-Design, kein Bug!** |
| **LC29H Single UART Problem** | **Waveshare HAT leitet nur UART 1 weiter, obwohl AG3335 Chip mehrere UARTs hat - NMEA+RTCM konkurrieren um Buffer** |
| **RTCM Message 1005** | **Enthält Basisstation-Position (ARP ECEF X/Y/Z) - NMEA nicht nötig für Positionsbestimmung!** |
| **pyrtcm für RTCM-Decode** | **`pip3 install pyrtcm` - Kann RTCM-Stream parsen und Message 1005 extrahieren** |
| **NTRIP-Server braucht kein NMEA** | **str2str nimmt RTCM-Input, kein NMEA nötig - Base Station sendet nur RTCM an Rover** |
| **Waveshare LC29H PPS auf GPIO 18!** | **NICHT GPIO 4! Doku war falsch - GPIO-Scan fand echten Pin (1 Puls/Sek, 11% Duty Cycle)** |
| **PPS Open-Drain braucht Pull-Up** | **`pinctrl set PIN pu` aktiviert internen Pull-Up - sonst permanent LOW trotz blinkender LED!** |
| **GPIO-Scan für verlorene Signale** | **Alle Pins mit Pull-Up scannen, wechselnde = Signal-Pin - rettet falsche Schaltpläne** |
| **LC29H Pin-Belegung komplett** | **Pin 8/10: UART (GPIO 14/15), Pin 12: PPS (GPIO 18!), Pin 2/4: 5V, Pin 6/9/14/20/25: GND - Schaltplan hatte GPIO 4 falsch!** |
| **chrony offset für PPS-Puls** | **`offset 0.102` kompensiert 100ms PPS-Puls - ohne offset ist PPS unusable (+101ms Offset)** |
| **ppstest für PPS-Diagnose** | **`sudo ppstest /dev/pps0` zeigt Live-Pulse - sequence++ jede Sekunde = funktioniert** |
| **Blinder Factory Reset GPS** | **PAIR001 auf ALLEN Baudraten (460800,115200,9600,230400,38400,57600,921600) - einer trifft!** |
| **str2str ntripc vs ntrips** | **ntripc = Caster (empfängt Rover), ntrips = Server (sendet AN Caster) - oft verwechselt!** |
| **LC29H PAIR753 PPS-Aktivierung** | **`PAIR753,1,100000,0,0` = Enable, 100ms Puls - funktioniert auch im Base Mode** |
| **chrony lock system deprecated?** | **chrony 4.3 kennt `lock system` nicht - stattdessen: offset + prefer, NTP gibt grobe Zeit** |

### WiFi & 802.11 Presence Detection
| Erkenntnis | Kontext |
|------------|---------|
| **Probe Requests Parallel** | **WiFi Promiscuous Mode kann 0x40 (Probe), 0x80 (Beacon), 0xD0 (NAN) parallel empfangen** |
| Probe Request Frame Type | Frame Control Byte 0 = `0x40` (Type 0, Subtype 4) für Probe Requests |
| MAC in Probe Request | Source MAC in Bytes 10-15, nicht Bytes 4-9 (das ist Destination = FF:FF:FF:FF:FF:FF) |
| SSID Tagged Parameters | TLV-Format: Tag (1 byte) + Length (1 byte) + Value (var), SSID = Tag 0x00 |
| **MAC Randomization** | **iOS 14+/Android 10+ nutzen Random MAC pro Netzwerk, iOS 18+ rotiert täglich!** |
| MAC Randomization Workaround | OUI bleibt erkennbar (erste 3 bytes) - Erkennung "Apple device" statt "John's iPhone" |
| RSSI für Proximity | Je näher an 0 dBm, desto STÄRKER! -40 dBm = sehr nah, -70 dBm = mittel, <-80 dBm = zu weit |
| Probe Request Rate | Residential: 10-50/min (2-5 Geräte), Office: 50-200/min, Airport: 1000-5000/min |
| **IRAM_ATTR Pflicht** | **WiFi Callback läuft in ISR-Context (Core 0) - muss in IRAM, kein Serial.print()!** |
| xQueueSendFromISR | ISR-Context braucht ISR-safe Varianten: `xQueueSendFromISR` statt `xQueueSend` |
| FreeRTOS Queue Memory | Queue-Daten kommen aus PSRAM wenn verfügbar (30 x 47 bytes = 1410 bytes) |
| OUI Database IEEE | IEEE vergibt Organizationally Unique Identifier (erste 3 Bytes MAC = Hersteller) |
| OUI Update Frequency | Monatlich neue OUIs - Database sollte alle 30 Tage aktualisiert werden |
| GDPR & MAC Addresses | MAC Address = Personal Data (kann Individuen identifizieren) - Retention Limits beachten! |
| Probe Suppression | Geräte die mit AP verbunden sind senden weniger/keine Probe Requests |

### Serial Port & Hardware Debugging
| Erkenntnis | Kontext |
|------------|---------|
| **Serial Port Contention** | **Linux serial ports allow ONLY ONE reader! Multiple readers = "device disconnected" error (NOT hardware!)** |
| **lsof für Serial Debugging** | **`lsof /dev/ttyACM0` zeigt welcher Prozess den Port blockiert - ESSENTIAL für Diagnose!** |
| **"device disconnected" ≠ Hardware** | **Kann Software-Konflikt sein! Prüfe ZUERST `dmesg` auf echte USB-Disconnects** |
| **Proxy Pattern für Serial** | **Single Reader + ZMQ Broadcast = Clean Solution für Multi-Consumer** |
| **ZMQ PUB/SUB für Broadcast** | **Perfekt für 1:N Routing ohne Port-Konflikt, non-blocking sends** |
| **dmesg vs Application Error** | **Kernel-Logs (dmesg) zeigen Hardware-Probleme, Application-Errors können Software sein** |
| **atoms3-proxy Architektur** | **Serial → Parse → Route by JSON type → ZMQ PUB (4224=remoteid, 4225=probe)** |
| **Time-Sharing Serial FAILS** | **Versuch, Port zeitversetzt zu nutzen funktioniert nicht - Port bleibt locked** |
| **USB CDC Timing** | **ESP32 USB CDC braucht 3-5s - Monitoring VOR Reset starten!** |

### NTRIP & GPS RTK
| Erkenntnis | Kontext |
|------------|---------|
| **str2str Source Table leer** | **str2str sendet `STR;BASE;` ohne Metadaten - Apps wie Lefebure können Mountpoint nicht auswählen!** |
| **NTRIP Caster vs Server** | **`ntripc` = Caster (empfängt Rover), `ntrips` = Server (sendet zu öffentlichem Caster) - verwechselt = Stunden Debugging!** |
| **ICY 200 OK Protocol** | **NTRIP Mountpoint nutzt Icecast-Protokoll (nicht HTTP!) - `ICY 200 OK` + sofort Binärdaten, kein Content-Length** |
| **HTTP Request 1:1 weiterleiten** | **str2str akzeptiert nur original Request! Neu aufbauen aus Headern = 0 bytes zurück!** |
| **Transparent Proxy Pattern** | **Source Table für `GET /`, 1:1 Passthrough für `GET /BASE` - beste Lösung für leere Source Table** |
| **Lefebure braucht GPS-Fix** | **App schließt nach 30s ohne GPS-Position! NTRIP funktioniert nur DRAUSSEN mit Satelliten-Fix** |
| **Port 5000 vs 5001** | **Port 5000 = str2str (direkt), Port 5001 = Proxy (mit Source Table) - Apps sollten Proxy nutzen** |
| **RTCM-Stream = endlos** | **NTRIP-Client erwartet kontinuierlichen Stream (~5 kbps), keine kurzen Requests wie HTTP!** |

### Security Best Practices
| Pattern | Warum |
|---------|-------|
| `set -o pipefail` | Erkennt Fehler in Pipes (z.B. `cmd1 \| cmd2`) |
| Input-Sanitization | Entferne `$()`, Backticks, `${` aus User-Input |
| Path-Validierung | Prüfe auf `..` und absolute Pfade bei Config-Einträgen |
| Atomare Dateiops | `flock` oder `(umask 077 && touch file)` |
| Keine Secrets in Logs | Token/Passwörter nie in Fehlermeldungen |

### NTP & Zeitsynchronisation (2026-02-03)
| Erkenntnis | Lösung |
|------------|--------|
| **chronyd lauscht nur auf localhost** | **`allow 192.168.1.0/24` + `local stratum 1` in chrony.conf hinzufügen** |
| **NTP-Server nicht im Netzwerk erreichbar** | **Port 123 muss auf 0.0.0.0 lauschen, nicht nur 127.0.0.1** |
| **Watchdog activating ohne Timeout** | **Grace-Period 120s implementieren - danach eingreifen falls hängt** |
| **activating-Marker braucht Timestamp** | **echo $now > marker statt touch - ermöglicht Zeitberechnung** |
| **Stratum 1 Server im LAN** | **GPS PPS macht Pi zu primärer Zeitquelle - besser als öffentliche NTP-Server** |
| **NTP vs NTS** | **NTS = Network Time Security, verschlüsselte NTP-Verbindung (PTB unterstützt)** |
| **chronyd cmdallow** | **`cmdallow 127.0.0.1` erlaubt `chronyc clients` Monitoring** |

### GPS & AGNSS (2026-02-04)

| Problem | Detail | Lösung |
|---------|--------|--------|
| **MediaTek EPO ≠ Quectel PAIR** | LC29H (Quectel) versteht MediaTek EPO.DAT nicht | Chip-spezifisches Format nötig |
| **Public EPO ≠ Vendor EPO** | `epodownload.mediatek.com` ist generic | LC29H braucht `wpepodownload.mediatek.com` mit vendor/project/device_id |
| **Blind AGNSS Testing** | EPO senden ohne NMEA-Feedback → GPS verwirrt 8min | **NIE** EPO senden ohne Device-Zugriff für Diagnose |
| **str2str blockiert Device** | `/dev/ttyAMA0` 24/7 belegt, kein NMEA-Zugriff | Service stoppen für Diagnose (Downtime!) |
| **TTFF Messung** | `systemd-analyze` während Boot → Fehler | Warte 60s nach Boot, dann messe |
| **AGNSS bei 24/7 Base Station** | Almanach verfällt NIE (<30d Offline), TTFF 60-90s akzeptabel | **AGNSS unnötig** für Base Stations |
| **Backup Battery Alternative** | ML1220 Battery (5-10€) → Warm Start <5s | Einfacher als AGNSS-Server-Credentials |
| **GitHub als Dokumentation** | Quectel PDFs in sbcshop/GPS-Hat, Code in platformio-quectel-examples | GitHub-Search ist besser als Vendor-Support |
| **PAIR Protocol** | Quectel proprietary, binary mode `$PMTK253,1,<baud>` | Siehe Quectel AGNSS Application Note |
| **EPO Server Credentials** | vendor/project/device_id nicht öffentlich | Muss bei Quectel Technical Support angefordert werden |

**WICHTIG:** Bei GPS mit blockiertem Device (str2str, gpsd, etc.) - AGNSS nur mit Service-Unterbrechung möglich!

**Alternative:** Backup-Batterie ist wartungsfreier und zuverlässiger als AGNSS-Server-Abhängigkeit.

### Home Assistant & MQTT Discovery (2026-02-05)

| Problem | Detail | Lösung |
|---------|--------|--------|
| **device_class nur für bestimmte Entity-Typen** | `device_class: 'connectivity'` nur für `binary_sensor`, nicht `sensor` | **Richtige Entity-Typ wählen** - ON/OFF = binary_sensor |
| **MQTT Discovery Fehler** | `'expected SensorDeviceClass...'` Error in HA | **discovery topic prüfen**: `sensor/...` vs `binary_sensor/...` |
| **Retained Messages löschen** | Alte falsche Discovery bleibt im MQTT Broker | `mosquitto_pub -t "topic" -n -r` (null + retain) |
| **Sensor vs Binary Sensor** | Numeric/String = sensor, ON/OFF = binary_sensor | Klare Trennung, unterschiedliche discovery topics |
| **Python MQTT Array-Struktur** | Getrennte Arrays für unterschiedliche Entity-Typen | `sensors = [...]` und `binary_sensors = [...]` |

**WICHTIG:** Home Assistant MQTT Discovery hat strikte Validierung - Entity-Typ muss zu device_class passen!

**Diagnose:**
```bash
# Alle MQTT Discovery Messages anzeigen
mosquitto_sub -h <broker> -t 'homeassistant/+/+/+/config' -v

# Retained Message löschen
mosquitto_pub -h <broker> -t "homeassistant/sensor/device/entity/config" -n -r
```

### Apt & Package Management (2026-02-05)

| Problem | Detail | Lösung |
|---------|--------|--------|
| **Trixie-Quellen = Migration?** | `/etc/apt/sources.list` mit bookworm + trixie Zeilen | **Prüfe Pinning-Konfiguration** in `/etc/apt/preferences.d/` |
| **Apt-Pinning übersehen** | Wartung alarmiert "System migriert zu trixie" | **False Positive** - Pinning erzwingt bookworm (Prio 900 > 50) |
| **ca-certificates aus trixie** | Einziges Paket mit trixie-Version (Prio 990) | **Beabsichtigt** - Let's Encrypt Root CA Bug in bookworm |
| **Pinning-Diagnose** | Wie prüfen ob Paket aus trixie kommt? | `apt-cache policy <paket>` zeigt Quelle mit `***` |
| **System-Migrationscheck** | Kernel vs. APT-Quellen inkonsistent? | **Pinning ist nicht Migration** - Prio entscheidet, nicht Quellen-Existenz |

**WICHTIG:** Trixie-Quellen in `sources.list` sind OK wenn `/etc/apt/preferences.d/` Pinning konfiguriert hat!

**Diagnose:**
```bash
# Alle trixie-Pakete auflisten (sollte nur ca-certificates sein)
dpkg -l | awk '/^ii/ {print $2}' | xargs -I {} sh -c \
  'apt-cache policy {} 2>/dev/null | grep -q "^\*\*\*.*trixie" && echo {}'

# Pinning-Prioritäten prüfen
apt-cache policy | grep -E "^\s+(500|900|990|50)" | head -20
```


### ZMQ & Message Queues (2026-02-06)

| Problem | Detail | Lösung |
|---------|--------|--------|
| **ZMQ Port-Konflikt** | Zwei Prozesse versuchen gleichen Port zu binden | **NUR EIN** Publisher pro Port (XPUB/PUB) |
| **--zmqsetting vs --zmqclients** | `--zmqsetting` = Server (BIND), `--zmqclients` = Client (CONNECT) | Parameter-Bedeutung IMMER prüfen |
| **Service Config Validierung** | Service startet nie (inactive), keine Logs | `systemctl status` zeigt nicht WARUM - `journalctl -u` prüfen |
| **Dekodierung: ESP32 vs Server** | Wo dekodieren? | **ESP32** effizienter - Server nur Routing |
| **Multi-Source unnötig** | zmq-decoder kann viele Quellen - brauchen wir nicht | **KISS** - nur nötige Features implementieren |
| **Architekturentscheidung ohne Analyse** | Service entfernt ohne Deep Dive/User-Frage | **5-Level Eskalation** immer befolgen |

**Wichtig:** ZMQ Publisher (PUB/XPUB) kann NUR EINMAL pro Port binden. Subscriber (SUB) können viele sein!

**Pattern:**
```
Publisher (BIND tcp://*:4224) ← Kann nur 1x pro Port existieren
    ↓
Subscriber (CONNECT tcp://host:4224) ← Beliebig viele möglich
Subscriber (CONNECT tcp://host:4224)
Subscriber (CONNECT tcp://host:4224)
```



### Wartungs-Watchdog False-Positives (2026-02-06)

| Problem | Detail | Lösung |
|---------|--------|--------|
| **Exit 1 != Fehler** | Claude CLI gibt Exit 1 bei PENDING-Session | Prüfe Session-State BEVOR Diagnose |
| **PENDING-Session** | User-Rückfrage ohne sofortige Antwort | Exit 1 mit `waiting_for_answer` = OK |
| **Diagnose-Fehlalarm** | Watchdog startet unnötige Diagnose-Claude | Session-File `/var/lib/claude-pending/session.json` prüfen |

**Pattern:**
```bash
# PENDING-Session prüfen BEVOR Exit 1 als Fehler behandelt wird
if [ -f "$session_file" ]; then
    session_state=$(jq -r ".state" "$session_file")
    if [ "$session_state" = "waiting_for_answer" ]; then
        # Exit 1 ist OK - Claude wartet auf User
        return 0
    fi
fi
# Kein PENDING → Exit 1 ist echter Fehler
```

**Wichtig:** Exit 1 bei PENDING-Session ist technisch korrekt (Claude beendete Wartung nicht vollständig), aber kein Fehler-Zustand!


### Claude Wartung: Declined Recommendations werden ignoriert (2026-02-06)

| Problem | Detail | Lösung |
|---------|--------|--------|
| **Wiederholte Vorschläge** | SSH-7408 wurde 3x vorgeschlagen (2026-01-18, 2026-01-30, 2026-02-06) | Declined-Liste besser prüfen |
| **MAINTENANCE-HISTORY.md** | Declined Recommendations nicht erkannt | Vor Vorschlag prüfen: `grep -i "keyword" MAINTENANCE-HISTORY.md` |
| **User-Frustration** | "Das hatten wir übrigens schon einmal!" | System-Prompts verstärken |

**Wichtig:** IMMER MAINTENANCE-HISTORY.md prüfen BEVOR User-Rückfragen gestellt werden!

**Pattern:**
```bash
# Vor Lynis-Vorschlag IMMER prüfen
SUGGESTION="SSH-7408"
if grep -qi "$SUGGESTION" ~/docs/MAINTENANCE-HISTORY.md; then
    echo "Bereits abgelehnt, überspringen"
    exit 0
fi
```

**Root Cause:** Claude Wartungs-Prompt sagt "Lies MAINTENANCE-HISTORY.md", aber Claude liest nur bei explizitem Status-Request, nicht bei täglicher Wartung.


### wait_for_quiet: Self-Detection (2026-02-06)

| Problem | Detail | Lösung |
|---------|--------|--------|
| **Henne-Ei-Problem** | Wartung wartete 10min auf sich selbst | Self-Detection: Eigenen Service ignorieren |
| **Type=oneshot** | Service ist "activating" während er läuft | Normal für oneshot, muss ausgefilter werden |
| **Infinite Loop** | wait_for_quiet() findet sich selbst → wartet → timeout | grep -v "^service-name$" |

**Pattern:**
```bash
# Prüfe auf aktivierende Services, aber NICHT dich selbst!
local activating_services=$(systemctl list-units --state=activating --no-legend --no-pager 2>/dev/null | \
    awk '{print $1}' | \
    grep -v "^$(basename $0 .service).service$")
```

**Wichtig:** Type=oneshot Services sind im "activating" Status während das ExecStart-Skript läuft. Das ist KEIN Fehler!

**Symptom:** Service läuft, aber wait_for_quiet() wartet 10 Minuten auf ihn → Timeout.

---

### Monitoring & Netzwerk-Check (2026-02-07)

| Problem | Detail | Lösung |
|---------|--------|--------|
| **Single-Ping False Positives** | Ein verlorenes Paket = "offline" | Multi-Host Multi-Ping Check |
| **Paket-Verlust ist normal** | 1-2% Paket-Verlust kommt vor | Nur fehlschlagen wenn ALLE Hosts unerreichbar |
| **DNS-Server überlastet** | Temporäre Probleme bei 8.8.8.8 | Mehrere DNS-Server testen (8.8.8.8, 1.1.1.1) |
| **Gateway vs Internet** | Internet offline ≠ LAN offline | Auch Gateway (192.168.1.1) testen |
| **Sofort-Alarm ungünstig** | Erste Warnung kann Ausrutscher sein | Warnung erst ab 2. konsekutivem Fehler |
| **Paradoxe Telegram-Nachricht** | "Netzwerk offline" via Telegram gesendet | Beweist dass Check zu strikt ist |

**Robuster Netzwerk-Check Pattern:**
```bash
check_network() {
    local hosts=(
        "8.8.8.8"      # Google DNS (Internet)
        "1.1.1.1"      # Cloudflare DNS (Internet)
        "192.168.1.1"  # Gateway (LAN)
    )

    # Teste jeden Host mit 2 Pings, 3s Timeout
    for host in "${hosts[@]}"; do
        if ping -c 2 -W 3 "$host" &>/dev/null; then
            # Mindestens ein Host erreichbar = Netzwerk OK
            return 0
        fi
    done

    # ALLE Hosts fehlgeschlagen = offline
    return 1
}
```

**Wichtig:**
- **Multi-Host:** Mehrere Ziele (Internet + LAN) für Robustheit
- **Multi-Ping:** 2 Pings pro Host reduziert Paket-Verlust-Effekt
- **Fail-Safe:** Nur wenn ALLE Hosts fehlschlagen = offline
- **Toleranz:** Warnung erst ab 2. konsekutivem Fehler (nicht beim ersten!)

**Effekt:** ✅ Keine False-Positives bei temporären Netzwerk-Aussetzern
