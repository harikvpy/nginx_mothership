#!/bin/bash
# #####################################################
# This script can be used to initialize a domain with
# its LetsEncrypt certificate. To use:
#
#   # ./setup-ssl-site.sh <domain_name>
#     
#     A LetsEncrypt certificate would be acquired for
#     <domain-name>. If you wish one certificate to cover
#     multiple domains, specify multiple domains in 
#     <domain-name>, separated by space and the whole
#     thing wrapped in quotes, making it the solitary
#     argument.
# 
# Based off the script at:
#   https://github.com/wmnnd/nginx-certbot
# #####################################################

function error_exit
{
    echo "$1" 1>&2
    exit 1
}

if ! [ -x "$(command -v docker compose)" ]; then
  echo 'Error: docker compose is not installed.' >&2
  exit 1
fi

# Root user check
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

if [ "$#" -ne 1 ]; then
  echo "Illegal number of arguments."
  echo
  echo "Specify a single domain to acquire certificate for as the solitary"
  echo "argument. If you want the same certificate to cover multiple domains,"
  echo "like example.com and www.example.com, enclose the multiple domains,"
  echo "separated by a space and in quotes, as the argument."
  echo
  exit 1
fi

if [ "$1" == "" ]; then
	echo "Error: specify domain name as argument"
	exit 1
fi 

domains=($1)
rsa_key_size=4096
data_path="/var/nginx/certbot"
email="hari@smallpearl.com" # Adding a valid address is strongly recommended
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

# Join $domains to -d args
first_domain=""
domains_arg=""
for domain in "${domains[@]}"; do
  if [ "$first_domain" == "" ]; then
    first_domain="$domain"
  fi
  domains_arg="$domains_arg -d $domain"
done
# echo "domains_arg: $domains_arg, first_domain: $first_domain"
# exit 1

# if [ -d "$data_path" ]; then
#   read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
#   if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
#     exit
#   fi
# fi

# if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
#   echo "### Downloading recommended TLS parameters ..."
#   mkdir -p "$data_path/conf"
#   curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
#   curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
#   echo
# fi

echo "### Creating placeholder index.html page for $first_domain..."
WWWROOT="/var/www"
mkdir -p "$WWWROOT/$first_domain"
cat > $WWWROOT/$first_domain/index.html << EOF
<!DOCTYPE html>
<html>
<body>

<h1>$first_domain</h1>

</body>
</html>
EOF

echo "### Creating non-secure nginx conf for $first_domain..."
mkdir -p /etc/nginx/conf.d
cat > /etc/nginx/conf.d/$first_domain.conf << EOF
server {
  listen 80;
  server_name $first_domain;

  location /.well-known/acme-challenge/ {
      root /var/www/certbot;
  }

  root /var/www/$first_domain;
  location / {
      try_files \$uri \$uri/ /index.html;
  }
}
EOF

echo "### Creating folders to store letencrypt files for $first_domain..."

mkdir -p /etc/letsencrypt/live/$first_domain
mkdir -p /etc/letsencrypt/archive/$first_domain
mkdir -p /etc/letsencrypt/renewal
mkdir -p /var/www/certbot
mkdir -p /var/www

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live"
mkdir -p "$data_path/conf/live/$first_domain"
docker compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:1024 -days 1\
    -keyout '$path/$first_domain/privkey.pem' \
    -out '$path/$first_domain/fullchain.pem' \
    -subj '/CN=localhost'" certbot || error_exit "Failed to create dummy certificate"
echo


echo "### Starting nginx ..."
docker compose up --force-recreate -d nginx || error_exit "Failed to start nginx"
echo

echo "### Deleting dummy certificate for $domains ..."
docker compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$first_domain && \
  rm -Rf /etc/letsencrypt/archive/$first_domain && \
  rm -Rf /etc/letsencrypt/renewal/$first_domain.conf" certbot || error_exit "Failed to delete dummy certificate"
echo

echo "### Requesting Let's Encrypt certificate for $domains ..."

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    --cert-name $first_domain
    $staging_arg \
    $email_arg \
    $domains_arg \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot || error_exit "Failed to request certificate"
echo

echo "### Reloading nginx ..."
docker compose exec nginx nginx -s reload || error_exit "Failed to reload nginx"

echo "### nginx reloaded successfuly. Now creating $first_domain.conf with SSL..."
cat > /etc/nginx/conf.d/$first_domain.conf << EOF
server {
  listen 80;
  server_name $first_domain;
  location / {
    return 301 https://$host$request_uri;
  }
}

server {
  set \$DOMAIN "$first_domain";

  listen 443 ssl;
  server_name $first_domain;

  ssl_certificate /etc/letsencrypt/live/$first_domain/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$first_domain/privkey.pem;
  include /etc/nginx/options-ssl-nginx.conf;
  ssl_dhparam /etc/nginx/ssl-dhparams.pem;

  location / {
    root /var/www/$first_domain;
    try_files \$uri \$uri/ /index.html;
    include /etc/nginx/security-headers.conf;
  }
}
EOF

echo "### Restarting nginx ..."
docker compose exec nginx nginx -s reload
echo "### Done!"
exit 0
