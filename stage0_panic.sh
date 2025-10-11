#!/usr/bin/env bash
# stage0_panic.sh - Debiana Way - Immediate containment & volatile collection
# Usage: as root: CONFIRM=I_AM_OWNER_AND_ACCEPT ./stage0_panic.sh
# WARNING: destructive actions (network down, process kills, sudoers lock, account lock).
set -euo pipefail
IFS=$'\n\t'

# --- Configurable settings (edit before running if needed) ---
TOKEN="I_AM_OWNER_AND_ACCEPT"     # must match CONFIRM env to run
FORensic_MOUNT="/mnt/usb"         # preferred external mount (optional)
SAVE_TO_ROOT_IF_NO_USB=true       # if no /mnt/usb, save to /root
STOP_SERVICES="sshd docker podman apache2 nginx kubelet containerd"  # services to stop
KILL_NETWORK_PROCS=true           # kill processes that hold sockets
LOCK_USERS=true                   # lock all non-system users (UID>=1000)
LOCK_SUDOERS=true                 # move /etc/sudoers.d and replace /etc/sudoers minimally
UNLOAD_MODULES=false              # set true only if you know what you're doing
# END config

# Safety: require explicit CONFIRM token environment variable
if [ "${CONFIRM:-}" != "${TOKEN}" ]; then
  cat <<EOF
ERROR: This is a high-impact containment script.
You must run it with the confirmation token environment variable:

  CONFIRM=${TOKEN} ./stage0_panic.sh

If you did not intend to perform destructive containment, abort now.
EOF
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: must be run as root" >&2
  exit 2
fi

TS=$(date -u +%Y%m%dT%H%M%SZ)
OUTDIR="${FORensic_MOUNT}/forensics-${TS}"
if [ ! -d "${FORensic_MOUNT}" ]; then
  if [ "${SAVE_TO_ROOT_IF_NO_USB}" = true ]; then
    OUTDIR="/root/forensics-${TS}"
  else
    echo "No external mount ${FORensic_MOUNT} found and SAVE_TO_ROOT_IF_NO_USB=false. Aborting." >&2
    exit 3
  fi
fi
mkdir -p "${OUTDIR}"
chmod 700 "${OUTDIR}"
echo "[*] Forensics output -> ${OUTDIR}"

# Helper to safe-run commands and log
run_and_log() {
  echo "[*] Running: $*"
  { eval "$@" ; } >> "${OUTDIR}/command.log" 2>&1 || echo "[!] Command failed: $*" >> "${OUTDIR}/command.log"
}

# 1) Quick volatile snapshot (minimal but useful) - keep it fast
echo "[*] Collecting volatile state (quick snapshot)"
run_and_log "ps auxwwf"
run_and_log "ss -tunap"
run_and_log "lsof -nP"
run_and_log "ip -o addr show"
run_and_log "ip -o link show"
run_and_log "ip route show"
run_and_log "cat /proc/modules"
run_and_log "lsmod"
run_and_log "dmesg -T || true"
run_and_log "journalctl --no-pager -n 1000 -o short-precise || true"
run_and_log "who -a || true"
run_and_log "last -n 200 || true"
run_and_log "env || true"
run_and_log "uname -a || true"
run_and_log "cat /proc/cmdline || true"
run_and_log "stat /etc/sudoers /etc/sudoers.d/* 2>/dev/null || true"

# 1a) Try memory extraction if avml or LiME present (non-blocking)
if command -v avml >/dev/null 2>&1; then
  echo "[*] avml found - attempting memory dump (may take time)"
  run_and_log "avml ${OUTDIR}/mem-avml.raw || true"
elif [ -f /tmp/LiME.ko ] || [ -f /usr/lib/lime/lime.ko ]; then
  LIMEMOD=$( [ -f /tmp/LiME.ko ] && echo /tmp/LiME.ko || echo /usr/lib/lime/lime.ko )
  echo "[*] LiME module found at ${LIMEMOD} - attempting memory dump (may take time)"
  run_and_log "insmod ${LIMEMOD} path=${OUTDIR}/mem-lime format=lime || true"
else
  echo "[*] No avml/LiME found - memory dump skipped (if you need it, prepare tool on rescue media)"
fi

# 2) Save critical small files (configs & logs)
echo "[*] Copying critical configuration files (non-destructive)"
for f in /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/sudoers; do
  [ -f "$f" ] && cp -a "$f" "${OUTDIR}/" || true
done
cp -a /etc/sudoers.d "${OUTDIR}/" 2>/dev/null || true
cp -a /etc/ssh/sshd_config "${OUTDIR}/" 2>/dev/null || true
cp -a /var/log/auth.log* "${OUTDIR}/" 2>/dev/null || true
cp -a /var/log/syslog* "${OUTDIR}/" 2>/dev/null || true
cp -a /var/log/kern.log* "${OUTDIR}/" 2>/dev/null || true
cp -a /var/log/*journal* "${OUTDIR}/" 2>/dev/null || true
cp -a /root/.ssh "${OUTDIR}/root-ssh" 2>/dev/null || true
cp -a /home/*/.ssh "${OUTDIR}/homes-ssh" 2>/dev/null || true
cp -a /etc/cron.* /etc/cron.d "${OUTDIR}/cron" 2>/dev/null || true

# sync to flush writes
sync

# 3) Containment: network isolation
echo "[*] Containment: isolating network interfaces and firewall"
# Backup nft/iptables rules
if command -v nft >/dev/null 2>&1; then
  run_and_log "nft list ruleset > ${OUTDIR}/nft-ruleset.pre || true"
  run_and_log "nft flush ruleset || true"
  # create minimal allow-loopback ruleset
  cat > "${OUTDIR}/nft-minimal.rules" <<'NFT'
