#!/bin/bash
# ##########################################################################
# Script to install PostgreSQL in a host. The script does the following:
#   0. Check if Docker is installed and running.
#   1. Install PostgreSQL, if it's not already installed and running.
#   2. Update PostgreSQL configuration to allow remote connections.
#   3. Allow password less connections from localhost and the docker internal
#      network 172.17.0.0/16.
# ##########################################################################

function error_exit
{
    echo "$1" 1>&2
    exit 1
}


# function countdown n seconds, printing the count in the same line
function countdown
{
  for i in $(seq $1 -1 1)
  do
    # echo without a line feed
    echo -n "$i "
    sleep 1
  done
}

# Root user check
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi


# Check if the remote host is running docker
if "docker --version" &> /dev/null
then
  echo "Remote host is running docker"
else
  echo "Remote host is not running docker"
  exit 1
fi


# Check if host has PostgreSQL installed
postgres_count=`ps aux | grep postgres | wc -l`
if [ "$postgres_count" -gt 1 ]
then
  echo "PostgreSQL is installed and running."
else
  echo "Installing PostgreSQL"
  ssh root@$remote_host "apt update && apt install -y postgresql postgresql-contrib" || error_exit "Error: failed to install PostgreSQL"
  echo "PostgreSQL installed. Waiting 5 seconds..."
  countdown 5
fi

# Get Postgresql version (only major version)
pg_version=$( "psql --version" | awk '{print $3}' | cut -d '.' -f 1)
echo "PostgreSQL version: $pg_version"

# If pg_version is empty, then PostgreSQL is not installed
if [ -z "$pg_version" ]; then
  echo "Error: PostgreSQL failed to install or is not running."
  exit 1
fi

echo "Updating PostgreSQL configuration..."
sleep 1
sed -i 's/^.*listen_addresses.*/listen_addresses = '\''localhost, 172.17.0.1'\''/g' /etc/postgresql/$pg_version/main/postgresql.conf || error_exit "Error: failed to update PostgreSQL configuration 1" 
sed -i 's/^local.*all.*postgres.*peer/local all  postgres trust/g' /etc/postgresql/$pg_version/main/pg_hba.conf || error_exit "Error: failed to update PostgreSQL configuration 2"
echo 'host    all      all        $remote_host/0        trust' >> /etc/postgresql/$pg_version/main/pg_hba.conf
echo 'host    all      all        172.17.0.0/16         trust' >> /etc/postgresql/$pg_version/main/pg_hba.conf
systemctl restart postgresql || error_exit "Error: failed to restart PostgreSQL"

echo "PostgreSQL configuration updated."

echo "Done"
exit 0
# #####################################################
