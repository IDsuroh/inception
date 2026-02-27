#!/bin/bash
set -e

SOCKET="/var/run/mysqld/mysqld.sock"
MARKER="/var/lib/mysql/.inception_initialized"

# Read secrets if provided
MYSQL_ROOT_PASSWORD="$(cat "$MYSQL_ROOT_PASSWORD_FILE")"
MYSQL_PASSWORD="$(cat "$MYSQL_PASSWORD_FILE")"

: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"

if [ -f "$MARKER" ]; then
	echo "MariaDB already initialized. Starting normally..."
	exec mysqld --user=mysql --datadir=/var/lib/mysql --socket="$SOCKET"
fi

echo "Starting MariaDB initialization..."

# Initialize DB directory if empty
if [ ! -d "/var/lib/mysql/mysql" ]; then
	echo "Initializing data directory..."
	mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

echo "Starting temporary MariaDB server for setup..."
mysqld --skip-networking --socket="$SOCKET" --user=mysql &
pid="$!"

echo "Waiting for MariaDB to be ready..."
tries=30
until mysqladmin --socket="$SOCKET" ping >/dev/null 2>&1; do
	tries=$((tries - 1))
	if [ "$tries" -le 0 ]; then
		echo "ERROR: MariaDB did not become ready in time."
		kill "$pid" 2>/dev/null || true
		exit 1
	fi
	sleep 1
done
echo "MariaDB is ready!"

echo "Running setup SQL..."
mysql --socket="$SOCKET" -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

touch "$MARKER"

echo "Shutting down temporary MariaDB..."
mysqladmin --socket="$SOCKET" -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

wait "$pid" || true

echo "Initialization complete. Starting MariaDB..."
exec mysqld --user=mysql --datadir=/var/lib/mysql --socket="$SOCKET"