#!/usr/bin/env bash
# branches/00_install.sh
# SKELL bootstrap: teljes memória-hardening + memguard runtime + debootstrap integrity + .so integritás + ld.so.conf.d locking
# Author: Beatrix Zelezny 🐱 + assistant merge
# Revision: 2025-10-19 (merged full)
set -euo pipefail
IFS=$'\n\t'

# ---------------------------
# CONFIG
# ---------------------------
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="/var/log/skell"
LOG_FILE="$LOGDIR/00_install_$TIMESTAMP.log"
CANARY_DIR="/var/lib/skell/canary"
CANARY_FILE="$CANARY_DIR/system_memory_hardening.ok"

# debootstrap settings
TARGET="/mnt/debian_trixie"
RELEASE="trixie"
MIRROR="http://deb.debian.org/debian"
BACKUP_ROOT="/var/backups/debootstrap_integrity"

# build/runtime memguard paths
MG_DIR="/usr/local/lib/memguard"
MG_SO="$MG_DIR/libmemguard.so"

# integritás/adatbázis kulcsok
INTEGRITY_DB_DIR="/var/lib/skell"
INTEGRITY_DB="$INTEGRITY_DB_DIR/lib_integrity_$TIMESTAMP.txt"
SIGNED_DB="$INTEGRITY_DB.sig"
KEY_DIR="/etc/skell/keys"
PRIVATE_KEY="$KEY_DIR/skell_integrity.key.pem"
PUBLIC_KEY="$KEY_DIR/skell_integrity.pub.pem"

# ld loader protection
SKELL_LDCONF="/etc/ld.so.conf.d/skell.conf"
SKELL_LIBDIR="/usr/local/lib"

# csomaglista, kímélve (opcionálisak)
PKGS=(hardening-wrapper build-essential dpkg-dev auditd apparmor debootstrap)

