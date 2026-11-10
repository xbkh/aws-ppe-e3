#!/bin/bash
# Script de démarrage des instances de test : un petit serveur web sur le port 80.
mkdir -p /srv/www
echo "<h1>ppe-e3 : serveur de test ($(hostname -f))</h1>" > /srv/www/index.html
nohup python3 -m http.server 80 --directory /srv/www > /var/log/test-http.log 2>&1 &
