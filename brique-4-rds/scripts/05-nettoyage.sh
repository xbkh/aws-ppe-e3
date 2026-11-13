#!/usr/bin/env bash
# À lancer quand les tests sont finis : supprime TOUT ce qui est facturé à l'heure (briques 4 et 5).
# Le VPC, les sous-réseaux, S3 + CloudFront et les rôles IAM restent (gratuits).
. "$(dirname "$0")/lib.sh"; load_b2

quiet() { "$@" >/dev/null 2>&1 || true; }

echo "ALB, écouteur et groupe cible"
if [ -n "${ALB:-}" ]; then quiet aws elbv2 delete-load-balancer --load-balancer-arn "$ALB"; sleep 20; forget ALB; fi
if [ -n "${TG:-}" ]; then quiet aws elbv2 delete-target-group --target-group-arn "$TG"; forget TG; fi

echo "Auto Scaling Group (brique 5)"
if aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ppe-e3-asg --query 'AutoScalingGroups[0].AutoScalingGroupName' --output text 2>/dev/null | grep -q ppe-e3-asg; then
  aws autoscaling delete-auto-scaling-group --auto-scaling-group-name ppe-e3-asg --force-delete
  for i in $(seq 1 30); do
    n=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ppe-e3-asg --query 'length(AutoScalingGroups)' --output text)
    [ "$n" = "0" ] && break; sleep 10
  done
fi

echo "Instances restantes du projet"
IDS=$(aws ec2 describe-instances --filters Name=tag:Projet,Values=ppe-e3 Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text)
if [ -n "$IDS" ]; then aws ec2 terminate-instances --instance-ids $IDS >/dev/null; aws ec2 wait instance-terminated --instance-ids $IDS; fi
forget INST_A; forget INST_B

echo "Base de données RDS (sans sauvegarde finale)"
if aws rds describe-db-instances --db-instance-identifier ppe-e3-db >/dev/null 2>&1; then
  aws rds delete-db-instance --db-instance-identifier ppe-e3-db --skip-final-snapshot --delete-automated-backups >/dev/null
  aws rds wait db-instance-deleted --db-instance-identifier ppe-e3-db
fi
quiet aws rds delete-db-subnet-group --db-subnet-group-name ppe-e3-db-subnets

echo "NAT Gateway et IP élastique"
if [ -n "${NAT:-}" ]; then
  quiet aws ec2 delete-route --route-table-id "$RT_APP" --destination-cidr-block 0.0.0.0/0
  aws ec2 delete-nat-gateway --nat-gateway-id "$NAT" >/dev/null
  aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT" 2>/dev/null || sleep 60
  forget NAT
fi
if [ -n "${EIP:-}" ]; then quiet aws ec2 release-address --allocation-id "$EIP"; forget EIP; fi

echo "Vérification : ce qui coûte encore à l'heure"
echo "  instances actives : $(aws ec2 describe-instances --filters Name=tag:Projet,Values=ppe-e3 Name=instance-state-name,Values=pending,running,stopping,stopped --query 'length(Reservations[].Instances[])' --output text)"
echo "  NAT Gateway       : $(aws ec2 describe-nat-gateways --filter Name=tag:Projet,Values=ppe-e3 Name=state,Values=pending,available,deleting --query 'length(NatGateways)' --output text)"
echo "  adresses IP élastiques : $(aws ec2 describe-addresses --filters Name=tag:Projet,Values=ppe-e3 --query 'length(Addresses)' --output text)"
echo "  load balancers    : $(aws elbv2 describe-load-balancers --query 'length(LoadBalancers[?contains(LoadBalancerName, `ppe-e3`)])' --output text)"
echo "  bases RDS         : $(aws rds describe-db-instances --query 'length(DBInstances)' --output text)"
