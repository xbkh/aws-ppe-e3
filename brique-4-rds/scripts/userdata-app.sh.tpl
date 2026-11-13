#!/bin/bash
# Démarrage d'un serveur d'application (Amazon Linux 2023). Les valeurs __X__ sont remplacées par 03-app-alb.sh.
# Aucun mot de passe ici : l'application lit le secret de la base dans Secrets Manager avec le rôle de l'instance.
set -euo pipefail
exec > >(tee /var/log/ppe-e3-userdata.log) 2>&1

dnf install -y python3-pip
useradd --system --home-dir /opt/ppe-e3 --shell /sbin/nologin appli || true
install -d -o appli -g appli /opt/ppe-e3
cd /opt/ppe-e3

aws s3 cp s3://__BUCKET__/app.tgz /tmp/app.tgz --region eu-central-2
tar xzf /tmp/app.tgz -C /opt/ppe-e3
python3 -m venv venv
venv/bin/pip install --no-cache-dir -r requirements.txt
chown -R appli:appli /opt/ppe-e3

cat > /etc/ppe-e3.env <<ENV
DB_HOST=__DB_HOST__
DB_NAME=inscriptions
DB_SECRET_ARN=__SECRET_ARN__
DB_SSLMODE=require
AWS_REGION=eu-central-2
PORT=8080
ENV
chmod 0640 /etc/ppe-e3.env

cat > /etc/systemd/system/ppe-e3-app.service <<'UNIT'
[Unit]
Description=Application d'inscription PPE E3
After=network-online.target

[Service]
User=appli
WorkingDirectory=/opt/ppe-e3
EnvironmentFile=/etc/ppe-e3.env
ExecStart=/opt/ppe-e3/venv/bin/gunicorn --bind 0.0.0.0:8080 --workers 2 app:app
Restart=always
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
UNIT
chgrp appli /etc/ppe-e3.env
systemctl daemon-reload
systemctl enable --now ppe-e3-app.service
