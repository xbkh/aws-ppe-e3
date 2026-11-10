#!/usr/bin/env bash
# Affiche un résumé des ressources réseau (utile pour les captures). Aucun identifiant de compte affiché.
. "$(dirname "$0")/lib.sh"; load

echo "VPC"
aws ec2 describe-vpcs --vpc-ids "$VPC" --query 'Vpcs[0].[Tags[?Key==`Name`]|[0].Value,CidrBlock,State]' --output text | tr '\t' '  '

echo; echo "Sous-réseaux (nom, bloc CIDR, zone, IP publique auto)"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'sort_by(Subnets,&Tags[?Key==`Name`]|[0].Value)[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' --output text

echo; echo "Règles entrantes des groupes de sécurité"
for sg in SG_PUBLIC SG_PRIVE; do
  aws ec2 describe-security-group-rules --filters "Name=group-id,Values=${!sg}" \
    --query 'SecurityGroupRules[?IsEgress==`false`].[GroupId,IpProtocol,FromPort,CidrIpv4||ReferencedGroupInfo.GroupId]' --output text \
    | sed "s/^${!sg}/$sg/"
done

echo; echo "Instances de test"
aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,InstanceType,Placement.AvailabilityZone,PrivateIpAddress,PublicIpAddress]' --output text
