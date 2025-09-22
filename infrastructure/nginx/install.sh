#!/bin/bash

apt install nginx -y

export $(grep -v '^#' .env | xargs)
cp infrastructure/nginx/nginx.conf > /etc/nginx/nginx.conf

systemctl restart nginx
apt install snapd


snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
#certbot --nginx