#!/bin/bash
echo "Starting..."
case $OBJ_CACHE in
	"memcached" )
		apk add --update --no-cache memcached php$PHP_VER-pecl-memcached
		memcached -d -u litespeed
		rm -rf /var/cache/apk/*
	;;
	"redis" )
		apk add --update --no-cache redis
		redis-server &
		rm -rf /var/cache/apk/*
	;;
esac

install=false

# LiteSpeed setup:
echo "Starting litespeed...."
ls_root="/var/lib/litespeed"
ls_conf="/etc/litespeed/httpd_config.conf"
patch -u "$ls_conf" -i /etc/litespeed/httpd_config.patch
rm /etc/litespeed/httpd_config.patch
sed -i "s/SOFT_LIMIT/$LS_SOFT_LIMIT/g" "$ls_conf"
sed -i "s/HARD_LIMIT/$LS_HARD_LIMIT/g" "$ls_conf"

# Remove Example data
rm -rf "$ls_root/Example"
rm -rf "$ls_root/conf/vhosts/Example"
rm -rf "$ls_root/logs/Example"

init_script=${INIT_SCRIPT:-"/var/www/init.sh"}
if [[ -f "$init_script" ]]; then
    echo "Starting custom script..."
    chmod +rx "$init_script"
    bash "$init_script"
    chmod -rwx "$init_script"
    echo "Custom script executed."
else
    echo "INFO: You can customize this site by adding 'init.sh' script under 'wp-content' directory";
fi

apk del patch
"$ls_root/bin/lswsctrl" start
#while pgrep litespeed > /dev/null; do
tail -f /var/log/litespeed/error.log
#done
