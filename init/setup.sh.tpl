#!/bin/bash

if [ x${ELASTIC_PASSWORD} == x ]; then
  echo "Set the ELASTIC_PASSWORD environment variable in the .env file";
  exit 1;
elif [ x${KIBANA_PASSWORD} == x ]; then
  echo "Set the KIBANA_PASSWORD environment variable in the .env file";
  exit 1;
fi;
if [ ! -f config/certs/ca.zip ]; then
  echo "Creating CA";
  bin/elasticsearch-certutil ca --silent --pem -out config/certs/ca.zip;
  unzip config/certs/ca.zip -d config/certs;
fi;
if [ ! -f config/certs/certs.zip ]; then
  echo "Creating certs";
  echo -ne \
  "instances:\n"\
  "  - name: es01\n"\
  "    dns:\n"\
  "      - es01\n"\
  "      - localhost\n"\
  "    ip:\n"\
  "      - 127.0.0.1\n"\
  "  - name: kibana\n"\
  "    dns:\n"\
  "      - kibana\n"\
  "      - localhost\n"\
  "    ip:\n"\
  "      - 127.0.0.1\n"\
  "  - name: fleet-server\n"\
  "    dns:\n"\
  "      - fleet-server\n"\
  "      - localhost\n"\
  "    ip:\n"\
  "      - 127.0.0.1\n"\
  "  - name: elastic-agent-apm\n"\
  "    dns:\n"\
  "      - elastic-agent-apm\n"\
  "      - localhost\n"\
  "    ip:\n"\
  "      - 127.0.0.1\n"\
  "  - name: otel-collector\n"\
  "    dns:\n"\
  "      - otel-collector\n"\
  "      - localhost\n"\
  "    ip:\n"\
  "      - 127.0.0.1\n"\
  "  - name: nginx\n"\
  "    dns:\n"\
  "      - nginx\n"\
  "      - localhost\n"\
  "    ip:\n"\
  "      - 127.0.0.1\n"\
  "  - name: postgres\n"\
  "    dns:\n"\
  "      - postgres\n"\
  "      - db\n"\
  "      - localhost\n"\
  "    ip:\n"\
  "      - 127.0.0.1\n"\
  "  - name: cubos\n"\
  "    dns:\n"\
  "      - cubos\n"\
  "      - localhost\n"\
  "    ip:\n"\
  "      - 127.0.0.1\n"\
  > config/certs/instances.yml;
  bin/elasticsearch-certutil cert --silent --pem -out config/certs/certs.zip --in config/certs/instances.yml --ca-cert config/certs/ca/ca.crt --ca-key config/certs/ca/ca.key;
  unzip config/certs/certs.zip -d config/certs;
fi;
echo "Setting file permissions"
chown -R root:root config/certs;
find . -type d -exec chmod 750 \{\} \;;
find . -type f -exec chmod 640 \{\} \;;
echo "Updating ca_trusted_fingerprint in kibana.yml"
sed -i -e "/^\s*xpack\.fleet\.outputs:/,/^\s*xpack\./{
  /^\s*-\s*id:\s*elasticsearch\s*$/,/^\s*-\s*id:/{
    s/^\(\s*ca_trusted_fingerprint:\s*\).*/\1\"$(openssl x509 -fingerprint -sha256 -noout -in config/certs/ca/ca.crt | sed "s/.*=//;s/://g")\"/
  }
}" /usr/share/kibana/config/kibana.yml;
echo "Waiting for Elasticsearch availability";
until curl -s --cacert config/certs/ca/ca.crt https://es01:9200 | grep -q "missing authentication credentials"; do sleep 30; done;
echo "Setting kibana_system password";
until curl -s -X POST --cacert config/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" https://es01:9200/_security/user/kibana_system/_password -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q "^{}"; do sleep 10; done;
echo "Extracting CA certificate SHA256 fingerprint"
echo "Updating xpack.fleet.agents.elasticsearch.ca_sha256 in kibana.yml"
CA_FINGERPRINT=$(openssl x509 -fingerprint -sha256 -noout -in config/certs/ca/ca.crt | sed "s/.*=//;s/://g")
echo "All done";

#postgres
# === Paths ===
MIGRATIONS_DIR=/migrations

# === Function to log messages ===

# # === Function to wait for PostgreSQL to be ready ===
# echo "### Waiting for PostgreSQL to be ready ###"
# until pg_isready -h db -U "$DB_USER" -d "$DB_NAME"; do
#     echo "PostgreSQL is unavailable - sleeping"
#     sleep 2
# done
# echo "PostgreSQL is up and running"
# echo "### Applying SQL migrations ###"
# install postgresql-client
apt-get update
apt-get install -y postgresql-client

# Define SSL parameters
SSL_PARAMS="host=db user=$DB_USER dbname=$DB_NAME sslmode=verify-full sslrootcert=config/certs/ca/ca.crt sslcert=config/certs/cubos/cubos.crt sslkey=config/certs/cubos/cubos.key"

# Apply the SQL script
PGPASSWORD="$DB_PASS" psql "host=db user=$DB_USER dbname=$DB_NAME $SSL_PARAMS" < "$MIGRATIONS_DIR/script.sql"

echo "### SQL migrations applied ###"
echo "### Init Container tasks completed ###"

tail -f /dev/null