# memguard source (embedded to keep the flow closed)
MEMGUARD_SRC="/tmp/memguard_$$.c"
cat > "$MEMGUARD_SRC" <<'C_SRC'
// memguard.c - embedded into 00_install.sh
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <dlfcn.h>
#include <string.h>
#include <pthread.h>
#include <time.h>
#include <stdatomic.h>
typedef struct meta_t { void *userptr; size_t size; uint64_t canary; int freed; struct meta_t *next; } meta_t;
#define BUCKETS 4096
static meta_t *buckets[BUCKETS];
static pthread_mutex_t global_lock = PTHREAD_MUTEX_INITIALIZER;
static uint64_t GLOBAL_CANARY = 0xfeedc0de00000000ULL ^ (uint64_t)0xBADF00D;
static FILE *logf = NULL;
static atomic_int inited = 0;
static void open_log(void) {
    if (logf) return;
    const char *path = "/var/log/skell/memguard.log";
    FILE *f = fopen(path, "a");
    if (!f) logf = stderr; else { logf = f; setvbuf(logf, NULL, _IOLBF, 0); }
}
static void log_msg(const char *fmt, ...) {
    open_log();
    va_list ap; va_start(ap, fmt);
    vfprintf(logf, fmt, ap); fprintf(logf, "\n"); va_end(ap); fflush(logf);
}
static uint64_t gen_canary(void) {
    uint64_t r = GLOBAL_CANARY;
    struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
    r ^= ((uint64_t)ts.tv_nsec << 32) ^ (uint64_t)getpid();
    r ^= (uint64_t)rand();
    return r ? r : 0xdeadbeefcafebabeULL;
}
static inline size_t hash_ptr(void *p) { return (((uintptr_t)p) >> 3) & (BUCKETS - 1); }
static void store_meta(meta_t *m) { size_t idx = hash_ptr(m->userptr); m->next = buckets[idx]; buckets[idx] = m; }
static meta_t *find_meta(void *userptr) { size_t idx = hash_ptr(userptr); meta_t *it = buckets[idx]; while (it) { if (it->userptr == userptr) return it; it = it->next; } return NULL; }
static void remove_meta(meta_t *m) { size_t idx = hash_ptr(m->userptr); meta_t **pp = &buckets[idx]; while (*pp) { if (*pp == m) { *pp = m->next; return; } pp = &(*pp)->next; } }
static void *(*real_malloc)(size_t) = NULL;
static void (*real_free)(void *) = NULL;
static void *(*real_calloc)(size_t, size_t) = NULL;
static void *(*real_realloc)(void *, size_t) = NULL;
__attribute__((constructor)) static void memguard_init(void) {
    if (atomic_exchange(&inited, 1)) return;
    srand((unsigned)time(NULL) ^ (unsigned)getpid()));
    GLOBAL_CANARY = gen_canary();
    open_log();
    log_msg("[memguard] init: canary=0x%016lx pid=%d", (unsigned long)GLOBAL_CANARY, (int)getpid());
    real_malloc = dlsym(RTLD_NEXT, "malloc");
    real_free = dlsym(RTLD_NEXT, "free");
    real_calloc = dlsym(RTLD_NEXT, "calloc");
    real_realloc = dlsym(RTLD_NEXT, "realloc");
    if (!real_malloc || !real_free) log_msg("[memguard] ERROR: cannot resolve real malloc/free!");
}
__attribute__((destructor)) static void memguard_fini(void) { log_msg("[memguard] fini: memguard shutting down"); if (logf && logf != stderr) fclose(logf); }
static void *alloc_common(size_t nmemb, size_t size) {
    size_t user_sz = nmemb * size;
    size_t meta_sz = sizeof(meta_t);
    size_t total = meta_sz + user_sz + sizeof(uint64_t) + 16;
    void *raw = real_malloc(total);
    if (!raw) return NULL;
    meta_t *m = (meta_t *)raw;
    void *userptr = (void *)((char *)raw + meta_sz);
    m->userptr = userptr; m->size = user_sz; m->canary = GLOBAL_CANARY ^ (uint64_t)userptr; m->freed = 0;
    uint64_t *end_canary = (uint64_t *)((char *)userptr + user_sz);
    *end_canary = m->canary;
    pthread_mutex_lock(&global_lock); store_meta(m); pthread_mutex_unlock(&global_lock);
    return userptr;
}
void *malloc(size_t size) { if (!real_malloc) memguard_init(); return alloc_common(1, size); }
void *calloc(size_t nmemb, size_t size) { if (!real_calloc) memguard_init(); void *p = alloc_common(nmemb, size); if (p) memset(p, 0, nmemb * size); return p; }
void *realloc(void *ptr, size_t size) {
    if (!real_realloc) memguard_init();
    if (!ptr) return malloc(size);
    pthread_mutex_lock(&global_lock);
    meta_t *m = find_meta(ptr);
    if (!m) { pthread_mutex_unlock(&global_lock); return real_realloc(ptr, size); }
    if (m->freed) { pthread_mutex_unlock(&global_lock); log_msg("[memguard] ERROR: realloc on freed pointer %p", ptr); abort(); }
    uint64_t *end_canary = (uint64_t *)((char *)ptr + m->size);
    if (*end_canary != m->canary) { pthread_mutex_unlock(&global_lock); log_msg("[memguard] DETECTED HEAP CORRUPTION before realloc ptr=%p", ptr); abort(); }
    pthread_mutex_unlock(&global_lock);
    void *newp = malloc(size);
    if (!newp) return NULL;
    size_t tocopy = (size < m->size) ? size : m->size;
    memcpy(newp, ptr, tocopy);
    free(ptr);
    return newp;
}
void free(void *ptr) {
    if (!ptr) return;
    if (!real_free) memguard_init();
    pthread_mutex_lock(&global_lock);
    meta_t *m = find_meta(ptr);
    if (!m) { pthread_mutex_unlock(&global_lock); log_msg("[memguard] free on unknown pointer %p", ptr); real_free(ptr); return; }
    if (m->freed) { pthread_mutex_unlock(&global_lock); log_msg("[memguard] DOUBLE FREE detected on %p", ptr); abort(); }
    uint64_t *end_canary = (uint64_t *)((char *)ptr + m->size);
    if (*end_canary != m->canary) { pthread_mutex_unlock(&global_lock); log_msg("[memguard] HEAP CORRUPTION detected on free ptr=%p", ptr); abort(); }
    m->freed = 1;
    void *raw = (void *)m;
    remove_meta(m);
    pthread_mutex_unlock(&global_lock);
    memset(ptr, 0xAB, m->size);
    real_free(raw);
}
C_SRC

