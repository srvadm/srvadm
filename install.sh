# fill .env files

sudo mkdir -p /opt/srvadm/system/volumes/{acme,certificates}/

# install Traefik Proxy
docker network create --driver=overlay --attachable traefik-public
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/traefik/ -f /opt/srvadm/system/services/traefik/docker-compose.yml config) traefik

# install SrvAdm-System

#docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/srvadm/ -f /opt/srvadm/system/services/srvadm/docker-compose.yml config) srvadm

# install SrvAdm-Mail
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/mail/ -f /opt/srvadm/system/services/mail/docker-compose.yml config) mail

docker run gilleslamiral/imapsync imapsync --host1="m02.srvadm.de" --user1="dev@m02.srvadm.de" --password1="dev" –-host2="m01.srvadm.de" --user2="dev@m01.srvadm.de" –-password2="dev"




  cert-dumper:
    image: ldez/traefik-certs-dumper:v2.7.0
    restart: unless-stopped
    volumes:
      - ../../volumes/acme/:/in
      - ../../volumes/certificates/:/out
      - /var/run/docker.sock:/var/run/docker.sock:ro
    deploy:
      placement:
        constraints:
          - node.role == manager
    command: >
      file
      --source=/in/acme.json
      --dest /out
      --watch
      --version=v2
      --domain-subdir=true
#      --clean=false
#      --post-hook=/hook.sh
#curl -XPOST --unix-socket /var/run/docker.sock -H 'Content-Type: application/json' http://localhost/containers/${COMTAINER-ID}/restart
