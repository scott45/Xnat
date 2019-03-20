#!/bin/sh
# wait-for-postgres.sh

set -e

cmd="/usr/local/tomcat/bin/catalina.sh run"

until psql -U "$XNAT_DATASOURCE_USERNAME" -h localhost -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 5
done

>&2 echo "Postgres is up - executing command \"$cmd\""
exec $cmd