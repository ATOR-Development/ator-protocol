job "anon-debian-repo" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "ator-network"

  group "anon-debian-repo-group" {
    count = 1

    constraint {
      attribute = "${node.unique.id}"
      value     = "c8e55509-a756-0aa7-563b-9665aa4915ab"
    }

    volume "deb-repo" {
      type      = "host"
      read_only = false
      source    = "deb-repo"
    }

    network  {
      port "reprepro-ssh" {
        static = 22
      }
      port "nginx-http" {
        static = 8001
      }
      port "exporter-http" {
        static = 8002
        to = 8080
      }
    }

    ephemeral_disk {
      migrate = true
      sticky  = true
    }

    task "anon-debian-repo-nginx-task" {
      driver = "docker"

      volume_mount {
        volume      = "deb-repo"
        destination = "/data/debian"
        read_only   = false
      }

      config {
        image = "nginx:stable"
        ports = ["nginx-http"]
        volumes = [
          "local/default.conf:/etc/nginx/conf.d/default.conf:ro",
        ]
      }

      resources {
        cpu = 256
        memory = 256
      }

      service {
        name = "anon-debian-repo-nginx"
        port = "nginx-http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.deb-repo.entrypoints=https",
          "traefik.http.routers.deb-repo.rule=Host(`deb.dmz.ator.dev`)",
          "traefik.http.routers.deb-repo.tls=true",
          "traefik.http.routers.deb-repo.tls.certresolver=atorresolver",
        ]
        check {
          name     = "nginx http server alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "10s"
          check_restart {
            limit = 10
            grace = "30s"
          }
        }
      }

      template {
        change_mode = "noop"
        data = <<EOH
server {
    listen       8001;
    listen  [::]:8001;
    server_name  localhost;

    location /db/ {
        deny all;
        return 403;
    }

    location /conf/ {
        deny all;
        return 403;
    }

    location /incoming/ {
        deny all;
        return 403;
    }

    location / {
        location /pool/main/a/anon/ {
	        access_log /alloc/data/access.log;
        }

        root   /data/debian;
        autoindex on;
    }
}
        EOH
        destination = "local/default.conf"
      }
    }

    task "anon-package-exporter-task" {
      driver = "docker"

      config {
        image = "svforte/package-exporter:v0.0.2"
        ports = ["exporter-http"]
        volumes = [
          "local/exporter.yml:/app/config.yml:ro",
        ]
      }

      service {
        name = "anon-download-exporter"
        port = "exporter-http"
        check {
          name     = "anon download exporter alive"
          type     = "http"
          port     = "exporter-http"
          path     = "/"
          interval = "10s"
          timeout  = "10s"
          check_restart {
            limit = 10
            grace = "30s"
          }
        }
      }

      resources {
        cpu = 256
        memory = 256
      }

      template {
        change_mode = "noop"
        data = <<EOH
fetchers:
  dockerhub_pulls:
    - name: anon_dev_dockerhub
      owner: svforte
      repo: anon-dev
    - name: anon_stage_dockerhub
      owner: svforte
      repo: anon-stage
    - name: anon_live_dockerhub
      owner: svforte
      repo: anon
  github_releases:
    - name: anon_dev_github_releases
      owner: ATOR-Development
      repo: ator-protocol
      assets_regexp: ^anon.+-dev-.+\.deb
    - name: anon_stage_github_releases
      owner: ATOR-Development
      repo: ator-protocol
      assets_regexp: ^anon.+-stage-.+\.deb
    - name: anon_live_github_releases
      owner: ATOR-Development
      repo: ator-protocol
      assets_regexp: ^anon.+-live-.+\.deb
  nginx_access_log:
    - name: anon_dev_debian_repo
      access_log_path: "/alloc/data/access.log"
      access_log_regexp: '"GET /pool/.+anon_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-dev.+\.deb HTTP\/1\.1" 200'
    - name: anon_stage_debian_repo
      access_log_path: "/alloc/data/access.log"
      access_log_regexp: '"GET /pool/.+anon_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-stage.+\.deb HTTP\/1\.1" 200'
    - name: anon_live_debian_repo
      access_log_path: "/alloc/data/access.log"
      access_log_regexp: '"GET /pool/.+anon_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-live.+\.deb HTTP\/1\.1" 200'
        EOH
        destination = "local/exporter.yml"
      }
    }

    task "anon-debian-repo-task" {
      driver = "docker"

      volume_mount {
        volume      = "deb-repo"
        destination = "/data/debian"
        read_only   = false
      }

      config {
        image = "svforte/reprepro:v0.0.6"
        ports = ["reprepro-ssh"]
        volumes = [
          "local/distributions:/data/debian/conf/distributions:ro",
          "local/incoming:/data/debian/conf/incoming:ro",
          "secrets/config:/config:ro"
        ]
      }

      resources {
        cpu = 256
        memory = 256
      }

      service {
        name = "anon-debian-repo-reprepro"
        port = "reprepro-ssh"
        check {
          name     = "reprepro ssh server alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "10s"
          check_restart {
            limit = 10
            grace = "30s"
          }
        }
      }

      template {
        change_mode = "noop"
        data = <<EOH
{{ base64Decode "[[.reprepro_sec]]" }}
        EOH
        destination = "secrets/config/reprepro-sec.gpg"
        perms = "0600"
      }

      template {
        change_mode = "noop"
        data = <<EOH
{{ base64Decode "[[.reprepro_pub]]" }}
        EOH
        destination = "secrets/config/reprepro-pub.gpg"
        perms = "0600"
      }

      template {
        change_mode = "noop"
        data = <<EOH
{{ base64Decode "[[.authorized_keys]]" }}
        EOH
        destination = "secrets/config/reprepro-authorized_keys"
      }

      template {
        change_mode = "noop"
        data = <<EOH
Origin: Anon
Label: Anon
Codename: anon-live-bookworm
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Boookworm Live
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-live-bullseye
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Bullseye Live
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-live-jammy
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Jammy Live
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-live-focal
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Focal Live
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-stage-bookworm
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Boookworm Stage
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-stage-bullseye
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Bullseye Stage
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-stage-jammy
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Jammy Stage
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-stage-focal
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Focal Stage
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-dev-bookworm
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Boookworm Dev
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-dev-bullseye
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Bullseye Dev
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-dev-jammy
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Jammy Dev
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-dev-focal
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Focal Dev
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-unstable-dev-bookworm
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Boookworm Unstable Dev
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-unstable-dev-bullseye
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Bullseye Unstable Dev
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-unstable-dev-jammy
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Jammy Unstable Dev
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-unstable-dev-focal
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Focal Unstable Dev
SignWith: YES
        EOH
        destination = "local/distributions"
      }

      template {
        change_mode = "noop"
        data = <<EOH
Name: incoming
IncomingDir: /data/debian/incoming
TempDir: /tmp
Allow: anon-live-bookworm anon-live-bullseye anon-live-jammy anon-live-focal anon-stage-bookworm anon-stage-bullseye anon-stage-jammy anon-stage-focal anon-dev-bookworm anon-dev-bullseye anon-dev-jammy anon-dev-focal anon-unstable-dev-bookworm anon-unstable-dev-bullseye anon-unstable-dev-jammy anon-unstable-dev-focal
Cleanup: on_deny on_error unused_files
        EOH
        destination = "local/incoming"
      }
    }
  }
}
