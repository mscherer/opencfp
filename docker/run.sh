#!/bin/bash

set -ex

wait_for_db() {
    while ! mysql -h$DB_PORT_3306_TCP_ADDR -uroot -p$DB_ENV_MYSQL_ROOT_PASSWORD -e "show databases" >/dev/null; do 
	echo "Wait for the db";
	sleep 1
    done
    sleep 5
}

db_exists() {
    db=$(mysql -h$DB_PORT_3306_TCP_ADDR -uroot -p$DB_ENV_MYSQL_ROOT_PASSWORD -e "show databases like 'cfp'")
    if [ -z "$db" ]; then
	false
    else
	true
    fi
}

create_db() {
    if ! db_exists; then
	mysql -h$DB_PORT_3306_TCP_ADDR -uroot -p$DB_ENV_MYSQL_ROOT_PASSWORD -e "create database cfp"
    fi
}

setup_environment() {
   cp docker/$CFP_ENV.dist.yml /app/config/$CFP_ENV.yml
   sed -i "s/%CFP_ENV%/$CFP_ENV/" /etc/apache2/sites-enabled/opencfp.conf
   sed -i "s/%CFP_ENV%/$CFP_ENV/" /app/phinx.yml
}

update_configuration_files() {
    sed -i "s%host: 127.0.0.1%host: $DB_PORT_3306_TCP_ADDR%" /app/config/$CFP_ENV.yml
    sed -i "s%dsn:.*%dsn: mysql:dbname=cfp;host=$DB_PORT_3306_TCP_ADDR%" /app/config/$CFP_ENV.yml
    sed -i "s#%datatbase_password%#$DB_ENV_MYSQL_ROOT_PASSWORD#" /app/config/$CFP_ENV.yml

    sed -i "s%host: localhost%host: $DB_PORT_3306_TCP_ADDR%" phinx.yml
    sed -i "s%pass: ''%pass: $DB_ENV_MYSQL_ROOT_PASSWORD%" phinx.yml
}

run_migration() {
    cd /app
    vendor/bin/phinx migrate --environment=$CFP_ENV
}

link_data_dir() {
    if [ ! -f /data/uploads/dummyphoto.jpg ]; then
	install -d -m 0750 -o www-data -g www-data /data/uploads
	cp /app/web/uploads/dummyphoto.jpg /data/uploads
    fi
    chown -R www-data.www-data /data/uploads
    rm -rf /app/web/uploads
    ln -s /data/uploads /app/web/uploads
}

wait_for_db
create_db
setup_environment
update_configuration_files
run_migration
link_data_dir

touch /var/log/php_errors.log
chown www-data:www-data /var/log/php_errors.log

exec /usr/local/bin/apache2-foreground
