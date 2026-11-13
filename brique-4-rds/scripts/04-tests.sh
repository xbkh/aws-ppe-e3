#!/usr/bin/env bash
# Brique 4 : tests des 3 tiers. L'identifiant de compte et l'adresse IP du poste ne sont jamais affichés.
. "$(dirname "$0")/lib.sh"; load_b2

mask() { sed -E 's/[0-9]{12}/<ID>/g; s/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/32/<IP du poste>\/32/g'; }

echo "T1  Base de données"
read -r moteur version publique chiffree multiaz etat < <(aws rds describe-db-instances --db-instance-identifier ppe-e3-db \
  --query 'DBInstances[0].[Engine,EngineVersion,PubliclyAccessible,StorageEncrypted,MultiAZ,DBInstanceStatus]' --output text)
echo "    moteur $moteur $version | accessible publiquement : $publique | chiffrée : $chiffree | Multi-AZ : $multiaz | état : $etat"

echo "T2  Règles d'entrée des 3 groupes de sécurité (source)"
for pair in "ALB:$SG_ALB" "application:$SG_APP" "base:$SG_DB"; do
  nom=${pair%%:*}; id=${pair#*:}
  src=$(aws ec2 describe-security-group-rules --filters Name=group-id,Values="$id" \
    --query 'SecurityGroupRules[?IsEgress==`false`].[FromPort,CidrIpv4||ReferencedGroupInfo.GroupId]' --output text | tr '\t' ' ' | mask)
  src=${src//$SG_ALB/groupe-ALB}; src=${src//$SG_APP/groupe-application}
  echo "    $nom : port/source = $src"
done

echo "T3  Base joignable depuis Internet (poste de test) ?"
printf '    '; if timeout 6 bash -c "exec 3<>/dev/tcp/$DB_HOST/5432" 2>/dev/null; then echo "ACCESSIBLE (anormal)"; else echo "injoignable, comme attendu"; fi

echo "T4  Politique IAM de l'application (actions et ressources)"
aws iam get-policy-version --policy-arn "$POLICY_ARN" --version-id v1 \
  --query 'PolicyVersion.Document.Statement[].[Action,Resource]' --output text | mask | sed 's/^/    /' | cut -c1-110

echo "T5  Serveurs d'application : adresse IP publique"
aws ec2 describe-instances --instance-ids "$INST_A" "$INST_B" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,PublicIpAddress]' --output text | sed 's/^/    /'

URL="http://$ALB_DNS"
echo "T6  Application via l'ALB"
printf '    /health : '; curl -s -o /dev/null -w '%{http_code}\n' "$URL/health"
printf '    /inscription : '; curl -s -o /dev/null -w '%{http_code}\n' "$URL/inscription"
NOM="Test PPE $(date +%H%M%S)"
printf '    POST inscription : '; curl -s -o /dev/null -w '%{http_code}\n' -X POST "$URL/inscription" \
  --data-urlencode "evenement=Sortie raquettes" --data-urlencode "nom=$NOM" --data-urlencode "email=test@example.org"
echo "    Lecture depuis la base, 6 requêtes (serveur qui répond, inscription présente ?) :"
for i in 1 2 3 4 5 6; do
  page=$(curl -s "$URL/inscription")
  hote=$(echo "$page" | grep -o 'Servi par : [^<]*' | sed 's/Servi par : //')
  echo "$page" | grep -q "$NOM" && p="oui" || p="NON"
  echo "      $hote -> inscription \"$NOM\" : $p"
done

echo "T7  Validation côté serveur et protection HTML"
printf '    nom vide : '; curl -s -o /dev/null -w '%{http_code}\n' -X POST "$URL/inscription" --data-urlencode "evenement=Sortie raquettes" --data-urlencode "nom=" --data-urlencode "email=a@b.ch"
curl -s -o /dev/null -X POST "$URL/inscription" --data-urlencode "evenement=Sortie raquettes" --data-urlencode "nom=<b>x</b>" --data-urlencode "email=a@b.ch"
printf '    balise <b> échappée dans la page : '; curl -s "$URL/inscription" | grep -q '&lt;b&gt;x&lt;/b&gt;' && echo "oui" || echo "NON"
