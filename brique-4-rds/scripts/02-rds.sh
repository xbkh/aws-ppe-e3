#!/usr/bin/env bash
# Brique 4 : base PostgreSQL RDS privée et chiffrée, mot de passe géré par Secrets Manager.
# FACTURÉ À L'HEURE tant que la base existe (voir 05-nettoyage.sh).
. "$(dirname "$0")/lib.sh"; load_b2

echo "Groupe de sous-réseaux de la base (sous-réseaux données A et B)"
aws rds create-db-subnet-group --db-subnet-group-name ppe-e3-db-subnets \
  --db-subnet-group-description "ppe-e3 sous-reseaux donnees" \
  --subnet-ids "$DATA_A" "$DATA_B" --tags Key=Projet,Value=ppe-e3 >/dev/null

echo "Instance RDS PostgreSQL 16 (privée, chiffrée, mot de passe dans Secrets Manager)"
aws rds create-db-instance \
  --db-instance-identifier ppe-e3-db \
  --engine postgres --engine-version 16.15 \
  --db-instance-class db.t3.micro \
  --allocated-storage 20 --storage-type gp3 --storage-encrypted \
  --db-name inscriptions \
  --master-username ppe_admin --manage-master-user-password \
  --db-subnet-group-name ppe-e3-db-subnets \
  --vpc-security-group-ids "$SG_DB" \
  --no-publicly-accessible --no-multi-az \
  --availability-zone eu-central-2a \
  --backup-retention-period 1 --no-deletion-protection \
  --tags Key=Projet,Value=ppe-e3 --query 'DBInstance.DBInstanceStatus' --output text

echo "Attente de la disponibilité (plusieurs minutes)"
aws rds wait db-instance-available --db-instance-identifier ppe-e3-db

DB_HOST=$(aws rds describe-db-instances --db-instance-identifier ppe-e3-db --query 'DBInstances[0].Endpoint.Address' --output text)
SECRET_ARN=$(aws rds describe-db-instances --db-instance-identifier ppe-e3-db --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)
save DB_HOST "$DB_HOST"; save SECRET_ARN "$SECRET_ARN"

echo "Politique IAM de l'application : lire CE secret et CE bucket, rien d'autre"
cat > /tmp/ppe-e3-app-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "LireLeSecretDeLaBase", "Effect": "Allow", "Action": "secretsmanager:GetSecretValue", "Resource": "$SECRET_ARN" },
    { "Sid": "LireLeCodeDeLApplication", "Effect": "Allow", "Action": "s3:GetObject", "Resource": "arn:aws:s3:::$BUCKET_ART/*" }
  ]
}
EOF
# Idempotent : la CLI peut rejouer l'appel après un délai réseau et recevoir « existe déjà »
aws iam create-policy --policy-name ppe-e3-app-policy --policy-document file:///tmp/ppe-e3-app-policy.json \
  --tags Key=Projet,Value=ppe-e3 >/dev/null 2>&1 || true
POLICY_ARN=$(aws iam list-policies --scope Local --query 'Policies[?PolicyName==`ppe-e3-app-policy`].Arn' --output text)
aws iam attach-role-policy --role-name ppe-e3-app-role --policy-arn "$POLICY_ARN"
save POLICY_ARN "$POLICY_ARN"
rm -f /tmp/ppe-e3-app-policy.json
echo "RDS prête : $DB_HOST"
