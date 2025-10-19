#!/bin/bash
# 19_stack_canary_enforce.sh - Stack Canary (-fstack-protector-strong) kikényszerítése globálisan

echo "--- 19_stack_canary_enforce: Stack Canary beállítások kikényszerítése ---"

# 1. Globális build opciók beállítása (pl. Gentoo / általános Linux build)
# Cél: Biztosítani, hogy a build rendszerek használják a -fstack-protector-strong opciót.
# Ha nem létezik /etc/make.conf (pl. Debian-alapú rendszer), akkor kihagyjuk, de érdemes lehet hozzáadni.
MAKE_CONF="/etc/make.conf"
STACK_CANARY_FLAG="-fstack-protector-strong"

echo "1. CFLAGS/CXXFLAGS beállítása globális build környezethez ($MAKE_CONF)..."

if [ -f "$MAKE_CONF" ]; then
    cp "$MAKE_CONF" "${MAKE_CONF}.bak.19"
    
    # Függvény a beállítás beszúrására/frissítésére
    update_flags() {
        local VAR_NAME=$1
        # Ellenőrizzük, hogy a változó már tartalmazza-e az opciót. Ha nem, hozzáadjuk, és eltávolítjuk az esetleges -fstack-protector-all vagy sima -fstack-protector-t.
        
        if grep -q "^${VAR_NAME}=" "$MAKE_CONF"; then
            # 1a. Eltávolítjuk a gyengébb, vagy meglévő canary opciót, ha van.
            sed -i "s/\(^${VAR_NAME}=.*-fstack-protector-all.*\)/\1/g" "$MAKE_CONF"
            sed -i "s/\(^${VAR_NAME}=.*-fstack-protector[^s][^t].*\)/\1/g" "$MAKE_CONF"
            
            # 1b. Hozzáadjuk a -fstack-protector-strong opciót, ha még nem szerepel.
            if ! grep -q "^${VAR_NAME}=.*${STACK_CANARY_FLAG}" "$MAKE_CONF"; then
                sed -i "/^${VAR_NAME}=/ s/\"$/ ${STACK_CANARY_FLAG}\"/" "$MAKE_CONF"
                echo "    -> Frissítve: ${VAR_NAME} beállítva $STACK_CANARY_FLAG-ra."
            else
                echo "    -> Ellenőrizve: ${VAR_NAME} már tartalmazza a $STACK_CANARY_FLAG opciót."
            fi
        else
            # Ha a változó nem létezik, hozzáadjuk a fájl végéhez.
            echo "${VAR_NAME}=\"${STACK_CANARY_FLAG}\"" >> "$MAKE_CONF"
            echo "    -> Hozzáadva: ${VAR_NAME} új sorral: $STACK_CANARY_FLAG."
        fi
    }
    
    update_flags "CFLAGS"
    update_flags "CXXFLAGS"
    
else
    echo "Figyelem: A(z) $MAKE_CONF fájl nem található. Manuális build folyamatok nem biztos, hogy öröklik a beállításokat."
fi

# 2. Globális környezeti változók beállítása (/etc/environment)
# Bár a /etc/make.conf a legjobb, /etc/environment biztosítja, hogy a legtöbb interaktív és nem interaktív shell ezt lássa.
ENV_CONF="/etc/environment"
echo "2. Globális környezeti változók ($ENV_CONF) beállítása..."

# Készítünk egy ideiglenes fájlt a CFLAGS/CXXFLAGS frissített értékének tárolására.
TEMP_ENV=$(mktemp)

# CFLAGS frissítése
# Eltávolítjuk a régi CFLAGS sort.
grep -v "^CFLAGS=" "$ENV_CONF" > "$TEMP_ENV"

# Hozzáadjuk az új sort (ha a CFLAGS már létezik, akkor kibővítjük, ha nem, akkor csak az új flag-et adjuk hozzá)
if grep -q "^CFLAGS=" "$ENV_CONF"; then
    OLD_CFLAGS=$(grep "^CFLAGS=" "$ENV_CONF" | cut -d\" -f2)
    NEW_CFLAGS="$OLD_CFLAGS $STACK_CANARY_FLAG"
    # Eltávolítjuk a duplikációt / gyengébb opciót
    NEW_CFLAGS=$(echo "$NEW_CFLAGS" | sed 's/-fstack-protector-all//g' | sed 's/-fstack-protector//g' | sed 's/  */ /g' | xargs | sed 's/ / /g')
    echo "CFLAGS=\"$NEW_CFLAGS\"" >> "$TEMP_ENV"
else
    echo "CFLAGS=\"$STACK_CANARY_FLAG\"" >> "$TEMP_ENV"
fi

# CXXFLAGS frissítése (ugyanaz a logika)
grep -v "^CXXFLAGS=" "$TEMP_ENV" > "$ENV_CONF.tmp2"
if grep -q "^CXXFLAGS=" "$ENV_CONF"; then
    OLD_CXXFLAGS=$(grep "^CXXFLAGS=" "$ENV_CONF" | cut -d\" -f2)
    NEW_CXXFLAGS="$OLD_CXXFLAGS $STACK_CANARY_FLAG"
    NEW_CXXFLAGS=$(echo "$NEW_CXXFLAGS" | sed 's/-fstack-protector-all//g' | sed 's/-fstack-protector//g' | sed 's/  */ /g' | xargs | sed 's/ / /g')
    echo "CXXFLAGS=\"$NEW_CXXFLAGS\"" >> "$ENV_CONF.tmp2"
else
    echo "CXXFLAGS=\"$STACK_CANARY_FLAG\"" >> "$ENV_CONF.tmp2"
fi

mv "$ENV_CONF.tmp2" "$ENV_CONF"
rm "$TEMP_ENV" 2> /dev/null

echo "Stack Canary opciók hozzáadva a(z) $ENV_CONF és $MAKE_CONF fájlokhoz."
echo "--- 19_stack_canary_enforce Befejezve ---"
