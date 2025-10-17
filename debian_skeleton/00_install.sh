#!/bin/bash
# Step 0 - Minimal debootstrap telepítés + offline integritásvizsgálat (--strict támogatással)
# Author: Beatrix Zelezny 🐱
# Revision: 2025-10-17

set -euo pipefail

TARGET="/mnt/debian_trixie"
RELEASE="trixie"
MIRROR="http://deb.debian.org/debian"
LOGDIR="/var/log/debootstrap_integrity"
BACKUP_ROOT="/var/backups/debootstrap_integrity"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
STRICT=false

# --- argumentumkezelés ---
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=true ;;
    --help)
      echo "Usage: sudo ./00_install.sh [--strict]"
      echo "  --strict : csak valódi hibák esetén lép ki (hash/BPF/ELF módosulás)"
      exit 0
      ;;
    *)
      echo "[WARN] Ismeretlen opció: $arg"
      ;;
  esac
done

mkdir -p "$TARGET" "$LOGDIR" "$BACKUP_ROOT"

echo "[0] debootstrap indul..."
debootstrap --arch=amd64 --variant=minbase "$RELEASE" "$TARGET" "$MIRROR"

echo "[0] Telepítés kész, chroot előkészítése..."
mount -t proc none "$TARGET/proc"
mount --rbind /sys "$TARGET/sys"
mount --rbind /dev "$TARGET/dev"

echo "[0] Offline integritásellenőrzés indul..."
LOGFILE="$LOGDIR/00_integrity_$TIMESTAMP.log"
exec 3>&1 1>>"$LOGFILE" 2>&1
log() { echo "$(date +%F' '%T) $*" >&3; echo "$(date +%F' '%T) $*" >>"$LOGFILE"; }

log "[INFO] Target: $TARGET"
log "[INFO] Strict mód: $STRICT"
log "[INFO] Checking libc, ld.so and BPF integrity offline..."

# ======== 1. Libc és ld.so fájlok keresése ========
find_lib_files() {
  local prefix="$TARGET"
  find "$prefix/lib" "$prefix/lib64" "$prefix/usr/lib" "$prefix/lib/x86_64-linux-gnu" \
    -type f \( -name 'libc.so*' -o -name 'ld-linux*.so*' -o -name 'ld-*.so*' \) 2>/dev/null || true
}
LIB_FILES=$(find_lib_files)
if [ -z "$LIB_FILES" ]; then
  log "[WARN] Nem talált libc/ld fájlokat!"
else
  log "[OK] Talált fájlok:"
  printf "%s\n" "$LIB_FILES" | sed 's/^/   /'
fi

# ======== 2. SHA256 mentés ========
SHAFILE="$BACKUP_ROOT/lib_sha256_$TIMESTAMP.txt"
: >"$SHAFILE"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  sha256sum "$f" >>"$SHAFILE"
done <<<"$(printf "%s\n" "$LIB_FILES")"
log "[OK] SHA256 hash-ek mentve ide: $SHAFILE"

# ======== 3. dpkg md5sums ellenőrzés ========
MD5INFO="$TARGET/var/lib/dpkg/info"
HARD_FAIL=false
if [ -d "$MD5INFO" ] && ls "$MD5INFO"/libc6*.md5sums >/dev/null 2>&1; then
  log "[INFO] libc6 md5sums fájl megtalálva, ellenőrzés indul..."
  while read -r sum path; do
    fullpath="$TARGET/$path"
    [ -f "$fullpath" ] || { log "[WARN] hiányzik: $fullpath"; continue; }
    md5calc=$(md5sum "$fullpath" | awk '{print $1}')
    expected=$(awk -v p="$path" '$2==p{print $1}' "$MD5INFO"/libc6*.md5sums)
    if [ "$md5calc" != "$expected" ]; then
      log "[ALERT] MD5 eltérés: $fullpath"
      HARD_FAIL=true
    else
      log "[OK] $fullpath md5 rendben"
    fi
  done < <(awk '{print $1 " " $2}' "$MD5INFO"/libc6*.md5sums)
else
  log "[INFO] Nincs libc6 md5sums információ, dpkg ellenőrzés kihagyva."
fi

# ======== 4. ELF sanity check ========
ELF_ALERT=false
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if file "$f" | grep -qi 'ELF'; then
    interp=$(readelf -l "$f" 2>/dev/null | awk '/INTERP/{print $2}' | tr -d '[]' || true)
    if [ -n "$interp" ] && ! echo "$interp" | grep -qE '/lib.*/ld'; then
      log "[WARN] Szokatlan INTERP útvonal: $interp ($f)"
      $STRICT || continue
    fi
    if strings "$f" | grep -i -E 'bpf|ebpf|prog_attach|kprobe' >/dev/null 2>&1; then
      log "[ALERT] Gyanús BPF string a binárisban: $f"
      ELF_ALERT=true
    fi
  fi
done <<<"$(printf "%s\n" "$LIB_FILES")"

# ======== 5. BPF / eBPF jelek ========
BPF_ALERT=false
if [ -d /sys/fs/bpf ] && [ "$(ls -A /sys/fs/bpf 2>/dev/null || true)" != "" ]; then
  log "[ALERT] /sys/fs/bpf nem üres – pinned BPF objektumok lehetnek!"
  BPF_ALERT=true
fi

if command -v bpftool >/dev/null 2>&1; then
  bpftool prog show >"$LOGDIR/bpftool_prog_$TIMESTAMP.txt" 2>/dev/null || true
  if grep -i pin "$LOGDIR/bpftool_prog_$TIMESTAMP.txt" >/dev/null 2>&1; then
    log "[ALERT] bpftool pinned objektumokat mutat!"
    BPF_ALERT=true
  fi
else
  log "[INFO] bpftool nem elérhető – kihagyva."
fi

if lsmod | grep -i bpf >/dev/null 2>&1; then
  log "[ALERT] BPF modulok betöltve!"
  BPF_ALERT=true
else
  log "[OK] Nincsenek betöltött bpf modulok."
fi

# ======== 6. SUID/SGID check ========
find "$TARGET/lib" "$TARGET/usr/lib" -xdev -type f \( -perm -4000 -o -perm -2000 \) \
  -print >"$BACKUP_ROOT/suid_list_$TIMESTAMP.txt" 2>/dev/null || true
if [ -s "$BACKUP_ROOT/suid_list_$TIMESTAMP.txt" ]; then
  log "[WARN] Talált SUID/SGID fájlok – lista: $BACKUP_ROOT/suid_list_$TIMESTAMP.txt"
fi

# ======== 7. Értékelés ========
if $HARD_FAIL || $ELF_ALERT || $BPF_ALERT; then
  log "[FAIL] Kritikus eltérés vagy gyanús viselkedés észlelve!"
  echo "[FAIL] Integritási problémák! Nézd át a logot: $LOGFILE" >&3
  exit 11
else
  log "[PASS] Minden lényegi integritásellenőrzés sikeres."
  echo "[OK] Továbbhaladhatsz a következő ágra." >&3
fi

exit 0
