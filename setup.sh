#!/bin/bash

###############################################################################
#            __     ______  ____    ____  _____ _____ _   _ ____              #
#            \ \   / /  _ \/ ___|  / ___|| ____|_   _| | | |  _ \             #
#             \ \ / /| | | \___ \  \___ \|  _|   | | | | | | |_) |            #
#              \ V / | |_| |___) |  ___) | |___  | | | |_| |  __/             #
#               \_/  |____/|____/  |____/|_____| |_|  \___/|_|                #
###############################################################################

CONF_DIR="/etc/${PWD##*/}"
mkdir -p $CONF_DIR

set_conf() {
        var=$1
        filename=$2
        file="$CONF_DIR/$filename"
        while [ ! -s "$file" ]; do
                read -p "Type $var: " answer
                if [[ -n "$answer" ]]; then
                        echo "$answer" > "$file"
                        echo "${var^} saved to file '$file'"

                else
                        echo "No $var provided!"
                fi
        done
}

set_conf "webhost" "webhost.txt"
set_conf "email" "email.txt"
set_conf "secret" "secret.txt"

webhost=$(cat "$CONF_DIR/webhost.txt")
email=$(cat "$CONF_DIR/email.txt")
secret=$(cat "$CONF_DIR/secret.txt")

###############################################################################
#      ____  _____ ____  ____    ___ _   _ ____ _____  _    _     _           #
#     |  _ \| ____|  _ \/ ___|  |_ _| \ | / ___|_   _|/ \  | |   | |          #
#     | | | |  _| | |_) \___ \   | ||  \| \___ \ | | / _ \ | |   | |          #
#     | |_| | |___|  __/ ___) |  | || |\  |___) || |/ ___ \| |___| |___       #
#     |____/|_____|_|   |____/  |___|_| \_|____/ |_/_/   \_\_____|_____|      #
###############################################################################

export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y
apt purge lua5.1 lua5.2 -y
apt install lua5.3 lua-event prosody prosody-modules lua-dbi-postgresql -y
apt install nginx certbot python3-certbot-nginx -y
apt install cron coturn postgresql -y
apt autoremove -y && apt clean -y

###############################################################################
#           _   _ _______        __  ____  _____ _____ _   _ ____             #
#          | | | |  ___\ \      / / / ___|| ____|_   _| | | |  _ \            #
#          | | | | |_   \ \ /\ / /  \___ \|  _|   | | | | | | |_) |           #
#          | |_| |  _|   \ V  V /    ___) | |___  | | | |_| |  __/            #
#           \___/|_|      \_/\_/    |____/|_____| |_|  \___/|_|               #
###############################################################################

ufw allow Turnserver
ufw allow 5222,5269/tcp
ufw allow 5432/tcp

###############################################################################
#    ____  _____ ______     _______ ____    ____  _____ _____ _   _ ____      #
#   / ___|| ____|  _ \ \   / / ____|  _ \  / ___|| ____|_   _| | | |  _ \     #
#   \___ \|  _| | |_) \ \ / /|  _| | |_) | \___ \|  _|   | | | | | | |_) |    #
#    ___) | |___|  _ < \ V / | |___|  _ <   ___) | |___  | | | |_| |  __/     #
#   |____/|_____|_| \_\ \_/  |_____|_| \_\ |____/|_____| |_|  \___/|_|        #
###############################################################################

subhost="conference.$webhost"
filehost="upload.$webhost"

set_prosody_server() {
	# set config
	cp conf/prosody.cfg.lua.default prosody.cfg.lua
	sed -i "s/myserver\.tld/$webhost/g" prosody.cfg.lua 
	sed -i "s/mysecret/$secret/g" prosody.cfg.lua 
	mv prosody.cfg.lua /etc/prosody
	# get certificates
	certbot -d "$webhost" certonly --nginx -n --agree-tos --email "$email"
	certbot -d "$subhost" certonly --nginx -n --agree-tos --email "$email"
	certbot -d "$filehost" certonly --nginx -n --agree-tos --email "$email"
	prosodyctl --root cert import /etc/letsencrypt/live
	# set service
	systemctl enable prosody
	systemctl restart prosody
}

set_filer_server() {
	# add new user
	subusername="prosody-filer"
	adduser --disabled-login --disabled-password "$subusername"
	# set binary and its config
	cp bin/prosody-filer "/home/$subusername"
	cp conf/config.toml.default config.toml
	sed -i "s/mysecret/$secret/g" config.toml
	mv config.toml "/home/$subusername"
	# set NGINX
	cp conf/prosody-filer.conf.default prosody-filer.conf
	sed -i "s/myserver\.tld/$webhost/g" prosody-filer.conf
	mv prosody-filer.conf "/etc/nginx/sites-available/$filehost"
	ln -s "/etc/nginx/sites-available/$filehost" /etc/nginx/sites-enabled
	rm -f /etc/nginx/sites-enabled/default
	# set service
	cp prosody-filer.service /etc/systemd/system
	systemctl daemon-reload
	systemctl enable prosody-filer
	systemctl restart prosody-filer
}

set_turn_server() {
	# get settings
	turn_conf="/etc/turnserver.conf"
	cat "$turn_conf" > turn.conf
	# set new settings
	turn_settings=(
		"realm=turn.$webhost"
		"use-auth-secret"
		"static-auth-secret=$secret"
	)
	# append new settings if needed
	for turn_setting in "${turn_settings[@]}"; do
		if ! grep -F -q "$turn_setting" turn.conf; then
		    echo "$turn_setting" >> "$turn_conf"
		fi
	done
	# delete old settings
	rm turn.conf
	# set service
	cp /root/xmpp-setup/conf/coturn.service /etc/systemd/system
	systemctl daemon-reload
	systemctl enable coturn nginx
	systemctl restart coturn nginx
}

set_prosody() {
	set_prosody_server
	set_filer_server
	set_turn_server
	mkdir /etc/prosody/conf.d
}

set_prosody

###############################################################################
#           ____  ____   ___  _       ____  _____ _____ _   _ ____            #
#          |  _ \/ ___| / _ \| |     / ___|| ____|_   _| | | |  _ \           #
#          | |_) \___ \| | | | |     \___ \|  _|   | | | | | | |_) |          #
#          |  __/ ___) | |_| | |___   ___) | |___  | | | |_| |  __/           #
#          |_|   |____/ \__\_\_____| |____/|_____| |_|  \___/|_|              #
###############################################################################

user="prosody"
db="prosody"
if ! su -c "psql -t -c '\du' | cut -d \| -f 1 | grep -qw $user" postgres; then
	su -c "psql -c \"CREATE USER $user WITH PASSWORD '$secret';\"" postgres
	su -c "psql -c \"CREATE DATABASE $db OWNER $user;\"" postgres
	su -
fi
systemctl restart prosody postgresql nginx

###############################################################################
#            ____ ____   ___  _   _   ____  _____ _____ _   _ ____            #
#           / ___|  _ \ / _ \| \ | | / ___|| ____|_   _| | | |  _ \           #
#          | |   | |_) | | | |  \| | \___ \|  _|   | | | | | | |_) |          #
#          | |___|  _ <| |_| | |\  |  ___) | |___  | | | |_| |  __/           #
#           \____|_| \_\\___/|_| \_| |____/|_____| |_|  \___/|_|              #
###############################################################################

cp /root/kalendaro/conf/crontab /etc/cron.d/kalendaro
systemctl restart cron
