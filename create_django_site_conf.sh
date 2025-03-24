#!/bin/bash
# #####################################################################
# This script can be used to create a new Django site configuration
# file. To use:
#
#   # ./create_django_site_conf.sh <domain_name> <appserver_interface>
#
#   A new Django site configuration file would be created for
#   <domain_name>. The configuration will be written to stdout. You
#   can redirect it to a file if you wish.
# #####################################################################


if [ "$#" -lt 1 ]; then
  echo "Illegal number of arguments."
  echo
  echo Usage:
  echo "  ./create_django_site_conf.sh <domain_name> [<appserver_interface>]"
  echo
  echo "Specify a single domain to create a Django site configuration"
  echo "file as the mandatory argument. You may optionally specify the"
  echo "interface of the appserver container to proxy requests to as the"
  echo "second argument. If you don't specify the second argument, the"
  echo "default value of 172.17.0.1:8000 would be used."
  echo
  exit 1
fi

if [ "$1" == "" ]; then
  echo "Error: specify domain name as argument"
  exit 1
fi

if [ "$2" == "" ]; then
  appserver_interface="172.17.0.1:8000"
else
  appserver_interface=$2
fi

domain=$1
domain_sanitized=$(echo "$domain" | tr '.' '_')
domain_appserver="${domain_sanitized}_appserver"

cat <<EOF
# ##########################################################################
# NGIX configuration for $domain
# Created by github.com/harikvpy/nginx_mothership/create_django_site_conf.sh
# ##########################################################################

upstream $domain_appserver {
    server $appserver_interface;
}

server {
    listen 80;
    server_name $domain;

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $domain;

    client_max_body_size 5M;
    keepalive_timeout 5;
    underscores_in_headers on;

    location / {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_redirect off;
        proxy_pass http://$domain_appserver;
    }

    # certbot config
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    include /etc/nginx/options-ssl-nginx.conf;
    ssl_dhparam /etc/nginx/ssl-dhparams.pem;
}
EOF
exit 0
# #####################################################################
# End of script