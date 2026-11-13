#!/usr/bin/env bash
# Brique 5 : simulation de la perte de la zone qui héberge la base principale
# (serveur de cette zone supprimé + bascule forcée de RDS)
# et mesure de la disponibilité vue d'un client, une requête par seconde sur 2 pages :
#   /health      (ne dépend pas de la base)
#   /inscription (lit la base : subit la bascule RDS)
. "$(dirname "$0")/../../brique-4-rds/scripts/lib.sh"; load_b2

URL="http://$ALB_DNS"
DUREE="${DUREE:-330}"       # durée totale du test (secondes)
AVANT="${AVANT:-30}"        # secondes de mesure avant la panne
LOG=$(mktemp)

sonde() {
  set +e   # une requête en échec (délai dépassé) ne doit pas arrêter la mesure : c'est ce qu'on mesure
  local fin=$((SECONDS + DUREE))
  while [ $SECONDS -lt $fin ]; do
    t=$(date +%s)
    h=$(curl -s -o /dev/null -m 3 -w '%{http_code}' "$URL/health")
    i=$(curl -s -o /dev/null -m 3 -w '%{http_code}' "$URL/inscription")
    echo "$t $h $i" >> "$LOG"
    sleep 1
  done
}

echo "État avant la panne"
echo "  RDS : zone $(aws rds describe-db-instances --db-instance-identifier ppe-e3-db --query 'DBInstances[0].AvailabilityZone' --output text), Multi-AZ $(aws rds describe-db-instances --db-instance-identifier ppe-e3-db --query 'DBInstances[0].MultiAZ' --output text)"
echo "  serveurs ASG : $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ppe-e3-asg --query 'AutoScalingGroups[0].Instances[].[AvailabilityZone,LifecycleState]' --output text | tr '\t' ':' | tr '\n' ' ')"

sonde &
PID=$!
sleep "$AVANT"

T0=$(date +%s)
ZONE=$(aws rds describe-db-instances --db-instance-identifier ppe-e3-db --query 'DBInstances[0].AvailabilityZone' --output text)
INST=$(aws ec2 describe-instances --filters Name=tag:aws:autoscaling:groupName,Values=ppe-e3-asg \
  Name=availability-zone,Values="$ZONE" Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
echo "PANNE (t=0) : perte de la zone $ZONE (serveur supprimé, bascule forcée de la base)"
aws ec2 terminate-instances --instance-ids "$INST" >/dev/null
aws rds reboot-db-instance --db-instance-identifier ppe-e3-db --force-failover >/dev/null

wait "$PID" || true

echo
echo "Résultats (t=0 : début de la panne ; une requête par seconde)"
analyse() { # colonne nom
  awk -v c="$1" -v t0="$T0" -v nom="$2" '
    { t=$1-t0; code=$c
      if (code != "200") { n++; if (!f) f=t; l=t
        if (t-prev>4 || run==0) { start=t; run=0 }
        run=t-start+1; if (run>max) max=run; prev=t } }
    END { if (n==0) printf "  %-13s aucune erreur\n", nom;
          else printf "  %-13s %d requêtes en erreur, de t=%ds à t=%ds, plus longue coupure %ds\n", nom, n, f, l, max }' "$LOG"
}
echo "  requêtes envoyées : $(wc -l < "$LOG")"
analyse 2 "/health"
analyse 3 "/inscription"
echo "  codes /inscription : $(awk '{c[$3]++} END{for(k in c) printf "%s×%d ", k, c[k]}' "$LOG")"
echo "  codes /health      : $(awk '{c[$2]++} END{for(k in c) printf "%s×%d ", k, c[k]}' "$LOG")"

echo
echo "État après la panne"
echo "  RDS : zone $(aws rds describe-db-instances --db-instance-identifier ppe-e3-db --query 'DBInstances[0].AvailabilityZone' --output text) (la bascule a changé de zone si différente de l'état avant)"
echo "  serveurs ASG : $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ppe-e3-asg --query 'AutoScalingGroups[0].Instances[].[AvailabilityZone,LifecycleState]' --output text | tr '\t' ':' | tr '\n' ' ')"
echo "  alarmes : $(aws cloudwatch describe-alarms --alarm-name-prefix ppe-e3- --query 'MetricAlarms[].[AlarmName,StateValue]' --output text | tr '\t' '=' | tr '\n' ' ')"
cp "$LOG" "$DIR/../../brique-5-resilience/panne-sondes.txt" 2>/dev/null || true
rm -f "$LOG"
