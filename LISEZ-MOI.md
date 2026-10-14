# plume — déploiement sur le NAS

Lecteur de mails Gmail construit sur l'export Takeout (`.mbox`). Ce document
décrit l'installation manuelle sur le Synology, via Container Manager.

---

## Ce qu'il faut avant de commencer

| Prérequis | Pourquoi |
|---|---|
| Container Manager (Docker) actif sur le NAS | héberge le conteneur `web` |
| `/volume1/plume/mbox/emails.mbox` (10 Go) | archive source de l'import |
| `/volume1/plume/data` | stockage des pièces jointes |
| Accès à la base PostgreSQL existante (192.168.1.30:5434) | messages et index |

La base **n'est pas installée par ce projet**. PostgreSQL tourne déjà sur le NAS
et héberge d'autres applications ; plume s'y connecte simplement.

> **Les volumes doivent être des dossiers locaux du NAS.** Jamais un partage SMB.
> PostgreSQL refuse un système de fichiers réseau, et le stockage des pièces
> jointes s'est déjà révélé fragile sur du matériel exFAT.

---

## 1. Préparer les dossiers

```bash
mkdir -p /volume1/plume/mbox
mkdir -p /volume1/plume/data
```

Copier ensuite l'archive dans `/volume1/plume/mbox/`. L'import lit ce fichier ;
rien d'autre n'est nécessaire.

---

## 2. Déposer l'application

Copier le dossier `plume/` dans `/volume1/plume/app` (ou un autre emplacement de
votre choix).

Deux fichiers sont propres au NAS et **ne doivent pas être versionnés** :

- `docker-compose.yml` (les chemins de volumes y sont des chemins NAS)
- `.env` (les identifiants y figurent)

---

## 3. Créer le fichier `.env`

À partir de `.env.example` :

```bash
cd /volume1/plume/app
cp .env.example .env
```

Puis remplir :

```ini
# openssl rand -hex 64
SECRET_KEY_BASE=<une valeur longue et aleatoire>

PLUME_DB_HOST=192.168.1.30
PLUME_DB_PORT=5434
PLUME_DB_USER=postgres
PLUME_DB_PASSWORD=<votre mot de passe>
PLUME_DB_NAME=plume_production
```

`SECRET_KEY_BASE` et `PLUME_DB_PASSWORD` n'ont pas de valeur par défaut : le
conteneur refuse volontairement de démarrer sans elles.

---

## 4. Créer la base

Une seule fois, depuis n'importe quel poste disposant de `psql` :

```bash
psql "postgresql://postgres:postgres@192.168.1.30:5434/postgres" \
     -c "CREATE DATABASE plume_production;"
```

---

## 5. Construire et démarrer

Dans Container Manager → **Projet** → **Créer**, indiquer le dossier
`/volume1/plume/app` comme chemin du projet. Container Manager détecte le
`docker-compose.yml` et construit l'image.

La construction prend **5 à 15 minutes** : les gems sont compilés sur le
processeur du Synology. Les couches sont mises en cache, les reconstructions
suivantes sont bien plus rapides.

Une fois le projet démarré, plume répond sur `http://<ip-du-nas>:3000`.

---

## 6. Lancer l'import

L'import lit 10 Go et écrit environ 2,6 Go de texte plus 4,8 Go de pièces
jointes. Sur le processeur d'un Synology, comptez **45 minutes à 2 heures**.

Dans Container Manager → projet `plume` → **Terminal** du conteneur :

```bash
MBOX=/data/../mbox/emails.mbox \
PLUME_OWN_ADDRESSES="legall.romain@gmail.com" \
  bin/rails mail:import
```

Si l'archive vit dans un dossier monté, ajustez le chemin. La progression
s'affiche en continu :

```
  messages  importes    spam  pieces     msg/s  ecoule
    5000       3980     231    1244     12.4    403s
```

`PLUME_OWN_ADDRESSES` sert à identifier les messages envoyés : indiquez vos
adresses séparées par des virgules.

### Reprendre après une interruption

Si le NAS s'est arrêté en cours de route, rien n'est perdu. Relancez en
indiquant le nombre de messages déjà traités :

```bash
MBOX=/volume1/plume/mbox/emails.mbox SKIP=12400 bin/rails mail:import
```

### Repartir de zéro

```bash
bin/rails mail:reset
```

Demande une confirmation interactive, puis efface messages, conversations,
étiquettes et les fichiers de pièces jointes.

---

## 7. Vérifier

```bash
docker compose exec web bin/rails runner "puts Conversation.count"
```

Si le chiffre correspond à l'archive, l'application affiche les conversations.
Vérifiez que les pièces jointes s'ouvrent : elles sont servies depuis
`/data`.

---

## Maintenance

**Mettre à jour l'application.** Re-déposer le dossier, puis dans Container
Manager reconstruire le projet. Les données vivent dans la base et dans
`/volume1/plume/data`, jamais dans l'image.

**Sauvegardes.** Deux éléments à sauvegarder, et rien d'autre :

```bash
pg_dump "postgresql://postgres:...@192.168.1.30:5434/plume_production" > plume.sql
tar czf plume-data.tar.gz -C /volume1/plume data
```

**Les pièces jointes peuvent être reconstruites** depuis le `.mbox` si elles
sont perdues : `bin/rails mail:import` les réécrit. Il faut donc conserver le
`.mbox` tant que la base et `/volume1/plume/data` ne sont pas sauvegardées.

---

## Réglages utiles

| Variable | Rôle | Défaut |
|---|---|---|
| `PLUME_DATA_DIR` | répertoire des pièces jointes | `/data` |
| `PLUME_OWN_ADDRESSES` | adresses utilisées pour détecter les messages envoyés | vide |
| `SKIP` | reprise d'import | `0` |
| `LIMIT` | nombre de messages à importer | tous |

Dans `docker-compose.yml`, adaptez la publication de port si le 3000 est déjà
pris sur le NAS :

```yaml
ports:
  - "8080:3000"
```

---

## Dépannage

| Symptôme | Cause probable |
|---|---|
| `SECRET_KEY_BASE` manquant au démarrage | `.env` incomplet ou non lu au bon endroit |
| `could not translate host name` | `PLUME_DB_HOST` injoignable depuis le conteneur ; vérifier l'IP du NAS |
| `access method "trigram" does not exist` | migration 20261014000000 non appliquée |
| Page vide alors que l'import a réussi | vérifier que le chemin de l'archive est bien un dossier local |
| Pièces jointes « introuvables sur le disque » | `PLUME_DATA_DIR` ne correspond pas au volume monté |

Les journaux du conteneur sont dans Container Manager → projet → **Journaux**.