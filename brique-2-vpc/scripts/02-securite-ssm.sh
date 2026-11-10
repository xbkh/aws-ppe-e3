#!/usr/bin/env bash
# Crée le rôle SSM (accès aux serveurs sans SSH) et les groupes de sécurité. Rien de facturé à l'heure.
. "$(dirname "$0")/lib.sh"; load

ROLE=ppe-e3-ssm-role
PROFILE=ppe-e3-ssm-profile

echo "Rôle et profil d'instance pour Session Manager"
aws iam create-role --role-name "$ROLE" --tags Key=Projet,Value=ppe-e3 \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  --query Role.RoleName --output text
aws iam attach-role-policy --role-name "$ROLE" --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam create-instance-profile --instance-profile-name "$PROFILE" --tags Key=Projet,Value=ppe-e3 \
  --query InstanceProfile.InstanceProfileName --output text
aws iam add-role-to-instance-profile --instance-profile-name "$PROFILE" --role-name "$ROLE"

echo "Groupes de sécurité (descriptions en ASCII, exigé par AWS)"
SG_PUBLIC=$(aws ec2 create-security-group --group-name ppe-e3-sg-public --vpc-id "$VPC" \
  --description "ppe-e3 serveur de test public : HTTP depuis Internet" \
  --tag-specifications "$(tags security-group ppe-e3-sg-public)" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_PUBLIC" --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null
save SG_PUBLIC "$SG_PUBLIC"

SG_PRIVE=$(aws ec2 create-security-group --group-name ppe-e3-sg-prive --vpc-id "$VPC" \
  --description "ppe-e3 serveur de test prive : HTTP depuis le groupe public uniquement" \
  --tag-specifications "$(tags security-group ppe-e3-sg-prive)" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_PRIVE" --protocol tcp --port 80 --source-group "$SG_PUBLIC" >/dev/null
save SG_PRIVE "$SG_PRIVE"

echo "Sécurité créée (aucune règle SSH : accès par Session Manager)"
