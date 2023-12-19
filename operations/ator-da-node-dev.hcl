job "ator-dir-auth-dev" {
  datacenters = ["ator-fin"]
  type = "service" 

  group "dir-auth-dev-group" {
    count = 3
    
    spread {
      attribute = "${node.unique.id}"
      weight    = 100
      target "067a42a8-d8fe-8b19-5851-43079e0eabb4" {
        percent = 34
      }
      target "16be0723-edc1-83c4-6c02-193d96ec308a" {
        percent = 33
      }
      target "e6e0baed-8402-fd5c-7a15-8dd49e7b60d9" {
        percent = 33
      }
    }

    network  {
      port "orport" {
        static = 9001
      }
      port "dirport" {
        static = 9030
      }

    }

    volume "dir-auth-dev" {
      type      = "host"
      read_only = false
      source    = "dir-auth-dev"
    }

    task "dir-auth-dev-task" {
      driver = "docker"
    
      volume_mount {
        volume      = "dir-auth-dev"
        destination = "/var/lib/tor/"
        read_only   = false
      } 
          
      config {
        image = "svforte/ator-protocol:latest"
        ports = ["orport", "dirport"]
        volumes = [
          "local/torrc:/etc/tor/torrc",
          "local/tor/keys:/var/lib/tor/keys",
          "local/tor/fingerprint:/var/lib/tor/fingerprint",
          "local/tor/fingerprint_ed25519:/var/lib/tor/fingerprint_ed25519"
        ]
      }

      vault {
        policies = ["ator-network-read"]
      }

      resources {
        cpu = 2048
        memory = 2048
      }  

      template {
        data = <<EOH
          {{ key (env "node.unique.id" | printf "ator-network/dev/dir-auth-%s/authority_certificate") }}
        EOH
        destination = "local/tor/keys/authority_certificate"
      }

      template {
        data = <<EOH
          {{ key (env "node.unique.id" | printf "ator-network/dev/dir-auth-%s/fingerprint") }}
        EOH
        destination = "local/tor/fingerprint"
      }

      template {
        data = <<EOH
          {{ key (env "node.unique.id" | printf "ator-network/dev/dir-auth-%s/fingerprint-ed25519") }}
        EOH
        destination = "local/tor/fingerprint_ed25519"
      }

      template {
        data = <<EOH
          {{ with secret  (env "node.unique.id" | printf "kv/ator-network/dev/dir-auth-%s") }}
          {{ .Data.data.authority_identity_key}}
          {{end}}
        EOH
        destination = "local/tor/keys/authority_identity_key"
      }

      template {
        data = <<EOH
          {{ with secret  (env "node.unique.id" | printf "kv/ator-network/dev/dir-auth-%s") }}
          {{.Data.data.authority_signing_key}}
          {{end}}
        EOH
        destination = "local/tor/keys/authority_signing_key"
      }

      template {
        data = <<EOH
          {{ with secret  (env "node.unique.id" | printf "kv/ator-network/dev/dir-auth-%s") }}
          {{ base64Decode .Data.data.ed25519_master_id_secret_key_base64}}
          {{end}}
        EOH
        destination = "local/tor/keys/ed25519_master_id_secret_key"
      }

      template {
        data = <<EOH
          {{ with secret  (env "node.unique.id" | printf "kv/ator-network/dev/dir-auth-%s") }}
          {{ base64Decode .Data.data.ed25519_signing_secret_key_base64}}
          {{end}}
        EOH
        destination = "local/tor/keys/ed25519_signing_secret_key"
      }

      template {
        data = <<EOH
          {{ with secret  (env "node.unique.id" | printf "kv/ator-network/dev/dir-auth-%s") }}
          {{ base64Decode .Data.data.secret_id_key_base64}}
          {{end}}
        EOH
        destination = "local/tor/keys/secret_id_key"
      }

      template {
        data = <<EOH
          {{ with secret  (env "node.unique.id" | printf "kv/ator-network/dev/dir-auth-%s") }}
          {{ base64Decode .Data.data.secret_onion_key_base64}}
          {{end}}
        EOH
        destination = "local/tor/keys/secret_onion_key"
      }

      template {
        data = <<EOH
          {{ with secret  (env "node.unique.id" | printf "kv/ator-network/dev/dir-auth-%s") }}
          {{ base64Decode .Data.data.secret_onion_key_ntor_base64}}
          {{end}}
        EOH
        destination = "local/tor/keys/secret_onion_key_ntor"
      }

      template {
        data = <<EOH
          ##=================== /etc/torrc =====================##
          # see /usr/local/etc/tor/torrc.sample and https://www.torproject.org/docs/tor-manual.html.en

          # Run Tor as a regular user (do not change this)
          User atord
          DataDirectory /var/lib/tor

          AuthoritativeDirectory 1
          V3AuthoritativeDirectory 1

          # Server's public IP Address (usually automatic)
          Address {{ key (env "node.unique.id" | printf "ator-network/dev/dir-auth-%s/public_ipv4") }}

          # Port to advertise for incoming Tor connections.
          ORPort 9001                  # common ports are 9001, 443
          #ORPort 1.1.1.1:9001

          # Mirror directory information for others (optional, not used on bridge)
          DirPort 9030                 # common ports are 9030, 80

          # Run Tor only as a server (no local applications)
          SocksPort 0
          ControlSocket 0

          # Run as a relay only (change policy to enable exit node)
          ExitPolicy reject *:*        # no exits allowed
          ExitPolicy reject6 *:*
          ExitRelay 0
          IPv6Exit 0
          
          # Set limits
          #AccountingMax 999 GB
          #RelayBandwidthRate 512 KB   # Throttle traffic to
          #RelayBandwidthBurst 1024 KB # But allow bursts up to
          #MaxMemInQueues 512 MB       # Limit Memory usage to
          
          ## Run Tor as obfuscated bridge
          # https://trac.torproject.org/projects/tor/wiki/doc/PluggableTransports/obfs4proxy
          #ServerTransportPlugin obfs4 exec /usr/local/bin/obfs4proxy
          #ServerTransportListenAddr obfs4  0.0.0.0:54444
          #ExtORPort auto
          #BridgeRelay 1
          
          ## If no Nickname or ContactInfo is set, docker-entrypoint will use
          ## the environment variables to add Nickname/ContactInfo below
          #Nickname ATORv4example          # only use letters and numbers
          #ContactInfo atorv4@example.org
        EOH
        destination = "local/torrc"
      }

      service {
        port = "dirport"
        check {
          name     = "dir auth alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "10s"
          check_restart {
            limit = 10
            grace = "30s"
          }
        }
      }
    }    
  }
}
