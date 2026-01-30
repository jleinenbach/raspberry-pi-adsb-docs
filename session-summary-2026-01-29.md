# System-Wartung Session 2026-01-29

## Durchgeführte Arbeiten

### 1. Hardware-Diagnostik & Spannungsüberwachung

**Aufgabe:** RTL-SDR V4 Treiber validieren und USB-Spannungsüberwachung integrieren

**Durchgeführt:**
- ✅ RTL-SDR Blog V4 Treiber-Validierung mit `rtl_test -d 1 -t`
- ✅ R828D-Tuner korrekt erkannt (V4-spezifischer Chip)
- ✅ Spannungsüberwachung (`vcgencmd get_throttled`) integriert in:
  - `/usr/local/sbin/telegram-bot-daemon` (Zeilen 264-281)
  - `/usr/local/sbin/daily-summary` (nach Temperatur-Check)
  - `/usr/local/sbin/claude-respond-to-reports` (Stromversorgungs-Sektion)
- ✅ Telegram Bot neu gestartet und getestet
- ✅ Ausgabe: "🟢 Spannung: Stabil" (throttled=0x0)

**Ergebnis:** Netzteil-Probleme werden jetzt automatisch in 3 Monitoring-Skripten erkannt.

**Dokumentation:**
- `docs/MONITORING.md` - Hardware-Diagnose-Abschnitt erweitert
- `docs/VOLTAGE-MONITORING.md` - Dedizierte Dokumentation erstellt
- `docs/HARDWARE-DIAGNOSE-2026-01-29.md` - Diagnose-Bericht
- `docs/voltage-monitoring-examples.sh` - Beispiel-Code
- `CLAUDE.md` - Implemented Changes aktualisiert

---

### 2. RTL-SDR Blog Library V4 Installation

**Problem:** "[R82XX] PLL not locked" Meldungen im ogn-rf Log

**Ursache gefunden:**
- Debian librtlsdr (0.6.0-4) aus 2012/2013 installiert
- Kennt RTL-SDR Blog V4 mit R828D-Tuner nicht
- ogn-rf und rbfeeder nutzten beide die veraltete Library
- Resultat: PLL-Lock-Fehler, falsche Tuner-Initialisierung

**Lösung implementiert:**
1. ✅ Watchdogs deaktiviert (feeder-watchdog, wartungs-watchdog)
2. ✅ OGN Services gestoppt (ogn-rf, ogn-decode, ogn2dump1090)
3. ✅ Alte Library entfernt (librtlsdr0, rtl-sdr, rbfeeder)
4. ✅ RTL-SDR Blog Library v1.3.6 kompiliert
   - Quelle: https://github.com/rtlsdrblog/rtl-sdr-blog
   - Build: cmake + make -j4 (als root wegen gcc-Hardening)
5. ✅ Library installiert nach `/usr/local/lib/`
6. ✅ rbfeeder wiederhergestellt (alte Library mit --force-depends entfernt)
7. ✅ Library-Links verifiziert (ldd zeigt neue Library)
8. ✅ Services getestet (alle 21 Services aktiv)
9. ✅ PLL-Status geprüft (keine neuen Meldungen nach Initialisierung)
10. ✅ Update-Check eingerichtet (im Wartungsskript)
11. ✅ Watchdogs reaktiviert

**Vorher/Nachher:**
| Aspekt | Vorher (0.6.0-4) | Nachher (v1.3.6) |
|--------|------------------|------------------|
| V4-Erkennung | ❌ "Generic RTL2832U" | ✅ "Blog V4" |
| Tuner | ✅ "R828D" | ✅ "R828D" + explizit |
| PLL-Meldungen | 🔴 Permanent | ✅ Nur bei Init |

**Library-Pfade:**
```
Alt: /lib/aarch64-linux-gnu/librtlsdr.so.0 (0.6.0-4)
Neu: /usr/local/lib/librtlsdr.so.0 (v1.3.6)
```

**Verifizierung:**
```bash
ldd /opt/rtlsdr-ogn/ogn-rf | grep rtlsdr
# → /usr/local/lib/librtlsdr.so.0 ✅

ldd /usr/bin/rbfeeder | grep rtlsdr
# → /usr/local/lib/librtlsdr.so.0 ✅
```

**Update-Mechanismus:**
- Automatischer Check im Wartungsskript (`claude-respond-to-reports`)
- Prüft wöchentlich auf neue GitHub-Versionen
- Warnt bei verfügbaren Updates

