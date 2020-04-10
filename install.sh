# Check for dependencies
  # Docker 18
  # Docker-Compose

#?????


# create Swarm
docker swarm init --advertise-addr eth0

# install Traefik Proxy
docker network create --driver=overlay traefik-public
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/traefik/ -f /opt/srvadm/system/services/traefik/docker-compose.yml config) traefik

# install SrvAdm
docker stack deploy -c <(docker-compose --project-directory /opt/srvadm/system/services/srvadm/ -f /opt/srvadm/system/services/srvadm/docker-compose.yml config) srvadm
docker cp /opt/srvadm/system/services/srvadm/files/public/ $(docker container ls --format '{{.Names}}' | grep srvadm_php):/var/www/html/
docker exec -it $(docker container ls --format '{{.Names}}' | grep srvadm_php) chown -R 1000:1000 /var/www/html/public

# install Seafile
echo -e "zjkmid6rQibdZ=uJMuWS" | docker login docker.seadrive.org --username seafile --password-stdin

# install MailCow
git clone https://github.com/mailcow/mailcow-dockerized /opt/srvadm/system/services/mailcow/
mv /opt/srvadm/system/services/mail-files/* /opt/srvadm/system/services/mailcow/
rm -r /opt/srvadm/system/services/mail-files/
sed -i 's|message_size_limit = .*|message_size_limit = 104857600|' /opt/srvadm/system/services/mailcow/data/conf/postfix/main.cf # set mailsizelimit to 100MB
sed "s|%domain%|$(hostname -d)|g" /opt/srvadm/system/services/mailcow/mailcow.tmpl | \
sed "s|%hostname%|$(hostname -f)|g" - |                                              \
sed "s|%dbname%|$(pwgen -s -c -n -1 10)|g" - |                                       \
sed "s|%dbuser%|$(pwgen -s -c -n -1 10)|g" - |                                       \
sed "s|%dbpass%|$(pwgen -s -c -n -1 10)|g" - |                                       \
sed "s|%dbroot%|$(pwgen -s -c -n -1 10)|g" - |                                       \
sed "s|%tz%|$(cat /etc/timezone)|g" - |                                              \
sed "s|%watchdogmail%|watchdog@$(hostname -d)|g" -                                   \
> /opt/srvadm/system/services/mailcow/mailcow.conf
cat << _EOF >> /opt/srvadm/system/services/mailcow/mailcow.conf
ADDITIONAL_SAN=$(hostname -f),mail.${domain},imap.${domain},mail.*,imap.*
ADD_DOMAINS=,\`mail.$(hostname -d)\`,\`imap.$(hostname -d)\`,\`autoconfig.$(hostname -d)\`,\`autodiscover.$(hostname -d)\`
_EOF
# remove last 2 lines
#sed '$d' /opt/srvadm/system/services/mailcow/mailcow.conf | sed '$d' | sed '$d'

