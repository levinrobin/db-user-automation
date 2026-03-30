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
 EXISTS=$(psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" -t -A -c \
   "SELECT 1 FROM pg_roles WHERE rolname = '$USER_NAME'")
 if [ "$EXISTS" = "1" ]; then
   echo "User $USER_NAME already exists"
   continue
 fi
 USER_PASSWORD=$(openssl rand -base64 16)
 SECRET_NAME="db-user-${USER_NAME}-password"
 psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" <<EOF
CREATE USER "$USER_NAME" WITH LOGIN PASSWORD '$USER_PASSWORD';
EOF
 if ! gcloud secrets describe "$SECRET_NAME" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
   gcloud secrets create "$SECRET_NAME" \
     --project="$GCP_PROJECT_ID" \
     --replication-policy="automatic"
 fi
 printf "%s" "$USER_PASSWORD" | gcloud secrets versions add "$SECRET_NAME" \
   --project="$GCP_PROJECT_ID" \
   --data-file=-
 echo "User $USER_NAME created and password stored in Secret Manager"
done
echo "Done"
psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" -c "\du"
