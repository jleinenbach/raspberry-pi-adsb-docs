# USB-Spannungsüberwachung - Implementierung 2026-01-29

## Übersicht

Die USB-Spannungsüberwachung wurde in drei kritische Monitoring-Skripte integriert, um Netzteil-Probleme, USB-Überlastung und defekte Kabel frühzeitig zu erkennen.

## Implementierte Skripte

### 1. Telegram Bot (/status)

**Datei:** `/usr/local/sbin/telegram-bot-daemon`
**Zeilen:** 264-281

**Code:**
```bash
# Spannungsüberwachung
local throttled=$(vcgencmd get_throttled 2>/dev/null | cut -d= -f2)
local throttled="${throttled:-0x0}"
local throttled_dec=$((throttled))
local volt_bit0=$((throttled_dec & 0x1))
local volt_bit16=$((throttled_dec & 0x10000))
local volt_icon="🟢"
local volt_status="OK"
if [ "$throttled" = "0x0" ]; then
    volt_icon="🟢"
    volt_status="Stabil"
elif [ "$volt_bit0" -eq 1 ]; then
    volt_icon="🔴"
    volt_status="Unterspannung JETZT!"
elif [ "$volt_bit16" -ne 0 ]; then
    volt_icon="🟡"
    volt_status="Unterspannung (Vergangenheit)"
fi
```

**Ausgabe in /status:**
```
*Hardware*
✅ SDR | 🌡 47.2°C | 📡 -25dB
🟢 Spannung: Stabil
```

### 2. Daily Summary

**Datei:** `/usr/local/sbin/daily-summary`
**Zeilen:** Nach Temperatur-Check

**Ausgabe (06:55 Uhr):**
```
*System*
⏱ Uptime: 2 days, 3 hours
💾 RAM: 45%
🌡 Temp: 47.2°C
🟢 Spannung: Stabil
```

### 3. Wartungsskript

**Datei:** `/usr/local/sbin/claude-respond-to-reports`
**Integration:** Nach USB-Hardware-Check

**Ausgabe in Wartungsbericht:**
```
=== STROMVERSORGUNG ===
Throttled: 0x0 (🟢 Stabil)
```

## Hex-Code-Tabelle

| Hex-Wert | Icon | Status | Bit 0 | Bit 16 | Bedeutung |
|----------|------|--------|-------|--------|-----------|
| `0x0` | 🟢 | Stabil | 0 | 0 | Keine Probleme |
| `0x1` | 🔴 | Unterspannung JETZT! | 1 | 0 | Aktuell unter 4.63V |
| `0x10000` | 🟡 | Unterspannung (Vergangenheit) | 0 | 1 | War niedrig seit Boot |
| `0x10001` | 🔴 | Unterspannung JETZT! | 1 | 1 | Aktuell + historisch |
| `0x50000` | 🟡 | Unterspannung (Vergangenheit) | 0 | 1 | War niedrig + Throttling |
| `0x50005` | 🔴 | Unterspannung JETZT! | 1 | 1 | Aktuell + Throttling |

## Bit-Bedeutung (vcgencmd get_throttled)

| Bit | Hex | Bedeutung |
|-----|-----|-----------|
| 0 | 0x1 | Aktuell Unterspannung (<4.63V) |
| 1 | 0x2 | Aktuell ARM-Frequenz gedrosselt |
| 2 | 0x4 | Aktuell Throttling aktiv |
| 3 | 0x8 | Aktuell Soft-Temp-Limit erreicht |
| 16 | 0x10000 | Jemals Unterspannung seit Boot |
| 17 | 0x20000 | Jemals ARM-Frequenz gedrosselt |
| 18 | 0x40000 | Jemals Throttling aktiv |
| 19 | 0x80000 | Jemals Soft-Temp-Limit erreicht |

## Häufige Probleme und Lösungen

| Problem | Hex-Wert | Ursache | Lösung |
|---------|----------|---------|--------|
| Schwaches Netzteil | 0x50000 | <3A bei Last | Offizielles RPi 4 Netzteil (5.1V/3A) |
| USB-Überlastung | 0x10000 | Zu viele Geräte | RTL-SDR an USB 3.0 (blau) |
| Defektes Kabel | 0x1 | Widerstand zu hoch | USB-C mit E-Mark Chip |
| Spannungsspitzen | 0x50005 | Instabiles Netzteil | Netzteil tauschen |

## Testing

### Manueller Test
```bash
# Rohwert prüfen
vcgencmd get_throttled
# Erwartete Ausgabe: throttled=0x0

# Daily Summary testen
sudo /usr/local/sbin/daily-summary

# Telegram Bot /status
# Erwartete Ausgabe zeigt: 🟢 Spannung: Stabil
```

### Simuliere Unterspannung (NUR ZU TESTZWECKEN)
```bash
# WARNUNG: Kann System beschädigen!
# Nur für kurze Tests verwenden
# Methode 1: USB-Hub mit vielen Geräten belasten
# Methode 2: Schwaches Netzteil temporär verwenden
```

## Dokumentation

- **MONITORING.md:** Hardware-Diagnose & Spannungsüberwachung
- **CLAUDE.md:** Implemented Changes (2026-01-29)
- **voltage-monitoring-examples.sh:** Beispiel-Code
- **HARDWARE-DIAGNOSE-2026-01-29.md:** Diagnose-Bericht

## Wichtige Hinweise

1. **RTL-SDR an USB 3.0:** Blog V4 sollte IMMER an USB 3.0 Port (blau)
2. **0x0 ist der einzige OK-Wert:** Alle anderen Werte zeigen Probleme
3. **Bit 16 bleibt gesetzt:** Nach Unterspannung bleibt Bit 16 bis zum Reboot
4. **Netzteil-Empfehlung:** Offizielles Raspberry Pi 4 Netzteil (5.1V/3A, USB-C)

## Changelog

**2026-01-29:**
- ✅ Spannungsüberwachung in telegram-bot-daemon integriert (Zeilen 264-281)
- ✅ Spannungsüberwachung in daily-summary integriert
- ✅ Spannungsüberwachung in claude-respond-to-reports integriert
- ✅ Telegram Bot neu gestartet
- ✅ Dokumentation in MONITORING.md erweitert
- ✅ Test erfolgreich (0x0 = Stabil)
