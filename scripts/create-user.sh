#!/bin/bash
set -e
USER_NAME="user_04"
USER_PASSWORD="$NEW_DB_PASSWORD"
echo "Checking if user '$USER_NAME' already exists..."
psql -h 127.0.0.1 -p 5432 -U "$PGUSER" -d "$PGDATABASE" <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (
     SELECT 1 FROM pg_roles WHERE rolname = '$USER_NAME'
  ) THEN
     CREATE USER $USER_NAME WITH PASSWORD '$USER_PASSWORD';
     RAISE NOTICE 'User created successfully.';
  ELSE
     RAISE NOTICE 'User already exists. Skipping creation.';
  END IF;
END
\$\$;
EOF
echo "Script execution completed."
