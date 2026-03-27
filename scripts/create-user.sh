#!/bin/bash
set -e
if [ ! -f user.yml ]; then
 echo "user.yml not found"
 exit 1
fi
USER_LIST=$(grep 'name:' user.yml | awk '{print $3}')
for USER_NAME in $USER_LIST
do
 echo "Checking user: $USER_NAME"
 psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (
     SELECT 1 FROM pg_roles WHERE rolname = '$USER_NAME'
  ) THEN
     CREATE USER "$USER_NAME" WITH LOGIN PASSWORD '$NEW_DB_PASSWORD';
     RAISE NOTICE 'User $USER_NAME created';
  ELSE
     RAISE NOTICE 'User $USER_NAME already exists';
  END IF;
END
\$\$;
EOF
done
EXISTING_USERS=$(psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" -t -A -c "
SELECT rolname
FROM pg_roles
WHERE rolname NOT IN ('postgres')
 AND rolname NOT LIKE 'pg_%'
 AND rolname NOT LIKE 'cloudsql%'
")
for DB_USER in $EXISTING_USERS
do
 if ! grep -q "name: $DB_USER" user.yml; then
   echo "Deleting user: $DB_USER"
   psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" <<EOF
REASSIGN OWNED BY "$DB_USER" TO "$PGUSER";
DROP OWNED BY "$DB_USER";
DROP ROLE "$DB_USER";
EOF
 fi
done
echo "Sync complete"
psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" -c "\du"
