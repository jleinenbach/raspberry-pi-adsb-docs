# System Maintenance Assistant - Vorlage

**System:** [SYSTEMNAME] | [OS/DISTRO]
**Standort:** [BESCHREIBUNG]

> **Dokumentation:** `~/docs/SERVICES.md` | `~/docs/MONITORING.md`

---

## MANDATORY: Status-Abfrage

**Trigger:** "Status", "Systemzustand", "Was steht an?", "Wartung", "Health"

```bash
# Errors 24h
docker logs --since 24h [CONTAINER] 2>&1 | grep -iE "error|warn|fail" | tail -30
# Oder für systemd:
# journalctl -p err --since "24 hours ago" --no-pager | tail -30

# Container-Status
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Ressourcen
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
df -h | grep -E "^/dev|Filesystem"

# Wartungsergebnis (falls vorhanden)
# cat /var/log/maintenance/response-$(date +%Y-%m-%d).log 2>/dev/null | tail -30
```

**Format:**
```
## System Status [DATUM]
### Current Issues / New Recommendations / Pending / Verification
```

**Danach:** CLAUDE.md aktualisieren (Declined/Pending/Implemented)

---

## Declined Recommendations
*NICHT erneut vorschlagen!*

| Datum | Item | Grund |
|-------|------|-------|
| YYYY-MM-DD | [Empfehlung] | [Begründung des Users] |

---

## Pending Recommendations
| Source | Recommendation | Risk |
|--------|----------------|------|
| - | *Keine offenen Empfehlungen* | - |

---

## Implemented Changes (Gruppiert)

### Security & Hardening
- [Änderungen hier dokumentieren]

### Services & Container
- [Container-Liste und Konfiguration]

### Monitoring & Automation
- [Watchdogs, Cronjobs, Alerts]

### System
- [Backup, Updates, Netzwerk]

---

## Benachrichtigungen (Optional)
**Methode:** [Telegram/Email/Webhook/...]
**Config:** [Pfad zur Konfiguration]

| Trigger | Beschreibung |
|---------|--------------|
| Service down | Container gestoppt/crashed |
| Disk > 90% | Speicherplatz kritisch |
| Backup failed | Backup-Job fehlgeschlagen |

---

## Self-Healing Regeln

### OHNE Rückfrage reparieren
- Container nicht laufend → `docker restart`
- Container nach Update kaputt → Rollback versuchen
- Log-Rotation voll → Aufräumen
- Broken mounts/permissions → fix

### MIT Rückfrage
- Container-Updates (neue Images)
- Konfigurationsänderungen
- Neue Services/Container
- Wesentliche Systemänderungen

### Nur melden
- Hardware-Probleme
- Netzwerk-Probleme (extern)
- Unbekannte Fehler
- Datenbank-Korruption

---

## Überwachte Services
*Diese Container/Services werden überwacht*

| # | Container | Typ | Beschreibung |
|---|-----------|-----|--------------|
| 1 | [name] | [web/db/...] | [Beschreibung] |

---

## Docker-Befehle Referenz

```bash
# Container-Status
docker ps -a
docker logs --tail 100 [CONTAINER]
docker inspect [CONTAINER]

# Neustart
docker restart [CONTAINER]
docker-compose -f [FILE] restart [SERVICE]

# Update (mit Backup!)
docker pull [IMAGE]
docker-compose -f [FILE] up -d [SERVICE]

# Aufräumen
docker system prune -f
docker volume prune -f  # VORSICHT: Löscht ungenutzte Volumes!

# Ressourcen
docker stats
docker system df
```

---

## Backup-Strategie

| Was | Wohin | Wann | Aufbewahrung |
|-----|-------|------|--------------|
| [Daten] | [Ziel] | [Schedule] | [Anzahl] |

**Backup prüfen:**
```bash
ls -lh [BACKUP_PATH]
# Letztes Backup älter als X Tage?
find [BACKUP_PATH] -name "*.tar.gz" -mtime +7
```

---

## Lessons Learned

### Docker-Fallen
| Problem | Lösung |
|---------|--------|
| Container startet nicht | `docker logs [CONTAINER]` prüfen |
| Port bereits belegt | `netstat -tlnp | grep [PORT]` |
| Volume-Permissions | `chown -R [UID]:[GID] [PATH]` |
| Image nicht gefunden | Registry-URL + Tag prüfen |

### Allgemein
| Erkenntnis | Kontext |
|------------|---------|
| Vor Updates: Backup! | Rollback-Fähigkeit sicherstellen |
| Logs rotieren | Sonst Disk voll |
| Healthchecks nutzen | Automatische Erkennung von Problemen |

---

## Checkliste: Neuen Container hinzufügen

1. [ ] Image testen (lokal oder Staging)
2. [ ] docker-compose.yml erweitern
3. [ ] Volumes/Mounts definieren
4. [ ] Netzwerk/Ports konfigurieren
5. [ ] Healthcheck hinzufügen
6. [ ] Monitoring erweitern
7. [ ] Backup-Strategie für Daten
8. [ ] CLAUDE.md aktualisieren

---

## QNAP-spezifisch (falls zutreffend)

### Container Station
- Web UI: https://[NAS]:8080/containerstation/
- CLI: `docker` direkt via SSH

### Pfade
- Container-Daten: `/share/Container/`
- Volumes: `/share/Container/volumes/`
- Compose-Files: `/share/Container/compose/`

### Einschränkungen
- Kein systemd (QTS verwendet init)
- Docker-Version ggf. älter
- Ressourcen mit NAS geteilt

### NAS-Befehle
```bash
# System-Info
uname -a
cat /etc/config/qpkg.conf | grep -A5 "ContainerStation"

# Speicher
df -h /share/
```
