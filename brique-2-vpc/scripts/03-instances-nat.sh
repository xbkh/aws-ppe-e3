#!/usr/bin/env bash
# FACTURÉ À L'HEURE : NAT Gateway, adresse IP publique, 2 instances t3.micro.
# À supprimer le soir avec 05-nettoyage-quotidien.sh.
. "$(dirname "$0")/lib.sh"; load

AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)

echo "Adresse IP élastique et NAT Gateway (dans le sous-réseau public A)"
EIP=$(aws ec2 allocate-address --domain vpc --tag-specifications "$(tags elastic-ip ppe-e3-eip-nat)" \
  --query AllocationId --output text)
save EIP "$EIP"
NAT=$(aws ec2 create-nat-gateway --subnet-id "$PUB_A" --allocation-id "$EIP" \
  --tag-specifications "$(tags natgateway ppe-e3-nat)" --query NatGateway.NatGatewayId --output text)
save NAT "$NAT"
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT"

echo "Route des sous-réseaux applicatifs vers le NAT"
aws ec2 create-route --route-table-id "$RT_APP" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT" >/dev/null

launch() { # nom sous-réseau groupe-de-sécurité option-ip-publique
  aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro --subnet-id "$2" \
    --security-group-ids "$3" "$4" --iam-instance-profile Name=ppe-e3-ssm-profile \
    --metadata-options HttpTokens=required --user-data "file://$DIR/userdata.sh" \
    --tag-specifications "$(tags instance "$1")" "$(tags volume "$1")" \
    --query 'Instances[0].InstanceId' --output text
}

echo "Instance publique (sous-réseau public A) et privée (sous-réseau app A)"
INST_PUBLIC=$(launch ppe-e3-test-public "$PUB_A" "$SG_PUBLIC" --associate-public-ip-address)
INST_PRIVE=$(launch ppe-e3-test-prive "$APP_A" "$SG_PRIVE" --no-associate-public-ip-address)
save INST_PUBLIC "$INST_PUBLIC"
save INST_PRIVE "$INST_PRIVE"
aws ec2 wait instance-running --instance-ids "$INST_PUBLIC" "$INST_PRIVE"

echo "Attente de l'enregistrement dans Systems Manager (jusqu'à 5 minutes)"
for i in $(seq 1 30); do
  n=$(aws ssm describe-instance-information \
        --filters "Key=InstanceIds,Values=$INST_PUBLIC,$INST_PRIVE" \
        --query 'length(InstanceInformationList[?PingStatus==`Online`])' --output text)
  [ "$n" = "2" ] && { echo "les 2 instances sont en ligne dans SSM"; break; }
  sleep 10
done
echo "Terminé. N'oubliez pas : 05-nettoyage-quotidien.sh"
