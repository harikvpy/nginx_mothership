# NGIX Mothership

This contains a bunch of scripts that sets up an host for an NGINX webserver that can host multiple domains as virtual hosts. 

## Scripts
| Script Name          | Description                                                                 |
|----------------------|-----------------------------------------------------------------------------|
| `setup-ssl-site.sh`  | Automates the creation of an NGINX site config, acquires SSL certificates, and updates the config for SSL-only traffic. |
| `init-host-for-postgresql.sh` | A script to install PostgreSQL binding it to localhost and docker internal network. Script also modifies it settings to password free local login.  |
| `create_postgres_db.sh` | Creates a PostgreSQL database with given name, role & password. |
| `create_django_site_conf.sh` | Creates the NGINX config file for deploying a Django appserver. |
| `create_ng_site_conf.sh` | Creates the NGINX config file for deploing an Angular site. |

This repo also contains a few NGINX specific configuration files that will be added as part of the site's `conf.d`. These provide better configuration of SSL security headers as per Mozilla recommendations.

## setup-ssl-site.sh

Thi script automates the process of creating an NGINX site config to acquire an SSL certificate from LetsEncrypt and once acquired, updates the site config to serve the site exclusively over SSL. It also contains a certbot container to renew these certificates routinely so that they don't expire.

1. Create a new VPS instance for running Docker containers. You can use the default Docker image provided by Docker. If you're adding a new virtual host to an existing droplet, skip to step 4.

2. Make sure to open ports 80 & 443 in the firewall. By default newly created Docker droplets only open ports 22, 2375 & 2376.

   ```
   # ufw allow 80
   # ufw allow 443
   ```

3. Clone this repo locally on the VPS.

4. Make the DNS entries for the new domain to point to the droplet IP. Wait a few minutes for the global DNS to be updated. Verify this by pinging the domain from your host computer (Not the VPS as that would use the service provider's internal DNS servers which would've been updated the moment the entries were made in their DNS control panel).

5. Once you have verified that the new domain points to the right works, run `./setup-ssl-site.sh` with the domain name as the argument.

   ```
   # ./setup-ssl-site.sh <domain name>
   ```

   The script will 
      1. Create a temporary nginx config file for certbot to identify the domain ownership. This
         config file is stored in `/etc/nginx/conf.d/<domain>.conf`.
      2. Create the necessary LetsEncrypt certificates and store them in `/etc/letsencrypt/live/<domain>`
      3. Update the `/etc/nginx/conf.d/<domain>.conf` for SSL redirecting all HTTP traffic to SSL.

   Depending on your website's requirements, update `/etc/nginx/conf.d/<domain>.conf` appropriately. For instance, if your site is going to be served by an appserver, you would have to customize it for a reserve proxy config.

   Note that the various <i>live</i> config files produced by NGINX & Certbot are stored in the host machine in their native folders. These are `/etc/nginx/conf.d` and `/etc/letsencrypt`. These folders are mapped into their namesake in the `nginx` & `certbot` containres. So if you want to tweak a site's configuration, like adding virtual paths or to tweak the cache setting, you can manually edit the respective file in these folders. Typically this is only required for `nginx` configuration. LetsEncrypt files are best left alone.

6. Verify that the SSL site is up and running. From your host terminal:

   ```
   $ curl <domain>
   <html>
   <head><title>301 Moved Permanently</title></head>
   <body>
   <center><h1>301 Moved Permanently</h1></center>
   <hr><center>nginx</center>
   </body>
   </html>

   $ curl https://<domain>
   <!DOCTYPE html>
   <html>
   <body>

   <h1><domain></h1>

   </body>
   </html>
   ```

   You can also visit the URL from a browser. If the secure website was served, your secure site is up and running!