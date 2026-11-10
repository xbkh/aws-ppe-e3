#!/usr/bin/env bash
# À lancer chaque soir : supprime ce qui est facturé à l'heure (instances, NAT Gateway, IP élastique).
# Le VPC, les sous-réseaux, l'Internet Gateway, les tables de routage et les groupes de sécurité
# restent : ils ne coûtent rien et servent aux briques suivantes.
. "$(dirname "$0")/lib.sh"; load

if [ -n "${INST_PUBLIC:-}${INST_PRIVE:-}" ]; then
  echo "Suppression des instances de test"
  aws ec2 terminate-instances --instance-ids ${INST_PUBLIC:-} ${INST_PRIVE:-} --query 'TerminatingInstances[].InstanceId' --output text >/dev/null
  aws ec2 wait instance-terminated --instance-ids ${INST_PUBLIC:-} ${INST_PRIVE:-}
  forget INST_PUBLIC; forget INST_PRIVE
fi

if [ -n "${NAT:-}" ]; then
  echo "Suppression de la route vers le NAT puis du NAT Gateway"
  aws ec2 delete-route --route-table-id "$RT_APP" --destination-cidr-block 0.0.0.0/0 2>/dev/null || true
  aws ec2 delete-nat-gateway --nat-gateway-id "$NAT" >/dev/null
  aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT" 2>/dev/null || sleep 60
  forget NAT
fi

if [ -n "${EIP:-}" ]; then
  echo "Libération de l'adresse IP élastique"
  aws ec2 release-address --allocation-id "$EIP"
  forget EIP
fi

echo "Vérification : ce qui coûte encore à l'heure"
echo "  instances actives : $(aws ec2 describe-instances --filters Name=tag:Projet,Values=ppe-e3 Name=instance-state-name,Values=pending,running,stopping,stopped --query 'length(Reservations[].Instances[])' --output text)"
echo "  NAT Gateway       : $(aws ec2 describe-nat-gateways --filter Name=tag:Projet,Values=ppe-e3 Name=state,Values=pending,available,deleting --query 'length(NatGateways)' --output text)"
echo "  adresses IP élastiques : $(aws ec2 describe-addresses --filters Name=tag:Projet,Values=ppe-e3 --query 'length(Addresses)' --output text)"
