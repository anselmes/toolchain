#!/bin/bash

# MOTD Setup Script for Custom Ubuntu Image
# This script configures the Message of the Day for ONIE-compatible Ubuntu systems

setup_motd() {
  set -euo pipefail

  # Get banner type from parameter (default: ubuntu)
  local BANNER_TYPE="${1:-ubuntu}"

  # Configuration
  local MOTD_DIR="/etc/update-motd.d"
  local MOTD_SCRIPTS_DIR="/usr/local/bin/motd-scripts"
  local STATIC_MOTD="/etc/motd"

  # Validate banner type
  case "${BANNER_TYPE}" in
    ubuntu|vyos|maas|kcm|socfpga)
      echo "Setting up MOTD with '${BANNER_TYPE}' banner..."
      ;;
    *)
      echo "Warning: Unknown banner type '${BANNER_TYPE}', using 'ubuntu' as default"
      BANNER_TYPE="ubuntu"
      ;;
  esac

  # Create motd scripts directory
  mkdir -p "${MOTD_SCRIPTS_DIR}"

  # Disable default Ubuntu MOTD scripts that we don't want
  for script in 10-help-text 50-motd-news 80-esm 95-hwe-eol; do
    if [[ -f "${MOTD_DIR}/${script}" ]]; then
      chmod -x "${MOTD_DIR}/${script}" 2>/dev/null || true
    fi
  done

  # Create our custom MOTD header (00-header) based on banner type
  case "${BANNER_TYPE}" in
    ubuntu)
      cat > "${MOTD_DIR}/00-header" << 'EOF'
#!/bin/sh

printf "\n"
cat << 'BANNER'
██╗   ██╗██████╗ ██╗   ██╗███╗   ██╗████████╗██╗   ██╗
██║   ██║██╔══██╗██║   ██║████╗  ██║╚══██╔══╝██║   ██║
██║   ██║██████╔╝██║   ██║██╔██╗ ██║   ██║   ██║   ██║
██║   ██║██╔══██╗██║   ██║██║╚██╗██║   ██║   ██║   ██║
╚██████╔╝██████╔╝╚██████╔╝██║ ╚████║   ██║   ╚██████╔╝
 ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝   ╚═╝    ╚═════╝
BANNER

printf "\n"
printf "Welcome to Ubuntu\n"
printf "================================================\n\n"
EOF
      ;;

    vyos)
      cat > "${MOTD_DIR}/00-header" << 'EOF'
#!/bin/sh

printf "\n"
cat << 'BANNER'
██╗   ██╗██╗   ██╗ ██████╗ ███████╗
██║   ██║╚██╗ ██╔╝██╔═══██╗██╔════╝
██║   ██║ ╚████╔╝ ██║   ██║███████╗
╚██╗ ██╔╝  ╚██╔╝  ██║   ██║╚════██║
 ╚████╔╝    ██║   ╚██████╔╝███████║
  ╚═══╝     ╚═╝    ╚═════╝ ╚══════╝
BANNER

printf "\n"
printf "VyOS Gateway - Network Operating System\n"
printf "================================================\n\n"
EOF
      ;;

    maas)
      cat > "${MOTD_DIR}/00-header" << 'EOF'
#!/bin/sh

printf "\n"
cat << 'BANNER'
███╗   ███╗ █████╗  █████╗ ███████╗
████╗ ████║██╔══██╗██╔══██╗██╔════╝
██╔████╔██║███████║███████║███████╗
██║╚██╔╝██║██╔══██║██╔══██║╚════██║
██║ ╚═╝ ██║██║  ██║██║  ██║███████║
╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝
BANNER

printf "\n"
printf "MAAS - Metal as a Service\n"
printf "================================================\n\n"
EOF
      ;;

    kcm)
      cat > "${MOTD_DIR}/00-header" << 'EOF'
#!/bin/sh

printf "\n"
cat << 'BANNER'
██╗  ██╗ ██████╗███╗   ███╗
██║ ██╔╝██╔════╝████╗ ████║
█████╔╝ ██║     ██╔████╔██║
██╔═██╗ ██║     ██║╚██╔╝██║
██║  ██╗╚██████╗██║ ╚═╝ ██║
╚═╝  ╚═╝ ╚═════╝╚═╝     ╚═╝
BANNER

