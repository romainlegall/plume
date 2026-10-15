#!/bin/bash

# Verification des mises a jour, destinee au Planificateur de taches du NAS.
#
# A executer toutes les heures : si le depot a bouge, lance deploy.sh.
# Ne fait rien si tout est a jour.

REPO_DIR="/volume1/docker/plume"
COMPOSE_DIR="$REPO_DIR/server"

# shellcheck source=/volume1/docker/plume/server/lib.sh
. "$COMPOSE_DIR/lib.sh"

GIT=$(trouver_git) || exit 0

BRANCH=$(grep -E '^GITHUB_BRANCH=' "$COMPOSE_DIR/env.production" 2>/dev/null | cut -d= -f2)
BRANCH="${BRANCH:-main}"

depot_est_clone "$REPO_DIR" || exit 0

cd "$REPO_DIR" || exit 1

"$GIT" fetch origin "$BRANCH" > /dev/null 2>&1 || exit 0

LOCAL=$("$GIT" rev-parse HEAD)
REMOTE=$("$GIT" rev-parse "origin/$BRANCH" 2>/dev/null)

if [ "$LOCAL" != "$REMOTE" ]; then
    bash "$COMPOSE_DIR/deploy.sh"
fi