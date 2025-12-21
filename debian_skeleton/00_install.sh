cd /home/debiana/w3school/objexamples/white-venom/debian_skeleton

cat > /tmp/wv_00_install_caps.patch <<'PATCH'
--- a/00_install.sh
+++ b/00_install.sh
@@ -136,6 +136,9 @@
 
 log "INFO" "Mode: $MODE"
 
+# Noninteractive package operations (when enabled)
+export DEBIAN_FRONTEND=noninteractive
+
 
 
 # ---------------------------------------------------------------------------
@@ -174,7 +177,7 @@
 }
 
-log "INFO" "Caps: KERNEL_LIVE=${WV_CAP_KERNEL_LIVE} BOOT_CHAIN=$...MGMT=${WV_CAP_SERVICE_MGMT} FS_IMMUTABLE=${WV_CAP_FS_IMMUTABLE}"
+log "INFO" "Caps: KERNEL_LIVE=${WV_CAP_KERNEL_LIVE} BOOT_CHAIN=${WV_CAP_BOOT_CHAIN} PACKAGE_MGMT=${WV_CAP_PACKAGE_MGMT} SERVICE_MGMT=${WV_CAP_SERVICE_MGMT} FS_IMMUTABLE=${WV_CAP_FS_IMMUTABLE}"
 
 # ---------------------------------------------------------------------------
 # 0.17 – JAVÍTÁS: Unwanted services immediate disable (exim4 - Systemd-free)
@@ -182,10 +185,12 @@
 log "INFO" "Disabling unwanted services (exim4 - Systemd-free)..."
 
 # Exim4 azonnali leállítása. /etc/init.d közvetlen hívása SysVinit módon
-/etc/init.d/exim4 stop 2>/dev/null || log "WARN" "exim4 stop failed (likely not installed)"
-
-# A futási szintekről való eltávolítás, hogy ne induljon el a következő bootoláskor.
-run update-rc.d exim4 remove 2>/dev/null || log "WARN" "exim4 disable failed (likely not installed/configured)"
+if cap_required "SERVICE_MGMT" "${WV_CAP_SERVICE_MGMT}" "service stop/disable"; then
+    run /etc/init.d/exim4 stop 2>/dev/null || log "WARN" "exim4 stop failed (likely not installed)"
+
+    # A futási szintekről való eltávolítás, hogy ne induljon el a következő bootoláskor.
+    run update-rc.d exim4 remove 2>/dev/null || log "WARN" "exim4 disable failed (likely not installed/configured)"
+fi
 
 # ---------------------------------------------------------------------------
 # 0.15 – Bootstrap Network + Kernel/FS Lockdown
@@ -214,7 +219,9 @@
 kernel.unprivileged_bpf_disabled = 1
 EOF
 
-    run sysctl --system
+    if cap_required "KERNEL_LIVE" "${WV_CAP_KERNEL_LIVE}" "sysctl --system"; then
+        run sysctl --system
+    fi
 fi
 
 # ---------------------------------------------------------------------------
@@ -247,6 +254,7 @@
 # ---------------------------------------------------------------------------
 # 1.0 – GRUB env tool + kernelopts baseline
 # ---------------------------------------------------------------------------
+if cap_required "BOOT_CHAIN" "${WV_CAP_BOOT_CHAIN}" "GRUB env tool + kernelopts baseline"; then
 log "INFO" "GRUB environment bootstrap..."
 
 GRUBENV_CMD=""
@@ -279,8 +287,13 @@
     else
-        run apt update -y
-        run apt install -y --no-install-recommends grub-common grub2-common
+        if cap_required "PACKAGE_MGMT" "${WV_CAP_PACKAGE_MGMT}" "install grub tools"; then
+            run apt update -y
+            run apt install -y --no-install-recommends grub-common grub2-common
+        else
+            log "FATAL" "GRUB tools missing and PACKAGE_MGMT capability disabled."
+            exit 55
+        fi
     fi
 fi
 
@@ -332,6 +345,7 @@
 }
 
 ensure_kernelopts
+fi
 
 # ---------------------------------------------------------------------------
 # 1.5 – JAVÍTÁS: Zero-Trust: Systemd Csomagrögzítés (APT Pinning)
@@ -370,7 +384,7 @@
 # 2.0 – APT update + toolchain + memguard deps + security baseline
 # ---------------------------------------------------------------------------
-run apt update -y
+if cap_required "PACKAGE_MGMT" "${WV_CAP_PACKAGE_MGMT}" "apt baseline install"; then
+    run apt update -y
 
 # JAVÍTÁS: Töröltük a git-et és a vim-nox-ot.
 ESSENTIAL_PKGS=(
@@ -412,18 +426,18 @@
     apparmor-utils
 )
 
-install_packages() {
-    local pkgs=("$@")
-    local line
-    line=$(printf "%s " "${pkgs[@]}")
-    run apt install -y --no-install-recommends $line
-}
+install_packages() {
+    local pkgs=("$@")
+    run apt install -y --no-install-recommends "${pkgs[@]}"
+}
 
-install_packages "${ESSENTIAL_PKGS[@]}"
-install_packages "${MEMGUARD_DEPS[@]}"
-install_packages "${SECURITY_BASE_PKGS[@]}"
+    install_packages "${ESSENTIAL_PKGS[@]}"
+    install_packages "${MEMGUARD_DEPS[@]}"
+    install_packages "${SECURITY_BASE_PKGS[@]}"
+else
+    log "INFO" "Skipping package installation due to capability gate."
+fi
 
 # ---------------------------------------------------------------------------
 # 3.0 – ldconfig sanity check
@@ -439,13 +453,17 @@
     local lib_paths
     lib_paths=$(ldconfig -v 2>/dev/null | awk -F':' '/:$/ {print $1}')
 
-    : > "$LD_LOG" 2>/dev/null || true
+    if [[ "$DRY_RUN" -eq 1 ]]; then
+        log "DRY" "Would create/truncate $LD_LOG"
+    else
+        : > "$LD_LOG" 2>/dev/null || true
+    fi
 
     while IFS= read -r path; do
         [[ -z "$path" || ! -d "$path" ]] && continue
         # ⚠️ JAVÍTÁS: Eltávolítva a || true a find parancsról!
-        run find "$path" -maxdepth 1 -type f -perm -0002 -print >> "$LD_LOG"
+        run bash -c 'find "$1" -maxdepth 1 -type f -perm -0002 -print >> "$2"' _ "$path" "$LD_LOG"
     done <<< "$lib_paths"
 
     if [[ -s "$LD_LOG" ]]; then
@@ -520,7 +538,9 @@
 }
 
-grub_cmdline_hardening_inject
+if cap_required "BOOT_CHAIN" "${WV_CAP_BOOT_CHAIN}" "GRUB cmdline hardening inject"; then
+    grub_cmdline_hardening_inject
+fi
 # ---------------------------------------------------------------------------
 # END
 # ---------------------------------------------------------------------------
PATCH

git apply /tmp/wv_00_install_caps.patch
chmod +x 00_install.sh
bash -n 00_install.sh

