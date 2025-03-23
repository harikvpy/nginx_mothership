upstream appserver {
    server 172.17.0.1:<port>;
}

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
    listen 443 ssl;
    server_name <domain>;

    client_max_body_size 5M;
    keepalive_timeout 5;
    underscores_in_headers on;

    location / {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_redirect off;
        proxy_pass http://appserver;
    }

    # certbot config
    ssl_certificate /etc/letsencrypt/live/api.qqden.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.qqden.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
