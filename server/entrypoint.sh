#!/bin/bash
set -e

export DISABLE_SPRING=1

# La base partagee peut demarrer apres plume : on attend qu'elle reponde
# plutot que de laisser le conteneur echouer.
echo "Attente de PostgreSQL..."

DB_HOST="db"
DB_PORT="5432"
DB_USER="postgres"
MAX_TRIES=30
COUNT=0

until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; do
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge $MAX_TRIES ]; then
        echo "PostgreSQL indisponible apres $MAX_TRIES tentatives. Abandon."
        exit 1
    fi
    echo "PostgreSQL indisponible (essai $COUNT/$MAX_TRIES)"
    sleep 2
done

echo "PostgreSQL repond."

rm -f /app/tmp/pids/server.pid

echo "Creation de la base si necessaire..."
bundle exec rails db:create 2>&1 | grep -v "^--" || true

echo "Application des migrations..."
bundle exec rails db:migrate

echo "Demarrage de l'application..."
exec "$@"