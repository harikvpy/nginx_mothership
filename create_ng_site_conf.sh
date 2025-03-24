#!/bin/bash
# #####################################################################
# This script can be used to create a new Angular site configuration
# file. To use:
#
#   # ./create_django_site_conf.sh <domain_name>
#
#   A new Django site configuration file would be created for
#   <domain_name>. The configuration will be written to stdout. You
#   can redirect it to a file if you wish.
# #####################################################################


if [ "$#" -lt 1 ]; then
  echo "Creates a new NGINX configuration file for Angular sites. The created file"
  echo "can be copied to /etc/nginx/sites-available and symlinked to"
  echo "/etc/nginx/sites-enabled to activate."
  echo
  echo "Illegal number of arguments."
  echo
  echo Usage:
  echo "  ./create_django_site_conf.sh <domain_name>"
  echo
  echo "Specify a single domain to create a Django site configuration"
  echo "file as the mandatory argument."
  echo
  exit 1
fi

if [ "$1" == "" ]; then
  echo "Error: specify domain name as argument"
  exit 1
fi

domain=$1
domain_sanitized=$(echo "$domain" | tr '.' '_')
domain_appserver="${domain_sanitized}_appserver"

cat <<EOF
# ##########################################################################
# NGIX configuration for $domain
# Created by github.com/harikvpy/nginx_mothership/create_ng_site_conf.sh
# ##########################################################################
server {
    listen 80;
    server_name $domain;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    set \$DOMAIN "$domain";

    listen 443 ssl;
    server_name $domain;

    root /var/www/$domain;

    location ~ /index.html$ {
        expires -1;
        add_header Cache-Control 'no-store, no-cache, must-revalidate,
            proxy-revalidate, max-age=0';
        include /etc/nginx/security-headers.conf;
    }

    location ~ .*\.css$|.*\.js$ {
        add_header Cache-Control 'max-age=604800'; # one week
        include /etc/nginx/security-headers.conf;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control 'max-age=86400'; # one day
        include /etc/nginx/security-headers.conf;
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