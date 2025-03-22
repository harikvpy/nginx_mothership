# NGIX Mothership

This contains a few scripts that would setup NGINX as a primary webserver that can host multiple domains as virtual hosts. The script automates the process of creating a NGIX site config to acquire an SSL certificate from LetsEncrypt and once acquired, updates the site config to serve the site exclusively over SSL. It also contains a certbot container to renew these certificates routinely so that they don't expire.

Besides the script that automates the site creation, it also contains a few NGINX specific configuration files that will be added as part of the site's `conf.d`. These provide better configuration of SSL security headers and other similar attributes.

## How to Use

1. Create a new VPS droplet in DO for running Docker containers. You can use the Docker image provided by Docker. If you're adding a new virtual host to an existing droplet, skip to step 4.

2. Make sure to open ports 80 & 443 in the firewall. By default newly created Docker droplets only open ports 22, 2375 & 2376.

   ```
   # ufw allow 80
   # ufw allow 443
   ```

3. SSH into the new droplet and generate ssh keys using the `ssh-keygen` command. We will add these keys to our `github.com:harikvpy/nginx_mothership` repository. Once you have generated the keys go to the repository's Settings and add the `.ssh/id_rsa.pub` file contents as a new deploy key. This will help us pull the `qqden-deploy` repo and start using its scripts.

4. Make the DNS entries for the new domain to point to the droplet IP. Wait a few minutes for the global DNS to be updated.

5. Now we create a secure site our NGIX. Before you do this, verify that the domain entries made above do point to the new droplet IP. You can verify this by pinging the domain from your host computer (Not DO VPS as that would use the DO internal DNS servers which would've been updated the moment the entries were made in the DO control panel).

   Once you have verified that the new domain works, run `./setup-ssl-site.sh` with the domain name as the argument.

      ```
      # cd nginx
      # ./setup-ssl-site.sh <domain name>
      ```

      The script will 
         1. Create the necessary folders
         2. Create a temporary nginx config file for certbot to identify the domain ownership. This
            config file is stored in `./config/etc/nginx/conf.d/<domain>.conf`.
         3. Create the necessary LetsEncrypt certificates and store them in `./config/etc/letsencrypt/live/<domain>`
         4. Update the `./config/etc/nginx/conf.d/<domain>.conf` for SSL redirecting all HTTP traffic to SSL.

      Depending on your website's requirements, update `./config/etc/nginx/conf.d/<domain>.conf` appropriately. For instance, if your site is going to be served by an appserver, you would have to customize it for a reserve proxy config.

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
   If you got the above responses, congratulations. Your secure site is up and running!