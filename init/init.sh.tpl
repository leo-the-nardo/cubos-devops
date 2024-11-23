#!/bin/bash

set -euo pipefail

# === Paths ===
ROOT_DIR=/certs
MIGRATIONS_DIR=/migrations

# === Function to log messages ===

# === Function to wait for PostgreSQL to be ready ===
echo "### Waiting for PostgreSQL to be ready ###"
until pg_isready -h db -U "$DB_USER" -d "$DB_NAME"; do
    echo "PostgreSQL is unavailable - sleeping"
    sleep 2
done
echo "PostgreSQL is up and running"
echo "### Applying SQL migrations ###"

# Define SSL parameters
SSL_PARAMS="host=db user=$DB_USER dbname=$DB_NAME sslmode=verify-full sslrootcert=/certs/ca/ca.crt sslcert=/certs/cubos/cubos.crt sslkey=/certs/cubos/cubos.key"

# Apply the SQL script
PGPASSWORD="$DB_PASS" psql "host=db user=$DB_USER dbname=$DB_NAME $SSL_PARAMS" < "$MIGRATIONS_DIR/script.sql"

echo "### SQL migrations applied ###"
echo "### Init Container tasks completed ###"
