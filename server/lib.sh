#!/bin/bash

# Localisation de git sur un Synology.
#
# git n'est pas dans le PATH des scripts non interactifs : le paquet Git de
# Synology s'installe dans /usr/local/git et n'est visible que depuis un shell
# interactif. Les scripts de deploiement doivent donc le chercher eux-memes.

CANDIDATS="/usr/local/git/bin/git /volume1/@appstore/git/bin/git /opt/bin/git /usr/bin/git /bin/git"

trouver_git() {
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

    return 1
}

# Le depot doit etre un clone git pour que deploy.sh puisse le mettre a jour.
depot_est_clone() {
    [ -d "$1/.git" ]
}