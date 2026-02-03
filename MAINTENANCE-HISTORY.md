# Maintenance History

**System:** Raspberry Pi 4 Model B - ADS-B/OGN/Remote ID Feeder
**Letzte Aktualisierung:** 2026-02-03

Dokumentation von abgelehnten und ausstehenden Wartungsempfehlungen.

---

## Declined Recommendations
*NICHT erneut vorschlagen!*

| Datum | Item | Grund |
|-------|------|-------|
| 2026-01-16 | USB-1000: USB storage deaktivieren | User will USB behalten |
| 2026-01-16 | AUTH-9282: Password expiration | User: NIEMALS |
| 2026-01-16 | AUTH-9262: PAM password strength | User will nicht |
| 2026-01-16 | FILE-6310: Separate Partitionen | Nicht ohne Reinstall |
| 2026-01-16 | DEB-0880: fail2ban | System nur im LAN |
| 2026-01-18 | SSH-7408: X11/Agent/TCP Forwarding | User: Nein |
| 2026-01-18 | BANN-7126/7130: Login Banner | User: Nein |
| 2026-01-19 | smartmontools | Nicht sinnvoll für SD-Karten |
| 2026-01-25 | KRNL-5788: Kernel-Update | Bereits auf neuestem Stand (6.12.62) |
| 2026-01-25 | LOGG-2154: External Logging | Übertrieben für LAN-System |
| 2026-01-25 | ACCT-9622: Process Accounting | Ressourcenintensiv für Pi |
| 2026-01-25 | ACCT-9628: auditd | Ressourcenintensiv für Pi |
| 2026-01-25 | CONT-8104: Docker Warnings | ARM-spezifisch, nicht änderbar |
| 2026-01-30 | SSH-7408: MaxSessions/TCPKeepAlive | Schränkt SSH-Client-Funktionalität ein |
| 2026-01-31 | BOOT-5264: systemd-analyze security | Zu umfangreich für laufende Wartung (21 Services) |
| 2026-01-31 | PROC-3614: Check IO processes | Keine IO-wartenden Prozesse gefunden |
| 2026-01-31 | FIRE-4513: iptables unused rules | Nur Docker-Regeln, alle ungenutzt (0 pkts = OK) |
| 2026-01-31 | bluez/libc CVEs | Nur in trixie gefixt, kein bookworm-Backport verfügbar |
| 2026-02-02 | CVE-2026-24061 inetutils-telnet | Benötigt libc6 >= 2.38 (Trixie), nicht auf Bookworm installierbar |

---

## Pending Recommendations

| Source | Recommendation | Risk |
|--------|----------------|------|
| *Keine* | Alle Systeme funktional | - |
