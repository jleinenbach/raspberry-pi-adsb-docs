# Monitoring & Automation Scripts

Diese Skripte überwachen und warten das Raspberry Pi ADS-B/OGN/Drone Receiver System automatisch.

## 📋 Übersicht

| Script | Funktion | Interval |
|--------|----------|----------|
| **feeder-watchdog** | Überwacht 18 Services (nach Kategorien), startet neu bei Ausfall | 5min |
| **wartungs-watchdog** | Überwacht Claude-Wartung, eskaliert bei Timeout | 10min |
| **claude-respond-to-reports** | Tägliche Wartung: CVEs, Updates, Security-Checks | 07:00 täglich |
| **telegram-bot-daemon** | Telegram-Bot für /status, /stats, /wartung, /do | Daemon |
| **telegram-secretary** | Validiert User-Input, blockiert gefährliche Befehle | On-demand |
| **do-queue-worker** | Verarbeitet /do Queue mit 2min Delay | 2min |
| **sd-health-check** | Prüft SD-Karte auf Fehler, warnt vor Ausfall | Wöchentlich |
| **telegram-notify** | Sendet Telegram-Nachrichten (Hilfsfunktion) | Library |
| **telegram-ask** | Interaktive Ja/Nein-Fragen via Telegram | Library |

## 🔐 Konfiguration

**Wichtig:** Die Skripte benötigen folgende Umgebungsvariablen bzw. Config-Files:

```bash
# Telegram Bot (für alle telegram-* Skripte)
TELEGRAM_BOT_TOKEN="your_bot_token_here"
TELEGRAM_CHAT_ID="your_chat_id_here"

# Optional: Claude API (für erweiterte Funktionen)
ANTHROPIC_API_KEY="your_api_key_here"  # Nur für claude-respond-to-reports
```

### Config-File Beispiel

Erstelle `/etc/telegram-bot.conf`:
```bash
TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
TELEGRAM_CHAT_ID="123456789"
```

Permissions:
```bash
sudo chmod 600 /etc/telegram-bot.conf
sudo chown root:root /etc/telegram-bot.conf
```

## 🚀 Installation

### 1. Skripte kopieren

```bash
sudo cp scripts/*.sh /usr/local/sbin/
sudo chmod +x /usr/local/sbin/{feeder-watchdog,wartungs-watchdog,claude-respond-to-reports}
```

### 2. Systemd Timer erstellen

**feeder-watchdog.timer** (5min):
```ini
[Unit]
Description=Feeder Watchdog Timer

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=30s

[Install]
WantedBy=timers.target
```

**wartungs-watchdog.timer** (10min):
```ini
[Unit]
Description=Wartungs Watchdog Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=10min
AccuracySec=1min

[Install]
WantedBy=timers.target
```

**claude-daily-maintenance.timer** (täglich 07:00):
```ini
[Unit]
Description=Daily Claude Maintenance

[Timer]
OnCalendar=*-*-* 07:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

### 3. Services aktivieren

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now feeder-watchdog.timer
sudo systemctl enable --now wartungs-watchdog.timer
sudo systemctl enable --now claude-daily-maintenance.timer
```

## 📊 Monitoring

### Logs anzeigen

```bash
# Watchdog-Logs
sudo tail -f /var/log/feeder-watchdog.log
sudo tail -f /var/log/wartungs-watchdog.log

# Wartungs-Reports
sudo tail -f /var/log/claude-maintenance/response-$(date +%Y-%m-%d).log
```

### Status prüfen

```bash
sudo systemctl status feeder-watchdog.timer
sudo systemctl status wartungs-watchdog.timer
journalctl -u feeder-watchdog.service -f
```

## 🔧 Anpassung

### Überwachte Services (18 nach Kategorien)

Die Services sind nach Funktion kategorisiert:

| Kategorie | Services | Anzahl |
|-----------|----------|--------|
| **Core ADS-B** | readsb | 1 |
| **Upload Feeds** | piaware, fr24feed, adsbexchange-feed, adsbfi-feed, opensky-feeder, theairtraffic-feed, rbfeeder, airplanes-feed, pfclient | 9 |
| **MLAT** | adsbexchange-mlat, adsbfi-mlat, airplanes-mlat | 3 |
| **Web** | tar1090, graphs1090, adsbexchange-stats | 3 |
| **DragonSync** | dragonsync | 1 |

**Telegram /status zeigt kategorisiert:**
```
*Services*
🟢 Core (readsb)
🟢 Upload Feeds (9/9)
🟢 MLAT Services (4/4)
🟢 Web (3/3)
🟢 DragonSync
```

**Ändern:** Editiere die Service-Listen in `feeder-watchdog`, `telegram-bot-daemon` und `claude-respond-to-reports` synchron!

### Eskalations-Strategie (feeder-watchdog)

Bei Ausfall wird automatisch:
1. **1. Versuch:** `systemctl restart <service>`
2. **2. Versuch:** `systemctl restart <service>` (nach 5min)
3. **3. Versuch:** Telegram-Warnung + AppArmor-Check
4. **Aufgeben:** Nach 3 erfolglosen Versuchen (Telegram-Eskalation)

### Telegram-Befehle

**Verfügbare Befehle:**
- `/status` - System Health (kategorisiert nach Core, Feeds, MLAT, Web, DragonSync)
- `/stats` - ADS-B Statistiken (Flugzeuge, Reichweite, MLAT-Rückkanal)
- `/log` - Letzte Wartung anzeigen
- `/do <cmd>` - Schnelle Anweisung an Claude (Queue-System)
- `/wartung [text]` - Volle Claude-Wartung starten
- `/abbrechen` - Offene Session abbrechen

**Befehle erweitern:** Siehe `telegram-bot-daemon` - Neue Befehle in `handle_command()` hinzufügen.

## ⚠️ Sicherheit

- ✅ Scripts laufen mit minimalen Rechten (User: pi wo möglich)
- ✅ Input-Sanitization in `telegram-secretary`
- ✅ Blacklist für gefährliche Befehle
- ✅ Command-Injection-Schutz via `sanitize_for_prompt()`
- ✅ Secrets in separater Config-Datei (nicht in Scripts)

**Lessons Learned:**
- Niemals `eval` oder ungesanitizten User-Input in Bash
- Immer `flock` für atomare Operationen (Queue)
- `set -o pipefail` für Fehler-Erkennung in Pipes
- Curl immer mit `--max-time` Timeout

## 📖 Weitere Dokumentation

Siehe Hauptdokumentation:
- [MONITORING.md](../MONITORING.md) - Überwachungs-Architektur
- [FEEDS.md](../FEEDS.md) - Feeder-Konfiguration
- [DRAGONSYNC.md](../DRAGONSYNC.md) - Drohnen-Erkennung

