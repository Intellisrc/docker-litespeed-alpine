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
		apk add --update --no-cache php$PHP_VER-mysqli php$PHP_VER-pdo php$PHP_VER-pdo_mysql
	;;
esac
rm -rf /var/cache/apk/*

install=false

# Validate the values used to tune the configuration (used by sed below)
for val in "$LS_SOFT_LIMIT" "$LS_HARD_LIMIT" "$PHP_MAX_UPLOAD"; do
	if [[ -n $val ]] && [[ ! $val =~ ^[0-9]+[KkMmGg]?$ ]]; then
		echo "ERROR: Invalid size value: '$val'"
		exit 1
	fi
done

# OpenLiteSpeed install (select the version with: OLS_VER):
ls_root="/usr/local/lsws"
ls_ver="${OLS_VER#v}"
if [[ -z $ls_ver ]]; then
	echo "OLS_VER not set, detecting the latest OpenLiteSpeed release..."
	ls_ver=$(curl -sIL -o /dev/null -w '%{url_effective}' \
		https://github.com/litespeedtech/openlitespeed/releases/latest | sed 's:.*/::')
	ls_ver="${ls_ver#v}"
fi
if [[ -z $ls_ver ]]; then
	echo "WARNING: Unable to detect the latest version, using the installed one"
	ls_ver=$(cat "$ls_root/VERSION" 2>/dev/null)
fi
if [[ -z $ls_ver ]]; then
	echo "ERROR: Unable to detect the OpenLiteSpeed version to install"
	exit 1
fi
if [[ ! $ls_ver =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
	echo "ERROR: Invalid OLS_VER: '$OLS_VER'"
	exit 1
fi
if [[ $(cat "$ls_root/.ols_installed" 2>/dev/null) != "$ls_ver" ]]; then
	arch=$(uname -m)
	ols_url="https://openlitespeed.org/packages/openlitespeed-$ls_ver-$arch-linux.tgz"
	echo "Downloading OpenLiteSpeed $ls_ver ($arch)..."
	total=$(curl -fsSLI "$ols_url" 2>/dev/null | awk 'tolower($1)=="content-length:" {t=$2} END {gsub("\r","",t); print t}')
	curl -fsSL -o /tmp/ols.tgz "$ols_url" &
	curl_pid=$!
	# Progress indicator (newline based, so it shows properly on container logs)
	while kill -0 $curl_pid 2>/dev/null; do
		size=$(stat -c %s /tmp/ols.tgz 2>/dev/null || echo 0)
		if [[ $total =~ ^[0-9]+$ ]] && [[ $total -gt 0 ]]; then
			echo "  $((size * 100 / total))% ($((size / 1048576))M / $((total / 1048576))M)"
		else
			echo "  $((size / 1048576))M downloaded..."
		fi
		sleep 5
	done
	if ! wait $curl_pid; then
		echo "ERROR: Unable to download: $ols_url"
		rm -f /tmp/ols.tgz
		exit 1
	fi
	if [[ -n $OLS_SHA256 ]]; then
		echo "Verifying checksum..."
		if ! echo "$OLS_SHA256  /tmp/ols.tgz" | sha256sum -c - >/dev/null 2>&1; then
			echo "ERROR: Checksum verification failed (expected: $OLS_SHA256)"
			rm -f /tmp/ols.tgz
			exit 1
		fi
	fi
	echo "Download complete ($(( $(stat -c %s /tmp/ols.tgz) / 1048576 ))M), extracting..."
	if ! tar -xzf /tmp/ols.tgz -C "$ls_root" --strip-components=1; then
		echo "ERROR: Unable to extract the OpenLiteSpeed package"
		rm -f /tmp/ols.tgz
		exit 1
	fi
	rm -f /tmp/ols.tgz
	# Marker written only on success, so a partial install is retried on next start
	echo "$ls_ver" > "$ls_root/.ols_installed"
fi

# LiteSpeed setup:
ls_conf="/etc/litespeed/httpd_config.conf"
ls_data="/var/lib/litespeed"
sed -i "s/SOFT_LIMIT/$LS_SOFT_LIMIT/g" "$ls_conf"
sed -i "s/HARD_LIMIT/$LS_HARD_LIMIT/g" "$ls_conf"
mkdir -p "$ls_data/sessions/"
chown litespeed:litespeed "$ls_data/sessions/"

# PHP setup:
php_ini="/etc/php${PHP_VER}/php.ini"
if [[ -n $PHP_MAX_UPLOAD ]]; then
	sed -i "s/upload_max_filesize = 2M/upload_max_filesize = $PHP_MAX_UPLOAD/" "$php_ini"
	sed -i "s/post_max_size = 8M/post_max_size = $PHP_MAX_UPLOAD/" "$php_ini"
fi

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

mkdir -p /var/log/litespeed/
chown litespeed:litespeed /var/log/litespeed/
echo "Starting litespeed ($ls_ver)...."
exec "$ls_root/bin/openlitespeed" -d
