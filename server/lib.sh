#!/bin/bash

# Localisation de git sur un Synology.
#
# git n'est pas dans le PATH des scripts non interactifs : le paquet Git de
# Synology s'installe dans /usr/local/git et n'est visible que depuis un shell
# interactif. Les scripts de deploiement doivent donc le chercher eux-memes.
#
# Si le paquet a ete installe ailleurs, indiquez le chemin dans env.production :
#   GIT_BIN=/volume1/@appstore/git/usr/bin/git

CANDIDATS="/usr/local/git/bin/git /volume1/@appstore/git/bin/git /volume1/@appstore/git/usr/bin/git /opt/bin/git /usr/bin/git /bin/git"

trouver_git() {
    if [ -n "${GIT_BIN:-}" ] && [ -x "$GIT_BIN" ]; then
        echo "$GIT_BIN"
        return 0
    fi

    if command -v git > /dev/null 2>&1; then
        command -v git
        return 0
    fi

    for chemin in $CANDIDATS; do
        if [ -x "$chemin" ]; then
            echo "$chemin"
            return 0
        fi
    done

    # Dernier recours : le binaire peut avoir ete deplace par une mise a jour.
    if [ -d /volume1/@appstore ]; then
        TROUVE=$(find /volume1/@appstore -maxdepth 4 -name git -type f -perm -u+x 2>/dev/null | head -1)
        if [ -n "$TROUVE" ]; then
            echo "$TROUVE"
            return 0
        fi
    fi

    return 1
}

# Le depot doit etre un clone git pour que deploy.sh puisse le mettre a jour.
depot_est_clone() {
    [ -d "$1/.git" ]
}