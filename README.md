# docker-wp-litespeed-alpine
Wordpress running with LiteSpeed and PHP 8 inside a Docker container running Alpine

## Docker

intellisrc/wp-litespeed-alpine:edge

Environment:

```
LS_SOFT_LIMIT=512M
LS_HARD_LIMIT=700M
PHP_MAX_WORKERS=20
WP_VER=latest
WP_PREFIX=wp_
DB_NAME=
DB_USER=
DB_PASSWORD=
DB_PASS=
DB_HOST=localhost
DB_CHARSET=utf8
OBJ_CACHE=none  #options: memcached, redis
```

It will download the latest (or the version specified in "WP_VER")

## Docker Swarm

Example:

```yaml
services:
  wp:
    image: intellisrc/wp-litespeed-alpine:edge
    volumes:
      - type: bind
        source: "/docker/sites/example/"
        target: "/var/www/wp-content/"
    networks:
      - proxy_net
      - database_net
    environment:
      DB_HOST: database_host
      DB_USER: example_user
      DB_NAME: wp_example
      DB_PASS: *****************
      WP_PREFIX: ex_
      HTTPS_DOMAIN: example.com
      LS_SOFT_LIMIT: 512M
      LS_HARD_LIMIT: 700M
      OBJ_CACHE: memcached
      #WP_LANG: ja
    healthcheck:
      test: wget -q -O - http://localhost/health_check.php | grep "ok"
      interval: 60s
      retries: 2
      timeout: 30s
    deploy:
      mode: replicated
      replicas: 1
      endpoint_mode: dnsrr
      placement:
        constraints: 
          - node.labels.wordpress == true
```
