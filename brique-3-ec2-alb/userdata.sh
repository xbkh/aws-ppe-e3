#!/bin/bash
# Amazon Linux 2023. Serveur de démonstration sans installation de paquets.
set -euo pipefail

install -d -m 0755 /var/www/ppe-e3
printf 'Serveur PPE E3 : %s\n' "$(hostname)" > /var/www/ppe-e3/index.html
printf 'OK\n' > /var/www/ppe-e3/health

cat > /etc/systemd/system/ppe-e3-web.service <<'UNIT'
[Unit]
Description=Serveur de demonstration PPE E3
After=network.target

[Service]
User=nobody
WorkingDirectory=/var/www/ppe-e3
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=on-failure
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable --now ppe-e3-web.service
