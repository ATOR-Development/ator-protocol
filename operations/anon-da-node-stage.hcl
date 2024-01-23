#TODO: use templating to avoid copypaste

job "ator-dir-auth-stage" {
  datacenters = ["ator-fin"]
  type = "service" 
  namespace = "ator-network"

  group "dir-auth-stage-group" {
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
        static = 9101
      }
      port "dirport" {
        static = 9130
      }

    }

    volume "dir-auth-stage" {
      type      = "host"
      read_only = false
      source    = "dir-auth-stage"
    }

    task "dir-auth-stage-task" {
      driver = "docker"
    
      volume_mount {
        volume      = "dir-auth-stage"
        destination = "/var/lib/anon/"
        read_only   = false
      } 
          
      config {
        image = "svforte/anon-stage:PLACEIMAGETAGHERE"
        ports = ["orport", "dirport"]
        volumes = [
          "local/anonrc:/etc/anon/anonrc",
          "secrets/anon/keys:/var/lib/anon/keys"
        ]
      }

      vault {
        policies = ["ator-network-read"]
      }

      resources {
        cpu = 256
        memory = 256
      }  

      template {
        change_mode = "noop"
        data = <<EOH
           {{ key (env `node.unique.id` | printf `ator-network/stage/dir-auth-%s/authority_certificate`) }}
        EOH
        destination = "secrets/anon/keys/authority_certificate"
      }
      
      template {
        change_mode = "noop"
        data = "{{ with secret (env `node.unique.id` | printf `kv/ator-network/stage/dir-auth-%s`) }}{{ .Data.data.authority_identity_key}}{{end}}"
        destination = "secrets/anon/keys/authority_identity_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/stage/dir-auth-%s`) }}{{.Data.data.authority_signing_key}}{{end}}"
        destination = "secrets/anon/keys/authority_signing_key"
      }

      template {
        change_mode = "noop"
        data = "{{ key (env `node.unique.id` | printf `ator-network/stage/dir-auth-%s/ed25519_master_id_public_key_base64`) | base64Encode }}"
        destination = "secrets/anon/keys/ed25519_master_id_public_key"
      }

      template {
        change_mode = "noop"
        data = "{{ key (env `node.unique.id` | printf `ator-network/stage/dir-auth-%s/ed25519_signing_cert_base64`) | base64Encode }}"
        destination = "secrets/anon/keys//ed25519_signing_cert"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/stage/dir-auth-%s`) }}{{ base64Decode .Data.data.ed25519_master_id_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_master_id_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/stage/dir-auth-%s`) }}{{ base64Decode .Data.data.ed25519_signing_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_signing_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/stage/dir-auth-%s`) }}{{ base64Decode .Data.data.secret_id_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_id_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/stage/dir-auth-%s`) }}{{ base64Decode .Data.data.secret_onion_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/stage/dir-auth-%s`) }}{{ base64Decode .Data.data.secret_onion_key_ntor_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key_ntor"
      }

      template {
        change_mode = "noop"
        data = <<EOH
# Run Tor as a regular user (do not change this)
User anond
DataDirectory /var/lib/anon

AuthoritativeDirectory 1
V3AuthoritativeDirectory 1

# Server's public IP Address (usually automatic)
Address {{ key (env "node.unique.id" | printf "ator-network/stage/dir-auth-%s/public_ipv4") }}

# Port to advertise for incoming Tor connections.
ORPort 9101                  # common ports are 9101, 443

# Mirror directory information for others (optional, not used on bridge)
DirPort 9130                 # common ports are 9130, 80

# Run Tor only as a server (no local applications)
SocksPort 0
ControlSocket 0

# Run as a relay only (change policy to enable exit node)
ExitPolicy reject *:*        # no exits allowed
ExitPolicy reject6 *:*
ExitRelay 0
IPv6Exit 0

V3AuthVotingInterval 5 minutes
V3AuthVoteDelay 1 minutes
V3AuthDistDelay 1 minutes

AuthDirMaxServersPerAddr 8

# Set limits
#AccountingMax 999 GB
#RelayBandwidthRate 512 KB   # Throttle traffic to
#RelayBandwidthBurst 1024 KB # But allow bursts up to
#MaxMemInQueues 512 MB       # Limit Memory usage to
          
## If no Nickname or ContactInfo is set, docker-entrypoint will use
## the environment variables to add Nickname/ContactInfo below
Nickname {{ key (env "node.unique.id" | printf "ator-network/stage/dir-auth-%s/nickname") }}
ContactInfo atorv4@example.org
        EOH
        destination = "local/anonrc"
      }

      service {
        name = "dir-auth-stage"
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
