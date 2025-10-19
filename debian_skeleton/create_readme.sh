#!/bin/bash
# --------------------------------------------------------------------
#  create_readme.sh - Bea Bootstrap Security README generátor
# --------------------------------------------------------------------
#  Használat:
#      ./create_readme.sh 17_module_blacklist.sh
#
#  Automatikusan létrehoz egy modul README fájlt.
# --------------------------------------------------------------------

# Ellenőrzés
if [ -z "$1" ]; then
  echo "Használat: $0 modul_fájlnév.sh"
  exit 1
fi

FILENAME=$(basename "$1")
MODULNUM=$(echo "$FILENAME" | cut -d'_' -f1)
MODULNAME=$(echo "$FILENAME" | cut -d'_' -f2- | sed 's/\.sh$//')
DATE=$(date +"%Y-%m-%d %H:%M:%S")

OUTFILE="README_${MODULNUM}_${MODULNAME}.txt"

# Ha már létezik, ne írjuk felül
if [ -f "$OUTFILE" ]; then
  VERSION=$(ls README_${MODULNUM}_${MODULNAME}*.txt 2>/dev/null | wc -l)
  OUTFILE="README_${MODULNUM}_${MODULNAME}_v$((VERSION+1)).txt"
fi

cat <<EOF > "$OUTFILE"
# Modul: ${MODULNAME}
## Verzió: ${MODULNUM}
## Létrehozva: ${DATE}

### Célja
Ez a modul a rendszerindítás során a kernelmodulok tiltását végzi, különös tekintettel a biztonsági kockázatot jelentő modulokra.

### Lefutási sorrend
Szekvenciális indítás: ${MODULNUM}  
Fázis: inicializálás / eszközmodulok betöltése előtt.

### Elérési útvonal
/etc/init.d/${FILENAME}

### Leírás
A modul a következő feladatokat látja el:
- Feketelistázza a veszélyes modulokat.
- Megakadályozza a kernel által automatikusan betöltött, ismert problémás drivereket.
- Növeli a rendszerindítás biztonságát a hardveres támadási felületek csökkentésével.

Használt konfigurációs fájlok:
- /etc/modprobe.d/blacklist.conf
- /usr/local/etc/module_blacklist.d/

### Megjegyzések
- Független a `00_base_init.sh` modultól.
- Ideiglenesen kikapcsolható:  
  \`chmod -x /etc/init.d/${FILENAME}\`
- Kézzel futtatható:  
  \`sudo /etc/init.d/${FILENAME} start\`

### Karbantartó
Bea  
Fejlesztő és rendszerarchitekt – Bootstrap Security Sequence
EOF

echo "✅ README fájl létrehozva: ${OUTFILE}"
