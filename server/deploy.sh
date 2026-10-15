#!/bin/bash

# Deploiement de plume sur le NAS.
#
# A lancer depuis le NAS :
#   bash /volume1/docker/plume/server/deploy.sh
#
# Tire les derniers commits, reconstruit l'image et redemarre le conteneur.
# L'archive mbox et les pieces jointes sont montees en volume : elles ne sont
# jamais touchees.

REPO_DIR="/volume1/docker/plume"
COMPOSE_DIR="$REPO_DIR/server"
LOG_FILE="$REPO_DIR/deploy.log"

# shellcheck source=/volume1/docker/plume/server/lib.sh
. "$COMPOSE_DIR/lib.sh"

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Charge les variables du fichier d'environnement, sans les exporter toutes :
# seules celles utilisees ci-dessous interessent.
charger_env() {
    [ -f "$COMPOSE_DIR/env.production" ] || return 1
    eval "$(grep -E '^[A-Z_]+=' "$COMPOSE_DIR/env.production" | sed 's/^export //')"
    return 0
}

log "=== Deploiement plume : $(date) ==="

if ! charger_env; then
    log "ERREUR : $COMPOSE_DIR/env.production est absent ou illisible."
    log "        cp $COMPOSE_DIR/env.production.example $COMPOSE_DIR/env.production"
    exit 1
fi

GIT=$(trouver_git)
if [ -z "$GIT" ]; then
    log "ERREUR : git est introuvable sur ce NAS."
    log "        Installer le paquet Git (Centre de paquets), puis relancer."
    log "        Si git est installe mais invisible :"
    log "          sudo ln -s /usr/local/git/bin/git /usr/bin/git"
    exit 1
fi
log "Git : $GIT ($($GIT --version 2>/dev/null | head -1))"

BRANCH="${GITHUB_BRANCH:-main}"

if depot_est_clone "$REPO_DIR"; then
    log "Mise a jour du depot..."
    cd "$REPO_DIR" || exit 1
    "$GIT" fetch origin "$BRANCH" 2>&1 | tee -a "$LOG_FILE"
    LOCAL=$("$GIT" rev-parse HEAD)
    REMOTE=$("$GIT" rev-parse "origin/$BRANCH" 2>/dev/null)

    if [ "$LOCAL" = "$REMOTE" ]; then
        log "Aucun nouveau commit (${LOCAL:0:8}), rien a reconstruire."
        log "=== Fin : $(date) ==="
        exit 0
    fi

    log "Nouveaux commits : ${LOCAL:0:8} -> ${REMOTE:0:8}"
    log "Récupération..."
    "$GIT" checkout "$BRANCH" 2>&1 | tee -a "$LOG_FILE"
    "$GIT" pull --ff-only origin "$BRANCH" 2>&1 | tee -a "$LOG_FILE"
else
    log "ATTENTION : $REPO_DIR n'est pas un clone git."
    log "           Le depot distant sera utilise tel quel pour la construction."
    log "           Pour activer les mises a jour automatiques, cloner une fois :"
    log "             cd $REPO_DIR && $GIT clone <url-du-depot>"
    log ""
    log "Reconstruction de l'image depuis GitHub..."
fi

log "Arrêt des conteneurs..."
docker-compose --env-file "$COMPOSE_DIR/env.production" -f "$COMPOSE_DIR/docker-compose.yml" down 2>&1 | tee -a "$LOG_FILE"

log "Reconstruction de l'image (plusieurs minutes sur Synology)..."
docker-compose --env-file "$COMPOSE_DIR/env.production" -f "$COMPOSE_DIR/docker-compose.yml" build --no-cache 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]:-0} -ne 0 ]; then
    log "ERREUR : la construction a echoue. Voir les lignes ci-dessus."
    log "=== Fin : $(date) ==="
    exit 1
fi

log "Démarrage..."
docker-compose --env-file "$COMPOSE_DIR/env.production" -f "$COMPOSE_DIR/docker-compose.yml" up -d 2>&1 | tee -a "$LOG_FILE"

sleep 5
log "Journaux du conteneur..."
docker-compose --env-file "$COMPOSE_DIR/env.production" -f "$COMPOSE_DIR/docker-compose.yml" logs --tail=30 2>&1 | tee -a "$LOG_FILE"

log "Deploiement termine. plume devrait repondre sur le port 3003."
log "=== Fin : $(date) ==="