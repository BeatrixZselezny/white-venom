# Mentés és visszaállítás segédlet 

Itt van tehát a megígért automatikus WSL2 backup script —
egy backup_wsl2_env.sh néven menthető és futtatható, akár root nélkül is.

Használat

Mentsd el a fájlt:

``bash
nano ~/backup_wsl2_env.sh
``

##Illeszd be a fenti kódot.

#Tedd futtathatóvá:

``bash
chmod +x ~/backup_wsl2_env.sh
``

#Futtasd:

``bash
./backup_wsl2_env.sh
``

Ez mindent ment a Windows Documents/ Debian_Backup/ mappába, tömörítve, dátumozva, logolva.


##Amikor az új Debianon megérkeztél

#Ott csak:

``bash
sudo apt install git maven openjdk-17-jdk postgresql
tar -xzvf home_backup_*.tar.gz -C ~
sudo -u postgres psql < postgres_all_*.sql
``

és már újra otthon vagy.
A backup_log_*.txt megmondja, mit mentett pontosan.


##restore_wsl2_env.sh

#Használat

Másold át a Windowsról a Debian_Backup/ mappát a natív Debianodra (pl. pendrive-ról vagy felhőből):

``bash
mkdir -p ~/Debian_Backup
cp -r /media/<valami>/Debian_Backup ~/Debian_Backup
``

#Hozd létre a scriptet:

``bash
nano ~/restore_wsl2_env.sh
``

Illeszd be a fenti kódot.

#Tedd futtathatóvá:

``bash
chmod +x ~/restore_wsl2_env.sh
``

#Futtasd:

``bash
./restore_wsl2_env.sh
``

##Extra funkciók, amit tud:

- felismeri, melyik mentés létezik, és csak azokat bontja ki

- automatikusan újraépíti a w3school/objexamples projektszerkezetet

- visszahozza a .ssh, .m2, .bashrc, .gnupg, .config fájlokat

- újra betölti az összes PostgreSQL adatbázist

csomaglistáról újra telepíti a korábbi csomagokat

- és természetesen: logol mindent, hogy semmi ne vesszen el

