# Dockerfile for lighttpd
FROM intellisrc/alpine:edge
EXPOSE 80
VOLUME ["/var/www"]

ENV DB_NAME=
ENV DB_USER=
ENV DB_PASS=
ENV DB_HOST=localhost
ENV DB_CHARSET=utf8
ENV LS_SOFT_LIMIT=512M
ENV LS_HARD_LIMIT=700M
# Object cache options: "redis", "memcached" or "none"
ENV OBJ_CACHE=none
# Adjust properly if needed:
ENV PHP_VER=8

RUN apk add --update --no-cache \
	curl patch litespeed \
	php$PHP_VER-curl php$PHP_VER-gd php$PHP_VER-mysqli php$PHP_VER-mbstring php$PHP_VER-exif php$PHP_VER-ctype \
	php$PHP_VER-fileinfo php$PHP_VER-intl php$PHP_VER-zip php$PHP_VER-iconv php$PHP_VER-dom php$PHP_VER-opcache && \
	rm -rf /var/cache/apk/*

COPY image/httpd_config.patch /etc/litespeed/httpd_config.patch
COPY image/vhost.conf /etc/litespeed/vhosts/default.conf
COPY image/php.ini /etc/php$PHP_VER/php.ini
COPY image/start.sh /usr/local/bin/

WORKDIR /var/www
CMD ["start.sh"]
