#!/usr/bin/env bash
# Brique 5 : RDS Multi-AZ, Auto Scaling Group sur 2 zones (remplace les 2 serveurs fixes de la brique 4).
# FACTURÉ À L'HEURE : le Multi-AZ double le coût de la base.
. "$(dirname "$0")/../../brique-4-rds/scripts/lib.sh"; load_b2

echo "RDS : passage en Multi-AZ (réplique synchrone dans l'autre zone)"
aws rds modify-db-instance --db-instance-identifier ppe-e3-db --multi-az --apply-immediately \
  --query 'DBInstance.DBInstanceStatus' --output text
for i in $(seq 1 90); do
  etat=$(aws rds describe-db-instances --db-instance-identifier ppe-e3-db --query 'DBInstances[0].[DBInstanceStatus,MultiAZ,length(PendingModifiedValues)]' --output text | tr '\t' ' ')
  [ "$etat" = "available True 0" ] && { echo "RDS Multi-AZ prête"; break; }
  sleep 20
done

echo "Auto Scaling Group : 2 à 4 serveurs sur 2 zones, contrôle de santé de l'ALB"
aws autoscaling create-auto-scaling-group --auto-scaling-group-name ppe-e3-asg \
  --launch-template LaunchTemplateName=ppe-e3-lt,Version='$Latest' \
  --min-size 2 --max-size 4 --desired-capacity 2 \
  --vpc-zone-identifier "$APP_A,$APP_B" --target-group-arns "$TG" \
  --health-check-type ELB --health-check-grace-period 300 \
  --tags "ResourceId=ppe-e3-asg,ResourceType=auto-scaling-group,Key=Name,Value=ppe-e3-asg-web,PropagateAtLaunch=true" \
         "ResourceId=ppe-e3-asg,ResourceType=auto-scaling-group,Key=Projet,Value=ppe-e3,PropagateAtLaunch=true"
# Au premier usage, AWS crée le rôle de service d'Auto Scaling : il peut mettre quelques minutes à être prêt
for i in $(seq 1 20); do
  aws autoscaling put-scaling-policy --auto-scaling-group-name ppe-e3-asg --policy-name ppe-e3-cpu-60 \
    --policy-type TargetTrackingScaling \
    --target-tracking-configuration '{"PredefinedMetricSpecification":{"PredefinedMetricType":"ASGAverageCPUUtilization"},"TargetValue":60.0}' >/dev/null 2>&1 && break
  sleep 15
done

echo "Attente de 4 cibles saines (2 fixes + 2 de l'ASG)"
for i in $(seq 1 40); do
  n=$(aws elbv2 describe-target-health --target-group-arn "$TG" --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)
  [ "$n" -ge 4 ] && break; sleep 15
done

echo "Retrait des 2 serveurs fixes de la brique 4"
aws elbv2 deregister-targets --target-group-arn "$TG" --targets Id="$INST_A" Id="$INST_B"
aws ec2 terminate-instances --instance-ids "$INST_A" "$INST_B" >/dev/null
forget INST_A; forget INST_B
sleep 60
echo "cibles saines : $(aws elbv2 describe-target-health --target-group-arn "$TG" --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)"