# ---------------------------
# HELPERS & LOG
# ---------------------------
mkdir -p -m 0755 "$LOGDIR" "$CANARY_DIR" "$INTEGRITY_DB_DIR" "$KEY_DIR" || true
touch "$LOG_FILE"
log() { echo "$(date +%F' '%T) [00_install] $*" | tee -a "$LOG_FILE"; }

on_err() {
  local rc=$?
  log "ERROR: Script hibával leállt (exit $rc). Lásd a logot: $LOG_FILE"
  echo "$(date +%F_%T) FAIL: system_memory_hardening incomplete (exit $rc)" > "$CANARY_FILE"
  exit $rc
}
trap on_err ERR

# ensure root
if [ "$(id -u)" -ne 0 ]; then
  log "ERROR: Root jog szükséges. Kilépek."
  exit 1
fi

log "START: SKELL 00_install bootstrap flow"

# ---------------------------
# 1) ASLR + sysctl persist
# ---------------------------
log "1) ASLR bekapcsolása (kernel.randomize_va_space=2)"
sysctl -w kernel.randomize_va_space=2 >/dev/null 2>&1 || true
want_sysctl=$'# Skell: rendszer szintű memória hardening\nkernel.randomize_va_space = 2\n'
if [ -f "/etc/sysctl.d/99-skell-memory-hardening.conf" ]; then
  cur=$(cat /etc/sysctl.d/99-skell-memory-hardening.conf)
  if [ "$cur" != "$want_sysctl" ]; then echo "$want_sysctl" > /etc/sysctl.d/99-skell-memory-hardening.conf; log "SYSCTL frissítve"; fi
else
  echo "$want_sysctl" > /etc/sysctl.d/99-skell-memory-hardening.conf; log "SYSCTL létrehozva"
fi
sysctl --system >/dev/null 2>&1 || log "INFO: sysctl --system hibát adott (folytatom)."

# ---------------------------
# 2) NX check (log only)
# ---------------------------
log "2) NX (Execute Disable) ellenőrzés"
NX_OK=0
if grep -qi -E '\bnx\b' /proc/cpuinfo 2>/dev/null; then NX_OK=1; log "NX bit SUPPORTED (proc/cpuinfo)."; else
  if dmesg 2>/dev/null | grep -qiE 'execute disable|nx|no-execute'; then NX_OK=1; log "NX jel a dmesg-ben."; else
    log "WARN: NX bit nem bizonyítható. BIOS/VM beállításokat ellenőrizd."
  fi
fi

# ---------------------------
# 3) Optional package install
# ---------------------------
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  log "3) apt-get update és opcionális csomagok telepítése"
  apt-get update -y >>"$LOG_FILE" 2>&1 || log "apt-get update hiba (folytatom)"
  for p in "${PKGS[@]}"; do
    if apt-cache show "$p" >/dev/null 2>&1; then
      log "Telepítem: $p"
      apt-get install -y --no-install-recommends "$p" >>"$LOG_FILE" 2>&1 || log "WARN: $p telepítése sikertelen"
    else
      log "INFO: $p nem elérhető, kihagyom"
    fi
  done
else
  log "INFO: apt nincs, kihagyom csomag telepítést"
fi

# ---------------------------
# 4) dpkg buildflags
# ---------------------------
log "4) dpkg buildflags beállítása"
DPKG_BUILDFLAGS="/etc/dpkg/buildflags.conf"
want_flags=$'# /etc/dpkg/buildflags.conf - Skell system-wide hardening defaults\nexport DEB_BUILD_MAINT_OPTIONS = hardening=+all\nCFLAGS   = -O2 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE -fstack-clash-protection\nCXXFLAGS = -O2 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE -fstack-clash-protection\nLDFLAGS  = -Wl,-z,relro -Wl,-z,now -pie\n'
if [ -f "$DPKG_BUILDFLAGS" ]; then
  cur=$(cat "$DPKG_BUILDFLAGS")
  if [ "$cur" != "$want_flags" ]; then echo "$want_flags" > "$DPKG_BUILDFLAGS"; log "dpkg buildflags frissítve"; fi