**Dokumentation:**
- `CLAUDE.md` - Implemented Changes + GitHub Repositories Sektion
- `CLAUDE.md` - Lessons Learned (librtlsdr veraltet, Library-Vorrang)
- `~/rtl-sdr-blog/` - Repository geklont und gebaut

---

## Alle durchgeführten Änderungen

### Modifizierte Dateien

| Datei | Änderung |
|-------|----------|
| `/usr/local/sbin/telegram-bot-daemon` | Spannungsüberwachung + OGN-Statistiken |
| `/usr/local/sbin/claude-respond-to-reports` | Stromversorgungs-Check + RTL-SDR Blog Update-Check |
| `/usr/local/sbin/daily-summary` | Spannungsüberwachung |
| `/home/pi/CLAUDE.md` | Implemented Changes + GitHub Repos + Lessons Learned |
| `/home/pi/docs/MONITORING.md` | Hardware-Diagnose + Spannungsüberwachung |
| `/home/pi/docs/README.md` | VOLTAGE-MONITORING.md + OGN-Updates |

### Neue Dateien

| Datei | Zweck |
|-------|-------|
| `/home/pi/docs/VOLTAGE-MONITORING.md` | Spannungsüberwachungs-Dokumentation |
| `/home/pi/docs/HARDWARE-DIAGNOSE-2026-01-29.md` | RTL-SDR & Power Diagnose-Bericht |
| `/home/pi/docs/voltage-monitoring-examples.sh` | Beispiel-Code für Spannungsüberwachung |
| `/home/pi/rtl-sdr-blog/` | RTL-SDR Blog Library Repository (v1.3.6) |
| `/usr/local/lib/librtlsdr.so.0` | Neue V4-optimierte Library |

### System-Änderungen

| Komponente | Vorher | Nachher |
|------------|--------|---------|
| librtlsdr | Debian 0.6.0-4 (2012) | RTL-SDR Blog v1.3.6 (2024) |
| ogn-rf Library-Link | `/lib/.../librtlsdr.so.0` | `/usr/local/lib/librtlsdr.so.0` |
| rbfeeder Library-Link | `/lib/.../librtlsdr.so.0` | `/usr/local/lib/librtlsdr.so.0` |
| PLL-Meldungen | Permanent | Nur während Initialisierung |
| V4-Erkennung | Generic | "Blog V4" explizit |

---

## Services Status

**Alle 21 Services laufen stabil:**
- ✅ Core: readsb
- ✅ Upload Feeds (9): piaware, fr24feed, adsbexchange, adsb.fi, opensky, theairtraffic, rbfeeder, airplanes, pfclient
- ✅ MLAT (4): mlathub, adsbexchange-mlat, adsbfi-mlat, airplanes-mlat
- ✅ Web (3): tar1090, graphs1090, adsbexchange-stats
- ✅ OGN (3): ogn-rf-procserv, ogn-decode-procserv, ogn2dump1090
- ✅ DragonSync (1): dragonsync
- ✅ Watchdogs: feeder-watchdog.timer, wartungs-watchdog.timer

---

## Lessons Learned

1. **Debian librtlsdr veraltet:** 0.6.0-4 aus 2012 kennt V4 nicht
2. **V4-Library Vorrang:** `/usr/local/lib/` überschreibt `/lib/` (ldconfig)
3. **ldd für Diagnose:** `ldd /usr/bin/rbfeeder | grep rtlsdr` zeigt Library
4. **PLL-Meldungen bei V4 normal:** Während Initialisierung/FFTW-Benchmarking
5. **gcc Security Hardening:** gcc nur für root → Build als root nötig
6. **rbfeeder Dependency:** Hängt von librtlsdr0 ab, mit --force-depends reparieren
7. **Spannungsüberwachung kritisch:** 0x0 ist einziger OK-Wert, alle anderen = Problem

---

## Nächste Schritte

1. ⏳ FFTW-Benchmarking abwarten (~15 Min) - Läuft automatisch
2. ⏳ Morgen tagsüber OGN-Empfang prüfen (Segelflugzeuge auf live.glidernet.org)
3. ✅ RTL-SDR Blog Library Update-Check läuft automatisch wöchentlich
4. ✅ Spannungsüberwachung läuft in allen 3 Skripten

---

**Session erfolgreich abgeschlossen am 2026-01-29 23:47 Uhr**
