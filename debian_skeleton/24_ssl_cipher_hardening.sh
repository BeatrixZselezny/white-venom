#!/bin/bash
# 25_ssl_cipher_hardening.sh - Rendszerszintű SSL/TLS protokollok szigorítása

echo "--- 25_ssl_cipher_hardening: SSL/TLS konfiguráció indítása (OpenSSL) ---"

OPENSSL_CONF="/etc/ssl/openssl.cnf"
MIN_PROTOCOL="TLSv1.2"
CIPHER_STRING="HIGH:!aNULL:!MD5:!3DES"

# 1. KRITIKUS: Az OpenSSL konfigurációs fájl feloldása (a 23. lépés után)
# A tranzakció érdekében ellenőrizzük és feloldjuk a chattr +i lezárást.
LOCK_STATUS=$(lsattr "$OPENSSL_CONF" 2>/dev/null | grep -o "i")

if [ "$LOCK_STATUS" == "i" ]; then
    echo "1a. FIGYELEM: A $OPENSSL_CONF le van zárva. Feloldás..."
    chattr -i "$OPENSSL_CONF" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "   -> KRITIKUS HIBA: Nem sikerült feloldani a fájlt. Megszakítás."
        exit 1
    fi
fi

# 2. OpenSSL konfiguráció módosítása
echo "2. Konfiguráció módosítása: MinProtocol és CipherString beállítása..."

# Ellenőrizzük, hogy létezik-e a [system_default_sect] blokk
if grep -q "^\s*\[\s*system_default_sect\s*\]" "$OPENSSL_CONF"; then
    
    # 2a. MinProtocol beállítása (TLSv1.2 kikényszerítése)
    # 1. Meglévő MinProtocol lecserélése, VAGY
    # 2. Hozzáadás, ha még nincs a szekcióban (a szekció után)
    if grep -q -P "MinProtocol\s*=" "$OPENSSL_CONF"; then
        sed -i "/\[system_default_sect\]/,/^\[/{ s/^\s*MinProtocol\s*=.*/MinProtocol = $MIN_PROTOCOL/ }" "$OPENSSL_CONF"
        echo "   -> MinProtocol frissítve $MIN_PROTOCOL-ra."
    else
        sed -i "/\[system_default_sect\]/a MinProtocol = $MIN_PROTOCOL" "$OPENSSL_CONF"
        echo "   -> MinProtocol hozzáadva $MIN_PROTOCOL-lal."
    fi

    # 2b. CipherString beállítása (Szigorú titkosítási csomagok)
    if grep -q -P "CipherString\s*=" "$OPENSSL_CONF"; then
        sed -i "/\[system_default_sect\]/,/^\[/{ s/^\s*CipherString\s*=.*/CipherString = $CIPHER_STRING/ }" "$OPENSSL_CONF"
        echo "   -> CipherString frissítve $CIPHER_STRING-ra."
    else
        sed -i "/\[system_default_sect\]/a CipherString = $CIPHER_STRING" "$OPENSSL_CONF"
        echo "   -> CipherString hozzáadva $CIPHER_STRING-gel."
    fi
else
    # Ha a szekció hiányzik (ritka a modern Debian/Ubuntu rendszereken), hozzáadjuk a fájl végére.
    echo "   -> Figyelem: A [system_default_sect] hiányzik. Hozzáadás a fájl végéhez."
    cat >> "$OPENSSL_CONF" << EOF

[ system_default_sect ]
MinProtocol = $MIN_PROTOCOL
CipherString = $CIPHER_STRING
EOF
fi

# 3. Módosítások alkalmazása (ca-certificates frissítés)
echo "3. Alkalmazás: CA tanúsítványok gyorsítótárának frissítése..."
if command -v update-ca-certificates &> /dev/null; then
    update-ca-certificates --fresh
    echo "Sikeres: update-ca-certificates --fresh futtatva."
else
    echo "FIGYELEM: A 'update-ca-certificates' parancs nem található. Kézi futtatás szükséges."
fi

# 4. KRITIKUS: Visszazárás, ha a fájl eredetileg le volt zárva
if [ "$LOCK_STATUS" == "i" ]; then
    echo "4. VISSZAZÁRÁS: A $OPENSSL_CONF fájl eredetileg le volt zárva. Visszazárás..."
    chattr +i "$OPENSSL_CONF" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "   -> Sikeresen visszazárva (chattr +i)."
    else
        echo "   -> FIGYELEM: A visszazárás sikertelen. Kézi ellenőrzés szükséges."
    fi
fi

echo "--- 25_ssl_cipher_hardening Befejezve ---"