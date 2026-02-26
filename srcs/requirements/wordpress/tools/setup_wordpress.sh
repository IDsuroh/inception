#!/bin/bash
set -e

WP_PATH="/var/www/html"
mkdir -p "$WP_PATH"

# Read secrets
if [ -n "$WORDPRESS_DB_PASSWORD_FILE" ] && [ -f "$WORDPRESS_DB_PASSWORD_FILE" ]; then
	WORDPRESS_DB_PASSWORD="$(cat "$WORDPRESS_DB_PASSWORD_FILE")"
fi
if [ -n "$WORDPRESS_ADMIN_PASSWORD_FILE" ] && [ -f "$WORDPRESS_ADMIN_PASSWORD_FILE" ]; then
	WORDPRESS_ADMIN_PASSWORD="$(cat "$WORDPRESS_ADMIN_PASSWORD_FILE")"
fi
if [ -n "$WORDPRESS_USER_PASSWORD_FILE" ] && [ -f "$WORDPRESS_USER_PASSWORD_FILE" ]; then
	WORDPRESS_USER_PASSWORD="$(cat "$WORDPRESS_USER_PASSWORD_FILE")"
fi

# Admin check
ADMIN_LC="$(printf "%s" "$WORDPRESS_ADMIN_USER" | tr '[:upper:]' '[:lower:]')"
if [[ "$ADMIN_LC" == *admin* ]] || [[ "$ADMIN_LC" == *administrator* ]]; then
	echo "ERROR: WORDPRESS_ADMIN_USER must not contain 'admin' or 'administrator'"
	exit 1
fi

echo "Setting up WordPress..."

# Download WordPress core if missing
if [ ! -f "$WP_PATH/wp-load.php" ]; then
	echo "Downloading WordPress..."
	wget -q https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz
	tar -xzf /tmp/wordpress.tar.gz -C /tmp
	rm -f /tmp/wordpress.tar.gz

	# Copy only missing files
	cp -rn /tmp/wordpress/* "$WP_PATH" || true
	rm -rf /tmp/wordpress
fi

# Install wp-cli if missing
if [ ! -x /usr/local/bin/wp ]; then
	echo "Installing wp-cli..."
	wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp
	chmod +x /usr/local/bin/wp
fi

# Create wp-config.php if missing
if [ ! -f "$WP_PATH/wp-config.php" ]; then
	echo "Creating wp-config.php..."
	WP_SALTS="$(wget -qO- https://api.wordpress.org/secret-key/1.1/salt/)"

	cat > "$WP_PATH/wp-config.php" << EOF
<?php
define('DB_NAME', '${WORDPRESS_DB_NAME}');
define('DB_USER', '${WORDPRESS_DB_USER}');
define('DB_PASSWORD', '${WORDPRESS_DB_PASSWORD}');
define('DB_HOST', '${WORDPRESS_DB_HOST}');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

\$table_prefix = '${WORDPRESS_TABLE_PREFIX:-wp_}';

${WP_SALTS}

define('WP_DEBUG', false);

if ( !defined('ABSPATH') )
	define('ABSPATH', __DIR__ . '/');

require_once ABSPATH . 'wp-settings.php';
EOF
fi

# Ensure correct ownership for wp-cli and runtime
chown -R www-data:www-data "$WP_PATH"

# Database connectability readiness check: waiting until wp-cli can talk to the Database
echo "Waiting for database..."
tries=30
until su -s /bin/sh www-data -c "wp --path='$WP_PATH' db check" >/dev/null 2>&1; do
	tries=$((tries - 1))
	if [ "$tries" -le 0 ]; then
		echo "ERROR: database not ready or credentials wrong."
		exit 1
	fi
	sleep 2
done

# Install WordPress + create second user if not installed
if ! su -s /bin/sh www-data -c "wp --path='$WP_PATH' core is-installed" >/dev/null 2>&1; then
	echo "Installing Wordpress..."
	su -s /bin/sh www-data -c "wp --path='$WP_PATH' core install \
		--url='https://${DOMAIN_NAME}' \
		--title='${WORDPRESS_SITE_TITLE}' \
		--admin_user='${WORDPRESS_ADMIN_USER}' \
		--admin_password='${WORDPRESS_ADMIN_PASSWORD}' \
		--admin_email='${WORDPRESS_ADMIN_EMAIL}'"
	
	echo "Creating second user..."
	su -s /bin/sh www-data -c "wp --path='$WP_PATH' user create '${WORDPRESS_USER}' '${WORDPRESS_USER_EMAIL}' \
		--role=author \
		--user_pass='${WORDPRESS_USER_PASSWORD}'"
fi

# Keep strict permissions
find "$WP_PATH" -type d -exec chmod 750 {} \;
find "$WP_PATH" -type f -exec chmod 640 {} \;

echo "Starting PHP-FPM..."
exec php-fpm8.2 -F
