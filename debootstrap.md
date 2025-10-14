

Partícionálás, fájlrendszer, mount (példa UEFI + GPT):

# példa: /dev/sda a cél
parted --script /dev/sda mklabel gpt
parted --script /dev/sda mkpart primary 1MiB 512MiB
parted --script /dev/sda set 1 esp on
parted --script /dev/sda mkpart primary 512MiB 100%

mkfs.vfat -F32 /dev/sda1
mkfs.ext4 /dev/sda2

mount /dev/sda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi

Debootstrap minimal Debian (példa bookworm helyett tetső release):

apt update
apt install -y debootstrap
debootstrap --arch amd64 bookworm /mnt http://deb.debian.org/debian

(Debootstrap referencia és leírás: hivatalos wiki.)
Debian Wiki

    Chroot + alap konfiguráció:

mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt /bin/bash -l

# belül:
echo "deb http://deb.debian.org/debian bookworm main contrib non-free" > /etc/apt/sources.list
apt update
apt install --yes locales
dpkg-reconfigure locales
apt install --yes linux-image-amd64 grub-efi-amd64 shim-signed

    WireGuard telepítése (elérhető a deb repo-ban):

apt update
apt install -y wireguard iproute2
# wg --version ellenőrzés

(WireGuard a Debian repo-ban: telepíthető apt install wireguard.)
Debian Wiki+1

Ha ragaszkodsz ip6tables-hez, megteheted, de a Debian közösség új installoknál inkább nftables-t javasolja; ip6tables legacy még elérhető, de kevesebb előnye van.
Debian Wiki+1

    Sysctl security config (USB-ről alkalmazva)

    Tegyük fel az USB-n: /media/usb/sysctl-security.conf

# on the host (chroot or after boot)
cp /media/usb/sysctl-security.conf /etc/sysctl.d/99-security.conf
sysctl --system

Példa hasznos beállításokra (te is küldhetted):

# disable IPv6 router advertisements accept if you want strict control
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# basic hardening
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.ip_forward = 0
kernel.exec-shield = 1

(Ezeket igazítsd a saját szabályaidhoz — ha kész a sysctl fájlod az USB-n, csak másold át és sysctl --system.)

    GRUB environment — óvatosan szerkesztés:

    A GRUB env blokkot a grub-editenv kezeli; ezzel tudsz "beoltani" értékeket (pl. mentett default).

# listázás
grub-editenv list
# beállítás (példa)
grub-editenv set myflag=1
# ellenőrzés
grub-editenv list

Az environment blokk formátuma fix méretű (grub manual). Ha "vuln injection"-t akarsz, nagyon óvatosan — a grubenv fájl megsérülése boot problémát okozhat. Backup: /boot/grub/grubenv.bak.
GNU+1

    AppArmor (telepítés + ellenőrzés)

apt install -y apparmor apparmor-utils apparmor-profiles
systemctl enable apparmor
systemctl start apparmor
aa-status   # ellenőrizd a profilokat és státuszt

AppArmor Debianon jól használható MAC réteg; alapértelmezés szerint a modern Debian kiadásokban támogatott/beállítható.
Debian Wiki+1