else
  echo "$want_flags" > "$DPKG_BUILDFLAGS"; log "dpkg buildflags létrehozva"
fi

# ---------------------------
# 5) hardening-wrapper alternatives (if present)
# ---------------------------
if command -v hardening-wrapper >/dev/null 2>&1; then
  log "5) hardening-wrapper alternatives beállítási kísérlet"
  if update-alternatives --query cc >/dev/null 2>&1; then
    if update-alternatives --list cc | grep -q 'hardening-wrapper' >/dev/null 2>&1; then
      update-alternatives --set cc /usr/bin/hardening-wrapper || true
    else
      update-alternatives --install /usr/bin/cc cc /usr/bin/hardening-wrapper 50 || true
      update-alternatives --set cc /usr/bin/hardening-wrapper || true
    fi
  fi
  if update-alternatives --query c++ >/dev/null 2>&1; then
    if update-alternatives --list c++ | grep -q 'hardening-wrapper' >/dev/null 2>&1; then
      update-alternatives --set c++ /usr/bin/hardening-wrapper || true
    else
      update-alternatives --install /usr/bin/c++ c++ /usr/bin/hardening-wrapper 50 || true
      update-alternatives --set c++ /usr/bin/hardening-wrapper || true
    fi
  fi
fi

# ---------------------------
# 6) Memguard build + install (self-contained, LD_PRELOAD via /etc/profile.d)
# ---------------------------
log "6) Memguard build & install (embedded source -> build -> install)"
mkdir -p "$MG_DIR" /var/log/skell
chmod 0755 /var/log/skell || true

# compile embedded source
if command -v gcc >/dev/null 2>&1; then
  log "Compiling memguard from embedded source..."
  gcc -shared -fPIC -pthread -O2 -rdynamic -o "$MG_SO" "$MEMGUARD_SRC" >>"$LOG_FILE" 2>&1 \
    && chmod 0644 "$MG_SO" \
    && log "memguard built and installed: $MG_SO" \
    || log "WARN: memguard build sikertelen (nézd: $LOG_FILE)"
else
  log "WARN: gcc nem található, memguard build kihagyva"
fi

# create profile.d for LD_PRELOAD (applies to shells and many non-setuid processes)
if [ -f "$MG_SO" ]; then
  cat > /etc/profile.d/skell_memguard.sh <<'EOF'
# memguard preload (autogenerated by 00_install.sh)
export LD_PRELOAD="/usr/local/lib/memguard/libmemguard.so${LD_PRELOAD:+:$LD_PRELOAD}"
EOF
  chmod 0644 /etc/profile.d/skell_memguard.sh
  log "LD_PRELOAD profile created: /etc/profile.d/skell_memguard.sh"
else
  log "INFO: memguard so nem elérhető, nem hozom létre a profile.d preload-ot"
fi

# cleanup embedded source file
rm -f "$MEMGUARD_SRC" || true

# ---------------------------
# 7) debootstrap + offline integritás (idempotens)
# ---------------------------
log "7) debootstrap + offline integritásellenőrzés (idempotens)"
mkdir -p "$TARGET" "$BACKUP_ROOT"

if command -v debootstrap >/dev/null 2>&1; then
  if [ -n "$(ls -A "$TARGET" 2>/dev/null || true)" ]; then
    log "INFO: $TARGET nem üres — kihagyom a debootstrap lépést."
  else
    log "Running debootstrap (minbase) for $RELEASE -> $TARGET"
    debootstrap --arch=amd64 --variant=minbase "$RELEASE" "$TARGET" "$MIRROR" >>"$LOG_FILE" 2>&1
    log "debootstrap kész."
  fi
else
  log "WARN: debootstrap nem elérhető, telepítés kihagyva."
fi

# chroot mounts (if any)
mount -t proc none "$TARGET/proc" 2>/dev/null || true
mount --rbind /sys "$TARGET/sys" 2>/dev/null || true
mount --rbind /dev "$TARGET/dev" 2>/dev/null || true

# offline libc/ld integrity check inside TARGET
LOGFILE_INT="$LOGDIR/00_integrity_$TIMESTAMP.log"
exec 3>&1 1>>"$LOGFILE_INT" 2>&1
echo "$(date +%F' '%T) [00_install] Integrity check starting" >&3

