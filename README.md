# Photoframe Immich

A simplified Immich installation optimized for photoframe users. Run a self-hosted photo backend on Raspberry Pi 5, Synology NAS, or free-tier VPS with minimal configuration.

## Quick Start

**Option A: Omnibus (Recommended for beginners)**
```bash
docker run -d \
  --name photoframe-immich \
  -p 2283:2283 \
  -v /path/to/photos:/library \
  -v photoframe-immich-data:/data \
  devbrewery/photoframe-immich:latest
```

**Option B: Docker Compose (Recommended for production)**
```bash
curl -fsSL https://raw.githubusercontent.com/dev-brewery/photoframe-immich/main/docker-compose.yml > docker-compose.yml
docker compose up -d
```

## What This Is

Immich is a self-hosted Google Photos alternative. This image is preconfigured for **photoframe use cases** — meaning it's optimized to:

- Serve photos to display devices (digital frames, tablets, TVs)
- Run on modest hardware (Raspberry Pi 5, 1-2GB RAM VPS)
- Minimize resource usage while maintaining core photo management features
- Provide a simple setup experience for users new to self-hosting

### What's Included

- **Immich Server** — Web UI, API, and photo management
- **Immich Machine Learning** — Smart search, face recognition (configurable)
- **PostgreSQL Database** — Photo metadata and settings
- **Redis** — Background job queue and caching

All preconfigured and tuned for photoframe workloads.

## System Requirements

| Platform | Minimum RAM | CPU | Storage |
|----------|-------------|-----|---------|
| Raspberry Pi 5 | 2GB | ARM64 | SD card + external USB/NAS |
| Synology NAS | 2GB | ARM64 or AMD64 | NAS volume |
| VPS (Oracle/Google free tier) | 2GB | AMD64 | Block storage |

**Disk space:** Depends on your photo library. Plan for at least 2x your current photo storage.

## Installation

### Option A: Omnibus Image (Single Container)

