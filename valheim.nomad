job "valheim" {
  datacenters = ["dc1"]

  group "valheim" {
    network {
      mode = "bridge"
      port "game1" {
        static = 2456
        to = 2456
      }
      port "game2" {
        static = 2457
        to = 2457
      }
      port "supervisor" {
        static = 9001
        to = 9001
      }
    }

    task "valheim-server" {
      driver = "docker"
      env {
        SERVER_NAME = "Testserver_Nomad"
        WORLD_NAME = "testworld"
        SERVER_PASS = "secret"
      }
      config {
        image = "ghcr.io/community-valheim-tools/valheim-server"
        volumes = [
          "/var/lib/valheim/config:/config",
          "/var/lib/valheim/data:/opt/valheim"
        ]
      }
      resources {
        cpu    = 6000
        memory = 4096
      }
    }
  }
}