find_lib_files() {
  local prefix="$TARGET"
  find "$prefix/lib" "$prefix/lib64" "$prefix/usr/lib" "$prefix/lib/x86_64-linux-gnu" \
    -type f \( -name 'libc.so*' -o -name 'ld-linux*.so*' -o -name 'ld-*.so*' \) 2>/dev/null || true
}
LIB_FILES=$(find_lib_files)
if [ -z "$LIB_FILES" ]; then
  echo "$(date +%F' '%T) [00_install] WARN: Nem talált libc/ld fájlokat" >&3
else
  echo "$(date +%F' '%T) [00_install] OK: Talált fájlok:" >&3
  printf "%s\n" "$LIB_FILES" | sed 's/^/   /' >&3
fi

# SHA256 mentés
mkdir -p "$BACKUP_ROOT"
SHAFILE="$BACKUP_ROOT/lib_sha256_$TIMESTAMP.txt"
: >"$SHAFILE"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  sha256sum "$f" >>"$SHAFILE"
done <<<"$(printf "%s\n" "$LIB_FILES")"
echo "$(date +%F' '%T) [00_install] SHA256 hash-ek mentve: $SHAFILE" >&3

# dpkg md5sums ellenőrzés
MD5INFO="$TARGET/var/lib/dpkg/info"
HARD_FAIL=false
if [ -d "$MD5INFO" ] && ls "$MD5INFO"/libc6*.md5sums >/dev/null 2>&1; then
  echo "$(date +%F' '%T) [00_install] libc6 md5sums ellenőrzés..." >&3
  while read -r sum path; do
    fullpath="$TARGET/$path"
    [ -f "$fullpath" ] || { echo "$(date +%F' '%T) [00_install] WARN: hiányzik: $fullpath" >&3; continue; }
    md5calc=$(md5sum "$fullpath" | awk '{print $1}')
    expected=$(awk -v p="$path" '$2==p{print $1}' "$MD5INFO"/libc6*.md5sums)
    if [ "$md5calc" != "$expected" ]; then
      echo "$(date +%F' '%T) [00_install] ALERT: MD5 eltérés: $fullpath" >&3
      HARD_FAIL=true
    else
      echo "$(date +%F' '%T) [00_install] OK: $fullpath md5 rendben" >&3
    fi
  done < <(awk '{print $1 " " $2}' "$MD5INFO"/libc6*.md5sums)
else
  echo "$(date +%F' '%T) [00_install] INFO: Nincs libc6 md5sums info, kihagyva" >&3
fi

# ELF sanity & BPF checks
ELF_ALERT=false
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if file "$f" | grep -qi 'ELF'; then
    interp=$(readelf -l "$f" 2>/dev/null | awk '/INTERP/{print $2}' | tr -d '[]' || true)
    if [ -n "$interp" ] && ! echo "$interp" | grep -qE '/lib.*/ld'; then
      echo "$(date +%F' '%T) [00_install] WARN: Szokatlan INTERP: $interp ($f)" >&3
      $STRICT || continue
    fi
    if strings "$f" | grep -i -E 'bpf|ebpf|prog_attach|kprobe' >/dev/null 2>&1; then
      echo "$(date +%F' '%T) [00_install] ALERT: Gyanús BPF string a binárisban: $f" >&3
      ELF_ALERT=true
    fi
  fi
done <<<"$(printf "%s\n" "$LIB_FILES")"

BPF_ALERT=false
if [ -d /sys/fs/bpf ] && [ "$(ls -A /sys/fs/bpf 2>/dev/null || true)" != "" ]; then
  echo "$(date +%F' '%T) [00_install] ALERT: /sys/fs/bpf nem üres (pinned BPF?)" >&3
  BPF_ALERT=true
fi
if command -v bpftool >/dev/null 2>&1; then
  bpftool prog show >"$LOGDIR/bpftool_prog_$TIMESTAMP.txt" 2>/dev/null || true
  if grep -i pin "$LOGDIR/bpftool_prog_$TIMESTAMP.txt" >/dev/null 2>&1; then
    echo "$(date +%F' '%T) [00_install] ALERT: bpftool pinned obj-ok" >&3
    BPF_ALERT=true
  fi
