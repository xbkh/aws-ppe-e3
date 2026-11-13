#!/usr/bin/env bash
# Brique 5 : alarmes CloudWatch, sujet SNS et tableau de bord. Quelques centimes par mois.
. "$(dirname "$0")/../../brique-4-rds/scripts/lib.sh"; load_b2

LB_DIM="${ALB#*loadbalancer/}"      # ex. app/ppe-e3-b4-alb/abc123
TG_DIM="${TG##*:}"                 # ex. targetgroup/ppe-e3-b4-web/def456 (tout ce qui suit le dernier « : »)

echo "Sujet SNS des alertes (aucun abonnement e-mail : à ajouter par l'étudiant)"
SNS=$(aws sns create-topic --name ppe-e3-alertes --tags Key=Projet,Value=ppe-e3 --query TopicArn --output text)
save SNS "$SNS"

alarme() { # nom namespace metrique dimensions statistique operateur seuil periodes description
  aws cloudwatch put-metric-alarm --alarm-name "$1" --namespace "$2" --metric-name "$3" \
    --dimensions $4 --statistic "$5" --comparison-operator "$6" --threshold "$7" \
    --period 60 --evaluation-periods "$8" --treat-missing-data notBreaching \
    --alarm-description "$9" --alarm-actions "$SNS" --tags Key=Projet,Value=ppe-e3
  echo "  alarme $1"
}

echo "Alarmes"
# HealthyHostCount existe par zone : on additionne les deux zones (expression m1+m2) pour voir la perte
# d'un serveur dans l'une d'elles. Données manquantes = alarme (« breaching ») : une alarme muette est
# plus dangereuse qu'une fausse alerte. Attention : une dimension fausse (nom du groupe cible mal extrait)
# donne une alarme qui ne reçoit jamais de données.
cat > /tmp/ppe-e3-metrics.json <<JSON
[
  { "Id": "m1", "ReturnData": false, "MetricStat": { "Period": 60, "Stat": "Minimum", "Metric": { "Namespace": "AWS/ApplicationELB", "MetricName": "HealthyHostCount",
      "Dimensions": [ { "Name": "TargetGroup", "Value": "$TG_DIM" }, { "Name": "LoadBalancer", "Value": "$LB_DIM" }, { "Name": "AvailabilityZone", "Value": "eu-central-2a" } ] } } },
  { "Id": "m2", "ReturnData": false, "MetricStat": { "Period": 60, "Stat": "Minimum", "Metric": { "Namespace": "AWS/ApplicationELB", "MetricName": "HealthyHostCount",
      "Dimensions": [ { "Name": "TargetGroup", "Value": "$TG_DIM" }, { "Name": "LoadBalancer", "Value": "$LB_DIM" }, { "Name": "AvailabilityZone", "Value": "eu-central-2b" } ] } } },
  { "Id": "e1", "Expression": "m1+m2", "Label": "Serveurs sains (2 zones)", "ReturnData": true }
]
JSON
aws cloudwatch put-metric-alarm --alarm-name ppe-e3-cibles-saines --metrics file:///tmp/ppe-e3-metrics.json \
  --comparison-operator LessThanThreshold --threshold 2 --evaluation-periods 1 --treat-missing-data breaching \
  --alarm-description "Moins de 2 serveurs sains derrière l'ALB (somme des 2 zones)" --alarm-actions "$SNS" --tags Key=Projet,Value=ppe-e3
rm -f /tmp/ppe-e3-metrics.json
echo "  alarme ppe-e3-cibles-saines (métrique par zone additionnée)"
alarme ppe-e3-erreurs-5xx AWS/ApplicationELB HTTPCode_ELB_5XX_Count "Name=LoadBalancer,Value=$LB_DIM" Sum GreaterThanThreshold 5 2 "Plus de 5 erreurs 5xx par minute sur l'ALB"
alarme ppe-e3-cpu-serveurs AWS/EC2 CPUUtilization "Name=AutoScalingGroupName,Value=ppe-e3-asg" Average GreaterThanThreshold 70 3 "CPU moyen des serveurs au-dessus de 70 %"
alarme ppe-e3-cpu-base AWS/RDS CPUUtilization "Name=DBInstanceIdentifier,Value=ppe-e3-db" Average GreaterThanThreshold 70 3 "CPU de la base au-dessus de 70 %"
alarme ppe-e3-stockage-base AWS/RDS FreeStorageSpace "Name=DBInstanceIdentifier,Value=ppe-e3-db" Minimum LessThanThreshold 2000000000 1 "Moins de 2 Go d'espace libre sur la base"

echo "Tableau de bord"
cat > /tmp/ppe-e3-dashboard.json <<EOF
{ "widgets": [
  { "type": "metric", "x": 0, "y": 0, "width": 12, "height": 6, "properties": { "title": "Serveurs sains derrière l'ALB", "region": "eu-central-2", "stat": "Minimum", "period": 60,
    "metrics": [ [ "AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", "$TG_DIM", "LoadBalancer", "$LB_DIM", "AvailabilityZone", "eu-central-2a", { "id": "m1", "visible": false } ], [ "...", "eu-central-2b", { "id": "m2", "visible": false } ], [ { "expression": "m1+m2", "label": "Serveurs sains (2 zones)", "id": "e1" } ] ] } },
  { "type": "metric", "x": 12, "y": 0, "width": 12, "height": 6, "properties": { "title": "Requêtes et erreurs 5xx", "region": "eu-central-2", "stat": "Sum", "period": 60,
    "metrics": [ [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "$LB_DIM" ], [ ".", "HTTPCode_ELB_5XX_Count", ".", "." ] ] } },
  { "type": "metric", "x": 0, "y": 6, "width": 12, "height": 6, "properties": { "title": "CPU des serveurs et de la base", "region": "eu-central-2", "stat": "Average", "period": 60,
    "metrics": [ [ "AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "ppe-e3-asg" ], [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "ppe-e3-db" ] ] } },
  { "type": "metric", "x": 12, "y": 6, "width": 12, "height": 6, "properties": { "title": "Connexions à la base", "region": "eu-central-2", "stat": "Maximum", "period": 60,
    "metrics": [ [ "AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "ppe-e3-db" ] ] } },
  { "type": "alarm", "x": 0, "y": 12, "width": 24, "height": 4, "properties": { "title": "État des alarmes",
    "alarms": [ "$(aws cloudwatch describe-alarms --alarm-name-prefix ppe-e3- --query 'MetricAlarms[].AlarmArn' --output text | sed 's/\t/", "/g')" ] } }
] }
EOF
aws cloudwatch put-dashboard --dashboard-name ppe-e3 --dashboard-body file:///tmp/ppe-e3-dashboard.json --query 'DashboardValidationMessages' --output text
rm -f /tmp/ppe-e3-dashboard.json
echo "Supervision en place"
