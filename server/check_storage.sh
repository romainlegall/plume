#!/bin/bash

# Verification des dossiers de donnees de plume sur le NAS.
# A lancer sur le Synology :  ./server/check_storage.sh
#
# plume lit deux dossiers locaux et jamais un partage SMB :
#   /volume1/docker/plume/mbox  l'archive Gmail, monte en lecture seule
#   /volume1/docker/plume/data  les pieces jointes, ecrites par l'import

MBOX_DIR="/volume1/docker/plume/mbox"
DATA_DIR="/volume1/docker/plume/data"
MBOX_FILE="$MBOX_DIR/emails.mbox"
ATTENDU_GO=9

if [ ! -d "/volume1" ]; then
    echo "Ce script doit etre execute sur le NAS Synology."
    exit 1
fi

echo "=========================================="
echo "  plume — dossiers de donnees"
echo "=========================================="
echo

for dossier in "$MBOX_DIR" "$DATA_DIR"; do
    if [ ! -d "$dossier" ]; then
        echo "MANQUANT  $dossier"
        echo "          creer avec : sudo mkdir -p $dossier"
        continue
    fi

    if [ -w "$dossier" ]; then
        echo "OK        $dossier  (ecriture possible)"
    else
        echo "SANS      $dossier  (dossier en LECTURE SEULE, l'import echouera)"
    fi
done

echo

if [ -f "$MBOX_FILE" ]; then
    TAILLE=$(du -m "$MBOX_FILE" | cut -f1)
    echo "Archive   : $MBOX_FILE"
    echo "Taille    : ${TAILLE} Mo (attendu environ $((ATTENDU_GO * 1024)) Mo)"

    if [ "$TAILLE" -lt $((ATTENDU_GO * 900)) ]; then
        echo "ATTENTION : archive plus petite que prevu, copie peut-etre incomplete"
    else
        echo "OK        : taille plausible"
    fi
else
    echo "MANQUANT  $MBOX_FILE"
fi

echo
echo "=========================================="