resource "docker_image" "init" {
  name = "init_image"

  build {
    context = abspath("${path.module}/../init")
  }
}

resource "docker_container" "init" {
  name    = "init"
  image   = docker_image.init.image_id
  restart = "no"

  env = [
    "DB_USER=${var.DB_USER}",
    "DB_PASS=${var.DB_PASS}",
    "DB_NAME=${var.DB_NAME}",
  ]

  depends_on = [
    docker_container.setup,
    docker_container.db,
  ]

  mounts {
    target = "/certs"
    source = docker_volume.certs.name
    type   = "volume"
  }

  mounts {
    target    = "/migrations"
    source    = abspath("${path.module}/../database/migrations")
    type      = "bind"
    read_only = true
  }

  networks_advanced {
    name = docker_network.app_net.name
  }

  networks_advanced {
    name = docker_network.data_net.name
  }
}

resource "docker_container" "db" {
  name    = "db"
  image   = "bitnami/postgresql:15"
  restart = "always"

  env = [
    "POSTGRESQL_USERNAME=${var.DB_USER}",
    "POSTGRESQL_PASSWORD=${var.DB_PASS}",
    "POSTGRESQL_DATABASE=${var.DB_NAME}",
    "POSTGRESQL_TLS_CERT_FILE=/certs/postgres/postgres.crt",
    "POSTGRESQL_TLS_KEY_FILE=/certs/postgres/postgres.key",
    "POSTGRESQL_TLS_CA_FILE=/certs/ca/ca.crt",
    "POSTGRESQL_ENABLE_TLS=yes",
  ]

  mounts {
    target = "/var/lib/postgresql/data"
    source = abspath("${path.module}/../db_data")
    type   = "bind"
  }

  mounts {
    target = "/certs"
    source = docker_volume.certs.name
    type   = "volume"
  }

  networks_advanced {
    name = docker_network.data_net.name
  }

  ports {
    internal = 5432
    external = 5432
  }

  healthcheck {
    test     = ["CMD", "pg_isready", "-U", "${var.DB_USER}"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }

  labels {
    label = "logging"
    value = "enabled"
  }

  depends_on = [
    docker_container.setup,
  ]
}

resource "docker_image" "backend" {
  name = "backend_image"

  build {
    context = abspath("${path.module}/../backend")
  }
}

resource "docker_container" "backend" {
  name    = "backend"
  image   = docker_image.backend.image_id
  restart = "always"

  env = [
    "PORT=3000",
    "DB_USER=${var.DB_USER}",
    "DB_PASS=${var.DB_PASS}",
    "DB_HOST=db",
    "DB_PORT=5432",
    "DB_NAME=${var.DB_NAME}",
    "PGSSLCERT=/app/certs/cubos/cubos.crt",
    "PGSSLKEY=/app/certs/cubos/cubos.key",
    "PGSSLROOTCERT=/app/certs/ca/ca.crt",
    "OTEL_TRACES_EXPORTER=otlp",
    "OTEL_METRICS_EXPORTER=otlp",
    "OTEL_LOGS_EXPORTER=otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL=grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT=${var.OTEL_COLLECTOR_URL}",
    "OTEL_EXPORTER_OTLP_HEADERS=Authorization=Bearer ${var.OTEL_TOKEN}",
    "OTEL_RESOURCE_ATTRIBUTES=service.name=cubos-backend,service.version=1.0.0,deployment.environment=production",
    "OTEL_NODE_RESOURCE_DETECTORS=env,host,os",
    "NODE_EXTRA_CA_CERTS=/app/certs/ca/ca.crt",
    "OTEL_SEMCONV_STABILITY_OPT_IN=http",
    "OTEL_EXPORTER_OTLP_METRICS_DEFAULT_HISTOGRAM_AGGREGATION=base2_exponential_bucket_histogram",
    # "OTEL_LOG_LEVEL=debug",
  ]

  mounts {
    target    = "/app/certs"
    source    = docker_volume.certs.name
    type      = "volume"
    read_only = true
  }

  depends_on = [
    docker_container.db,
    docker_container.init,
  ]

  networks_advanced {
    name = docker_network.app_net.name
  }

  networks_advanced {
    name = docker_network.data_net.name
  }
}

resource "docker_image" "nginx" {
  name = "nginx_image"
  keep_locally = false
  build {
    context    = "${path.module}/../nginx"
    no_cache = true
  }
  
}

resource "docker_container" "nginx" {
  name    = "nginx"
  image   = docker_image.nginx.image_id
  restart = "always"

  ports {
    internal = 80
    external = 80
  }

  ports {
    internal = 443
    external = 443
  }

  depends_on = [
    docker_container.setup,
    docker_container.backend,
  ]

  mounts {
    target    = "/etc/nginx/certs"
    source    = docker_volume.certs.name
    type      = "volume"
    read_only = true
  }

  networks_advanced {
    name = docker_network.web_net.name
  }

  networks_advanced {
    name = docker_network.app_net.name
  }
}

resource "docker_container" "postgres_exporter" {
  name  = "postgres-exporter"
  image = "bitnami/postgres-exporter:latest"

  env = [
    "DATA_SOURCE_NAME=postgresql://${var.DB_USER}:${var.DB_PASS}@db:5432/${var.DB_NAME}",
    "PGSSLMODE=verify-full",
    "PGSSLROOTCERT=/certs/ca/ca.crt",
    "PGSSLCERT=/certs/cubos/cubos.crt",
    "PGSSLKEY=/certs/cubos/cubos.key",
  ]

  mounts {
    target    = "/certs"
    source    = docker_volume.certs.name
    type      = "volume"
    read_only = true
  }

  depends_on = [
    docker_container.setup,
    docker_container.db,
  ]

  networks_advanced {
    name = docker_network.app_net.name
  }

  networks_advanced {
    name = docker_network.data_net.name
  }

  command = ["--no-collector.wal"]
  
  labels {
    label = "logging"
    value = "enabled"
  }

}

resource "docker_container" "otel_collector" {
  name    = "otel-collector"
  image   = "otel/opentelemetry-collector-contrib:0.113.0"
  restart = "unless-stopped"

  ports {
    internal = 4317
    external = 4317
  }

  ports {
    internal = 4318
    external = 4318
  }

  env = [
    "OTEL_TOKEN=${var.OTEL_TOKEN}",
    "ELASTIC_APM_URL=${var.ELASTIC_APM_URL}",
    "ELASTIC_APM_TOKEN=${var.ELASTIC_APM_TOKEN}",
    "NEWRELIC_API_KEY=${var.NEWRELIC_API_KEY}",
    "OTEL_LGTM_URL=${var.OTEL_LGTM_URL}",
    "NEWRELIC_URL=${var.NEWRELIC_URL}",
  ]

  mounts {
    target    = "/etc/otel/config.yaml"
    source    = abspath("${path.module}/../otel-collector/config.yaml")
    type      = "bind"
    read_only = true
  }

  mounts {
    target    = "/certs"
    source    = docker_volume.certs.name
    type      = "volume"
    read_only = true
  }

  command = ["--config", "/etc/otel/config.yaml"]

  depends_on = [
    docker_container.setup,
    docker_container.db,
  ]

  networks_advanced {
    name = docker_network.app_net.name
  }
}

resource "docker_container" "es01" {
  name  = "es01"
  image = "docker.elastic.co/elasticsearch/elasticsearch:${var.STACK_VERSION}"

  env = [
    "node.name=es01",
    "cluster.name=${var.CLUSTER_NAME}",
    "discovery.type=single-node",
    "ELASTIC_PASSWORD=${var.ELASTIC_PASSWORD}",
    "bootstrap.memory_lock=true",
    "xpack.security.enabled=true",
    "xpack.security.http.ssl.enabled=true",
    "xpack.security.http.ssl.key=certs/es01/es01.key",
    "xpack.security.http.ssl.certificate=certs/es01/es01.crt",
    "xpack.security.http.ssl.certificate_authorities=certs/ca/ca.crt",
    "xpack.security.transport.ssl.enabled=true",
    "xpack.security.transport.ssl.key=certs/es01/es01.key",
    "xpack.security.transport.ssl.certificate=certs/es01/es01.crt",
    "xpack.security.transport.ssl.certificate_authorities=certs/ca/ca.crt",
    "xpack.security.transport.ssl.verification_mode=certificate",
    "xpack.license.self_generated.type=${var.LICENSE}",
    "cluster.routing.allocation.disk.watermark.low=20mb",
    "cluster.routing.allocation.disk.watermark.high=15mb",
    "cluster.routing.allocation.disk.watermark.flood_stage=10mb",
    "ES_JAVA_OPTS=-Xms512m -Xmx512m",
  ]

  mounts {
    target = "/usr/share/elasticsearch/config/certs"
    source = docker_volume.certs.name
    type   = "volume"
  }

  mounts {
    target = "/usr/share/elasticsearch/data"
    source = docker_volume.esdata01.name
    type   = "volume"
  }

  ports {
    internal = 9200
    external = var.ES_PORT
  }

  ulimit {
    name = "memlock"
    soft = -1
    hard = -1
  }

  healthcheck {
    test     = ["CMD-SHELL", "curl -s --cacert config/certs/ca/ca.crt https://localhost:9200 | grep -q 'missing authentication credentials'"]
    interval = "10s"
    timeout  = "10s"
    retries  = 120
  }

  networks_advanced {
    name = docker_network.data_net.name
  }

  depends_on = [
    docker_container.setup,
  ]

  memory = var.ES_MEM_LIMIT
}

resource "docker_container" "kibana" {
  name  = "kibana"
  image = "docker.elastic.co/kibana/kibana:${var.STACK_VERSION}"

  env = [
      "SERVERNAME=kibana",
      "ELASTICSEARCH_HOSTS=https://es01:9200",
      "ELASTICSEARCH_USERNAME=kibana_system",
      "ELASTICSEARCH_PASSWORD=${var.KIBANA_PASSWORD}",
      "ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES=/usr/share/kibana/config/certs/ca/ca.crt",
      "XPACK_SECURITY_ENCRYPTIONKEY=${var.ENCRYPTION_KEY}",
      "XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY=${var.ENCRYPTION_KEY}",
      "XPACK_REPORTING_ENCRYPTIONKEY=${var.ENCRYPTION_KEY}",
      "XPACK_REPORTING_KIBANASERVER_HOSTNAME=localhost",
      "SERVER_SSL_ENABLED=true",
      "SERVER_SSL_CERTIFICATE=config/certs/kibana/kibana.crt",
      "SERVER_SSL_KEY=config/certs/kibana/kibana.key",
      "SERVER_SSL_CERTIFICATEAUTHORITIES=/usr/share/kibana/config/certs/ca/ca.crt",
      "ELASTIC_APM_SECRET_TOKEN=${var.ELASTIC_APM_SECRET_TOKEN}",
      "KIBANA_FLEET_CA=/usr/share/kibana/config/certs/ca/ca.crt",
  ]

  mounts {
    target = "/usr/share/kibana/config/certs"
    source = docker_volume.certs.name
    type   = "volume"
  }

  mounts {
    target = "/usr/share/kibana/data"
    source = docker_volume.kibanadata.name
    type   = "volume"
  }

  mounts {
    target    = "/usr/share/kibana/config/kibana.yml"
    source    = abspath("${path.module}/../elk/kibana.yml")
    type      = "bind"
    read_only = true
  }

  ports {
    internal = 5601
    external = var.KIBANA_PORT
  }

  healthcheck {
    test     = ["CMD-SHELL", "curl -I -s --cacert config/certs/ca/ca.crt https://localhost:5601 | grep -q 'HTTP/1.1 302 Found'"]
    interval = "10s"
    timeout  = "10s"
    retries  = 120
  }
  wait = true
  networks_advanced {
    name = docker_network.app_net.name
  }

  networks_advanced {
    name = docker_network.data_net.name
  }

  depends_on = [
    docker_container.es01,
  ]

  memory = var.KB_MEM_LIMIT
}

resource "docker_container" "setup" {
  name    = "setup"
  image   = "docker.elastic.co/elasticsearch/elasticsearch:${var.STACK_VERSION}"
  rm = false
  wait = true
  command = [
    "/bin/bash",
    "-c",
    templatefile("${path.module}/../init/setup.sh.tpl", {
    "ELASTIC_PASSWORD" = var.ELASTIC_PASSWORD
    "KIBANA_PASSWORD" = var.KIBANA_PASSWORD
    "DB_USER" = var.DB_USER
    "DB_PASS" = var.DB_PASS
    "DB_NAME" = var.DB_NAME
    })
  ]
  user = "0"
  logs = true
  # attach = true  
  mounts {
    target = "/usr/share/elasticsearch/config/certs"
    source = docker_volume.certs.name
    type   = "volume"
  }
  mounts {
    target    = "/migrations"
    source    = abspath("${path.module}/../database/migrations")
    type      = "bind"
    read_only = true
  }

  mounts {
    target = "/usr/share/kibana/config"
    source = abspath("${path.module}/../elk")
    type   = "bind"
  }

  healthcheck {
    test     = ["CMD-SHELL", "[ -f config/certs/es01/es01.crt ]"]
    interval = "7s"
    timeout  = "5s"
    retries  = 120
  }

  networks_advanced {
    name = docker_network.data_net.name
  }

  networks_advanced {
    name = docker_network.app_net.name
  }
  must_run = true
  # environment = {  }
}

output "logs" {
  value = docker_container.setup.container_logs
}
resource "docker_container" "fleet_server" {
  name    = "fleet-server"
  image   = "docker.elastic.co/beats/elastic-agent:${var.STACK_VERSION}"
  user    = "root"
  # rm = false
  # logs = true
  # attach = true
  env = [
    "SSL_CERTIFICATE_AUTHORITIES=/certs/ca/ca.crt",
    "CERTIFICATE_AUTHORITIES=/certs/ca/ca.crt",
    "FLEET_CA=/certs/ca/ca.crt",
    "FLEET_ENROLL=1",
    "FLEET_INSECURE=true",
    "FLEET_SERVER_ELASTICSEARCH_CA=/certs/ca/ca.crt",
    "FLEET_SERVER_ELASTICSEARCH_HOST=https://es01:9200",
    "FLEET_SERVER_ELASTICSEARCH_INSECURE=true",
    "FLEET_SERVER_ENABLE=1",
    "FLEET_SERVER_CERT=/certs/fleet-server/fleet-server.crt",
    "FLEET_SERVER_CERT_KEY=/certs/fleet-server/fleet-server.key",
    "FLEET_SERVER_INSECURE_HTTP=true",
    "FLEET_SERVER_POLICY_ID=fleet-server-policy",
    "FLEET_URL=https://fleet-server:8220",
    "KIBANA_FLEET_CA=/certs/ca/ca.crt",
    "KIBANA_FLEET_SETUP=1",
    "KIBANA_FLEET_USERNAME=elastic",
    "KIBANA_FLEET_PASSWORD=${var.ELASTIC_PASSWORD}",
    "KIBANA_HOST=https://kibana:5601",
  ]

  mounts {
    target = "/certs"
    source = docker_volume.certs.name
    type   = "volume"
  }

  mounts {
    target = "/usr/share/elastic-agent"
    source = docker_volume.fleetserverdata.name
    type   = "volume"
  }

  mounts {
    target = "/var/lib/docker/containers"
    source = "/var/lib/docker/containers"
    type   = "bind"
    read_only = true
  }

  mounts {
    target = "/var/run/docker.sock"
    source = "/var/run/docker.sock"
    type   = "bind"
    read_only = true
  }

  # mounts {
  #   target = "/sys/fs/cgroup"
  #   source = "/sys/fs/cgroup"
  #   type   = "bind"
  #   read_only = true
  # }

  # mounts {
  #   target = "/proc"
  #   source = "/proc"
  #   type   = "bind"
  #   read_only = true
  # }

  # mounts {
  #   target = "/hostfs"
  #   source = "/"
  #   type   = "bind"
  #   read_only = true
  # }

  ports {
    internal = 8220
    external = var.FLEET_PORT
  }

  ports {
    internal = 8200
    external = var.APMSERVER_PORT
  }

  networks_advanced {
    name = docker_network.app_net.name
  }
  networks_advanced {
    name = docker_network.data_net.name
  }

  depends_on = [
    docker_container.kibana,
    docker_container.es01,
  ]
}

# resource "docker_container" "filebeat" {
#   name  = "filebeat"
#   image = "docker.elastic.co/beats/filebeat:${var.STACK_VERSION}"

#   env = [
#     "ELASTICSEARCH_URL=${var.ELASTICSEARCH_URL}",
#     "ELASTICSEARCH_FILEBEAT_APIKEY=${var.ELASTICSEARCH_FILEBEAT_APIKEY}",
#   ]

#   mounts {
#     target    = "/usr/share/filebeat/filebeat.yml"
#     source    = abspath("${path.module}/../elk/filebeat/filebeat.yml")
#     type      = "bind"
#     read_only = true
#   }

#   mounts {
#     target = "/var/lib/docker/containers"
#     source = "/var/lib/docker/containers"
#     type   = "bind"
#     read_only = true
#   }

#   mounts {
#     target = "/var/run/docker.sock"
#     source = "/var/run/docker.sock"
#     type   = "bind"
#     read_only = true
#   }

#   mounts {
#     target = "/etc/filebeat/certs"
#     source = docker_volume.certs.name
#     type   = "volume"
#     read_only = true
#   }

#   mounts {
#     target = "/var/log/filebeat"
#     source = abspath("${path.module}/../elk/filebeat/logs")
#     type   = "bind"
#   }

#   networks_advanced {
#     name = docker_network.data_net.name
#   }

#   networks_advanced {
#     name = docker_network.app_net.name
#   }

#   depends_on = [
#     docker_container.setup,
#   ]
# }

resource "docker_container" "otel_lgtm" {
  name  = "otel-lgtm"
  image = "grafana/otel-lgtm:latest"

  ports {
    internal = 3000
    external = 3000
  }

  # Uncomment if needed
  # ports {
  #   internal = 4317
  #   external = 4317
  # }

  ports {
    internal = 9090
    external = 9090
  }

  networks_advanced {
    name = docker_network.app_net.name
  }

  networks_advanced {
    name = docker_network.data_net.name
  }

  mounts {
    target = "/otel-lgtm/grafana/data"
    source = abspath("${path.module}/../otel-lgtm/.data/grafana/data")
    type   = "bind"
  }

  mounts {
    target = "/data/prometheus"
    source = abspath("${path.module}/../otel-lgtm/.data/prometheus")
    type   = "bind"
  }

  mounts {
    target = "/loki"
    source = abspath("${path.module}/../otel-lgtm/.data/loki")
    type   = "bind"
  }

  mounts {
    target    = "/otel-lgtm/grafana/conf/provisioning/datasources/grafana-datasources.yaml"
    source    = abspath("${path.module}/../otel-lgtm/grafana-datasources.yaml")
    type      = "bind"
    read_only = true
  }

  mounts {
    target    = "/otel-lgtm/grafana/conf/provisioning/dashboards/grafana-dashboards.yaml"
    source    = abspath("${path.module}/../otel-lgtm/grafana-dashboards.yaml")
    type      = "bind"
    read_only = true
  }

  # Uncomment if needed
  # mounts {
  #   target    = "/otel-lgtm/grafana/conf/custom.ini"
  #   source    = abspath("${path.module}/../otel-lgtm/grafana.ini")
  #   type      = "bind"
  #   read_only = true
  # }

  mounts {
    target    = "/otel-lgtm/dashboards-json"
    source    = abspath("${path.module}/../otel-lgtm/dashboards-json")
    type      = "bind"
    read_only = true
  }

  mounts {
    target    = "/otel-lgtm/loki-config.yaml"
    source    = abspath("${path.module}/../otel-lgtm/loki-config.yaml")
    type      = "bind"
    read_only = true
  }

  mounts {
    target    = "/otel-lgtm/otelcol-config.yaml"
    source    = abspath("${path.module}/../otel-lgtm/otelcol-config.yaml")
    type      = "bind"
    read_only = true
  }

  mounts {
    target    = "/otel-lgtm/prometheus.yaml"
    source    = abspath("${path.module}/../otel-lgtm/prometheus.yaml")
    type      = "bind"
    read_only = true
  }

  mounts {
    target    = "/otel-lgtm/tempo-config.yaml"
    source    = abspath("${path.module}/../otel-lgtm/tempo-config.yaml")
    type      = "bind"
    read_only = true
  }

  env = [
    # Uncomment if needed
    # "GF_AUTH_ANONYMOUS_ENABLED=false",
    # "GF_AUTH_ANONYMOUS_ORG_ROLE=Admin",
    "ENABLE_LOGS_GRAFANA=true",
    "ENABLE_LOGS_LOKI=true",
    "ENABLE_LOGS_OTELCOL=true",
    "ENABLE_LOGS_TEMPO=true",
  ]
}
