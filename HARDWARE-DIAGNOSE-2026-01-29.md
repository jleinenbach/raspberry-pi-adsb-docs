# RTL-SDR & Stromversorgungs-Diagnose
**Datum:** 2026-01-29
**System:** Raspberry Pi 4 Model B | Debian 12 (Bookworm)

## Schritt 1: Treiber-Validierung

**Befehl:** `rtl_test -d 1 -t`

**Output-Analyse:**
```
Device 1: RTLSDRBlog, Blog V4, SN: 00000001
Found Rafael Micro R828D tuner
```

**Analyse-Regel A:** ✅ String "R828D" gefunden
**Analyse-Regel B:** ✅ "RTL-SDR Blog V4" erkannt (nicht nur "Generic RTL2832U")

**Ergebnis:** Der **richtige V4-spezifische Treiber** ist installiert! Der R828D-Tuner wurde korrekt identifiziert.

---

## Schritt 2: Spannungs-Überwachung

**Befehl:** `vcgencmd get_throttled`

**Output:** `throttled=0x0`

**Bit-Analyse:**
- Bit 0 (aktuell Unterspannung): `0` = NEIN ✅
- Bit 16 (jemals Unterspannung): `0` = NEIN ✅

**Hex-Code-Interpretation:**
- `0x0` ist der **einzige akzeptable Wert** ✅
- Keine aktuellen Spannungsprobleme
- Keine historischen Spannungsprobleme seit Boot

---

## Zusammenfassung

| Kategorie | Status | Begründung |
|-----------|--------|------------|
| **Treiber-Status** | ✅ OK | RTL-SDR Blog V4 Treiber korrekt installiert, R828D-Tuner erkannt |
| **Strom-Status** | ✅ STABIL | vcgencmd = 0x0, keine Under-voltage Events |

## Empfehlung

**Keine Maßnahmen erforderlich!**

Das System ist optimal konfiguriert:
- ✅ Korrekter V4-Treiber aktiv
- ✅ R828D-Tuner wird verwendet
- ✅ Stabile Stromversorgung ohne Throttling
- ✅ Netzteil dimensioniert ausreichend

## Hardware-Details

**Erkannte Devices:**
- Device 0: Realtek RTL2832U (ADS-B, 1090 MHz)
- Device 1: RTLSDRBlog Blog V4 (OGN, 868 MHz) ← **Aktiv für OGN**

**Tuner:** Rafael Micro R828D (V4-spezifisch)
**Gain-Range:** 0.0 - 49.6 dB (29 Stufen)

---

## Hinweis zur kontinuierlichen Überwachung

Die Spannungsüberwachung wird jetzt in folgende Skripte integriert:
- `/usr/local/sbin/telegram-bot-daemon` (/status)
- `/usr/local/sbin/claude-respond-to-reports` (Wartung)
- `/usr/local/sbin/daily-summary` (Täglicher Bericht)

**Alarm-Schwellwerte:**
- `0x0` = 🟢 OK
- `0x50000` oder höher = 🟡 Warnung (Unterspannung in Vergangenheit)
- `0x50005` = 🔴 Kritisch (aktuell Unterspannung)
