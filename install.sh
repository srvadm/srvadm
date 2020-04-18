# fill .env files

sudo mkdir -p /opt/srvadm/system/volumes/{acme,certificates,traefik_config}/
sudo cat << EOF > /opt/srvadm/system/volumes/traefik_config/default-tls
tls:
  options:
    default-tls:
      sniStrict: true
      minVersion: VersionTLS12
      cipherSuites:
        - TLS_AES_128_GCM_SHA256
        - TLS_CHACHA20_POLY1305_SHA256
        - TLS_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
      preferServerCipherSuites: true
      curvePreferences:
        - secp384r1
EOF

# install Traefik Proxy
docker network create --driver=overlay --attachable traefik-public
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/traefik/ -f /opt/srvadm/system/services/traefik/docker-compose.yml config) traefik

# install SrvAdm-System

#docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/srvadm/ -f /opt/srvadm/system/services/srvadm/docker-compose.yml config) srvadm

# install SrvAdm-Mail
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/mail/ -f /opt/srvadm/system/services/mail/docker-compose.yml config) mail

docker run gilleslamiral/imapsync imapsync --host1="m02.srvadm.de" --user1="dev@m02.srvadm.de" --password1="dev" –-host2="m01.srvadm.de" --user2="dev@m01.srvadm.de" –-password2="dev"
