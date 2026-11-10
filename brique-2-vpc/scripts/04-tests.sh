#!/usr/bin/env bash
# Tests d'isolation et de routage de la brique 2. L'identifiant de compte n'est jamais affiché.
. "$(dirname "$0")/lib.sh"; load

# ssm_run <instance> <commande> : exécute une commande sur l'instance via Systems Manager
ssm_run() {
  local id cmd
  cmd=$(aws ssm send-command --instance-ids "$1" --document-name AWS-RunShellScript \
        --parameters "commands=[\"$2\"]" --query Command.CommandId --output text)
  aws ssm wait command-executed --command-id "$cmd" --instance-id "$1" 2>/dev/null || true
  aws ssm get-command-invocation --command-id "$cmd" --instance-id "$1" \
    --query StandardOutputContent --output text | tr -d '\n'
}

PUB_IP=$(aws ec2 describe-instances --instance-ids "$INST_PUBLIC" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
PRIV_IP=$(aws ec2 describe-instances --instance-ids "$INST_PRIVE" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
PRIV_PUBLIC=$(aws ec2 describe-instances --instance-ids "$INST_PRIVE" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
NAT_IP=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT" --query 'NatGateways[0].NatGatewayAddresses[0].PublicIp' --output text)

echo "T1  Adresses des instances"
echo "    publique : IP privée $(aws ec2 describe-instances --instance-ids "$INST_PUBLIC" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text), IP publique $PUB_IP"
echo "    privée   : IP privée $PRIV_IP, IP publique $PRIV_PUBLIC"

echo "T2  Instance publique joignable depuis Internet (HTTP port 80)"
printf '    code HTTP : '; curl -s -o /dev/null -w '%{http_code}\n' --max-time 10 "http://$PUB_IP/"

echo "T3  Instance privée joignable depuis Internet ?"
printf '    '; if curl -s -o /dev/null --max-time 6 "http://$PRIV_IP/"; then echo "ACCESSIBLE (anormal)"; else echo "injoignable (délai dépassé), comme attendu"; fi

echo "T4  Sortie Internet de l'instance privée passe par le NAT"
OUT=$(ssm_run "$INST_PRIVE" "curl -s --max-time 10 https://checkip.amazonaws.com")
echo "    adresse vue depuis Internet : $OUT"
echo "    adresse du NAT              : $NAT_IP"
[ "$OUT" = "$NAT_IP" ] && echo "    => identiques : la sortie passe bien par le NAT" || echo "    => DIFFÉRENTES"

echo "T5  Instance publique vers instance privée (réseau interne, groupe de sécurité)"
printf '    code HTTP : '; ssm_run "$INST_PUBLIC" "curl -s -o /dev/null -w %{http_code} --max-time 10 http://$PRIV_IP/"; echo

echo "T6  Routes des tables de routage"
for rt in RT_PUBLIC RT_APP RT_DATA; do
  printf '    %-10s ' "$rt"
  aws ec2 describe-route-tables --route-table-ids "${!rt}" \
    --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId||NatGatewayId]' --output text | tr '\t' ' ' | tr '\n' ';' | sed 's/;$//; s/;/  |  /g'
  echo
done
