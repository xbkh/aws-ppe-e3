#!/usr/bin/env bash
# Brique 5 : preuve du moindre privilège. Les commandes sont exécutées SUR un serveur de l'ASG,
# donc avec les droits du rôle ppe-e3-app-role. La valeur du mot de passe n'est jamais affichée.
. "$(dirname "$0")/../../brique-4-rds/scripts/lib.sh"; load_b2

INST=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ppe-e3-asg \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)

sur_serveur() { # commande -> sortie (compte masqué, tronquée)
  local id
  id=$(aws ssm send-command --instance-ids "$INST" --document-name AWS-RunShellScript \
        --parameters "commands=[\"export AWS_DEFAULT_REGION=eu-central-2; $1 2>&1 | head -c 400\"]" \
        --query Command.CommandId --output text)
  aws ssm wait command-executed --command-id "$id" --instance-id "$INST" 2>/dev/null || true
  aws ssm get-command-invocation --command-id "$id" --instance-id "$INST" --query StandardOutputContent --output text \
    | sed -E 's/[0-9]{12}/<ID>/g' | tr -d '\n' | cut -c1-150
}

verdict() { # attendu sortie
  if echo "$2" | grep -q -E "AccessDenied|not authorized|UnauthorizedOperation"; then
    [ "$1" = "refuse" ] && echo "REFUSÉ (attendu)" || echo "REFUSÉ (anormal)"
  else
    [ "$1" = "autorise" ] && echo "AUTORISÉ (attendu) : $2" || echo "AUTORISÉ (anormal)"
  fi
}

echo "Rôle de l'application, testé depuis un serveur de l'ASG"
printf '%-52s' "lire LE secret de la base (nom seulement) :";       verdict autorise "$(sur_serveur "aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query Name --output text")"
printf '%-52s' "lire le code dans le bucket d'artefacts :";         verdict autorise "$(sur_serveur "aws s3api get-object --bucket $BUCKET_ART --key app.tgz /tmp/x --query ContentLength --output text")"
printf '%-52s' "lister TOUS les secrets :";                         verdict refuse "$(sur_serveur "aws secretsmanager list-secrets")"
printf '%-52s' "lister les buckets S3 :";                           verdict refuse "$(sur_serveur "aws s3api list-buckets")"
printf '%-52s' "lister les instances EC2 :";                        verdict refuse "$(sur_serveur "aws ec2 describe-instances")"
printf '%-52s' "supprimer une instance EC2 :";                      verdict refuse "$(sur_serveur "aws ec2 terminate-instances --instance-ids $INST --dry-run")"
printf '%-52s' "créer un utilisateur IAM :";                        verdict refuse "$(sur_serveur "aws iam create-user --user-name x")"
