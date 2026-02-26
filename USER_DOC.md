# USER_DOC.md

## 1. Overview of the Infrastructure

This project deploys a secure WordPress website using Docker.

The infrastructure consists of three services:

### 🔹 NGINX
- Acts as the only public entry point.
- Listens only on port **443 (HTTPS)**.
- Uses **TLSv1.2 and TLSv1.3**.
- Forwards PHP requests to the WordPress container.

### 🔹 WordPress (PHP-FPM)
- Runs the WordPress application.
- Handles dynamic PHP processing.
- Communicates with MariaDB for database operations.

### 🔹 MariaDB
- Stores WordPress data (posts, users, settings).
- Uses a persistent Docker named volume to preserve data across restarts.

---

## 2. How to Start and Stop the Project

### Start the project

From the project root:

```bash
make
# or
make up
```
This will:
- Build Docker images
- Start all containers in detached mode

### Stop the project
```bash
make down
```
This stops and removes containers but keeps persistent data.

### Remove everything (including database)
```bash
make fclean
```
All data will be deleted.

---

## 3. Accessing the Website

### Step 1 - Configure domain resolution
- Edit the /etc/hosts file
- Add the following line: 127.0.0.1 suroh.42.fr

### Step 2 — Open the website
- Open a browser and visit: https://suroh.42.fr

### Step 3 — Access the Admin Panel
- Visit: https://suroh.42.fr/wp-admin
- Log in using the WordPress administrator credentials.

---

## 4. Credentials Management

Sensitive credentials are stored using Docker secrets and they are located in the secrets/ directory:
- db_root_password.txt
- db_password.txt
- wp_admin_password.txt
- wp_user_password.txt

These files:
- Are NOT committed to Git
- Are mounted securely inside containers at runtime

---

## 5. Verifying Services Are Running
Check container status
```bash
make ps
```
All services should show as running.

Check logs
```bash
make logs
```
Logs can be used to detect errors or restart loops.

Verify HTTPS is active
```bash
curl -k https://suroh.42.fr
```
If HTML content is returned, NGINX and WordPress are functioning correctly.

---

## 6. Checking Data Persistence

- Create a WordPress post.
- Restart containers:
```bash
make down
make up
```
Refresh the website.

If the post remains visible, data persistence is working correctly.

---

## 7. Project Compliance Notes

- Only port 443 is exposed publicly.
- TLSv1.2 and TLSv1.3 are enforced.
- No passwords are stored in Dockerfiles.
- Docker named volumes are used for persistence.
- Secrets are not committed to the Git repository.