printf "\n"
printf "KCM - Kubernetes Cluster Manager\n"
printf "================================================\n\n"
EOF
      ;;

    socfpga)
      cat > "${MOTD_DIR}/00-header" << 'EOF'
#!/bin/sh

printf "\n"
cat << 'BANNER'
███████╗ ██████╗  ██████╗███████╗██████╗  ██████╗  █████╗
██╔════╝██╔═══██╗██╔════╝██╔════╝██╔══██╗██╔════╝ ██╔══██╗
███████╗██║   ██║██║     █████╗  ██████╔╝██║  ███╗███████║
╚════██║██║   ██║██║     ██╔══╝  ██╔═══╝ ██║   ██║██╔══██║
███████║╚██████╔╝╚██████╗██║     ██║     ╚██████╔╝██║  ██║
╚══════╝ ╚═════╝  ╚═════╝╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝
BANNER

printf "\n"
printf "SoCFPGA HPS - Hard Processor System\n"
printf "================================================\n\n"
EOF
      ;;
  esac

  # Create system information script (01-sysinfo)
  cat > "${MOTD_DIR}/01-sysinfo" << 'EOF'
#!/bin/bash

# System Information
printf "System Information:\n"
printf "  Hostname:     $(hostname -f)\n"
printf "  Kernel:       $(uname -r)\n"
printf "  Architecture: $(uname -m)\n"
printf "  Ubuntu:       $(lsb_release -ds 2>/dev/null || echo 'Unknown')\n"
printf "  Uptime:       $(uptime -p 2>/dev/null || echo 'Unknown')\n"
printf "  Load:         $(uptime | awk -F'load average:' '{print $2}' | xargs)\n"
printf "\n"
EOF

  # Create hardware information script (02-hardware)
  cat > "${MOTD_DIR}/02-hardware" << 'EOF'
#!/bin/bash

# Hardware Information
printf "Hardware:\n"
if command -v lscpu >/dev/null 2>&1; then
    cpu_model=$(lscpu | grep 'Model name' | cut -d: -f2 | xargs)
    printf "  CPU:          ${cpu_model:-Unknown}\n"
    printf "  CPU Cores:    $(nproc 2>/dev/null || echo 'Unknown')\n"
else
    printf "  CPU:          Unknown\n"
fi

if command -v free >/dev/null 2>&1; then
    memory=$(free -h | awk '/^Mem:/ {print $2}' | tr -d 'i')
    printf "  Memory:       ${memory} RAM\n"
else
    printf "  Memory:       Unknown\n"
fi
printf "\n"
EOF

  # Create storage information script (03-storage)
  cat > "${MOTD_DIR}/03-storage" << 'EOF'
#!/bin/bash

# Storage Information
printf "Storage:\n"
df -h 2>/dev/null | grep -E '^/dev/' | head -3 | while read filesystem size used avail percent mount; do
    printf "  %-15s %8s total, %8s used, %8s free (%s)\n" "$filesystem" "$size" "$used" "$avail" "$percent"
done
printf "\n"
EOF

  # Create network information script (04-network)
  cat > "${MOTD_DIR}/04-network" << 'EOF'
#!/bin/bash

# Network Information
printf "Network Interfaces:\n"
if command -v ip >/dev/null 2>&1; then
    ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v lo | head -5 | while read interface; do
        state=$(ip link show "$interface" 2>/dev/null | grep -o 'state [A-Z]*' | cut -d' ' -f2 || echo 'UNKNOWN')
        ip_addr=$(ip addr show "$interface" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1 || echo 'No IP')
        printf "  %-15s %s (%s)\n" "$interface:" "$state" "$ip_addr"
    done
else
    printf "  Network tools not available\n"
fi
printf "\n"
EOF

  # Create services status script (06-services)
  cat > "${MOTD_DIR}/06-services" << 'EOF'
#!/bin/bash

# Services Status
printf "Key Services:\n"
for service in ssh networking systemd-networkd; do
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            status="Active"
        else
            status="Inactive"
        fi
    else
        status="Unknown"
    fi
    printf "  %-20s %s\n" "$service:" "$status"
done
printf "\n"
EOF

  # Create footer with helpful information (99-footer) based on banner type
  case "${BANNER_TYPE}" in
    ubuntu)
      cat > "${MOTD_DIR}/99-footer" << 'EOF'
