resource "docker_volume" "certs" {
  name = "certs"
}

resource "docker_volume" "esdata01" {
  name = "esdata01"
}

resource "docker_volume" "kibanadata" {
  name = "kibanadata"
}

resource "docker_volume" "metricbeatdata01" {
  name = "metricbeatdata01"
}

resource "docker_volume" "fleetserverdata" {
  name = "fleetserverdata"
}
