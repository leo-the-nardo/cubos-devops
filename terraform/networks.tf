resource "docker_network" "web_net" {
  name   = "web_net"
  driver = "bridge"
}

resource "docker_network" "app_net" {
  name   = "app_net"
  driver = "bridge"
}

resource "docker_network" "data_net" {
  name     = "data_net"
  driver   = "bridge"
  internal = true
}
