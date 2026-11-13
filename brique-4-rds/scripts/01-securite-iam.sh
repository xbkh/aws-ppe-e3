#!/usr/bin/env bash
# Brique 4 : groupes de sécurité des 3 tiers, bucket d'artefacts, rôle IAM de l'application. Gratuit.
# Réutilise le VPC de la brique 2 (identifiants lus dans brique-2-vpc/scripts/ids.env).
. "$(dirname "$0")/lib.sh"; load_b2

MON_IP="$(curl -s --max-time 8 https://checkip.amazonaws.com)/32"

echo "Groupes de sécurité : ALB -> application -> base de données"
SG_ALB=$(aws ec2 create-security-group --group-name ppe-e3-b4-alb --vpc-id "$VPC" \
  --description "ppe-e3 ALB : HTTP depuis le poste de test" \
  --tag-specifications "$(tags security-group ppe-e3-b4-alb)" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ALB" --protocol tcp --port 80 --cidr "$MON_IP" >/dev/null

SG_APP=$(aws ec2 create-security-group --group-name ppe-e3-b4-app --vpc-id "$VPC" \
  --description "ppe-e3 application : 8080 depuis ALB uniquement" \
  --tag-specifications "$(tags security-group ppe-e3-b4-app)" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_APP" --protocol tcp --port 8080 --source-group "$SG_ALB" >/dev/null

SG_DB=$(aws ec2 create-security-group --group-name ppe-e3-b4-db --vpc-id "$VPC" \
  --description "ppe-e3 base de donnees : 5432 depuis application uniquement" \
  --tag-specifications "$(tags security-group ppe-e3-b4-db)" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_DB" --protocol tcp --port 5432 --source-group "$SG_APP" >/dev/null
save SG_ALB "$SG_ALB"; save SG_APP "$SG_APP"; save SG_DB "$SG_DB"

echo "Bucket d'artefacts privé (code de l'application)"
BUCKET_ART="ppe-e3-artefacts-$(openssl rand -hex 4)"
aws s3api create-bucket --bucket "$BUCKET_ART" --region eu-central-2 \
  --create-bucket-configuration LocationConstraint=eu-central-2 >/dev/null
aws s3api put-public-access-block --bucket "$BUCKET_ART" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-tagging --bucket "$BUCKET_ART" --tagging 'TagSet=[{Key=Projet,Value=ppe-e3}]'
save BUCKET_ART "$BUCKET_ART"

echo "Rôle IAM de l'application (moindre privilège, politique créée à l'étape RDS)"
aws iam create-role --role-name ppe-e3-app-role --tags Key=Projet,Value=ppe-e3 \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  --query Role.RoleName --output text
aws iam attach-role-policy --role-name ppe-e3-app-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam create-instance-profile --instance-profile-name ppe-e3-app-profile --tags Key=Projet,Value=ppe-e3 >/dev/null
aws iam add-role-to-instance-profile --instance-profile-name ppe-e3-app-profile --role-name ppe-e3-app-role
echo "terminé"
