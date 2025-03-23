server {
    listen 80;
    server_name <domain>;

    # location /.well-known/acme-challenge/ {
    #     root /var/www/certbot;
    # }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    set $DOMAIN "<domain>";

    listen 443 ssl;
    server_name <domain>;

    root /var/www/<domain>;

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
        try_files $uri $uri/ /index.html;
        add_header Cache-Control 'max-age=86400'; # one day
        include /etc/nginx/security-headers.conf;
    }

    # certbot config
    ssl_certificate /etc/letsencrypt/live/<domain>/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/<domain>/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