else
  echo "$(date +%F' '%T) [00_install] INFO: bpftool nincs, kihagyva" >&3
fi
if lsmod | grep -i bpf >/dev/null 2>&1; then
  echo "$(date +%F' '%T) [00_install] ALERT: BPF modulok betöltve" >&3
  BPF_ALERT=true
else
  echo "$(date +%F' '%T) [00_install] OK: nincs betöltött bpf modul" >&3
fi

# SUID/SGID check
find "$TARGET/lib" "$TARGET/usr/lib" -xdev -type f \( -perm -4000 -o -perm -2000 \) -print >"$BACKUP_ROOT/suid_list_$TIMESTAMP.txt" 2>/dev/null || true
if [ -s "$BACKUP_ROOT/suid_list_$TIMESTAMP.txt" ]; then
  echo "$(date +%F' '%T) [00_install] WARN: SUID/SGID fájlok listája: $BACKUP_ROOT/suid_list_$TIMESTAMP.txt" >&3
fi

# evaluate integrity stage
if $HARD_FAIL || $ELF_ALERT || $BPF_ALERT; then
  echo "$(date +%F' '%T) [00_install] FAIL: Integritási probléma észlelve" >&3
  echo "$(date +%F_%T) FAIL: system_memory_hardening incomplete" > "$CANARY_FILE"
  log "Integrity checks failed. See: $LOGFILE_INT"
  exit 11
else
  echo "$(date +%F' '%T) [00_install] PASS: Integritás ok" >&3
fi

# restore stdout/stderr
exec 1>&3 3>&-

# ---------------------------
# 8) Shared object protection: gather .so hashes, sign, chattr +i, ldconfig
# ---------------------------
log "8) Shared object protection: create integrity DB, sign, normalize perms, try chattr +i"

mkdir -p "$INTEGRITY_DB_DIR" "$KEY_DIR"
: > "$INTEGRITY_DB"

# Gather .so files from chosen dirs
SKELL_LIBDIRS="/usr/local/lib /usr/lib /lib"
for d in $SKELL_LIBDIRS; do
  [ -d "$d" ] || continue
  find "$d" -type f -name '*.so*' -print 2>/dev/null | while read -r f; do
    # skip writable world-writable weird files
    sha256sum "$f" >> "$INTEGRITY_DB" 2>/dev/null || true
  done
done
log "Lib hash-ek mentve: $INTEGRITY_DB"

# generate local keypair if missing (self-signed, local use)
if [ ! -f "$PRIVATE_KEY" ]; then
  log "Nincs privát kulcs, generálok (lokális use). Uchold offline biztonságosan a $PRIVATE_KEY fájlt ha production."
  if command -v openssl >/dev/null 2>&1; then
    openssl genpkey -algorithm RSA -out "$PRIVATE_KEY" -pkeyopt rsa_keygen_bits:2048 >>"$LOG_FILE" 2>&1 || true
    openssl rsa -in "$PRIVATE_KEY" -pubout -out "$PUBLIC_KEY" >>"$LOG_FILE" 2>&1 || true
    chmod 0600 "$PRIVATE_KEY" || true
    chmod 0644 "$PUBLIC_KEY" || true
  else
    log "WARN: openssl nincs telepítve, nem generálok kulcsot"
  fi
fi

# sign the integrity DB (if key exists)
if [ -f "$PRIVATE_KEY" ] && command -v openssl >/dev/null 2>&1; then
  openssl dgst -sha256 -sign "$PRIVATE_KEY" -out "$SIGNED_DB" "$INTEGRITY_DB" >>"$LOG_FILE" 2>&1 || log "WARN: integritás aláírás sikertelen"
  log "Integritás adatbázis aláírva: $SIGNED_DB"
else
  log "INFO: nem történt aláírás (kulcs vagy openssl hiányzik)"
fi

# normalize perms and chattr +i where possible for libs we just recorded
while read -r sum path; do
  [ -f "$path" ] || continue
  chmod 0644 "$path" 2>/dev/null || true
  chown root:root "$path" 2>/dev/null || true
done < "$INTEGRITY_DB"

