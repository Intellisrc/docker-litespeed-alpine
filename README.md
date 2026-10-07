# docker-litespeed-alpine
LiteSpeed and PHP 8 inside a Docker container running Alpine

[OpenLiteSpeed](https://openlitespeed.org) with PHP (lsphp) on Alpine Linux
([intellisrc/alpine](https://hub.docker.com/r/intellisrc/alpine)).
Alpine packages only the `lsphp` SAPI, so the official OpenLiteSpeed binary release is
downloaded on start-up and executed through `gcompat` (the glibc compatibility layer for musl).

## Quick start

```bash
docker run -d --name web -p 8080:80 -v /var/www:/var/www intellisrc/litespeed-alpine:3.24
```

Everything under `/var/www` is served immediately, PHP included:

```bash
echo '<?php phpinfo();' > /var/www/index.php
```

The default virtual host uses WordPress style rewrites (anything that is not a file is
routed to `/index.php`) and the WebAdmin console is disabled (`disableWebAdmin 1`).

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLS_VER` | *(latest)* | OpenLiteSpeed version to install on start-up (`1.9.3`, `v1.8.5`, ...). When empty, the latest official release is detected and installed automatically. |
| `OLS_SHA256` | — | Optional SHA-256 checksum of the OpenLiteSpeed package. When set, the download is verified before installing (recommended together with a pinned `OLS_VER`). |
| `PHP_MAX_UPLOAD` | *(php.ini)* | Sets both `upload_max_filesize` and `post_max_size`. When empty, the PHP defaults are kept (`2M`/`8M`). |
| `LS_SOFT_LIMIT` | `512M` | Soft memory limit (`RLIMIT_AS`) for the PHP/CGI workers. |
| `LS_HARD_LIMIT` | `700M` | Hard memory limit (`RLIMIT_AS`) for the PHP/CGI workers. |
| `OBJ_CACHE` | `none` | Object cache: `redis`, `memcached` or `none`. The selected service is installed and started on start-up. |
| `USE_DB` | `none` | Installs the PHP database drivers on start-up: `mysql` or `mariadb` (mysqli + PDO). |
| `DB_NAME`, `DB_USER`, `DB_PASS`, `DB_HOST`, `DB_CHARSET` | — | Passed through for your application / `init.sh` to use. |
| `INIT_SCRIPT` | `/home/init.sh` | Custom script executed before the server starts (falls back to `/var/www/init.sh`). |
| `PHP_VER` | `83` | PHP version (build time, e.g. `83` → `php83-*` packages). |

## Volumes

| Path | Description |
|------|-------------|
| `/var/www` | Document root (your application). |
| `/var/lib/litespeed/sessions` | PHP session files. |
| `/var/log/litespeed` | Server logs. Errors are also written to stderr, so `docker logs` works. |

## Port

- `80` — HTTP

## Docker Swarm

The OpenLiteSpeed version is selected at start-up, so it can be changed per deployment
without rebuilding the image:

```yaml
version: "3.8"
services:
  web:
    image: intellisrc/litespeed-alpine:3.24
    ports:
      - "80:80"
    volumes:
      - /var/www:/var/www
      - /var/lib/litespeed/sessions:/var/lib/litespeed/sessions
    environment:
      - OLS_VER=1.8.5          # omit to install the latest release
      - PHP_MAX_UPLOAD=64M
    deploy:
      replicas: 2
```

On start-up the OpenLiteSpeed package (~90MB) is downloaded with a progress indicator in the
logs, extracted to `/usr/local/lsws`, and kept inside the container: it is only downloaded
again when `OLS_VER` changes (or is resolved to a newer release).

## Custom initialization

A script placed at `/home/init.sh` (or `/var/www/init.sh`, or the file set in `INIT_SCRIPT`)
runs once before the server starts. Use it to install extra packages, set up the database,
run `composer`, etc.:

```bash
#!/bin/bash
apk add --no-cache composer php83-mysqli
cd /var/www && composer install --no-dev
```

## Configuration

| Path | Description |
|------|-------------|
| `/etc/litespeed/httpd_config.conf` | Main server configuration (symlink to `/usr/local/lsws/conf`). |
| `/etc/litespeed/vhosts/default.conf` | Virtual host configuration (doc root `/var/www`). |
| `/etc/php83/php.ini` | PHP configuration. |
| `/usr/local/lsws` | OpenLiteSpeed installation (created on start-up). |

## Included PHP extensions

openssl, phar, tokenizer, xml, simplexml, xmlreader, xmlwriter, curl, gd, mbstring, exif,
ctype, fileinfo, intl, zip, iconv, dom, session and opcache plus `lsphp` (the LiteSpeed SAPI).
Anything else can be installed at start-up, either in `init.sh` or with `OBJ_CACHE`/`USE_DB`
(see above).

## Production notes

- **Pin `OLS_VER` in production.** When it is empty, every new task resolves and installs the
  latest release, which means a service restart can silently upgrade the web server.
- Set **`OLS_SHA256`** together with a pinned `OLS_VER` to verify the integrity of the download
  (it is fetched over HTTPS from `openlitespeed.org`, like the official installer does).
- Environment values are visible in `docker inspect`. Keep real credentials in
  [Docker secrets](https://docs.docker.com/engine/swarm/secrets/) (mounted files) and have
  `init.sh` read them, instead of putting passwords in `DB_PASS`.
- The container needs network access on start-up (the OpenLiteSpeed download, and the optional
  `apk add` performed by `OBJ_CACHE`/`USE_DB`).
- The server master process runs as root (it binds port 80 and drops privileges); workers,
  PHP and sessions run as the `litespeed` user.

## Build

```bash
docker build -t litespeed-alpine .
```

The image tag is the Alpine version it is based on (`intellisrc/litespeed-alpine:3.24`).
`update.sh` builds and publishes that tag, and `docker-inspect` opens a shell inside the
image (or a running container) for inspection:

```bash
./docker-inspect              # builds and opens a shell in the image
./docker-inspect cont myweb   # opens a shell in a running container
```
