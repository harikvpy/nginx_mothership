#!/bin/bash
# ##########################################################################
# Script to create a PostgreSQL database. Specify the database name and DB
# user as arguments.
# ##########################################################################

function error_exit
{
    echo "$1" 1>&2
    exit 1
}

# Verify arguments
if [ "$#" -ne 2 ]; then
  echo "Please specify the database name and DB user name as arguments."
  echo
  echo "Usage: $0 <db_name> <db_user> [<db_password>]"
  echo
  exit 1
fi

# Root user check
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Default db_password to db_user
if [ "$#" -eq 2 ]; then
  db_password=$2
else:
  db_password=$3
fi

db=$1
db_user=$2
echo "Creating PostgreSQL database $db and user $db_user; password: $db_password"

# Check if host has PostgreSQL installed
postgres_count=`ps aux | grep postgres | wc -l`
if [ "$postgres_count" -gt 1 ]
then
  echo "PostgreSQL is installed and running."
else
  echo "PostgreSQL is not installed or is not running."
  exit 1
fi

echo "Creating PostgreSQL database $db..."
psql -U postgres -c "DROP DATABASE IF EXISTS $db; CREATE DATABASE $db;"
psql -U postgres -c "DROP USER IF EXISTS $db; CREATE USER $db_user WITH PASSWORD '\''$db_password'\''; GRANT ALL PRIVILEGES ON DATABASE $db TO $db_user;'"

echo "PostgreSQL database $db and user $db_user created."
echo "Done"
exit 0
# ##########################################################################
# End of script
