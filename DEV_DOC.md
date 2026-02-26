# DEV_DOC.md

## 1. Project Overview

This project deploys a secure WordPress infrastructure using Docker.

The stack includes:

- **NGINX** (reverse proxy + TLS termination)
- **WordPress (PHP-FPM)** (application layer)
- **MariaDB** (database layer)

All services are containerized and orchestrated using Docker Compose.
Persistent data is managed using Docker named volumes.

---

## 2. Prerequisites

To set up the environment from scratch, the following are required:

### System Requirements
- Linux environment (Debian/Ubuntu recommended)
- Docker Engine
- Docker Compose (v2)
- GNU Make

### Verify Installation

```bash
docker --version
docker compose version
make --version
```

---

## 3. Initial Project Setup

### 3.1 Clone the Repository
```bash
git clone <repository_url>
cd <project_directory>
```

### 3.2 Configure Environment Variables
Create a .env file in the project root:
```bash
nano .env
```

Example content:
```bash
DOMAIN_NAME=suroh.42.fr

MYSQL_DATABASE=wordpress_db
MYSQL_USER=wp_user

WORDPRESS_DB_HOST=mariadb
WORDPRESS_DB_NAME=wordpress_db
WORDPRESS_DB_USER=wp_user
WORDPRESS_TABLE_PREFIX=wp_
WORDPRESS_SITE_TITLE=MyWebsite
WORDPRESS_ADMIN_USER=bigboss
WORDPRESS_ADMIN_EMAIL=admin@example.com
WORDPRESS_USER=avgusr
WORDPRESS_USER_EMAIL=user@example.com
```
*Do NOT place passwords in .env.*

### 3.3 Create Secrets
Create a secrets/ directory:
```bash
mkdir secrets
```

Create the following files:

secrets/db_root_password.txt
secrets/db_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt

Add the corresponding passwords inside each file.

Set secure permissions:
```bash
chmod 600 secrets/*.txt
```
These secrets are mounted securely into containers at runtime.

---

## 4. Building and Launching the Project

### Build and Start
```bash
make
# or
make up
```
This will:
- Build Docker images
- Create the network
- Create named volumes
- Start all containers in detached mode

### Stop Containers
```bash
make down
```
Stops and removes containers but preserves volumes.

### Full Cleanup (including volumes and images)
```bash
make fclean
```
Removes:
- Containers
- Networks
- Named volumes
- Images

All persistent data will be lost.

---

## 5. Managing Containers and Volumes

### View Running Containers
```bash
make ps
# or
docker compose ps
```

### View Logs
```bash
make logs
# or
docker compose logs -f
```

### Inspect Volumes
- List volumes:
```bash
docker volume ls
```

- Inspect a volume:
```bash
docker volume inspect mariadb_data
```

### Remove Volumes Manually
```bash
docker volume rm mariadb_data
docker volume rm wordpress_data
```

---

## 6. Data Storage and Persistence

### Named Volumes Used
- mariadb_data
- wordpress_data
These are Docker named volumes defined in docker-compose.yml.

### Physical Storage Location
Docker’s data root has been configured to:
- /home/<login>/data/docker

The actual volume data is stored under:
- /home/<login>/data/docker/volumes/

MariaDB data directory inside container:
- /var/lib/mysql

WordPress files directory inside container:
- /var/www/html

Because these paths are mapped to named volumes, data persists even if containers are removed.
Docker does the following:
- Creates a volume outside the container filesystem.
- Mounts that volume into the container at /var/lib/mysql.
- All database files are written directly into the volume.
- The volume exists independently of the container lifecycle.

---

## 7. Persistence Validation Procedure

### Start the project:
```bash
make up
```

### Create a WordPress post.
Restart containers:
```bash
make down
make up
```

### Verify that the post still exists.
If the post remains, persistence is working correctly.

---

## 8. Rebuilding the Project from Scratch

To completely reset the environment:
```bash
make fclean
make up
```
This rebuilds images and recreates containers and volumes from scratch.