#!/bin/sh

cat << 'FOOTER'
===============================================================================
Network Configuration:
  networkctl status             - Show network status
  ip addr show                  - Display IP addresses
  systemctl status networking   - Check network service

System Administration:
  journalctl -f                 - View system logs
  systemctl status              - View service status
  htop                          - Process monitor
===============================================================================

FOOTER

printf "Current time:   $(date)\n"
printf "Documentation:  https://ubuntu.com/server/docs\n\n"
EOF
      ;;

    vyos)
      cat > "${MOTD_DIR}/99-footer" << 'EOF'
#!/bin/sh

cat << 'FOOTER'
===============================================================================
VyOS Commands:
  configure                     - Enter configuration mode
  show interfaces               - Display interface status
  show ip route                 - Display routing table
  show log                      - View system logs

Network Operations:
  ping <host>                   - Test connectivity
  traceroute <host>             - Trace network path
  monitor interface <if>        - Monitor interface traffic
===============================================================================

FOOTER

printf "Current time:   $(date)\n"
printf "Documentation:  https://docs.vyos.io/\n\n"
EOF
      ;;

    maas)
      cat > "${MOTD_DIR}/99-footer" << 'EOF'
#!/bin/sh

cat << 'FOOTER'
===============================================================================
MAAS Operations:
  maas <profile> machines list  - List all machines
  maas <profile> nodes list     - List all nodes
  maas status                   - Check MAAS status
  snap logs maas                - View MAAS logs

Metal Provisioning:
  curl http://localhost:5240/   - MAAS Web Interface
  maas <profile> boot-resources - Manage boot images
  systemctl status maas-*       - Check MAAS services
===============================================================================

FOOTER

printf "Current time:   $(date)\n"
printf "Documentation:  https://maas.io/docs\n\n"
EOF
      ;;

    kcm)
      cat > "${MOTD_DIR}/99-footer" << 'EOF'
#!/bin/sh

cat << 'FOOTER'
===============================================================================
Kubernetes Operations:
  kubectl get nodes             - List cluster nodes
  kubectl get pods --all-namespaces - List all pods
  kubectl cluster-info          - Display cluster information
  k9s                          - Kubernetes TUI

Cluster Management (k0s):
  k0s status                   - Show k0s cluster status
  k0s token create             - Create join tokens
  systemctl status k0scontroller - Check k0s controller service
  journalctl -u k0scontroller  - View k0s controller logs
===============================================================================

FOOTER

printf "Current time:   $(date)\n"
printf "Documentation:  https://docs.k0sproject.io/\n\n"
EOF
      ;;

    socfpga)
      cat > "${MOTD_DIR}/99-footer" << 'EOF'
#!/bin/sh

cat << 'FOOTER'
===============================================================================
HPS Operations:
  systemctl status             - Check system services
  ip addr show                 - Display network interfaces
  lscpu                        - Show ARM CPU information
  free -h                      - Display memory usage

HPS-FPGA Bridge:
  devmem <addr> [width] [value] - Read/write HPS-FPGA bridge
  cat /proc/device-tree/sopc@0/bridge@* - Show bridge configuration
  ls /dev/uio*                 - List UIO devices for FPGA access
  /sys/class/fpga_manager/     - FPGA manager interface

System Monitoring:
  journalctl -f                - Follow system logs
  htop                         - Process and resource monitor
  iostat                       - I/O statistics
===============================================================================

FOOTER

