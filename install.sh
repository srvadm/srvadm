# fill .env files

# install Traefik Proxy
sudo mkdir -p /opt/srvadm/system/volumes/traefik/{acme,certificates,config}/
sudo sh -c "cat << EOF > /opt/srvadm/system/volumes/traefik/config/default-tls.yml
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
EOF"

docker network create --driver=overlay --attachable traefik-public
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/traefik/ -f /opt/srvadm/system/services/traefik/docker-compose.yml config) traefik

# install SrvAdm-System

#docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/srvadm/ -f /opt/srvadm/system/services/srvadm/docker-compose.yml config) srvadm

# install SrvAdm-Mail
sudo mkdir -p /opt/srvadm/system/volumes/mail/{data,mysql,www,redis,rspamd}/
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/mail/ -f /opt/srvadm/system/services/mail/docker-compose.yml config) mail



# wireguard
##### https://vitobotta.com/2019/07/17/kubernetes-wireguard-vpn-rancheros/
sudo ros service enable kernel-headers
sudo ros service up kernel-headers
sudo ros config set rancher.modules "['wireguard']"
cat <<EOD > /var/lib/rancher/conf/wireguard.yml
wireguard:
  image: vitobotta/docker-wireguard:0.15.0
  net: host
  privileged: true
  restart: always
  volumes:
  - /home/rancher/wireguard:/etc/wireguard
  - /usr/src:/usr/src
  - /lib/modules:/lib/modules
  environment:
    INTERFACE: "wg0"
    LISTEN_PORT: "51820"
EOD
sudo ros service enable /var/lib/rancher/conf/wireguard.yml
sudo ros service up wireguard
sleep 10
sudo ros service rm wireguard
sudo ros service disable /var/lib/rancher/conf/wireguard.yml
sudo rm /var/lib/rancher/conf/wireguard.yml
docker stop wireguard
docker rm wireguard
docker run -d -v /opt/srvadm/system/volumes/wireguard:/etc/wireguard -v /usr/src:/usr/src -v /lib/modules:/lib/modules -p 51820:51820/udp --cap-add net_admin --name wireguard --rm alpine sh -c 'apk add wireguard-tools curl&&wg-quick up wg0&&while true ; do continue ; done'
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/wireguard/ -f /opt/srvadm/system/services/wireguard/docker-compose.yml config) wireguard

docker run gilleslamiral/imapsync imapsync --host1="m02.srvadm.de" --user1="dev@m02.srvadm.de" --password1="dev" –-host2="m01.srvadm.de" --user2="dev@m01.srvadm.de" –-password2="dev"


occ config:system:set trusted_proxies 1 --value='traefik'
occ config:system:set overwritehost --value="nextcloud.srvadm.de"
occ config:system:set overwriteprotocol --value="https"

docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/nextcloud/ -f /opt/srvadm/system/services/nextcloud/docker-compose.yml config) nextcloud
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/jitsi/ -f /opt/srvadm/system/services/jitsi/docker-compose.yml config) jitsi
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/swarmprom/ -f /opt/srvadm/system/services/swarmprom/docker-compose.yml config) swarmprom


docker exec --user www-data nextcloud_nextcloud.1.kr2dsyisw426evzx7nk1z7i2r php occ
