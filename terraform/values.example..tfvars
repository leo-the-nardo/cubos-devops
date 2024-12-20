DB_USER="cubos"
DB_PASS="cubos"
DB_NAME="naruto"

# ELASTICSEARCH_FILEBEAT_APIKEY="a:a"
ELASTICSEARCH_URL="https://elasticsearch.cloudificando.com:443"

OTEL_TOKEN=luffy
ELASTIC_APM_URL="http://fleet-server:8200"
ELASTIC_APM_TOKEN="supersecrettoken"
NEWRELIC_API_KEY=""
NEWRELIC_URL="https://otlp.nr-data.net:443"
OTEL_LGTM_URL="http://otel-lgtm:4318"
OTEL_COLLECTOR_URL="https://otel-collector:4317"
# PROMETHEUS_URL=http://prometheus:9090
# ELASTICSEARCH_GRAFANA_APIKEY="=="



# Password for the 'elastic' user (at least 6 characters)
ELASTIC_PASSWORD="changeme"

# Password for the 'kibana_system' user (at least 6 characters)
KIBANA_PASSWORD="changeme"

# Version of Elastic products
#https://www.elastic.co/downloads/past-releases#elasticsearch
STACK_VERSION="8.14.3"
# STACK_VERSION=8.16.0
# STACK_VERSION=8.8.2

# Set the cluster name
CLUSTER_NAME="docker-cluster"

# Set to 'basic' or 'trial' to automatically start the 30-day trial
LICENSE="basic"
#LICENSE=trial

# Port to expose Elasticsearch HTTP API to the host
ES_PORT=9200

# Port to expose Kibana to the host
KIBANA_PORT=5601

# Port to expose Fleet to the host
FLEET_PORT=8220

# Port to expose APM to the host
APMSERVER_PORT=8200

# APM Secret Token for POC environments only
ELASTIC_APM_SECRET_TOKEN="supersecrettoken"

# Increase or decrease based on the available host memory (in bytes)
ES_MEM_LIMIT=3073741824
KB_MEM_LIMIT=1073741824
LS_MEM_LIMIT=1073741824

# SAMPLE Predefined Key only to be used in POC environments
ENCRYPTION_KEY="c34d38b3a14956121ff2170e5030b471551370178f43e5626eec58b04a30fae2"