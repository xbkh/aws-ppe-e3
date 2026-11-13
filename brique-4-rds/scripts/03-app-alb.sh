#!/usr/bin/env bash
# Brique 4 : NAT, modèle de lancement, 2 serveurs d'application privés, ALB.
# FACTURÉ À L'HEURE : NAT, IP élastique, instances, ALB (voir 05-nettoyage.sh).
. "$(dirname "$0")/lib.sh"; load_b2
APP_DIR="$DIR/../app"

echo "Envoi du code de l'application dans le bucket d'artefacts"
tar czf /tmp/app.tgz -C "$APP_DIR" app.py db.py templates requirements.txt
aws s3 cp /tmp/app.tgz "s3://$BUCKET_ART/app.tgz" --region eu-central-2 >/dev/null
rm -f /tmp/app.tgz

echo "NAT Gateway (sortie Internet des sous-réseaux applicatifs : installation des paquets, API AWS)"
EIP=$(aws ec2 allocate-address --domain vpc --tag-specifications "$(tags elastic-ip ppe-e3-eip-nat)" --query AllocationId --output text)
save EIP "$EIP"
NAT=$(aws ec2 create-nat-gateway --subnet-id "$PUB_A" --allocation-id "$EIP" \
  --tag-specifications "$(tags natgateway ppe-e3-nat)" --query NatGateway.NatGatewayId --output text)
save NAT "$NAT"
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT"
aws ec2 create-route --route-table-id "$RT_APP" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT" >/dev/null

echo "Modèle de lancement"
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
sed -e "s|__BUCKET__|$BUCKET_ART|" -e "s|__DB_HOST__|$DB_HOST|" -e "s|__SECRET_ARN__|$SECRET_ARN|" \
  "$DIR/userdata-app.sh.tpl" > /tmp/userdata-app.sh
UD=$(base64 -w0 /tmp/userdata-app.sh); rm -f /tmp/userdata-app.sh
cat > /tmp/lt.json <<EOF
{
  "ImageId": "$AMI",
  "InstanceType": "t3.micro",
  "IamInstanceProfile": { "Name": "ppe-e3-app-profile" },
  "SecurityGroupIds": ["$SG_APP"],
  "MetadataOptions": { "HttpTokens": "required", "HttpEndpoint": "enabled" },
  "UserData": "$UD"
}
EOF
aws ec2 create-launch-template --launch-template-name ppe-e3-lt --launch-template-data file:///tmp/lt.json \
  --tag-specifications "$(tags launch-template ppe-e3-lt)" --query LaunchTemplate.LaunchTemplateId --output text
rm -f /tmp/lt.json

echo "2 serveurs d'application, un par zone, sans IP publique"
launch() { # nom sous-réseau
  aws ec2 run-instances --launch-template LaunchTemplateName=ppe-e3-lt --subnet-id "$2" \
    --tag-specifications "$(tags instance "$1")" --query 'Instances[0].InstanceId' --output text
}
INST_A=$(launch ppe-e3-b4-app-a "$APP_A"); INST_B=$(launch ppe-e3-b4-app-b "$APP_B")
save INST_A "$INST_A"; save INST_B "$INST_B"
aws ec2 wait instance-running --instance-ids "$INST_A" "$INST_B"

echo "Groupe cible et ALB"
TG=$(aws elbv2 create-target-group --name ppe-e3-b4-web --protocol HTTP --port 8080 --vpc-id "$VPC" \
  --health-check-path /health --health-check-interval-seconds 15 --healthy-threshold-count 2 \
  --tags Key=Projet,Value=ppe-e3 --query 'TargetGroups[0].TargetGroupArn' --output text)
save TG "$TG"
aws elbv2 register-targets --target-group-arn "$TG" --targets Id="$INST_A" Id="$INST_B"
ALB=$(aws elbv2 create-load-balancer --name ppe-e3-b4-alb --subnets "$PUB_A" "$PUB_B" --security-groups "$SG_ALB" \
  --scheme internet-facing --type application --tags Key=Projet,Value=ppe-e3 \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
save ALB "$ALB"
aws elbv2 wait load-balancer-available --load-balancer-arns "$ALB"
aws elbv2 create-listener --load-balancer-arn "$ALB" --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TG" >/dev/null
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB" --query 'LoadBalancers[0].DNSName' --output text)
save ALB_DNS "$ALB_DNS"

echo "Attente des cibles saines (installation de l'application : 2 à 4 minutes)"
for i in $(seq 1 40); do
  n=$(aws elbv2 describe-target-health --target-group-arn "$TG" --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)
  [ "$n" = "2" ] && { echo "2 cibles saines"; break; }
  sleep 15
done
echo "ALB : http://$ALB_DNS/"
