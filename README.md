*This project has been created as part of the 42 curriculum by <suroh>.*
---
## Description

Inception is a System Administration project from the 42 curriculum.  
Its objective is to design and deploy a small, secure infrastructure using Docker and Docker Compose inside a virtual machine.

The project consists of containerizing multiple services - NGINX, WordPress (with PHP-FPM), and MariaDB - each running in its own dedicated Docker container. These services are connected through a custom Docker network and use Docker named volumes to ensure persistent data storage.

The main goal of this project is to understand how modern infrastructures are built using containerization instead of traditional virtual machines. It focuses on:

- Writing custom Dockerfiles for each service  
- Configuring secure HTTPS access with TLSv1.2 or TLSv1.3  
- Managing environment variables and secrets properly  
- Ensuring service isolation and controlled networking  
- Persisting application data using Docker volumes  

This project teaches how to set and configure a Docker architecture and learn how container networking works.

## Project Description & Design Choices

### Use of Docker in This Project

This project uses Docker to containerize and isolate each service of the infrastructure.
Instead of installing NGINX, WordPress, and MariaDB directly on the virtual machine,
each service runs inside its own dedicated container.

Docker allows:

- Service isolation
- Reproducible environments
- Lightweight deployment
- Simplified dependency management
- Clear separation of responsibilities between services

Docker Compose is used to orchestrate the containers, define networks, configure volumes,
and manage environment variables in a centralized way.

---

## Design Comparisons

### Virtual Machines vs Docker

| Virtual Machines | Docker Containers |
|------------------|-------------------|
| Emulate entire hardware | Share the host kernel |
| Require full OS per instance | Use minimal base images |
| Heavy resource consumption | Lightweight |
| Slower boot time | Fast startup |
| Larger disk footprint | Smaller footprint |

Virtual Machines virtualize hardware, while Docker virtualizes at the OS level.
For this project, Docker was chosen because it is lightweight, efficient,
and aligns with modern DevOps practices.

---

### Secrets vs Environment Variables

| Environment Variables | Docker Secrets |
|----------------------|----------------|
| Defined in `.env` | Stored securely by Docker |
| Easier to configure | Designed for sensitive data |
| Can be exposed via logs or inspect | Not directly readable |

Environment variables are mandatory for configuration in this project.
However, for production-grade security, Docker secrets are preferred
for storing sensitive information such as database passwords.

---

### Docker Network vs Host Network

| Docker Network | Host Network |
|---------------|-------------|
| Isolated container communication | Direct access to host networking |
| Internal DNS-based resolution | No container-level isolation |
| More secure | Less secure |

A dedicated Docker bridge network is used to allow internal communication
between containers (WordPress <-> MariaDB <-> NGINX) while exposing only NGINX
to the outside world.

---

### Docker Volumes vs Bind Mounts

| Docker Named Volumes | Bind Mounts |
|---------------------|-------------|
| Managed by Docker | Directly map host paths |
| Portable and cleaner abstraction | Host-dependent |
| Recommended for persistent storage | Less portable |

Docker named volumes are used to ensure that database data and website files
persist even if containers are stopped or rebuilt. The subject explicitly
requires named volumes and forbids bind mounts for these services.

---
## Instructions

### Build and Launch the Project

From the root of the repository, run:
```bash
make
```
This command will:

- Build all Docker images using the Dockerfiles
- Create the Docker network
- Create the required named volumes
- Start all containers using Docker Compose

After successful execution, the infrastructure should be running.

Verify running containers with:
```bash
docker ps
```
---

### Access the Website

Open a browser and navigate to:

https://suroh.42.fr

If the project is configured correctly, the browser should land directly on the WordPress site (homepage or configured content).  
WordPress must be installed automatically by the container startup configuration.

NGINX is the only exposed service and listens exclusively on port 443 using TLSv1.2 or TLSv1.3.
---

### Stop the Project

To stop and remove containers:
```bash
make down
```
Or manually:
```bash
docker compose down
```
To remove volumes as well (⚠️ this deletes stored data):
```bash
docker compose down -v
```
---

### Rebuild from Scratch

To rebuild everything:
```bash
make fclean
make
```
Or manually:
```bash
docker compose down -v
docker compose build --no-cache
docker compose up -d
```
---

### Verify Services

Check logs with:
```bash
docker logs <container_name>
```

Check network:
```bash
docker network ls
```

Check volumes:
```bash
docker volume ls
```
---

## Resources

This project required extensive research on Docker, containerization, networking,
NGINX configuration, WordPress deployment, and MariaDB setup.

Below are the main references used during development:

---

### Official Documentation

- Docker Official Documentation — https://docs.docker.com/
- Docker Compose Documentation — https://docs.docker.com/compose/
- NGINX Documentation — https://nginx.org/en/docs/
- MariaDB Documentation — https://mariadb.org/documentation/
- WordPress Documentation — https://wordpress.org/support/

---

### Tutorials & Guides

- Grademe Inception Guide  
  https://tuto.grademe.fr/inception/

- Medium — Inception (imyzf)  
  https://medium.com/@imyzf/inception-3979046d90a0

- Medium — Inception Guide Part I (ssterdev)  
  https://medium.com/@ssterdev/inception-guide-42-project-part-i-7e3af15eb671

- Medium — Inception Guide Part II (ssterdev)  
  https://medium.com/@ssterdev/inception-42-project-part-ii-19a06962cf3b

- Educative — Docker Compose Tutorial  
  https://www.educative.io/blog/docker-compose-tutorial

- DEV.to — Docker + NGINX + WordPress + MariaDB (alejiri)  
  https://dev.to/alejiri/docker-nginx-wordpress-mariadb-tutorial-inception42-1eok

- Reddit — “Explain Docker Like I’m an Idiot”  
  https://www.reddit.com/r/docker/comments/keq9el/please_someone_explain_docker_to_me_like_i_am_an/

---

### GitHub Repositories (Reference Implementations)

- https://github.com/llescure/42_Inception  
- https://github.com/malatini42/inception  
- https://github.com/vbachele/Inception/blob/main/README.md#definitions  

These repositories were consulted to understand different structural approaches,
Dockerfile organization, and container orchestration patterns.

---

## AI Usage

AI tools were used responsibly and critically throughout this project for:

- Clarifying Docker concepts (containers, volumes, networks, PID 1, daemon behavior)
- Understanding differences between:
  - Virtual Machines vs Docker
  - Docker Volumes vs Bind Mounts
  - Secrets vs Environment Variables
  - Docker Network vs Host Network
- Structuring Docker Compose files correctly
- Debugging container startup issues
- Improving TLS configuration understanding for NGINX
- Drafting and refining project documentation

AI was not used to blindly generate production-ready configurations.
All generated suggestions were:

- Manually reviewed
- Tested inside the virtual machine
- Adjusted to comply strictly with the subject requirements

The goal was to use AI as a learning assistant to reduce repetitive tasks and clarify concepts,
while ensuring full understanding and ownership of the implementation.