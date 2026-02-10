#!/bin/bash
TEST_FILE="/tmp/venom_test.txt"

echo "--- 1. FÁZIS: Tiszta adatok (TEXT) ---"
for i in {1..5}; do
    echo "Normál naplózási esemény $i" > $TEST_FILE
    sleep 0.5
done

echo "--- 2. FÁZIS: Zero-Trust teszt (Magas entrópia) ---"
# Véletlenszerű bináris adatok, amiket a StreamProbe ki fog dobni
for i in {1..5}; do
    head -c 100 /dev/urandom > $TEST_FILE
    sleep 0.5
done

echo "--- 3. FÁZIS: DoS Flood (Debounce teszt) ---"
# Nagyon gyors egymásutáni írás, a debounce-nak itt szűrnie kell
for i in {1..50}; do
    echo "FLOOD $i" > $TEST_FILE
done

echo "--- Teszt vége ---"
