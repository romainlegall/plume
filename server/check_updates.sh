#!/bin/bash

# Verification des mises a jour, destinee au planificateur de taches du NAS.
#
# A executer toutes les heures : si le depot a bouge, lance deploy.sh.
# Ne fait rien si tout est a jour.

REPO_DIR="/volume1/docker/plume"
BRANCH="${GITHUB_BRANCH:-main}"

cd "$REPO_DIR" || exit 1

git fetch origin "$BRANCH" > /dev/null 2>&1 || exit 1

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$BRANCH")

if [ "$LOCAL" != "$REMOTE" ]; then
    "$REPO_DIR/server/deploy.sh"
fi