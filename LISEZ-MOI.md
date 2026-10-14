# plume — mise en oeuvre sur le NAS

Lecteur de mails Gmail construit sur l'export Takeout (`.mbox`).

Même organisation que `gestion_locative` : le code vit dans un dépôt Git, le NAS
ne porte que la configuration de déploiement et les données.

---

## Où sont les choses

| Sur votre Mac | Sur le NAS |
|---|---|
| `~/Perso/04 - Developements/plume` (le code) | `/volume1/docker/plume/server/` |
| dépôt GitHub | `/volume1/docker/plume/mbox/emails.mbox` |
| | `/volume1/docker/plume/data/` (pièces jointes) |
| | `/volume1/docker/plume/config/master.key` |

L'image Docker **clone le code depuis GitHub** pendant la construction. Le NAS
n'a donc pas besoin du code applicatif, seulement de `server/`.

---

## Étape 1 — Créer le dépôt GitHub (seule chose à faire de votre côté)

L'accès GitHub n'est pas configuré sur cette machine : ni GitHub CLI, ni clé
SSH, ni jeton valide. Le commit est donc prêt en local mais pas poussé.

Créez un dépôt **privé** sur github.com, nommé `plume`, puis :

```bash
cd ~/Perso/04\ -\ Developements/plume
git remote add origin git@github.com:romainlegall/plume.git
git push -u origin main
```

Si vous préférez passer par HTTPS, utilisez un jeton GitHub comme mot de passe.

## Étape 2 — Renseigner le jeton de lecture

La construction clone un dépôt privé : GitHub exige un jeton.

Créez un jeton **fine-grained**, portée limitée au dépôt `plume`, permission
**lecture seule du contenu**, puis sur le NAS :

```bash
nano /volume1/docker/plume/server/env.production
# GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

Si vous préférez un dépôt public, videz simplement cette variable.

## Étape 3 — Vérifier les dossiers de données

```bash
bash /volume1/docker/plume/server/check_storage.sh
```

Contrôle que `mbox/` et `data/` existent, qu'ils sont accessibles en écriture et
que l'archive a bien la taille attendue. **Déjà fait** au moment de la
préparation : 50 256 messages comptés, taille conforme.

## Étape 4 — Créer la base

```bash
docker exec shared_postgres_db createdb -U postgres plume_production
```

Déjà fait également lors de la préparation.

## Étape 5 — Déployer

En SSH sur le NAS :

```bash
cd /volume1/docker/plume
docker-compose --env-file ./server/env.production -f ./server/docker-compose.yml build --no-cache
docker-compose --env-file ./server/env.production -f ./server/docker-compose.yml up -d
```

Ou, une fois le depot clone sur le NAS :

```bash
./server/deploy.sh
```

L'application répond alors sur `http://<ip-du-nas>:3003`.

---

## Lancer l'import

Première opération seulement, dans le conteneur :

```bash
docker exec -it plume sh -c 'MBOX=/mbox/emails.mbox PLUME_OWN_ADDRESSES=legall.romain@gmail.com bin/rails mail:import'
```

Lecture des 10 Go, écriture d'environ 2,6 Go de texte et 4,8 Go de pièces
jointes. Comptez **45 minutes à 2 heures** sur le processeur du Synology ; la
progression s'affiche en continu.

Reprendre après une coupure :

```bash
docker exec -it plume sh -c 'MBOX=/mbox/emails.mbox SKIP=12400 bin/rails mail:import'
```

---

## Mises à jour ensuite

Le NAS peut surveiller le dépôt et redéployer tout seul. Dans **Planificateur de
tâches** du Synology, une tâche qui s'exécute toutes les heures :

```bash
/volume1/docker/plume/server/check_updates.sh
```

Le script compare la révision locale à celle de GitHub et lance `deploy.sh`
seulement s'il y a du nouveau. Il faut d'abord cloner le dépôt sur le NAS :

```bash
cd /volume1/docker/plume
git clone git@github.com:romainlegall/plume.git repo
```

`deploy.sh` s'attend à trouver le dépôt à la racine de `/volume1/docker/plume` ;
adaptez `REPO_DIR` si vous le clonez dans un sous-dossier.

---

## À savoir

**Le port.** `plume` occupe le port 3003. `gestion_locative` utilise 3002.

**La base est partagée.** `plume_production` vit dans le conteneur
`shared_postgres_db`, aux côtés de `gestion_locative_production` et
`tresor_prive_production`. Une migration ou un `docker compose down` mal ciblé
toucherait les trois.

**La construction est lente.** Le Synology recompile tous les gems à chaque
build avec `--no-cache`. Prévoir 5 à 15 minutes. Sans `--no-cache`, c'est bien
plus rapide mais les changements de Gemfile ne sont pas pris en compte.

**Les données sont hors du dépôt.** `mbox/` et `data/` sont montés en volume et
ignorés par Git. `deploy.sh` ne les touche jamais.

**Sauvegarde.** Deux éléments seulement :

```bash
pg_dump "postgresql://postgres:postgres@db:5432/plume_production" > plume.sql
tar czf plume-data.tar.gz -C /volume1/docker/plume/data .
```

Les pièces jointes peuvent être reconstruites depuis le `.mbox`, mais la
reconstruction demande l'archive complète : conservez-la tant que la base et
`data/` ne sont pas sauvegardés.