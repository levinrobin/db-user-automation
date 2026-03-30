#!/bin/bash
set -e
if [ ! -f user.yml ]; then
 echo "user.yml not found"
 exit 1
fi
USER_LIST=$(grep 'name:' user.yml | awk '{print $3}')
if [ -z "$USER_LIST" ]; then
 echo "no users found in user.yml"
 exit 1
fi
for USER_NAME in $USER_LIST
do
 echo "Checking user: $USER_NAME"
 USER_EXISTS=$(psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" \
   -t -A -c "SELECT 1 FROM pg_roles WHERE rolname = '$USER_NAME'")
 if [ "$USER_EXISTS" = "1" ]; then
   echo "User $USER_NAME already exists"
 else
   USER_PASSWORD=$(openssl rand -base64 16)
   SECRET_NAME="${USER_NAME}-db-password"
   psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" <<EOF
CREATE USER "$USER_NAME" WITH LOGIN PASSWORD '$USER_PASSWORD';
EOF
   echo "User $USER_NAME created"
   if gcloud secrets describe "$SECRET_NAME" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
     printf "%s" "$USER_PASSWORD" | gcloud secrets versions add "$SECRET_NAME" \
       --project="$GCP_PROJECT_ID" \
       --data-file=-
   else
     gcloud secrets create "$SECRET_NAME" \
       --project="$GCP_PROJECT_ID" \
       --replication-policy="automatic"
     printf "%s" "$USER_PASSWORD" | gcloud secrets versions add "$SECRET_NAME" \
       --project="$GCP_PROJECT_ID" \
       --data-file=-
   fi
   echo "Password stored for $USER_NAME"
 fi
done
EXISTING_USERS=$(psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" -t -A -c "
SELECT rolname
FROM pg_roles
WHERE rolname NOT IN ('postgres', 'migration_user')
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
   SECRET_NAME="${DB_USER}-db-password"
   if gcloud secrets describe "$SECRET_NAME" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
     gcloud secrets delete "$SECRET_NAME" \
       --project="$GCP_PROJECT_ID" \
       --quiet
     echo "Deleted secret for $DB_USER"
   fi
 fi
done
echo "Sync complete"
psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" -c "\du"
