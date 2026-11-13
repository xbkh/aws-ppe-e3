#!/usr/bin/env bash
# Fonctions communes de la brique 4. Les identifiants créés vont dans ids.env (non versionné).
set -euo pipefail
export AWS_PAGER=""
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-eu-central-2}"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$DIR/ids.env"
B2_STATE="$DIR/../../brique-2-vpc/scripts/ids.env"
touch "$STATE"

tags() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Projet,Value=ppe-e3}]"; }
save() { sed -i "/^$1=/d" "$STATE"; echo "$1=$2" >> "$STATE"; }
forget() { sed -i "/^$1=/d" "$STATE"; }
load() { set +u; . "$STATE"; set -u; }
# Réseau de la brique 2 (VPC, sous-réseaux, tables de routage)
load_b2() { set +u; . "$B2_STATE"; . "$STATE"; set -u; }
