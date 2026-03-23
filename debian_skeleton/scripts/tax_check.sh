# Ez a parancs kiolvassa a széf tartalmát, de nem módosítja, így a lakat (i) marad!
sudo sh -c "lsattr /etc/venom/harvest.gold && echo '--- TARTALOM ---' && cat /etc/venom/harvest.gold"