printf "Current time:   $(date)\n"
printf "Documentation:  https://docs.intel.com/fpga/hps/\n\n"
EOF
      ;;
  esac

  # Make all scripts executable
  chmod +x "${MOTD_DIR}"/*

  # Update /etc/issue for console login banner based on banner type
  case "${BANNER_TYPE}" in
    ubuntu)
      cat > /etc/issue << 'EOF'
Ubuntu System \n \l

================================================================================
This system is designed for network equipment and automation environments.
For more information, see the documentation or contact your system administrator.
================================================================================

EOF
      ;;

    vyos)
      cat > /etc/issue << 'EOF'
VyOS Gateway \n \l

================================================================================
Network Operating System for Routing and Firewalling
Configure with 'configure' command after login.
================================================================================

EOF
      ;;

    maas)
      cat > /etc/issue << 'EOF'
MAAS \n \l

================================================================================
Metal as a Service - Automated Server Provisioning
Web Interface: http://localhost:5240/
================================================================================

EOF
      ;;

    kcm)
      cat > /etc/issue << 'EOF'
KCM \n \l

================================================================================
Kubernetes Cluster Manager
Use 'kubectl' commands to manage the cluster.
================================================================================

EOF
      ;;

    socfpga)
      cat > /etc/issue << 'EOF'
SoCFPGA HPS \n \l

================================================================================
Intel SoC FPGA Hard Processor System
ARM-based Processing Subsystem
================================================================================

EOF
      ;;
  esac

  # Update /etc/issue.net for SSH banner based on banner type
  case "${BANNER_TYPE}" in
    ubuntu)
      cat > /etc/issue.net << 'EOF'
================================================================================
Ubuntu System

This system is designed for network equipment and automation environments.
Unauthorized access is prohibited.

For more information, contact your system administrator.
================================================================================
EOF
      ;;

    vyos)
      cat > /etc/issue.net << 'EOF'
================================================================================
VyOS Gateway

Network Operating System for Routing and Firewalling.
Unauthorized access is prohibited.

Configure with 'configure' command after login.
================================================================================
EOF
      ;;

    maas)
      cat > /etc/issue.net << 'EOF'
================================================================================
MAAS

Metal as a Service - Automated Server Provisioning.
Unauthorized access is prohibited.

Web Interface: http://localhost:5240/
================================================================================
EOF
      ;;

    kcm)
      cat > /etc/issue.net << 'EOF'
================================================================================
KCM

Kubernetes Cluster Manager.
Unauthorized access is prohibited.

Use 'kubectl' commands to manage the cluster.
================================================================================
EOF
      ;;

    socfpga)
      cat > /etc/issue.net << 'EOF'
================================================================================
SoCFPGA HPS

Intel SoC FPGA Hard Processor System.
Unauthorized access is prohibited.

ARM-based Processing Subsystem for SoC FPGA applications.
================================================================================
EOF
      ;;
  esac

  echo "✅ MOTD configuration completed successfully with ${BANNER_TYPE} banner!"
  echo "📄 The following files have been configured:"
  echo "   - ${MOTD_DIR}/00-header (Custom ${BANNER_TYPE} banner)"
  echo "   - ${MOTD_DIR}/01-sysinfo (System information)"
  echo "   - ${MOTD_DIR}/02-hardware (Hardware details)"
  echo "   - ${MOTD_DIR}/03-storage (Storage information)"
  echo "   - ${MOTD_DIR}/04-network (Network interfaces)"
  echo "   - ${MOTD_DIR}/06-services (Service status)"
  echo "   - ${MOTD_DIR}/99-footer (${BANNER_TYPE}-specific commands and tips)"
  echo "   - /etc/issue (Console login banner)"
  echo "   - /etc/issue.net (SSH login banner)"
  echo ""
  echo "🔄 To test the MOTD, run: sudo run-parts /etc/update-motd.d/"
  echo ""
  echo "💡 Usage: $0 [banner_type]"
  echo "   Available banner types: ubuntu (default), vyos, maas, kcm, socfpga"
  echo ""
}

# Show usage function
show_usage() {
  echo "Usage: $0 [BANNER_TYPE]"
  echo ""
  echo "Configure MOTD (Message of the Day) with different banner types"
  echo ""
  echo "Banner Types:"
  echo "  ubuntu    Default Ubuntu system banner"
  echo "  vyos      VyOS Gateway - Network Operating System"
  echo "  maas      MAAS - Metal as a Service"
  echo "  kcm       KCM - Kubernetes Cluster Manager"
  echo "  socfpga   SoCFPGA HPS - Hard Processor System"
  echo ""
  echo "Examples:"
  echo "  $0                # Use default ubuntu banner"
  echo "  $0 ubuntu         # Ubuntu system"
  echo "  $0 vyos           # VyOS gateway"
  echo "  $0 maas           # MAAS appliance"
  echo "  $0 kcm            # Kubernetes cluster manager"
  echo "  $0 socfpga        # SoCFPGA HPS system"
  echo ""
}

# If script is run directly (not sourced), call the function
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
  case "$1" in
    --help|-h)
      show_usage
      ;;
    *)
      setup_motd "$@"
      ;;
  esac
fi
