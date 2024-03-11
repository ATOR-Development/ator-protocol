#arguments folder node-id env

vault kv put -output-curl-string -mount=kv ator-network/$3/dir-auth-$2 \
            authority_identity_key="$(cat $1/tor-data/keys/authority_identity_key)" \
            authority_signing_key="$(cat $1/tor-data/keys/authority_signing_key)" \
            ed25519_master_id_secret_key_base64="$(base64 -w 0 $1/tor-data/keys/ed25519_master_id_secret_key)" \
            ed25519_signing_secret_key_base64="$(base64 -w 0 $1/tor-data/keys/ed25519_signing_secret_key)" \
            secret_id_key_base64="$(base64 -w 0 $1/tor-data/keys/secret_id_key)" \
            secret_onion_key_base64="$(base64 -w 0 $1/tor-data/keys/secret_onion_key)" \
            secret_onion_key_ntor_base64="$(base64 -w0 $1/tor-data/keys/secret_onion_key_ntor)"