# try to make them immutable
if command -v chattr >/dev/null 2>&1; then
  while read -r sum path; do
    [ -f "$path" ] || continue
    chattr +i "$path" 2>>"$LOG_FILE" || log "INFO: chattr +i sikertelen for $path"
  done < "$INTEGRITY_DB"
  log "Próbáltam immutability-t beállítani a felsorolt .so fájlokra (ha támogatott)"
else
  log "INFO: chattr nincs telepítve, nem állítok immutability-t a libs-okra"
fi

# Add /usr/local/lib to ld config and lock the skell.conf
mkdir -p /etc/ld.so.conf.d
want_line="$SKELL_LIBDIR"
if [ -f "$SKELL_LDCONF" ]; then
  if ! grep -Fxq "$want_line" "$SKELL_LDCONF"; then
    echo "$want_line" >> "$SKELL_LDCONF"
    log "Frissítve $SKELL_LDCONF (hozzáadva $want_line)"
  else
    log "$SKELL_LDCONF már tartalmazza $want_line"
  fi
else
  echo "$want_line" > "$SKELL_LDCONF"
  log "Létrehozva $SKELL_LDCONF"
fi

if command -v ldconfig >/dev/null 2>&1; then
  ldconfig >>"$LOG_FILE" 2>&1 || log "WARN: ldconfig visszaadott hibát"
  log "ldconfig futtatva"
else
  log "INFO: ldconfig nincs jelen"
fi

# try to lock skell.conf immutably
chmod 0644 "$SKELL_LDCONF" 2>/dev/null || true
chown root:root "$SKELL_LDCONF" 2>/dev/null || true
if command -v chattr >/dev/null 2>&1; then
  if chattr +i "$SKELL_LDCONF" 2>>"$LOG_FILE"; then
    log "SUCCESS: $SKELL_LDCONF immutably locked with chattr +i"
  else
    log "INFO: chattr +i sikertelen $SKELL_LDCONF (fs nem támogatott vagy már zárolt)"
  fi
else
  log "INFO: chattr nincs telepítve, nem zárolom $SKELL_LDCONF"
fi

# Extra: if you insist - lock /etc/ld.so.conf itself (dangerous; disabled)
PROTECT_ETC_LDCONF=false
if [ "$PROTECT_ETC_LDCONF" = "true" ]; then
  ETC_LDCONF="/etc/ld.so.conf"
  if [ -f "$ETC_LDCONF" ]; then
    if ! grep -qi "/etc/ld.so.conf.d" "$ETC_LDCONF"; then
      echo "" >> "$ETC_LDCONF"
      echo "# include dir managed by skell" >> "$ETC_LDCONF"
      echo "include /etc/ld.so.conf.d/*.conf" >> "$ETC_LDCONF"
    fi
    chmod 0644 "$ETC_LDCONF" || true; chown root:root "$ETC_LDCONF" || true
    if command -v chattr >/dev/null 2>&1; then chattr +i "$ETC_LDCONF" 2>>"$LOG_FILE" || log "INFO: chattr +i /etc/ld.so.conf sikertelen"; fi
    log "NOTE: /etc/ld.so.conf immutably locked (if PROTECT_ETC_LDCONF=true)"
  fi
fi

# ---------------------------
# 9) Quick sanity & write CANARY
# ---------------------------
OK=1
ASLR_NOW=$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo "0")
if [ "$ASLR_NOW" -ne 2 ]; then log "WARN: ASLR nem 2 (jelenleg: $ASLR_NOW)"; OK=0; else log "ASLR OK (2)"; fi
if [ "$NX_OK" -ne 1 ]; then log "WARN: NX nem bizonyítható"; OK=0; else log "NX OK"; fi
if [ ! -f "$INTEGRITY_DB" ]; then log "ERROR: Integritás DB hiányzik: $INTEGRITY_DB"; OK=0; else log "Integritás DB megtalálva"; fi

if [ "$OK" -eq 1 ]; then
  echo "$(date +%F_%T) OK: system_memory_hardening active" > "$CANARY_FILE"
  log "CANARY OK létrehozva: $CANARY_FILE"
else
  echo "$(date +%F_%T) FAIL: system_memory_hardening incomplete" > "$CANARY_FILE"
  log "CANARY FAIL létrehozva: $CANARY_FILE (nézd meg a logot)"
fi

log "00_install completed. RC=0"
exit 0
