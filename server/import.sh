#!/bin/bash

# Import de l'archive Gmail dans plume.
#
# A lancer sur le NAS :
#   bash /volume1/docker/plume/server/import.sh
#
# Utilise docker-compose plutot que "docker exec" : le nom du conteneur peut
# differer de celui attendu, la commande vise le service compose, qui est
# toujours le bon.

REPO_DIR="/volume1/docker/plume"
COMPOSE_DIR="$REPO_DIR/server"
ENV_FILE="$COMPOSE_DIR/env.production"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
MBOX_FILE="${MBOX:-/mbox/emails.mbox}"
BATCH="${LIMIT:-0}"

COMPOSE="docker-compose -p plume --env-file $ENV_FILE -f $COMPOSE_FILE"

# Les adresses servent a distinguer les messages que vous avez envoyes des
# messages recus. Surchargeable : PLUME_OWN_ADDRESSES=... ./import.sh
OWN="${PLUME_OWN_ADDRESSES:-legall.romain@gmail.com}"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERREUR : $ENV_FILE est absent."
    exit 1
fi

if [ "$BATCH" != "0" ]; then
    echo "Import limite a $BATCH messages (test)."
else
    echo "Import complet. Pour interrompre sans perdre : Ctrl-C"
    echo "Pour reprendre apres coup : SKIP=<position affichee dans la progression> bash $0"
fi
echo "Archive : $MBOX_FILE"
echo

# --skip : position dans l'archive (la colonne "messages" de la progression),
# pas le nombre de messages importes : les spam et illisibles comptent aussi.
# Les messages deja importes sont de toute facon ignores, donc un SKIP trop
# petit ne cree pas de doublon.
$COMPOSE exec -T web sh -c "MBOX=$MBOX_FILE SKIP=${SKIP:-0} LIMIT=$BATCH PLUME_OWN_ADDRESSES='$OWN' bin/rails mail:import"
CODE=$?

echo
if [ $CODE -eq 0 ]; then
    echo "Import termine."
    echo "Verification : $COMPOSE exec -T web bin/rails runner 'puts Conversation.count'"
else
    echo "Import interrompu (code $CODE). Reprenez avec SKIP=<position affichee>, ou simplement sans SKIP."
fi

exit $CODE
