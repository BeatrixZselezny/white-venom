# Debian Bootstrap Master Plan — 08_apparmor_hardening.sh Inline Script (Systemd nélkül)

## 08: apparmor_hardening.sh (inline változat a skeleton.sh-hoz, Systemd eltávolítva)

```bash
# 08_apparmor_hardening.sh inline

# Ellenőrzés: root
if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root!" >&2
  exit 1
fi

LOGFILE="/var/log/apparmor_hardening.log"

# 1. Telepítés
apt-get install -y apparmor apparmor-utils

# 2. Alapértelmezett profilok listája
# Minden kritikus alap szolgáltatás
PROFILES=(
  usr.sbin.sshd
  usr.bin.dpkg
  usr.sbin.cron
  usr.sbin.rsyslogd
  usr.bin.curl
)

# 3. Profilok élesítése (enforce)
for prof in "${PROFILES[@]}"; do
  if [ -f "/etc/apparmor.d/$prof" ]; then
    aa-enforce "$prof"
    echo "$prof set to enforce mode" | tee -a "$LOGFILE"
  else
    echo "$prof profile not found, skipping" | tee -a "$LOGFILE"
  fi
done

# 4. Non-default / nem biztonságos profilok tiltása
# Csak példa, a konkrét tiltandó profilt a környezet határozza meg
# aa-disable /etc/apparmor.d/usr.local.unwanted

# 5. Naplózás beállítása
# Tiltott hozzáférések logolása
echo "AppArmor log path: /var/log/apparmor.log" | tee -a "$LOGFILE"

# 6. Snapshot / rollback lehetőség
BACKUP_DIR="~/apparmor_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/apparmor.d "$BACKUP_DIR"

echo "08_apparmor_hardening completed. Logs in $LOGFILE"
```

### Megjegyzések / Direktívák

* A `usr.bin.systemctl` profil eltávolítva, mivel a rendszer teljesen SystemV / init.d alapú.
* Inline a skeleton.sh-ban, az orchestrator csak a fő scriptet hívja.
* Naplózás és rollback snapshot megtartva.
* Kritikus szolgáltatások profiljai enforce módba állítva, non-default profilok letilthatók `aa-disable`-el.
