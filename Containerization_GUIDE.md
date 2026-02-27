## 1. MariaDB

--Dockerfile--

- runs and makes the container from up to down order.
- expose and entrypoint are created at build-time and after the container is made, it starts.

- FROM <- base system
- RUN <- run commands
- COPY <- copy the file from the host to the container
- EXPOSE <- later when we set up connection, we use this exposed port
- ENTRYPOINT <- command that runs after container is made

```dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/mysqld && chown -R mysql:mysql /var/run/mysqld && chmod 755 /var/run/mysqld
RUN mkdir -p /var/log/mysql && chown -R mysql:mysql /var/log/mysql

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/init_db.sh /usr/local/bin/init_db.sh
RUN chmod +x /usr/local/bin/init_db.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/init_db.sh"]
```


--conf/50-server.cnf--

- specific setups for the container
- runs everything else on default and after that, specifically set this

- bind address to all the other network interfaces (within the docker)
- this service is set to port 3306
- using UNIX socket file path connection (fast and secure, allows communication to MariaDB)
  - What is mysqld.sock?
    It is a file on disk but it is not a normal file. It represents a live communication endpoint created by the mysqld process. When MariaDB starts, it creates this file and listens on it.
    It allows local processes (processes running on the same system/container) to communicate with MariaDB without using TCP networking (without Docker networking)
    *** local process-to-process communication ***
- data directory is where MariaDB stores all persistent database state. <- later binds to
  database outside the container.
- logging error to error.log for later debugging if there is a problem.
- pid-file is important because a PID file contains the process ID of the running mysqld 
  process.
  USED WHEN:
  When MariaDB is asked to shut down:
  - tools read the PID
  - send signals to that exact process
  - ensure graceful shutdown
  It also prevents:
  - starting two MariaDB servers using the same data directory

```INI
[mysqld]
bind-address = 0.0.0.0
port = 3306
socket = /var/run/mysqld/mysqld.sock
datadir = /var/lib/mysql
log-error = /var/log/mysql/error.log
pid-file = /var/run/mysqld/mysqld.pid
```


---tools/init_db.sh---

- this is a first run setup so that the containers don't have to be configured **!everytime!** the containers are made.
The script does automation like:
1. If database files don’t exist, initialize them
2. Start MariaDB temporarily
3. Run SQL commands to create DB and users
4. Stop temporary MariaDB
5. Start MariaDB normally

```bash
#!/bin/bash   # shebang
set -e        # exits immediately if a command fails

SOCKET="/var/run/mysqld/mysqld.sock"  # only stores a path as a text for now.
MARKER="/var/lib/mysql/.inception_initialized"  # set a variable that acts as a permanent flag when re containerized

# Read secrets if provided (best practice for subject)
MYSQL_ROOT_PASSWORD="$(cat "$MYSQL_ROOT_PASSWORD_FILE")"
MYSQL_PASSWORD="$(cat "$MYSQL_PASSWORD_FILE")"

# : "..." is a no-op (does nothing), used to trigger the expansion.
# ${VAR:?message} means:
# if VAR is unset or empty -> print message and exit with error
# otherwise -> expand to its value
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"

# If already initialized before, just start MariaDB
if [ -f "$MARKER" ]; then   # if this path exists and its a regular file,
  echo "MariaDB already initialized. Starting normally..."
  exec mysqld --user=mysql --datadir=/var/lib/mysql --socket="$SOCKET"  # run MariaDB server as linux user mysql and use the persistent database files in the volume. Then create and listen on the Unix socket file.
fi

echo "Starting MariaDB initialization..."

# Initialize DB directory if empty
if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo "Initializing data directory..."
  mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi
# mysql_install_db creates the inital internal system tables and base structure of MariaDB.
# user flag initializes files owned by the mysql user

echo "Starting temporary MariaDB server for setup..."
mysqld --skip-networking --socket="$SOCKET" --user=mysql &
pid="$!"
# We need to start a temp server because we need to create databases/users and set passwords while MariaDB is running so we can set them by SQL commands.
# mysqld -> server side
# --skip-networking -> disable TCP networking and connections via Unix socket are allowed
# --socket="$SOCKET" -> use that socket path to create the socket file
# --user=mysql -> run the server as mysql user
# & runs mysql in the background so the script still continues
# $! is the PID of the most recently started background process

echo "Waiting for MariaDB to be ready..."   # added a timeout
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
# mysqladmin ping connects through socket locally and sends ping
# we are waiting because we ran mysqld in the background

echo "Running setup SQL..."
mysql --socket="$SOCKET" -u root <<EOF  # mysql -> MariaDB client connecting through socket as root user
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

touch "$MARKER"   # When we first initialize, we make this file so that when we re run, we dont init next time again.

# sets root password to root
# create database as MYSQL_DATABASE
# create user with the name of MYSQL_USER(user from wp) with the password MYSQL_PASSWORD and this user can connect from anywhere
# Give full rights to that user but only on MYSQL_DATABASE
# apply the changes immediately

echo "Shutting down temporary MariaDB..."
mysqladmin --socket="$SOCKET" -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

# waits until the temporary mysqld process actually exits
wait "$pid" || true

echo "Initialization complete. Starting MariaDB..."
exec mysqld --user=mysql --datadir=/var/lib/mysql --socket="$SOCKET"
```