The omnibus image runs all Immich services in one container using [s6-overlay](https://github.com/just-containers/s6-overlay). This is the simplest option — just run and go.

#### 1. Pull the Image

```bash
docker pull devbrewery/photoframe-immich:latest
```

#### 2. Run the Container

```bash
docker run -d \
  --name photoframe-immich \
  --restart unless-stopped \
  -p 2283:2283 \
  -v /path/to/your/photos:/library \
  -v photoframe-immich-data:/data \
  -e IMMICH_ADMIN_EMAIL=admin@example.com \
  -e IMMICH_ADMIN_PASSWORD=changeme \
  devbrewery/photoframe-immich:latest
```

**Explanation:**
- `-p 2283:2283` — Web UI and API on port 2283
- `-v /path/to/your/photos:/library` — Your photo library location
- `-v photoframe-immich-data:/data` — Database and config (Docker volume)
- `IMMICH_ADMIN_EMAIL` — Initial admin email
- `IMMICH_ADMIN_PASSWORD` — Initial admin password

#### 3. Access the Web UI

Open `http://your-device-ip:2283` in a browser.

Log in with the admin credentials you set, then:
1. Add your photos to the library (either upload or sync from external storage)
2. Create an API key for your photoframe device
3. Configure your photoframe software to use the Immich API

#### 4. Persistent Data

Your photos, database, and configuration are stored in:
- `/library` — Your photo files (mounted from your host)
- `/data` — Database, cache, and Immich data (Docker volume)

To back up:
```bash
# Backup database and config
docker exec photoframe-immich /app/backup.sh

# Copy backup from container
docker cp photoframe-immich:/data/backup ./immich-backup
```

### Option B: Docker Compose (Multi-Container)

For production use or if you prefer the standard Immich architecture, use Docker Compose. This runs each service in its own container for better isolation and scalability.

#### 1. Create the Compose File

Save this as `docker-compose.yml`:

```yaml
name: photoframe-immich

services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:v1.120.0
    container_name: photoframe_immich_server
    restart: unless-stopped
    ports:
      - "2283:2283"
    volumes:
      - ${UPLOAD_LOCATION:-./library}:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
    env_file:
      - .env
    depends_on:
      - redis
      - database
    environment:
      # Photoframe optimizations
      - DISABLE_MACHINE_LEARNING=false
      - MACHINE_LEARNING_WORKER_CONCURRENCY=2
      - MACHINE_LEARNING_WORKERS=1
      - ENABLE_MAP=false

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:v1.120.0
    container_name: photoframe_immich_ml
    restart: unless-stopped
    volumes:
      - model-cache:/cache
    env_file:
      - .env
    environment:
      # Reduce ML workers for modest hardware
      - MACHINE_LEARNING_WORKER_CONCURRENCY=2
      - MACHINE_LEARNING_WORKERS=1

  redis:
    image: docker.io/valkey/valkey:9@sha256:3b55fbaa0cd93cf0d9d961f405e4dfcc70efe325e2d84da207a0a8e6d8fde4f9
    container_name: photoframe_immich_redis
    restart: unless-stopped
    healthcheck:
      test: redis-cli ping || exit 1

  database:
    image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23
    container_name: photoframe_immich_postgres
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_DB: ${DB_DATABASE_NAME}
      POSTGRES_INITDB_ARGS: '--data-checksums'
    volumes:
      - ${DB_DATA_LOCATION:-./postgres}:/var/lib/postgresql/data
    shm_size: 128mb
    healthcheck:
      test: pg_isready -d ${DB_DATABASE_NAME} -U ${DB_USERNAME} || exit 1

volumes:
  model-cache:
```

#### 2. Create the Environment File

Save this as `.env`:

```bash
# You can find documentation for all supported env variables at https://docs.immich.app/install/environment-variables

# The location where your uploaded files are stored
UPLOAD_LOCATION=./library

# The location where your database files are stored
DB_DATA_LOCATION=./postgres

# The Immich version to use
IMMICH_VERSION=v1.120.0

# Database credentials (CHANGE THIS!)
DB_PASSWORD=changeme-secure-password
DB_USERNAME=immich
DB_DATABASE_NAME=immich

# Initial admin account (optional - will be created on first run)
# IMMICH_ADMIN_EMAIL=admin@example.com
# IMMICH_ADMIN_PASSWORD=changeme

# Photoframe optimizations (optional overrides)
# DISABLE_MACHINE_LEARNING=false
# MACHINE_LEARNING_WORKER_CONCURRENCY=2
# MACHINE_LEARNING_WORKERS=1
```

#### 3. Start the Stack

```bash
# Create necessary directories
mkdir -p library postgres

# Set proper permissions (Linux only)
chmod 755 library postgres

# Start all services
docker compose up -d

# Check logs
docker compose logs -f

# Stop services
docker compose down
```

#### 4. Initial Setup

1. Wait for all services to be healthy (~30 seconds)
2. Open `http://your-device-ip:2283`
3. Create your admin account
4. Add your photos (upload or sync)
5. Generate an API key for photoframe integration

## Photoframe Integration

### Creating an API Key

1. Log in to Immich web UI
2. Go to **Administration → API Keys**
3. Click **Create New API Key**
4. Name it (e.g., "Photoframe - Living Room")
5. Set permissions: Read all assets, Read all albums
6. Copy the API key — you'll need it for your photoframe software

### Connecting Your Photoframe

In your photoframe software configuration:

```yaml
photo_service:
  type: immich
  api_url: http://your-immich-ip:2283
  api_key: your-api-key-here
  albums:
    - "Favorites"
    - "Family Photos"
```

## Configuration

### Environment Variables (Omnibus)

| Variable | Default | Description |
|----------|---------|-------------|
| `IMMICH_ADMIN_EMAIL` | — | Initial admin email |
| `IMMICH_ADMIN_PASSWORD` | — | Initial admin password |
| `TZ` | `Etc/UTC` | Timezone (e.g., `America/New_York`) |
| `DISABLE_MACHINE_LEARNING` | `false` | Disable ML features (saves CPU) |
| `MACHINE_LEARNING_WORKERS` | `1` | Number of ML workers (Raspberry Pi: 1, VPS: 2-4) |
| `ENABLE_MAP` | `false` | Disable map feature (saves resources) |

### Performance Tuning

**For Raspberry Pi 5 (2GB RAM):**
```yaml
MACHINE_LEARNING_WORKERS: 1
DISABLE_MACHINE_LEARNING: false
MACHINE_LEARNING_WORKER_CONCURRENCY: 1
ENABLE_MAP: false
```

**For VPS (4GB+ RAM):**
```yaml
MACHINE_LEARNING_WORKERS: 2
MACHINE_LEARNING_WORKER_CONCURRENCY: 2
ENABLE_MAP: true
```

**For NAS (limited CPU):**
```yaml
MACHINE_LEARNING_WORKERS: 1
DISABLE_MACHINE_LEARNING: false
ENABLE_MAP: false
```

## Updating

### Omnibus Image

```bash
# Stop and remove old container
docker stop photoframe-immich
docker rm photoframe-immich

# Pull latest image
docker pull devbrewery/photoframe-immich:latest

# Run with same command as initial install
docker run -d \
  --name photoframe-immich \
  --restart unless-stopped \
  -p 2283:2283 \
  -v /path/to/photos:/library \
  -v photoframe-immich-data:/data \
  devbrewery/photoframe-immich:latest
```

### Docker Compose

```bash
# Pull new images
docker compose pull

# Restart with new images
docker compose up -d
```

## Troubleshooting

### Container won't start

**Check logs:**
```bash
docker logs photoframe-immich
```

**Common issues:**
- **Permission denied on `/library`**: Ensure the mounted directory is readable by the container user (UID 1000)
- **Port 2283 already in use**: Change port mapping (`-p 8080:2283`)
- **Out of memory**: Reduce `MACHINE_LEARNING_WORKERS` or disable ML entirely

### Can't access web UI

- **Check container is running:** `docker ps`
- **Check port is open:** `curl http://localhost:2283`
- **Firewall:** Ensure port 2283 is allowed through your firewall

### Photos not showing

- **Check library path:** Ensure `/library` mount points to your actual photo directory
- **Check permissions:** Immich needs read access to all photo files
- **Trigger scan:** In web UI, go to **Administration → Jobs → Library** and run "Scan Library Files"

### High CPU usage

This is usually the machine learning worker processing photos. To reduce:

```bash
docker stop photoframe-immich
docker run -d \
  --name photoframe-immich \
  ... \
  -e MACHINE_LEARNING_WORKERS=1 \
  -e MACHINE_LEARNING_WORKER_CONCURRENCY=1 \
  devbrewery/photoframe-immich:latest
```

Or disable ML entirely:
```bash
-e DISABLE_MACHINE_LEARNING=true
```

## Backups

### Omnibus Image

```bash
# Backup script built into the image
docker exec photoframe-immich /app/backup.sh

# Copy backup from container
docker cp photoframe-immich:/data/backup ./immich-backup-$(date +%Y%m%d)
```

### Docker Compose

```bash
# Backup database
docker exec photoframe_immich_postgres pg_dump -U immich immich > immich-db-backup.sql

# Backup uploaded files
tar -czf immich-library-backup.tar.gz ./library
```

### Restoring

```bash
# Stop containers
docker compose down

# Restore database
cat immich-db-backup.sql | docker exec -i photoframe_immich_postgres psql -U immich immich

# Restore library
tar -xzf immich-library-backup.tar.gz

# Start containers
docker compose up -d
```

## Security Notes

- **Change default passwords** immediately after first login
- **Use HTTPS** in production: Put Immich behind a reverse proxy (Nginx Proxy Manager, Traefik, Caddy) with SSL certificates
- **Firewall**: Only expose port 2283 to trusted networks or use a VPN
- **Backups**: Set up automated backups of both database and photo library
- **Updates**: Subscribe to [Immich releases](https://github.com/immich-app/immich/releases) for security updates

## Architecture

### Omnibus Image

```
┌─────────────────────────────────────────┐
│   photoframe-immich container           │
│                                         │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │ Immich       │  │ PostgreSQL      │ │
│  │ Server       │◄─┤ (with pgvector) │ │
│  │ (port 2283)  │  │                 │ │
│  └──────┬───────┘  └─────────────────┘ │
│         │                               │
│         │  ┌─────────────────┐         │
│         └──┤ Redis           │         │
│            │ (cache/queue)   │         │
│            └─────────────────┘         │
│                                         │
│  ┌─────────────────────────────────┐  │
│  │ Immich Machine Learning         │  │
│  │ (face recognition, search)      │  │
│  └─────────────────────────────────┘  │
│                                         │
│  s6-overlay process supervision        │
└─────────────────────────────────────────┘
```

### Docker Compose

```
┌────────────────┐     ┌──────────────────┐
│ Immich Server  │────►│ Redis            │
│ (port 2283)    │     │ (cache/queue)    │
└────────┬───────┘     └──────────────────┘
         │
         ├──────────────────┐
         │                  │
         ▼                  ▼
┌──────────────────┐  ┌──────────────┐
│ Machine Learning │  │ PostgreSQL   │
│                  │  │ (pgvector)   │
└──────────────────┘  └──────────────┘
```

## Support

- **Immich Documentation**: https://docs.immich.app
- **Photoframe Project**: https://github.com/dev-brewery/photoframe
- **Issues**: https://github.com/dev-brewery/photoframe-immich/issues

## License

This project bundles Immich, which is licensed under the GNU AGPL v3 License.

## Acknowledgments

- [Immich](https://immich.app) — The amazing self-hosted photo management solution
- [s6-overlay](https://github.com/just-containers/s6-overlay) — Process supervision for the omnibus image
- [photoframe](https://github.com/mrworf/photoframe) — The original photoframe project by @mrworf
