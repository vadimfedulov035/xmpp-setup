# XMPP setup
## Script to set up XMPP server via Prosody

![cover](https://github.com/vadimfedulov035/xmpp-setup/raw/main/logo.jpg)

## Set up server
```bash
./setup.sh
```

You will need to mention:
1) Webhost
2) Email (for certificate)
3) Secret (for configs)

The script is intended to be executed by root in /root/xmpp-setup

## Set up crontab
```bash
apt update
apt install cron -y
crontab -e
"0 0 5 * * prosodyctl --root cert import /etc/letsencrypt/live/"
"@daily find /home/prosody-filer/upload/ -mindepth 1 -type d -mtime +28 -print0 | xargs -0 -- rm -rf"
```