---


## 2. WordPress

--Dockerfile--

```dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y \
  php8.2-fpm \
  php8.2-mysql \
  php8.2-curl \
  php8.2-gd \
  php8.2-intl \
  php8.2-mbstring \
  php8.2-soap \
  php8.2-xml \
  php8.2-zip \
  wget \
  curl \
  ca-certificates \
  default-mysql-client \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/setup_wordpress.sh /usr/local/bin/setup_wordpress.sh
RUN chmod +x /usr/local/bin/setup_wordpress.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/setup_wordpress.sh"]
```

--conf/www.conf--

- Configures a PHP-FPM pool (pool => a managed group of PHP worker processes)
- runs after php-fpm is executed on the last line of the script and after reading the main config.
- [www] <- name of the pool, group label of the pool
- user = www-data <- The PHP-FPM worker processes which executes the PHP code will run as Linux user www-data
- listen = 9000 <- PHP-FPM setting, open port 9000 and accept FastCGI here
  - different with EXPOSE 9000 because they are for different layers.
  - listen = 9000 means PHP-FPM opens a network “door” inside the container on port 9000
  - EXPOSE 9000 means that this container is supposed to connect to 9000, works like a comment
- pm means process manager. So we are setting the process manager settings.
- pm = dynamic means number of workers would change automatically based on traffic

```INI
[www]
user = www-data
group = www-data
listen = 9000
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

--tools/setup_wordpress.sh--

- What is a ***salt***?
  - a ***salt*** is a unique, random string of data added to a password before it is processed by a ***cryptographic hash function***. Its purpose is to ensure that identical passwords result in unique hash values, which prevents attackers from using precomputed tables to crack stolen password databases.
  Then what is a ***cryptographic hash function***?
  - a mathematical algorithm that maps data of arbitrary size (the "message") to a fixed-length string of bytes, known as a hash value or digest.

```bash
#!/bin/bash   #shebang
set -e        #exit on error

WP_PATH="/var/www/html" # stores the path where WordPress live
mkdir -p "$WP_PATH"

# Read secrets <each FILE variable contains a path to a secret file set by external file>
WORDPRESS_DB_PASSWORD="$(cat "$WORDPRESS_DB_PASSWORD_FILE")"
WORDPRESS_ADMIN_PASSWORD="$(cat "$WORDPRESS_ADMIN_PASSWORD_FILE")"
WORDPRESS_USER_PASSWORD="$(cat "$WORDPRESS_USER_PASSWORD_FILE")"

# Admin check <admin username cannot contain admin>
ADMIN_LC="$(printf "%s" "$WORDPRESS_ADMIN_USER" | tr '[:upper:]' '[:lower:]')"
if [[ "$ADMIN_LC" == *admin* ]] || [[ "$ADMIN_LC" == *administrator* ]]; then
  echo "ERROR: WORDPRESS_ADMIN_USER must not contain 'admin' or 'administrator' (subject rule)."
  exit 1
fi

echo "Setting up WordPress..."

