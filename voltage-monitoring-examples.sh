#!/bin/bash
# Beispiele für USB-Spannungsüberwachung
# Dokumentiert: 2026-01-29

#===============================================================================
# Einfache Funktion mit Ausgabe
#===============================================================================
get_voltage_status() {
    local throttled=$(vcgencmd get_throttled 2>/dev/null | cut -d= -f2)
    local hex_value="${throttled:-0x0}"
    local dec_value=$((hex_value))
    
    # Bit 0: Aktuell Unterspannung
    # Bit 16 (0x10000): Jemals Unterspannung seit Boot
    local bit0=$((dec_value & 0x1))
    local bit16=$((dec_value & 0x10000))
    
    if [ "$hex_value" = "0x0" ]; then
        echo "ok|0x0|🟢 Stabil"
    elif [ "$bit0" -eq 1 ]; then
        echo "critical|$hex_value|🔴 Unterspannung JETZT!"
    elif [ "$bit16" -ne 0 ]; then
        echo "warning|$hex_value|🟡 Unterspannung (Vergangenheit)"
    else
        echo "unknown|$hex_value|⚪ Unbekannt"
    fi
}

#===============================================================================
# Verwendung in Monitoring-Skripten (Variablen)
#===============================================================================
check_voltage_for_monitoring() {
    local throttled=$(vcgencmd get_throttled 2>/dev/null | cut -d= -f2)
    throttled="${throttled:-0x0}"
    local throttled_dec=$((throttled))
    local bit0=$((throttled_dec & 0x1))
    local bit16=$((throttled_dec & 0x10000))
    
    local volt_icon="🟢"
    local volt_status="Stabil"
    
    if [ "$throttled" = "0x0" ]; then
        volt_icon="🟢"
        volt_status="Stabil"
    elif [ "$bit0" -eq 1 ]; then
        volt_icon="🔴"
        volt_status="UNTERSPANNUNG!"
    elif [ "$bit16" -ne 0 ]; then
        volt_icon="🟡"
        volt_status="War niedrig"
    fi
    
    # Für Telegram-Ausgabe
    echo "${volt_icon} Spannung: ${volt_status}"
}

#===============================================================================
# Verwendung in Report-Generierung
#===============================================================================
check_voltage_for_report() {
    vcgencmd get_throttled 2>/dev/null | while read line; do
        throttled=$(echo "$line" | cut -d= -f2)
        throttled="${throttled:-0x0}"
        throttled_dec=$((throttled))
        bit0=$((throttled_dec & 0x1))
        bit16=$((throttled_dec & 0x10000))
        
        if [ "$throttled" = "0x0" ]; then
            echo "Throttled: $throttled (🟢 Stabil)"
        elif [ "$bit0" -eq 1 ]; then
            echo "Throttled: $throttled (🔴 UNTERSPANNUNG JETZT!)"
        elif [ "$bit16" -ne 0 ]; then
            echo "Throttled: $throttled (🟡 Unterspannung in Vergangenheit)"
        else
            echo "Throttled: $throttled (⚪ Unbekannter Status)"
        fi
    done
}

#===============================================================================
# Hex-Werte Tabelle
#===============================================================================
: '
Hex-Wert    | Dezimal  | Bit 0 | Bit 16 | Bedeutung
------------|----------|-------|--------|-----------------------------
0x0         | 0        | 0     | 0      | Keine Probleme
0x1         | 1        | 1     | 0      | Aktuell Unterspannung
0x10000     | 65536    | 0     | 1      | War Unterspannung
0x10001     | 65537    | 1     | 1      | War + Aktuell Unterspannung
0x50000     | 327680   | 0     | 1      | War Unterspannung + Throttling
0x50005     | 327685   | 1     | 1      | Aktuell Unterspannung + Throttling

Alle Bits im Detail:
Bit  | Hex      | Bedeutung
-----|----------|------------------------------
0    | 0x1      | Aktuell Unterspannung (<4.63V)
1    | 0x2      | Aktuell ARM-Frequenz gedrosselt
2    | 0x4      | Aktuell Throttling aktiv
3    | 0x8      | Aktuell Soft-Temp-Limit
16   | 0x10000  | Jemals Unterspannung seit Boot
17   | 0x20000  | Jemals ARM-Frequenz gedrosselt
18   | 0x40000  | Jemals Throttling aktiv
19   | 0x80000  | Jemals Soft-Temp-Limit
'

# Beispiel-Tests
echo "=== Test-Ausgaben ==="
echo "1. Einfache Status-Funktion:"
get_voltage_status

echo -e "\n2. Monitoring-Format:"
check_voltage_for_monitoring

echo -e "\n3. Report-Format:"
check_voltage_for_report

echo -e "\n4. Rohwert:"
vcgencmd get_throttled
