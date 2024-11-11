#!/bin/bash
echo "Starting..."
case $OBJ_CACHE in
	"memcached" )
		apk add --update --no-cache memcached php$PHP_VER-pecl-memcached
		memcached -d -u litespeed
	;;
	"redis" )
		apk add --update --no-cache redis
		redis-server &
	;;
esac
case $USE_DB in
	"mysql" | "mariadb" )
		apk add --update --no-cache php$PHP_VER-mysqli 
	;;
esac
rm -rf /var/cache/apk/*

install=false

# LiteSpeed setup:
adduser -D -H -h /var/www/ litespeed
echo "Starting litespeed...."
ls_root="/var/lib/litespeed"
ls_conf="/etc/litespeed/httpd_config.conf"
patch -u "$ls_conf" -i /etc/litespeed/httpd_config.patch
rm /etc/litespeed/httpd_config.patch
sed -i "s/SOFT_LIMIT/$LS_SOFT_LIMIT/g" "$ls_conf"
sed -i "s/HARD_LIMIT/$LS_HARD_LIMIT/g" "$ls_conf"
mkdir -p "$ls_root/sessions/"
chown litespeed:litespeed "$ls_root/sessions/"

# PHP setup:
php_ini="/etc/php${PHP_VER}/php.ini"
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = $PHP_MAX_UPLOAD/" "$php_ini"
sed -i "s/post_max_size = 8M/post_max_size = $PHP_MAX_UPLOAD/" "$php_ini"
case $USE_DB in
	"mysql" | "mariadb" )
		sed -i "s/;extension=mysqli/extension=mysqli/" "$php_ini"
	;;
esac

# Remove Example data
rm -rf "$ls_root/Example"
rm -rf "$ls_root/conf/vhosts/Example"
rm -rf "$ls_root/logs/Example"

init_script=${INIT_SCRIPT:-"/home/init.sh"}
if [[ ! -f $init_script ]]; then
	init_script="/var/www/init.sh";
fi
if [[ -f "$init_script" ]]; then
    echo "Starting custom script..."
    chmod +rx "$init_script"
    bash "$init_script"
    chmod -rwx "$init_script"
    echo "Custom script executed."
else
    echo "INFO: You can customize this site by adding 'init.sh' script under 'home' or 'www' directory";
fi

apk del patch
mkdir -p /var/log/litespeed/
chown litespeed:litespeed /var/log/litespeed/
#/usr/bin/lsphp$PHP_VER -c "$php_ini"
