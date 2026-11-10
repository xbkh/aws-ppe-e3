#!/usr/bin/env bash
# Fonctions communes aux scripts de la brique 2.
# Les identifiants créés sont écrits dans ids.env (non versionné) pour que les autres scripts les retrouvent.
set -euo pipefail
export AWS_PAGER=""

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$DIR/ids.env"
touch "$STATE"

# tags <type de ressource> <nom> : étiquettes Name et Projet=ppe-e3
tags() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Projet,Value=ppe-e3}]"; }

# save NOM VALEUR : enregistre un identifiant
save() { sed -i "/^$1=/d" "$STATE"; echo "$1=$2" >> "$STATE"; }

# load : relit les identifiants déjà créés
load() { set +u; . "$STATE"; set -u; }

# forget NOM : oublie un identifiant (ressource supprimée)
forget() { sed -i "/^$1=/d" "$STATE"; }
