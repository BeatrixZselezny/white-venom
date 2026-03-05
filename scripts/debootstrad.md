#1. Előkészület: partíció és mount

Bootolj a Debian telepítőből expert módban, majd amikor a "Detect and mount file systems" vagy "Partition disks" lépés után elérhető a shell (Alt+F2), csináld meg a partíciót és mountold

``bash
# példa: /dev/sda1 a root partíciód
mkfs.ext4 /dev/sda1
mount /dev/sda1 /mnt
``

Ha külön /boot, /home stb. van, azokat is mountold a megfelelő helyre:

``bash
mount /dev/sda2 /mnt/boot
mount /dev/sda3 /mnt/home
``

#2. Alaprendszer telepítése debootstrap-pel
``bash
debootstrap --arch=amd64 bookworm /mnt http://deb.debian.org/debian/
``

Ha nem akarod a systemd-t, itt még nem gond, mert azt majd később választod ki az init-nél.

#Belépés a chroot környezetbe
``bash
mount -t proc /proc /mnt/proc
mount -t sysfs /sys /mnt/sys
mount --rbind /dev /mnt/dev
mount --rbind /run /mnt/run
chroot /mnt /bin/bash
``

Most már benne vagy az új rendszerben.

#4. Alap konfigurációk
``bash
echo "debian-pure" > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
ln -sf /usr/share/zoneinfo/Europe/Budapest /etc/localtime
dpkg-reconfigure tzdata
``

Fstab például:
``bash
cat <<EOF > /etc/fstab
/dev/sda1   /       ext4    defaults   0 1
/dev/sda2   /boot   ext4    defaults   0 2
/dev/sda3   /home   ext4    defaults   0 2
EOF
``

#5. Init-rendszer választás (Systemd-mentesen)
``bash
apt-get install sysvinit-core sysvinit-utils
``

Ez automatikusan kinyírja a systemd-csomagokat.
Utána még pucolás:

``bash
apt-get purge --auto-remove systemd systemd-sysv
apt-mark hold systemd
``

Tisztán induló, init.d alapú rendszered lesz.

#Alap eszközök és csomagok:

Minimalista fejlesztői alap:
``bash
apt-get install --no-install-recommends linux-image-amd64 grub-pc bash-completion net-tools iproute2 ifupdown sudo vim less
``

Ha SSH-t is akarsz rögtön:
``bash
apt-get install --no-install-recommends openssh-server
``
Ha saját kernel vagy firmware van, azt is most tedd be /boot-ba és update-grub majd grub-install (lásd alább).

#7. GRUB telepítés kézzel
``bash
grub-install /dev/sda
update-grub
``

Ha egyedi GRUB scripted van (ahogy említetted, “grub cpu env inject”), csak másold be a /etc/grub.d/ alá, adj rá futási jogot, majd újra:

``bash
update-grub
``

#8. Root jelszó, user és kilépés:
``bash
passwd
adduser bea
adduser bea sudo
exit
umount -R /mnt
reboot
``

#9. Ha systemd nélkül akarsz teljes bootot (init.d only)

``bash
ls -l /sbin/init
# -> /lib/sysvinit/init-re mutasson
``

És hogy nincsen semmilyen maradék systemctl:

``bash
which systemctl || echo "✅ No systemctl here!"
``

#10. Finomítás (apt policy szigorítás, ahogy írtad)

Ha már chrootban vagy, és van apt.conf.d szigorításod (pl. pinning, signature verify), akkor most másold be a ~/Debian_Backup/apt_conf_strict/ fájlokat ide:

``bash
cp -a ~/Debian_Backup/apt_conf_strict/* /mnt/etc/apt/apt.conf.d/
``

Majd ellenőrizd a sources.list:

``bash
cat /etc/apt/sources.list
``

Itt érdemes csak main ágat hagyni, ha szigorított környezet kell:

``bash
deb http://deb.debian.org/debian/ bookworm main
deb http://security.debian.org/debian-security bookworm-security main
``

#Röviden:

- debootstrap → alap rendszer

- chroot → konfiguráció

- apt install sysvinit-core → systemd eltávolítás

- grub-install + update-grub

- passwd, adduser, kilépés, reboot

