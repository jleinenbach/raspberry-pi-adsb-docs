# tar1090 Filter-Button Fix (2026-02-12)

## Problem
Mode-S und OGN Filter-Buttons waren im Dark Theme permanent weiß hinterlegt, während alle anderen Buttons dunkle Farben hatten.

## Ursache
In `/usr/local/share/tar1090/html/config.js` fehlten die Farbdefinitionen für:
- `modeS` (Mode-S Filter)
- `adsc` (wird als "OGN" angezeigt via `jaeroLabel = "OGN"`)

Wenn JavaScript `background-color: undefined` setzt, zeigt der Browser weiß an.

## Lösung
Hinzugefügt in `tableColors`:
```javascript
tableColors = {
    unselected: {
        // ...
        modeS:      "#5a5a7a",    // Blau-Violett (Mode-S) - HELLER
        adsc:       "#5a7a5a",    // Grün (OGN/JAERO) - HELLER
        // ...
    },
    selected: {
        // ...
        modeS:      "#8a8aaa",    // Helles Blau-Violett
        adsc:       "#8aaa8a",    // Helles Grün
        // ...
    },
};
```

## Dateien
- `/usr/local/share/tar1090/html/config.js` (Zeilen 120, 127)
- Backup: `/var/backups/scripts/config.js.backup-20260212-*`

## Ergebnis
✅ Alle Filter-Buttons haben jetzt konsistente dunkle Hintergrundfarben im Dark Theme
