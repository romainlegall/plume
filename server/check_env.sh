#!/bin/bash

# Diagnostic complet avant de deployer plume.
# A lancer sur le NAS :  bash /volume1/docker/plume/server/check_env.sh
#
# Verifie une a une les conditions de deploiement et dit quoi faire quand
# quelque chose manque.

REPO_DIR="/volume1/docker/plume"
ENV_FILE="$REPO_DIR/server/env.production"
SOURCE_DIR="/volume1/docker/plume"

# shellcheck source=/volume1/docker/plume/server/lib.sh
. "$REPO_DIR/server/lib.sh"

OK=0
KO=0

vert() { echo "  [OK]    $1"; }
rouge() { echo "  [MANQUE] $1"; KO=$((KO + 1)); }
jaune() { echo "  [INFO]   $1"; }

echo "=============================================="
echo "  plume — diagnostic de deploiement"
echo "=============================================="
echo

# --- 1. git -----------------------------------------------------------------
echo "1. Git"
GIT=$(trouver_git)
if [ -n "$GIT" ]; then
    vert "$GIT"
    jaune "version : $($GIT --version 2>/dev/null | head -1)"
else
    rouge "git introuvable"
    echo "         Installer le paquet Git depuis le Centre de paquets du Synology,"
    echo "         ou rendre l'executable permanent avec :"
    echo "           sudo ln -s /usr/local/git/bin/git /usr/bin/git"
fi
echo

# --- 2. Depot local ---------------------------------------------------------
echo "2. Depot local"
if depot_est_clone "$REPO_DIR"; then
    vert "$REPO_DIR est un clone git"
else
    rouge "$REPO_DIR n'est pas un clone git"
    echo "         deploy.sh ne peut pas mettre a jour le code sans depot."
    echo "         A executer une seule fois :"
    echo "           cd $REPO_DIR && $GIT clone git@github.com:romainlegall/plume.git repo"
    echo "         puis adapter REPO_DIR dans deploy.sh (ou deplacer le clone a la racine)"
fi
echo

# --- 3. Fichier de configuration -------------------------------------------
echo "3. Configuration"
if [ -f "$ENV_FILE" ]; then
    vert "env.production present"
else
    rouge "env.production absent"
    echo "         cp $REPO_DIR/server/env.production.example $ENV_FILE"
fi

if [ -f "$ENV_FILE" ]; then
    manquants=""
    while IFS='=' read -r cle val; do
        case "$cle" in
            GITHUB_TOKEN|SECRET_KEY_BASE|RAILS_MASTER_KEY)
                [ -z "$val" ] && manquants="$manquants $cle"
                ;;
        esac
    done < "$ENV_FILE"

    if [ -n "$manquants" ]; then
        rouge "variables vides :$manquants"
    else
        vert "variables sensibles renseignees"
    fi
fi
echo

# --- 4. Donnees -------------------------------------------------------------
echo "4. Donnees"
for dossier in "$SOURCE_DIR/mbox" "$SOURCE_DIR/data"; do
    if [ -d "$dossier" ] && [ -w "$dossier" ]; then
        vert "$dossier accessible en ecriture"
    elif [ -d "$dossier" ]; then
        rouge "$dossier existe mais n'est pas accessible en ecriture"
    else
        rouge "$dossier absent"
    fi
done

if [ -f "$SOURCE_DIR/mbox/emails.mbox" ]; then
    TAILLE=$(du -m "$SOURCE_DIR/mbox/emails.mbox" 2>/dev/null | cut -f1)
    vert "emails.mbox : ${TAILLE} Mo"
    if [ "${TAILLE:-0}" -lt 8600 ]; then
        rouge "archive trop petite, copie probablement incomplete"
    fi
else
    rouge "emails.mbox absent de $SOURCE_DIR/mbox"
fi
echo

# --- 5. Reseau Docker --------------------------------------------------------
echo "5. Reseau"
if command -v docker > /dev/null 2>&1; then
    vert "docker disponible"
    if docker network ls 2>/dev/null | grep -q "shared-database_default"; then
        vert "reseau shared-database_default present"
    else
        rouge "reseau shared-database_default absent"
        echo "         La base partagee n'est pas demarree, ou le projet"
        echo "         shared-database a ete renomme."
    fi
else
    rouge "docker indisponible"
fi

if command -v docker > /dev/null 2>&1 && docker ps 2>/dev/null | grep -q shared_postgres_db; then
    vert "conteneur shared_postgres_db en marche"
    if docker exec shared_postgres_db psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='plume_production'" 2>/dev/null | grep -q 1; then
        vert "base plume_production presente"
    else
        rouge "base plume_production absente"
        echo "         docker exec shared_postgres_db createdb -U postgres plume_production"
    fi
else
    jaune "conteneur shared_postgres_db non detectable depuis ce script"
fi
echo

echo "=============================================="
if [ "$KO" -eq 0 ]; then
    echo "  Tout est en place. Deploiement possible."
else
    echo "  $KO element(s) a regler avant de deployer."
fi
echo "=============================================="
exit $KO