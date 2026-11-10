# Brique 0 — Préparation du poste

Installation des outils en ligne de commande sur le poste de travail (Pop!_OS 24.04, x86_64).
Tout est installé **dans le dossier personnel**, sans `sudo` et sans toucher au système.

## 1. AWS CLI v2

```bash
curl -fsSL -o awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
unzip -q awscliv2.zip
./aws/install -i "$HOME/.local/aws-cli" -b "$HOME/.local/bin"
```

Vérification :

```console
$ aws --version
aws-cli/2.39.7 Python/3.14.8 Linux/7.2.15-76070215-generic exe/x86_64.pop.24
```

![Version de l'AWS CLI](captures/01-aws-cli-version.png)

## 2. Plugin Session Manager

Le plugin permet d'ouvrir une session sur une instance privée sans ouvrir le port 22. Le paquet
`.deb` officiel est extrait puis le binaire est copié dans `~/.local/bin` :

```bash
curl -fsSL -o session-manager-plugin.deb \
  https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb
dpkg-deb -x session-manager-plugin.deb extracted
cp extracted/usr/local/sessionmanagerplugin/bin/session-manager-plugin "$HOME/.local/bin/"
```

Vérification :

```console
$ session-manager-plugin --version
1.2.896.0
```

![Version du plugin Session Manager](captures/02-session-manager-plugin-version.png)

Les deux outils sont bien trouvés dans le `PATH` et installés dans le dossier personnel :

![Emplacement des deux outils](captures/03-outils-installes.png)

## 3. État des identifiants (avant connexion)

Avant la connexion, aucun identifiant AWS n'est configuré, ce qui est attendu :

```console
$ aws sts get-caller-identity
aws: [ERROR]: An error occurred (NoCredentials): Unable to locate credentials.
```

![Aucun identifiant configuré](captures/04-identifiants-absents.png)

## 4. Connexion au compte et région

La connexion se fait avec `aws login`, qui ouvre la page de connexion AWS dans le navigateur : les
identifiants sont saisis par l'étudiant sur cette page, jamais dans le terminal ni dans le dépôt.
À l'invite, la région choisie est **`eu-central-2` (Zurich)**.

```console
$ aws login
AWS Region [us-east-1]: eu-central-2
...
$ aws sts get-caller-identity      # renvoie bien le compte
$ aws configure get region
eu-central-2
$ aws ec2 describe-availability-zones --region eu-central-2
eu-central-2a  available
eu-central-2b  available
eu-central-2c  available
```

La région Zurich est active et offre 3 zones de disponibilité, ce qui suffit pour le Multi-AZ.

> La connexion actuelle utilise le compte racine. Pour la suite du projet, il est prévu de créer
> un utilisateur IAM à droits limités et d'activer le MFA sur le compte racine.

## 5. Plan gratuit et coûts

Le compte est sur le **plan gratuit AWS** avec des crédits, consultable en ligne de commande :

```bash
aws freetier get-account-plan-state --region us-east-1
```

![Plan gratuit du compte](captures/05-plan-gratuit.png)

Le plan est `FREE` et actif, avec 100 USD de crédits restants jusqu'au 10 mai 2027. Les crédits
sont consommés par l'usage : NAT Gateway, Application Load Balancer et RDS sont facturés à
l'heure, d'où l'alerte de budget ci-dessous et le nettoyage quotidien prévu dans le README
principal.

## 6. Alerte de budget (« jour 0 »)

Un budget mensuel de 10 USD, **sans déduire les crédits** (pour suivre la consommation réelle),
avec deux alertes par e-mail à 80 % et à 100 % de la dépense réelle. Les fichiers JSON de
configuration sont écrits à part et ne sont pas versionnés (ils contiennent l'adresse e-mail).

```bash
aws budgets create-budget --account-id "$ACCOUNT_ID" \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifs.json
```

Points importants de `budget.json` : `BudgetType: COST`, `TimeUnit: MONTHLY`, limite `10` en
`USD`, et `CostTypes.IncludeCredit: false`.

Vérification du budget puis de ses alertes :

![Budget créé](captures/06-budget-cree.png)

![Alertes du budget](captures/07-alertes-budget.png)

## À faire ensuite

- [x] Créer ou récupérer le compte AWS (compte personnel, plan gratuit).
- [x] Créer l'alerte de budget (« jour 0 » du README principal).
- [x] Configurer les identifiants (`aws login`, saisis par l'étudiant sur la page AWS).
- [x] Vérifier avec `aws sts get-caller-identity`.
- [ ] Créer un utilisateur IAM à droits limités et activer le MFA sur le compte racine.
- [ ] Capture de la page Budgets dans la console AWS.

## Captures

Les images de `captures/` sont de vraies captures d'un terminal exécutant les vraies commandes
ci-dessus (dans un écran virtuel isolé, pour ne montrer que le terminal). Les captures de la
console AWS (briques 1 à 5) seront ajoutées dans le dossier de chaque brique.
