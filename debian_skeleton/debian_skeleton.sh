#!/bin/bash
# Debian Minimal Security Skeleton Runner
# Author: Beatrix Zelezny 🐱

ROOT_DIR="$(dirname "$0")"
DRY_RUN=false

if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY RUN MODE] A parancsok nem fognak ténylegesen lefutni!"
fi

for STEP in $(seq -w 00 12); do
    SCRIPT="$ROOT_DIR/${STEP}_*.sh"
    FILE=$(ls $SCRIPT 2>/dev/null | head -n 1)
    if [[ -f "$FILE" ]]; then
        echo "⚙️  Step $STEP → $(basename "$FILE")"
        if $DRY_RUN; then
            echo "   [DRY-RUN] $FILE lefutna..."
        else
            bash "$FILE" || { echo "❌ Hiba a $FILE futtatásakor"; exit 1; }
        fi
    else
        echo "⚠️  Step $STEP script hiányzik!"
    fi
done

echo "🏁 Skeleton futás vége."
