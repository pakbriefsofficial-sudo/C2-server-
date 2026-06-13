#!/bin/bash
# APT C2 MASTER LAUNCHER
# One command to access everything

echo "╔══════════════════════════════════════════╗"
echo "║  💀 APT C2 MASTER CONTROL PANEL        ║"
echo "║  ALL 15 PHASES — ONE INTERFACE         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

echo "Select Phase:"
echo "  1) C2 Listener          9)  Anti-Forensics"
echo "  2) Victim Manager       10) Persistence"
echo "  3) Auto-Reconnect       11) VPN Pivot"
echo "  4) Data Collection      12) AD Attack"
echo "  5) Anomaly Detection    13) CI/CD Poison"
echo "  6) Kill Switch          14) Email Hijack"
echo "  7) Domain Fronting      15) Domain Admin"
echo "  8) Kernel Implant       0)  EXIT"
echo ""

read -r -p "Choose Phase: " phase

case $phase in
    1) bash ~/c2_server/listener/real_c2.sh ;;
    2) bash ~/c2_server/listener/victim_manager.sh ;;
    3) bash ~/c2_server/listener/auto_reconnect.sh ;;
    4) bash ~/c2_server/modules/data_collect/data_harvester.sh ;;
    5) bash ~/c2_server/modules/anomaly_detector.sh ;;
    6) bash ~/c2_server/modules/kill_switch.sh ;;
    7) bash ~/c2_server/modules/stealth/domain_fronting.sh ;;
    8) bash ~/c2_server/modules/stealth/kernel_implant.sh ;;
    9) bash ~/c2_server/modules/stealth/anti_forensics.sh ;;
    10) bash ~/c2_server/modules/stealth/persistence.sh ;;
    11) bash ~/c2_server/modules/corporate/vpn_pivot.sh ;;
    12) bash ~/c2_server/modules/corporate/ad_attack.sh ;;
    13) bash ~/c2_server/modules/corporate/ci_cd_poison.sh ;;
    14) bash ~/c2_server/modules/corporate/email_hijack.sh ;;
    15) bash ~/c2_server/modules/corporate/domain_admin.sh ;;
    0) exit 0 ;;
esac
