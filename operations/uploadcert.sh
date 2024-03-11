#arguments folder node-id ip nickname env

consul kv put ator-network/$5/dir-auth-$2/authority_certificate "$(cat $1/tor-data/keys/authority_certificate)"
consul kv put ator-network/$5/dir-auth-$2/ed25519_master_id_public_key_base64 "$(base64 -w 0 $1/tor-data/keys/ed25519_master_id_public_key)"
consul kv put ator-network/$5/dir-auth-$2/ed25519_signing_cert_base64 "$(base64 -w 0 $1/tor-data/keys/ed25519_signing_cert)"
consul kv put ator-network/$5/dir-auth-$2/fingerprint "$(cat $1/tor-data/fingerprint)"
consul kv put ator-network/$5/dir-auth-$2/fingerprint-ed25519 "$(cat $1/tor-data/fingerprint-ed25519)"
consul kv put ator-network/$5/dir-auth-$2/nickname "$4"
consul kv put ator-network/$5/dir-auth-$2/public_ipv4 "$3"

