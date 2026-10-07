# Dockerfile for litespeed
FROM intellisrc/alpine:3.24
EXPOSE 80
VOLUME ["/var/www"]

# OpenLiteSpeed version to install on start-up (e.g.: 1.9.3 or v1.9.3).
# When empty, the latest official release is detected and installed automatically.
ENV OLS_VER=

ENV DB_NAME=
ENV DB_USER=
ENV DB_PASS=
ENV DB_HOST=localhost
ENV DB_CHARSET=utf8
ENV LS_SOFT_LIMIT=512M
ENV LS_HARD_LIMIT=700M
# Object cache options: "redis", "memcached" or "none"
ENV OBJ_CACHE=none
# Install DB if needed. options: "mysql" "mariadb"
ENV USE_DB=none
# Adjust properly if needed:
ENV PHP_VER=83

# Alpine does not package the OpenLiteSpeed server (only the lsphp SAPI),
# so the official binary release is installed on start-up (see start.sh) and
# executed through gcompat (the glibc compatibility layer for musl).
RUN apk add --update --no-cache \
	curl gcompat patch shadow php$PHP_VER-litespeed \
	php$PHP_VER-curl php$PHP_VER-gd php$PHP_VER-mbstring php$PHP_VER-exif php$PHP_VER-ctype \
	php$PHP_VER-fileinfo php$PHP_VER-intl php$PHP_VER-zip php$PHP_VER-iconv php$PHP_VER-dom \
	php$PHP_VER-openssl php$PHP_VER-phar php$PHP_VER-tokenizer php$PHP_VER-xml php$PHP_VER-simplexml \
	php$PHP_VER-xmlreader php$PHP_VER-xmlwriter php$PHP_VER-session php$PHP_VER-opcache && \
	apk upgrade && \
	adduser -D -H -h /var/www/ litespeed && \
	adduser -D -H -s /sbin/nologin -h /usr/local/lsws/admin/ -g "LiteSpeed Web Server Admin" lsadm && \
	mkdir -p /usr/local/lsws/conf/vhosts /usr/local/lsws/fcgi-bin \
		/var/log/litespeed /var/lib/litespeed/sessions /tmp/lshttpd && \
	ln -s /usr/bin/lsphp$PHP_VER /usr/local/lsws/fcgi-bin/lsphp && \
	ln -s /var/log/litespeed /usr/local/lsws/logs && \
	chown -R litespeed:litespeed /var/log/litespeed /var/lib/litespeed && \
	rm -rf /var/cache/apk/*

COPY httpd_config.conf /usr/local/lsws/conf/httpd_config.conf
COPY image/httpd_config.patch /usr/local/lsws/conf/httpd_config.patch
COPY image/vhost.conf /usr/local/lsws/conf/vhosts/default.conf
COPY image/php.ini /etc/php$PHP_VER/php.ini
COPY image/start.sh /usr/local/bin/

# Apply the customizations at build time and keep the traditional config location
RUN patch -u /usr/local/lsws/conf/httpd_config.conf -i /usr/local/lsws/conf/httpd_config.patch && \
	rm /usr/local/lsws/conf/httpd_config.patch && \
	ln -s /usr/local/lsws/conf /etc/litespeed && \
	apk del patch

WORKDIR /var/www
CMD ["start.sh"]
