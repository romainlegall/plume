#!/bin/bash

# Deploiement de plume sur le NAS.
#
# A lancer depuis le NAS, dans /volume1/docker/plume :
#   ./server/deploy.sh
#
# Le script tire les derniers commits, reconstruit l'image et redemarre le
# conteneur. L'archive mbox et les pieces jointes ne sont pas touchees : elles
# sont montees en volume et hors du depot git.

set -e

REPO_DIR="/volume1/docker/plume"
COMPOSE="docker-compose --env-file $REPO_DIR/server/env.production -f $REPO_DIR/server/docker-compose.yml"
LOG_FILE="$REPO_DIR/deploy.log"

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "=== Deploiement plume : $(date) ==="

cd "$REPO_DIR"

log "Recuperation des commits..."
git fetch origin "${GITHUB_BRANCH:-main}" 2>&1 | tee -a "$LOG_FILE"

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/${GITHUB_BRANCH:-main}")

if [ "$LOCAL" != "$REMOTE" ]; then
    log "Nouveaux commits detectes (${LOCAL:0:8} -> ${REMOTE:0:8})"

    log "Arrêt des conteneurs..."
    $COMPOSE down 2>&1 | tee -a "$LOG_FILE"

    log "Reconstruction de l'image (several minutes sur Synology)..."
    $COMPOSE build --no-cache --pull 2>&1 | tee -a "$LOG_FILE"

    log "Demarrage..."
    $COMPOSE up -d 2>&1 | tee -a "$LOG_FILE"

    log "Derniers journaux..."
    $COMPOSE logs --tail=30 2>&1 | tee -a "$LOG_FILE"

    log "Deploiement termine"
else
    log "Aucun nouveau commit, rien a faire"
fi

log "=== Fin : $(date) ==="