#!/bin/bash
set -e

export DISABLE_SPRING=1

# La base partagee peut demarrer apres plume : on attend qu'elle reponde
# plutot que de laisser le conteneur echouer.
echo "Attente de PostgreSQL..."

# DATABASE_URL fait foi. A defaut, on retombe sur le conteneur "db" du reseau
# partage du NAS, ce qui est le cas normal en production.
DB_HOST="${DATABASE_HOST:-db}"
DB_PORT="${DATABASE_PORT:-5432}"
DB_USER="${POSTGRES_USER:-postgres}"

if [ -n "${DATABASE_URL:-}" ]; then
    # postgresql://utilisateur:motdepasse@hote:port/base
    DB_HOST=$(printf '%s' "$DATABASE_URL" | sed -E 's#^[^:]+://##; s#^([^@]*@)?##; s#/.*$##; s#^([^:]*)(:([0-9]+))?$#\1#')
    DB_PORT=$(printf '%s' "$DATABASE_URL" | sed -E 's#^[^:]+://##; s#^[^@]*@##; s#/.*$##; s#^.*:([0-9]+)$#\1#')
    DB_USER=$(printf '%s' "$DATABASE_URL" | sed -E 's#^[^:]+://##; s#^([^:]*):.*$#\1#')
    echo "Configuration lue depuis DATABASE_URL ($DB_USER@$DB_HOST:$DB_PORT)"
fi

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

echo "Application des migrations..."
bundle exec rails db:prepare

echo "Demarrage de l'application..."
exec "$@"