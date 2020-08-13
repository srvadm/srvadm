#!/bin/sh

set -o errexit
set -o pipefail
set -o nounset


# fill .env files
# for passwords use
# docker run --rm srvadm/tools:pwgen 10

# install Traefik Proxy
mkdir -p /opt/srvadm/system/volumes/traefik/{acme,certificates,config}/
cat << EOF > /opt/srvadm/system/volumes/traefik/config/default-tls.yml
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

docker network create --driver=overlay --attachable traefik-public
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/traefik/ -f /opt/srvadm/system/services/traefik/docker-compose.yml config) traefik
while ! [ $(ls -A /opt/srvadm/system/volumes/traefik/certificates/ | wc -l) -gt 1 ]; do
  sleep 10
done

# install SrvAdm-System

#docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/srvadm/ -f /opt/srvadm/system/services/srvadm/docker-compose.yml config) srvadm

# install SrvAdm-Mail
sudo mkdir -p /opt/srvadm/system/volumes/mail/{data,www,redis,rspamd}/
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/mail/ -f /opt/srvadm/system/services/mail/docker-compose.yml config) mail

# MySQL-Backup
#   docker exec $(docker ps | grep mail_mysql | cut -d ' ' -f1) sh -c 'mysqldump -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE' > mail_mysql.sql
# MySQL-Restore
#   cat mail_mysql.sql | docker exec -i $(docker ps | grep mail_mysql | cut -d ' ' -f1) sh -c 'mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE'

# restic
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/restic/ -f /opt/srvadm/system/services/restic/docker-compose.yml config) restic


# wireguard
mkdir -p /opt/srvadm/system/volumes/wireguard/
wg genkey | sudo tee /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/publickey
docker run -it -v /opt/srvadm/system/volumes/wireguard:/etc/wireguard -v /usr/src:/usr/src -v /lib/modules:/lib/modules --name wireguard_setup --privileged --rm ubuntu:18.04 bash -c 'apt-get update -qq; apt-get install -y -qq software-properties-common; add-apt-repository -y ppa:wireguard/wireguard; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wireguard libelf-dev build-essential pkg-config git; git clone https://git.zx2c4.com/wireguard-linux-compat; make -C wireguard-linux-compat/src -j$(nproc); make -C wireguard-linux-compat/src install; wg genkey | sudo tee /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/publickey'
cat << EOF > /opt/srvadm/system/volumes/wireguard/wg0.conf
[Interface]
Address = 10.10.1.1/24
PrivateKey = $(cat /opt/srvadm/system/volumes/wireguard/privatekey)
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE;iptables -A FORWARD -o eth0 -j ACCEPT; curl https://link-ip.nextdns.io/bc51b4/5dae758c21db2864
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE;iptables -D FORWARD -o eth0 -j ACCEPT
SaveConfig = true

# Raspberry
[Peer]
PublicKey = LWFbt8ns8ccCCJhu/q6OYo39hn9WpxYObCgvuwqkMhk=
AllowedIPs = 10.10.1.10

# Macbook Pro
[Peer]
PublicKey = Fde/nmVm9R696pkNlxFuWrcstqT1QwJdEv7vuW4Kj2c=
AllowedIPs = 10.10.1.20

# iPhone X
[Peer]
PublicKey = WQj/p+Yp6+ZZkWjmEherNDxk8Zy6B0sGPLtM8HKVo0Q=
AllowedIPs = 10.10.1.30
EOF
ros service enable kernel-headers
ros service up kernel-headers
ros config set rancher.modules "['wireguard']"
docker run -d -v /opt/srvadm/system/volumes/wireguard:/etc/wireguard -p 51820:51820/udp --cap-add net_admin --name wireguard --rm alpine sh -c 'apk add wireguard-tools curl&&wg-quick up wg0&&while true ; do continue ; done'



##### https://vitobotta.com/2019/07/17/kubernetes-wireguard-vpn-rancheros/
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
docker run -it -v /usr/src:/usr/src -v /lib/modules:/lib/modules --name wireguard_setup --privileged --rm ubuntu:18.04 bash -c 'apt-get update -qq; apt-get install -y -qq software-properties-common; add-apt-repository -y ppa:wireguard/wireguard; apt-get update -qq; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wireguard libelf-dev build-essential pkg-config git; git clone https://git.zx2c4.com/wireguard-linux-compat; make -C wireguard-linux-compat/src -j$(nproc); make -C wireguard-linux-compat/src install'
docker run -it -v /opt/srvadm/system/volumes/wireguard:/etc/wireguard -p 51820:51820/udp --cap-add net_admin --name wireguard --rm alpine sh -c 'apk add wireguard-tools curl&&wg-quick up wg0&&while true ; do continue ; done'
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/wireguard/ -f /opt/srvadm/system/services/wireguard/docker-compose.yml config) wireguard

docker run gilleslamiral/imapsync imapsync --host1="m02.srvadm.de" --user1="dev@m02.srvadm.de" --password1="dev" –-host2="m01.srvadm.de" --user2="dev@m01.srvadm.de" –-password2="dev"


occ config:system:set trusted_proxies 1 --value='traefik'
occ config:system:set overwritehost --value="nextcloud.srvadm.de"
occ config:system:set overwriteprotocol --value="https"

docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/nextcloud/ -f /opt/srvadm/system/services/nextcloud/docker-compose.yml config) nextcloud
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/jitsi/ -f /opt/srvadm/system/services/jitsi/docker-compose.yml config) jitsi
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/swarmprom/ -f /opt/srvadm/system/services/swarmprom/docker-compose.yml config) swarmprom

docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/portainer/ -f /opt/srvadm/system/services/portainer/docker-compose.yml config) portainer
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/thediver/ -f /opt/srvadm/system/services/thediver/docker-compose.yml config) thediver

docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/restic/ -f /opt/srvadm/system/services/restic/docker-compose.yml config) restic


echo TRAEFIK_PROXY_NETWORK=$(docker network inspect traefik-public --format='{{(index .IPAM.Config 0).Gateway}}') >> /opt/srvadm/services/nextcloud/.env
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/services/nextcloud/ -f /opt/srvadm/services/nextcloud/docker-compose.yml config) cloud_thediver_info


docker exec --user www-data nextcloud_nextcloud.1.kr2dsyisw426evzx7nk1z7i2r php occ