# Download WordPress core if missing
if [ ! -f "$WP_PATH/wp-load.php" ]; then
  echo "Downloading WordPress..."
  wget -q https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz  # quiet mode and set the output file name
  tar -xzf /tmp/wordpress.tar.gz -C /tmp  # extract gzip file change current directory to this path before executing
  rm -f /tmp/wordpress.tar.gz # remove tar.gz file

  # Copy only missing files
  cp -rn /tmp/wordpress/* "$WP_PATH" || true  # recursively and not overwriting existing files and forcess success
  rm -rf /tmp/wordpress
fi

# Install wp-cli if missing <wp-cli is the WordPress Command Line Interface>(to control WordPress from the terminal)
if [ ! -x /usr/local/bin/wp ]; then
  echo "Installing wp-cli..."
  wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp
  chmod +x /usr/local/bin/wp
fi

# Create wp-config.php if missing
if [ ! -f "$WP_PATH/wp-config.php" ]; then
  echo "Creating wp-config.php..."
  WP_SALTS="$(wget -qO- https://api.wordpress.org/secret-key/1.1/salt/)"  # quietly and output to stdout so taht we can save it to WP_SALTS

  cat > "$WP_PATH/wp-config.php" << EOF # things that should be in the wp-config.php file
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
EOF # setting ABSPATH to /var/www/html
fi

# Ensure correct ownership for wp-cli and runtime
chown -R www-data:www-data "$WP_PATH"
# change ownership recursively meaning to every file and folder to www-data

# Database connectability readiness check: waiting until wp-cli can talk to the Database
echo "Waiting for database..."
tries=30
until su -s /bin/sh www-data -c "wp --path='$WP_PATH' db check" >/dev/null 2>&1; do # switch user and use sh as the shell and run as www-data to run the command inside the quotes. db check means try connecting to the database using wp-config.php credentials and check if it works. >/dev/null hides standard output and 2>&1 redirects standard error to the same place
  tries=$((tries - 1))
  if [ "$tries" -le 0 ]; then # le means less than or equal to
    echo "ERROR: database not ready or credentials wrong."
    exit 1
  fi
  sleep 2
done

# Install WordPress + create second user if not installed
# using su www-data because when we run these wp commands in root, when php-fpm runs with www-data, we can't modify
if ! su -s /bin/sh www-data -c "wp --path='$WP_PATH' core is-installed" >/dev/null 2>&1; then # wp core is-installed checks the WordPress database tables and options.
  echo "Installing WordPress..."
  su -s /bin/sh www-data -c "wp --path='$WP_PATH' core install \
    --url='https://${DOMAIN_NAME}' \
    --title='${WORDPRESS_SITE_TITLE}' \
    --admin_user='${WORDPRESS_ADMIN_USER}' \
    --admin_password='${WORDPRESS_ADMIN_PASSWORD}' \
    --admin_email='${WORDPRESS_ADMIN_EMAIL}'"
    # installing wordpress with the admin user account

  echo "Creating second user..."
  su -s /bin/sh www-data -c "wp --path='$WP_PATH' user create \
    '${WORDPRESS_USER}' '${WORDPRESS_USER_EMAIL}' \
    --role=author \
    --user_pass='${WORDPRESS_USER_PASSWORD}'"
fi

# Keep strict permissions
find "$WP_PATH" -type d -exec chmod 750 {} \; # ownder can enter/write | group can enter/read | has no access for anyone
find "$WP_PATH" -type f -exec chmod 640 {} \; # owner can read/write | group can read | everyone else has no access

echo "Starting PHP-FPM..."
exec php-fpm8.2 -F  # -F run foreground so PHP-FPM becomes PID 1
```
---

## 3. NGINX

--Dockerfile--

```dockerfile
FROM  debian:bookworm

# Install nginx and openssl
RUN   apt-get update && apt-get install -y nginx openssl && rm -rf /var/lib/apt/lists/*

# Create SSL directory
RUN   mkdir -p /etc/nginx/ssl

# Copy configuration files
COPY  conf/nginx.conf /etc/nginx/nginx.conf
COPY  tools/generate_ssl.sh /usr/local/bin/

# Set permissions
RUN   chmod +x /usr/local/bin/*.sh

EXPOSE  443

ENTRYPOINT  ["/usr/local/bin/generate_ssl.sh"]
```

--tools/generate_ssl.sh--

```bash
#!/bin/bash   #shebang
set -e        #exit immediately if any command fails

# Ensure SSL directory exists
mkdir -p /etc/nginx/ssl

# Default domain if not provided
: "${DOMAIN_NAME:=localhost}"
  # if DOMAIN_NAME is set, we use it, if not, set it to localhost. (: is a do nothing command just used to trigger the variable assignment)

# Generate SSL certificate if it doesn't exist
if [ ! -f /etc/nginx/ssl/nginx.crt ] || [ ! -f /etc/nginx/ssl/nginx.key ]; then
  echo "Generating self-signed SSL certificate for ${DOMAIN_NAME}..."

    # -f means "file exists and is a regular file"

  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=${DOMAIN_NAME}"
  
      # openssl req -> use openssl's certificate request feature
      # -x509 -> Output a certificate directly in X.509 format (standard for certificates) without CSA (certification request)
      # -nodes -> "NO DES" means don't encrypt the private key file with passphrase/password so that nginx can use it
      # -days -> valid for 365 days
      # -newkey rsa:2048 -> generate a new RSA key with 2048 bits (RSA = public-key cryptography algo)
      # -keyout -> save the private key to that path
      # -out -> save the certificate to that path
      # -subj -> fills the Subject fields of the certificate

  chmod 600 /etc/nginx/ssl/nginx.key  # owner can read/write, nobody else can read it
  chmod 644 /etc/nginx/ssl/nginx.crt  # owner can read/write, everyone else can read
else
  echo "SSL certificate already exists. Skipping generation."
fi

# Test nginx configuration before starting
echo "Testing nginx configuration..."
nginx -t    # checks nginx config for syntax/validity <- basically just a test

# Start nginx in foreground as PID 1
echo "Starting Nginx..."
exec nginx -g "daemon off;" # replaces the shell script process with nginx
```

--conf/nginx.conf--

```nginx
user  www-data; # runs nginx workers as a non-root user

events  { # set maximum number of clients one nginx worker can handle at once
  worker_connections 1024;
}

http  {
  include /etc/nginx/mime.types;  # loads mappings to help browsers interpret files correctly.

  server  { # one server
    listen  443 ssl;  # listen on port 443e (HTTPS) and the server uses TLS
    server_name suroh.42.fr;

    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    root  /var/www/html;
    index index.php;
    # different with index.html
    # not a page but a main controller or entry point of the entire application.
    # the front controller of the WordPress application
    # not created manually unlike index.html
    # more dynamic and serves different applications

    location / {
      try_files $uri $uri/ /index.php?$args;
    }
    # $uri is an nginx variable that contains the URL path the client requested.
    # searches inside /var/www/html from file, folder, then falls back to index.php but with preserved query
    # $uri -> Is there a real file/folder that matches the URL? If yes, serve directly the static file or the directory with index index.php inside it.
    # /index.php?$args -> Send the request to WordPress’s main program, with the same query parameters the client sent.
    # If user requests https://suroh.42.fr/about -> can't find about and $args is empty -> effectively /index.php
    # If user requests https://suroh.42.fr/?s=nginx -> $args = s=nginx -> /index.php?s=nginx

    location ~ \.php$ { # uses regex match, deos ths url end with .php, fallback /index.php?$args come here
      fastcgi_pass  wordpress:9000; # send the request to a FastCGI server at host wordpress port 9000
      include fastcgi_params; # fastcgi_params is a file that defines standard variables needed for FastCGI
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; # Execute request to root+whateverphp
    }
  }
}
```

---

## 4. .env configuration and password settings

--.env--

```env
DOMAIN_NAME=suroh.42.fr

MYSQL_DATABASE=wordpress_db
MYSQL_USER=wp_user

# WordPress settings
WORDPRESS_DB_HOST=mariadb
WORDPRESS_DB_NAME=wordpress_db
WORDPRESS_DB_USER=wp_user
WORDPRESS_TABLE_PREFIX=wp_
WORDPRESS_SITE_TITLE=MyWebsite
WORDPRESS_ADMIN_USER=bigboss
WORDPRESS_ADMIN_EMAIL=bigboss@bigboss.com
WORDPRESS_USER=avgusr
WORDPRESS_USER_EMAIL=avgusr@bigboss.com
```

---

--secrets/db_root_password.txt--

- MariaDB “root” account password
- Used by the init_db.sh to:
  - set the root password
  - create the WordPress database
  - create the normal DB user
  - grant privileges

--secrets/db_password.txt--

- WordPress database user password
- This is the password for the DB user created (MYSQL_USER, e.g. wp_user)
- Needed in two places
  - WordPress uses it to log into MariaDB.
  - MariaDB needs it to create DB user

--secrets/wp_admin_password.txt--
- password for the WordPress admin account

--secrets/wp_user_password.txt--
- password for the WordPress user

after creation:
chmod 600 *.txt <- ownser can read/write but not others

---

## 5. docker-compose.yml

--srcs/docker-compose.yml--

Questions that I had.
1. *restart: always* - what is it, and why still do “if checks” in Dockerfiles/entrypoints?
  - *restart: always* is a runtime policy for the Docker when if the container stops for some reason (crash, process exit, etc.), Docker will try to bring it back up automatically. So it is completely separate from the initialization logic.

2. *Same line vs '-' + new lines* - what’s the difference?
  - When something is a list, we use '-' items.
  - When something is a mapping, we use `KEY: VALUE`

3. *depends_on* - what does it do?
  - *depends_on* controls startup order and means to start whatever is listed on the depends_on first.
  - e.g.) wordpress: depends_on: - mariadb means compose will start the mariadb container before starting the wordpress container.

```yaml
services:

  mariadb:
    build:
      context: requirements/mariadb
    image: mariadb
    container_name: mariadb
    restart: always
    networks:
      - inception-network
    volumes:
      - mariadb_data:/var/lib/mysql
    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/db_root_password
      MYSQL_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_root_password
      - db_password

  wordpress:
    build:
      context: requirements/wordpress
    image: wordpress
    container_name: wordpress
    restart: always
    depends_on:
      - mariadb
    networks:
      - inception-network
    volumes:
      - wordpress_data:/var/www/html
    environment:
      DOMAIN_NAME: ${DOMAIN_NAME}
      WORDPRESS_DB_HOST: ${WORDPRESS_DB_HOST}
      WORDPRESS_DB_NAME: ${WORDPRESS_DB_NAME}
      WORDPRESS_DB_USER: ${WORDPRESS_DB_USER}
      WORDPRESS_DB_PASSWORD_FILE: /run/secrets/db_password
      WORDPRESS_TABLE_PREFIX: ${WORDPRESS_TABLE_PREFIX}
      WORDPRESS_SITE_TITLE: ${WORDPRESS_SITE_TITLE}
      WORDPRESS_ADMIN_USER: ${WORDPRESS_ADMIN_USER}
      WORDPRESS_ADMIN_EMAIL: ${WORDPRESS_ADMIN_EMAIL}
      WORDPRESS_ADMIN_PASSWORD_FILE: /run/secrets/wp_admin_password
      WORDPRESS_USER: ${WORDPRESS_USER}
      WORDPRESS_USER_EMAIL: ${WORDPRESS_USER_EMAIL}
      WORDPRESS_USER_PASSWORD_FILE: /run/secrets/wp_user_password
    secrets:
      - db_password
      - wp_admin_password
      - wp_user_password

  nginx:
    build:
      context: requirements/nginx
    image: nginx
    container_name: nginx
    restart: always
    depends_on:
      - wordpress
    networks:
      - inception-network
    volumes:
      - wordpress_data:/var/www/html
    environment:
      DOMAIN_NAME: ${DOMAIN_NAME}
    ports:
      - "443:443"

networks:
  inception-network:
    driver: bridge

volumes:
  mariadb_data:
  wordpress_data:

secrets:
  db_root_password:
    file: ../secrets/db_root_password.txt
  db_password:
    file: ../secrets/db_password.txt
  wp_admin_password:
    file: ../secrets/wp_admin_password.txt
  wp_user_password:
    file: ../secrets/wp_user_password.txt
```

## 6. Moving Docker's storage root (so the named volumes live under /home/suroh/data)

1. Create directory for the volumes
```bash
sudo mkdir -p /home/suroh/data/docker
```

2. Set Docker data-root
```bash
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF' # feeds the block of text into a command as stdin
{
  "data-root": "/home/suroh/data/docker"
}
EOF # Store Docker's data under this path
```
- we user tee because it writes input to a file and overwrites the file. If the file does not exist, it creates it.

3. Load the config
```bash
sudo systemctl restart docker
# or
sudo systemctl start docker
```

4. Check if the mountpoint changed
```bash
docker volume ls # check the volumes

docker volume inspect nameofthevolume | grep Mountpoint -n
```

'docker controls'

sudo systemctl is-active docker
- checks if docker is active or not

docker compose up --build -d (should run only on the directory where the docker-compose.yml exists)
--build -> Compose ensures the latest dockerfile script changes to be applied to the image.
-d -> detached mode, or runs containers in the background.

## 7. MAKEFILE

```make
COMPOSE_FILE = srcs/docker-compose.yml
PROJECT = inception

.PHONY: all build up down logs ps clean fclean re

all: up

up:
  docker compose -p $(PROJECT) -f $(COMPOSE_FILE) up -d --build

build:
  docker compose -p $(PROJECT) -f $(COMPOSE_FILE) build

down:
  docker compose -p $(PROJECT) -f $(COMPOSE_FILE) down

logs:
  docker compose -p $(PROJECT) -f $(COMPOSE_FILE) logs -f

ps:
  docker compose -p $(PROJECT) -f $(COMPOSE_FILE) ps

clean:
  docker compose -p $(PROJECT) -f $(COMPOSE_FILE) down -v

fclean:
  docker compose -p $(PROJECT) -f $(COMPOSE_FILE) down -v --rmi all

re: fclean up
```

COMPOSE_FILE = srcs/docker-compose.yml
- defines a Mkae variable named "COMPOSE_FILE"

Phony targets
- declares as commands and not file names

all: up

docker compose -p $(PROJECT) -f $(COMPOSE_FILE) up -d --build
- up -> create/start containers
- --build -> rebuild images first if needed
- -d -> run in background

docker compose -> uses docker compose v2
-p $(PROJECT) -> project name set to inception
-f $(COMPOSE_FILE) ->  -f means which compose files to use (use srcs/docker-compose.yml)

down
- stops containers
- removes containers
- removes the project network
X does not remove named volumes
X does not remove images

logs -f
- shows live output (stdout/stderr) from all containers

ps target
- shows the status of compose services

docker compose -p $(PROJECT) -f $(COMPOSE_FILE) down -v
- stops containers
- deletes volumes
- keeps images

down -v --rmi all
- remove Image
- all images

## 8. once everything is done...

```bash
make
# or
make up

make ps
# to check if the containers are running

make logs
# to monitor if there are errors or any restart loops
```

Making the domain resolve to the machine
1. Edit /etc/hosts through sudo nano
2. add '127.0.0.1 suroh.42.fr'
3. turn off proxy in settings->network settings if on
4. go to https://suroh.42.fr
5. go to https://suroh.42.fr/wp-admin to log in with admin credentials
6. doodle around and make a quick post page or whatever

How to check persistence
1. Restart containers without deleting volumes
```bash
make down
make up
# or
docker compose down
docker compose up -d
```
2. Refresh http://suroh.42.fr
3. Check for the post

---

## 9. adding the configuration to git
```gitignore
secrets/
```

---

## 10. Check NGINX port 443
```bash
ss -lntp
```
This commands should not show ':80'
```bash
docker ps
```
should show that nginx is open to 443 only

*How to check SSL/TLS connection*
```bash
curl -v https://suroh.42.fr
```
Will show information about TLS

```bash
docker images
```
Will show image names

---

## 11. How to log in to database and check data

Enter the container
```bash
docker exec -it mariadb bash
```
-it flag means interactive and allocates a terminal
So, it means to open an interactive terminal session inside the container and start a bash shell

Check password
```bash
cat /run/secrets/db_root_password
```

login
```bash
mysql -u root -p
# or
mysql -u wp_user -p
```
-p is a flag for asking for a password interactively

show database
```bash
SHOW DATABASES;
USE wordpress_db;
SHOW TABLES;
```