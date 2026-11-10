#!/usr/bin/env bash
# Crée le VPC, les 6 sous-réseaux sur 2 zones, l'Internet Gateway et les tables de routage.
# Rien ici n'est facturé à l'heure.
. "$(dirname "$0")/lib.sh"

AZ_A=eu-central-2a
AZ_B=eu-central-2b

echo "VPC 10.0.0.0/16"
VPC=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications "$(tags vpc ppe-e3-vpc)" \
  --query Vpc.VpcId --output text)
aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-support '{"Value":true}'
aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-hostnames '{"Value":true}'
save VPC "$VPC"

subnet() { # nom cidr zone
  aws ec2 create-subnet --vpc-id "$VPC" --cidr-block "$2" --availability-zone "$3" \
    --tag-specifications "$(tags subnet "$1")" --query Subnet.SubnetId --output text
}

echo "Sous-réseaux (public, app, données) x 2 zones"
PUB_A=$(subnet ppe-e3-public-a  10.0.0.0/24  $AZ_A); save PUB_A  "$PUB_A"
PUB_B=$(subnet ppe-e3-public-b  10.0.1.0/24  $AZ_B); save PUB_B  "$PUB_B"
APP_A=$(subnet ppe-e3-app-a     10.0.10.0/24 $AZ_A); save APP_A  "$APP_A"
APP_B=$(subnet ppe-e3-app-b     10.0.11.0/24 $AZ_B); save APP_B  "$APP_B"
DATA_A=$(subnet ppe-e3-data-a   10.0.20.0/24 $AZ_A); save DATA_A "$DATA_A"
DATA_B=$(subnet ppe-e3-data-b   10.0.21.0/24 $AZ_B); save DATA_B "$DATA_B"

# Seuls les sous-réseaux publics attribuent une adresse IPv4 publique au lancement
aws ec2 modify-subnet-attribute --subnet-id "$PUB_A" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$PUB_B" --map-public-ip-on-launch

echo "Internet Gateway"
IGW=$(aws ec2 create-internet-gateway --tag-specifications "$(tags internet-gateway ppe-e3-igw)" \
  --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC"
save IGW "$IGW"

rtable() { # nom
  aws ec2 create-route-table --vpc-id "$VPC" --tag-specifications "$(tags route-table "$1")" \
    --query RouteTable.RouteTableId --output text
}

echo "Tables de routage"
# Publique : sortie directe vers Internet par l'Internet Gateway
RT_PUBLIC=$(rtable ppe-e3-rt-public); save RT_PUBLIC "$RT_PUBLIC"
aws ec2 create-route --route-table-id "$RT_PUBLIC" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW" >/dev/null
aws ec2 associate-route-table --route-table-id "$RT_PUBLIC" --subnet-id "$PUB_A" >/dev/null
aws ec2 associate-route-table --route-table-id "$RT_PUBLIC" --subnet-id "$PUB_B" >/dev/null

# Applicative : aucune route Internet pour l'instant (le NAT est ajouté par 03-instances-nat.sh)
RT_APP=$(rtable ppe-e3-rt-app); save RT_APP "$RT_APP"
aws ec2 associate-route-table --route-table-id "$RT_APP" --subnet-id "$APP_A" >/dev/null
aws ec2 associate-route-table --route-table-id "$RT_APP" --subnet-id "$APP_B" >/dev/null

# Données : jamais de route vers Internet
RT_DATA=$(rtable ppe-e3-rt-data); save RT_DATA "$RT_DATA"
aws ec2 associate-route-table --route-table-id "$RT_DATA" --subnet-id "$DATA_A" >/dev/null
aws ec2 associate-route-table --route-table-id "$RT_DATA" --subnet-id "$DATA_B" >/dev/null

echo "Réseau créé : $VPC"
