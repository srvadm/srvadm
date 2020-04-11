# fill .env files

sudo mkdir -p /opt/srvadm/system/volumes/{acme,certificates}/

# install Traefik Proxy
docker network create --driver=overlay --attachable traefik-public
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/traefik/ -f /opt/srvadm/system/services/traefik/docker-compose.yml config) traefik

# install SrvAdm-System

#docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/srvadm/ -f /opt/srvadm/system/services/srvadm/docker-compose.yml config) srvadm

# install SrvAdm-Mail
#docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/mail/ -f /opt/srvadm/system/services/mail/docker-compose.yml config) mail