table inet filter {
  chain input { type filter hook input priority 0; policy drop; ct state established,related accept; iif "lo" accept; }
  chain forward { type filter hook forward priority 0; policy drop; }
  chain output { type filter hook output priority 0; policy drop; oif "lo" accept; }
}
NFT
  nft -f "${OUTDIR}/nft-minimal.rules" || true
else
  run_and_log "iptables-save > ${OUTDIR}/iptables.pre 2>/dev/null || true"
  run_and_log "iptables -F || true"
  run_and_log "iptables -P INPUT DROP || true"
  run_and_log "iptables -P FORWARD DROP || true"
  run_and_log "iptables -P OUTPUT DROP || true"
fi

# Bring down non-loopback interfaces (best effort)
echo "[*] Bringing down non-loopback interfaces"
for IF in $(ip -o link show | awk -F': ' '{print $2}'); do
  if [ "$IF" != "lo" ]; then
    ip link set dev "$IF" down 2>/dev/null || true
  fi
done
# Flush routes
ip route flush table main 2>/dev/null || true

# 4) Stop common network-exposed services (best-effort)
echo "[*] Stopping likely network services"
for svc in $STOP_SERVICES; do
  systemctl stop "$svc" 2>/dev/null || true
  systemctl disable "$svc" 2>/dev/null || true
done

# 5) Kill network-associated processes (if configured)
if [ "${KILL_NETWORK_PROCS}" = true ]; then
  echo "[*] Killing processes holding network sockets (aggressive)"
  # gather PIDs from ss
  PIDS=$(ss -tunap 2>/dev/null | awk '/LISTEN|ESTAB/ { for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+,/) { split($i,a,","); print a[1] } }' | sort -u) || true
  # fallback parse
  if [ -z "${PIDS}" ]; then
    PIDS=$(ss -tunap 2>/dev/null | awk '/LISTEN|ESTAB/ {print $6}' | sed 's/.*,//' | sort -u) || true
  fi
  for pid in $PIDS; do
    [ -z "$pid" ] && continue
    # avoid killing PID 1
    if [ "$pid" -ne 1 ]; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
  # also try to kill common tool pids
  killall -9 nc ncat socat wget curl python3 perl ruby bash sh sshd ssh dropbear 2>/dev/null || true
fi

# 6) Lock down sudoers and user keys (temporary containment)
if [ "${LOCK_SUDOERS}" = true ]; then
  echo "[*] Locking down sudoers (moving /etc/sudoers.d -> backup and replacing /etc/sudoers minimally)"
  mkdir -p "${OUTDIR}/sudoers-backup"
  if [ -d /etc/sudoers.d ]; then
    cp -a /etc/sudoers.d "${OUTDIR}/sudoers-backup/" 2>/dev/null || true
    mv /etc/sudoers.d /etc/sudoers.d.disabled."${TS}" 2>/dev/null || true
  fi
  cp -a /etc/sudoers "${OUTDIR}/sudoers-backup/" 2>/dev/null || true
  cat > /etc/sudoers <<'EOF'
# Emergency locked sudoers - only root may act
Defaults    env_reset,secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
root ALL=(ALL:ALL) ALL
EOF
  chmod 440 /etc/sudoers || true
fi

# 7) Lock user accounts (non-system UIDs)
if [ "${LOCK_USERS}" = true ]; then
  echo "[*] Locking non-system user accounts (UID>=1000)"
  awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd | while read -r u; do
    passwd -l "$u" 2>/dev/null || true
  done
fi

# 8) Neutralize authorized_keys (backup and truncate)
echo "[*] Backing up and clearing authorized_keys for local accounts (to prevent remote re-entry)"
mkdir -p "${OUTDIR}/ssh-auth-backup"
for auth in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
  if [ -f "$auth" ]; then
    cp -a "$auth" "${OUTDIR}/ssh-auth-backup/$(basename "$auth").$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || true
    : > "$auth" || true
  fi
done

# 9) Optional: unload non-essential kernel modules (DANGEROUS; disabled by default)
if [ "${UNLOAD_MODULES}" = true ]; then
  echo "[!] UNLOAD_MODULES=true - attempting to rmmod non-essential modules (risky)"
  # skip essential modules (very conservative list)
  SKIP="ext4 xfs btrfs nvme ahci sd_mod ext3 ext2 uio_pci_generic e1000e igb i40e virtio_net"
  for m in $(lsmod | awk 'NR>1{print $1}'); do
    if echo " ${SKIP} " | grep -q " ${m} "; then
      echo "[*] Skipping module ${m}"
      continue
    fi
    rmmod "$m" 2>/dev/null || true
  done
fi

# 10) Final sync and advisory
sync
echo "[*] CONTAINMENT actions completed. Forensics dir: ${OUTDIR}"
echo "[*] Network interfaces brought down, firewall locked to loopback, network processes killed."
echo "[*] sudoers truncated and user accounts locked (backups in forensics dir)."
echo
cat <<'ADVICE'
IMPORTANT NEXT STEPS:
- Do NOT reboot unless you accept losing memory/state.
- If possible, detach external drive with ${OUTDIR} and analyze on isolated workstation.
- Create full disk image (bit-for-bit) from another trusted host/boot media as soon as possible.
  Example (from rescue host): dd if=/dev/sdX of=/path/to/storage/image.img bs=4M conv=sync,noerror
- If legal/forensic chain-of-custody matters, record everything (who did what, when).
ADVICE

# End of script
exit 0
