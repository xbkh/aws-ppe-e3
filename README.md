# PPE Cloud AWS — Plateforme web résiliente, construite brique par brique

**Cours de référence :** Cloud AWS — Intégration de services réseau multiplateformes (CFC 300)
**Classe :** E3
**Durée :** 5 jours (une brique par jour, semaine PPE qui suit le cours du 16 au 20 novembre 2026)
**Niveau :** Débutant → Avancé (la difficulté monte au fil des jours)

> **Statut : proposition à faire valider par Morrad avant de commencer.**
> Les fiches officielles (`03-cloud-aws/`) demandent de choisir **un** projet sur 5. Ce document
> propose un projet « fil rouge » qui reprend les 5 projets l'un après l'autre, un par jour.
> Il couvre donc plus large que la consigne : l'accord du formateur est nécessaire pour savoir
> s'il remplace le choix d'un projet ou s'il s'y ajoute.

## Contexte

Une association (fictive) organise des événements et veut une petite plateforme : un **site
vitrine** rapide, et une **application d'inscription** aux événements avec une base de données.
Elle veut démarrer simplement, puis rendre l'ensemble sûr et tolérant aux pannes.

Plutôt que 5 exercices séparés, on construit **une seule plateforme** : chaque jour ajoute une
couche à celle de la veille, et chaque couche correspond à un des 5 projets officiels.

```
Internet
   │
   ▼
CloudFront ──► S3 (site vitrine)                         ← Jour 1 (projet 1)
   │
   ▼  /inscription
Application Load Balancer (sous-réseaux publics, 2 AZ)   ← Jour 3 (projet 3)
   │
   ▼
EC2 ×2 (sous-réseaux privés « app », 1 par AZ)           ← Jours 3 et 5
   │
   ▼
RDS (sous-réseaux privés « données », Multi-AZ)          ← Jours 4 et 5 (projets 4 et 5)

Le tout dans un VPC à 2 zones de disponibilité           ← Jour 2 (projet 2)
IAM (moindre privilège) + CloudWatch + coûts             ← Jour 5 (projet 5)
```

## Correspondance avec les projets officiels

| Jour | Brique | Projet officiel couvert | Niveau |
|---|---|---|---|
| 1 | Site statique S3 + CloudFront | Projet 1 | Débutant |
| 2 | VPC, sous-réseaux publics/privés, routage | Projet 2 | Débutant/Intermédiaire |
| 3 | EC2 ×2 derrière un Application Load Balancer | Projet 3 | Intermédiaire |
| 4 | RDS dans un sous-réseau privé, flux inter-tiers | Projet 4 | Intermédiaire/Avancé |
| 5 | Multi-AZ, IAM, CloudWatch, test de panne, coûts | Projet 5 | Avancé |

## Règles pour tout le projet

- **Région :** `eu-central-1` (Francfort) : tous les services du projet y sont disponibles.
- **Accès aux serveurs :** via **AWS Systems Manager Session Manager**, sans ouvrir le port 22
  sur Internet. Si le SSH est utilisé, il est restreint à votre IP et justifié dans le rapport.
- **Nommage et étiquettes :** chaque ressource porte un nom `ppe-e3-<role>` et l'étiquette
  `Projet=ppe-e3`, ce qui permet de tout retrouver et tout supprimer.
- **Aucun secret dans le dépôt :** mots de passe et clés dans AWS Secrets Manager, jamais dans le
  code, les captures ou l'historique Git.

### Coûts : à lire avant de commencer

Certaines ressources sont **facturées à l'heure même sans trafic** : NAT Gateway, Application Load
Balancer, RDS (surtout en Multi-AZ), adresses IPv4 publiques. Les prix exacts sont à vérifier dans
le [calculateur AWS](https://calculator.aws/), ils changent selon la région.

1. **Jour 0 :** créer une alerte de budget (AWS Budgets, par exemple 10 CHF) et activer les
   notifications par e-mail.
2. **Chaque soir :** supprimer ou arrêter ce qui coûte à l'heure (NAT Gateway, ALB, RDS, instances).
   Un schéma décrit l'architecture : tout doit pouvoir être recréé le lendemain.
3. **Fin de semaine :** supprimer toutes les ressources portant l'étiquette `Projet=ppe-e3` et
   joindre au rapport une capture de la facture ou du Cost Explorer.

L'infrastructure en code (Terraform ou CloudFormation) est un **bonus** valorisé, mais pas une
obligation : elle rend le « recréer chaque matin » beaucoup plus simple.

---

## Jour 1 — Site vitrine sur S3 et CloudFront (projet 1)

**Objectif :** publier la page d'accueil de l'association en HTTPS, rapide, sans bucket public.

**Étapes**
1. Créer un bucket S3 **privé** (blocage de l'accès public activé) et y déposer un site HTML/CSS
   de 2 ou 3 pages (accueil, événements, contact).
2. Créer une distribution CloudFront avec ce bucket comme origine, accès via **Origin Access
   Control (OAC)**, et une politique de bucket qui n'autorise que cette distribution.
3. Rediriger HTTP vers HTTPS, définir `index.html` comme objet racine, ajouter une page d'erreur.
4. Tester : l'URL CloudFront répond, l'URL directe du bucket est refusée (403).

**Livrables :** URL CloudFront fonctionnelle, schéma S3 + CloudFront, politique de bucket,
captures des deux tests (accès par CloudFront accepté, accès direct refusé).

## Jour 2 — Le réseau : VPC à 2 zones, public et privé (projet 2)

**Objectif :** poser le réseau sur lequel tout le reste va tourner.

**Plan d'adressage de départ** (à justifier ou adapter dans le rapport)

| Sous-réseau | AZ A | AZ B | Rôle |
|---|---|---|---|
| Public | `10.0.0.0/24` | `10.0.1.0/24` | Load balancer, NAT |
| Privé « app » | `10.0.10.0/24` | `10.0.11.0/24` | Serveurs applicatifs |
| Privé « données » | `10.0.20.0/24` | `10.0.21.0/24` | Base de données |

VPC en `10.0.0.0/16`.

**Étapes**
1. Créer le VPC et les 6 sous-réseaux répartis sur 2 zones de disponibilité.
2. Internet Gateway et table de routage publique ; tables de routage privées **sans** route
   directe vers Internet.
3. Sortie Internet des sous-réseaux privés (mises à jour système) via **1 NAT Gateway** dans un
   sous-réseau public. Noter dans le rapport le compromis coût / résilience (1 NAT ou 1 par AZ).
4. Lancer une petite instance de test dans un sous-réseau public et une dans un sous-réseau privé.
5. Prouver l'isolation : l'instance privée n'est pas joignable depuis Internet, mais peut sortir
   par le NAT ; l'instance publique est joignable comme prévu.

**Livrables :** VPC opérationnel, schéma réseau annoté (CIDR, AZ, tables de routage), preuves
d'isolation (sorties de commandes ou captures).

## Jour 3 — Serveurs web derrière un Application Load Balancer (projet 3)

**Objectif :** ne plus dépendre d'un seul serveur.

**Étapes**
1. Lancer **2 instances EC2** (1 par AZ) dans les sous-réseaux **privés « app »**, avec un serveur
   web installé par script de démarrage (user data). La page doit afficher l'identifiant de
   l'instance et sa zone de disponibilité, pour voir quel serveur répond.
2. Créer un Application Load Balancer dans les sous-réseaux **publics**, un groupe cible, et un
   contrôle de santé (par exemple `/health`).
3. Groupes de sécurité **chaînés** : Internet → ALB (80/443) ; ALB → instances (80 uniquement,
   depuis le groupe de sécurité de l'ALB, pas depuis une plage d'adresses).
4. Tester la répartition : actualiser plusieurs fois et constater l'alternance des instances.
5. Tester la tolérance : arrêter un serveur, vérifier que le site répond toujours et que la cible
   passe en `unhealthy`.

**Livrables :** infrastructure EC2 + ALB, schéma mis à jour, tableau des règles de sécurité,
preuve de répartition (captures ou `curl` en boucle) et du retrait d'une cible défaillante.

## Jour 4 — Architecture 3 tiers avec RDS (projet 4)

**Objectif :** ajouter la base de données et l'application d'inscription.

**Étapes**
1. Créer un **DB subnet group** avec les deux sous-réseaux privés « données ».
2. Déployer **RDS** (MySQL ou PostgreSQL, petite taille) : non accessible publiquement, chiffré,
   un seul mode AZ pour l'instant (le Multi-AZ vient le jour 5).
3. Stocker le mot de passe dans **Secrets Manager** ; l'application le lit au démarrage.
4. Groupe de sécurité de la base : entrée **uniquement** depuis le groupe de sécurité des serveurs
   applicatifs, sur le port de la base. Aucune autre règle.
5. Application minimale sur les serveurs : formulaire d'inscription à un événement, enregistrement
   en base, liste des inscrits. Un langage simple suffit (Python/Flask par exemple).
6. Test de bout en bout : s'inscrire depuis le navigateur, voir la ligne en base, et prouver que la
   base est injoignable depuis Internet **et** depuis un sous-réseau qui n'est pas le sien.
7. *Bonus d'intégration :* faire servir le chemin `/inscription/*` par CloudFront vers l'ALB, le
   reste restant servi par S3 : un seul nom de domaine pour tout le site.

**Livrables :** architecture 3 tiers opérationnelle, schéma complet, documentation des règles de
sécurité entre les tiers (qui parle à qui, sur quel port, pourquoi).

## Jour 5 — Résilience, IAM, supervision et coûts (projet 5)

**Objectif :** rendre l'ensemble tolérant à la panne d'une zone et le surveiller.

**Étapes**
1. **Multi-AZ :** passer RDS en Multi-AZ ; remplacer les 2 instances par un **Auto Scaling Group**
   (minimum 2, réparti sur les 2 AZ) branché sur le groupe cible de l'ALB.
2. **IAM, moindre privilège :** un rôle par composant (instance applicative : lire *ce* secret et
   rien d'autre, plus l'accès Session Manager ; etc.). Aucune politique `*:*`. Justifier chaque
   permission dans le rapport.
3. **CloudWatch :** alarmes sur le CPU des instances, le nombre de cibles saines de l'ALB, les
   erreurs 5xx, les connexions et l'espace disque de RDS ; un tableau de bord regroupant ces métriques ;
   notification par e-mail (SNS).
4. **Test de panne :** simuler la perte d'une zone (arrêter les instances d'une AZ, forcer un
   basculement RDS). Mesurer et noter la durée d'indisponibilité, vérifier que l'inscription
   fonctionne encore, vérifier que les alarmes se déclenchent.
5. **Coûts :** estimation du coût mensuel dans le calculateur AWS (export joint), avec 3 pistes
   d'optimisation chiffrées (taille d'instance, NAT unique, arrêt hors heures de bureau, etc.).
6. Schéma final et nettoyage complet des ressources.

**Livrables :** architecture multi-AZ testée, politiques IAM, tableau de bord CloudWatch, résultat
du test de panne, estimation de coût mensuel, schéma final.

---

## Rendu

Un dépôt Git avec un seul README principal et un sous-dossier par jour :

```
aws-ppe-e3/
├── README.md                  # ce document, devenu le rapport (synthèse, schéma final)
├── jour-1-s3-cloudfront/      # captures, configurations, notes du jour
├── jour-2-vpc/
├── jour-3-ec2-alb/
├── jour-4-rds/
├── jour-5-resilience/
├── schemas/                   # un schéma par jour, plus le schéma final
├── iac/                       # bonus : Terraform ou CloudFormation
└── couts/                     # export du calculateur AWS, capture de la facture
```

Chaque dossier de jour contient : ce qui a été fait, les commandes ou réglages importants, les
tests réalisés **avec leur résultat**, et les problèmes rencontrés. Selon la consigne des fiches
officielles, le rendu est déposé dans un sous-dossier `rendu-<nom-etudiant>/` à côté des fiches du
cours (voir `03-cloud-aws/README.md`).

## Barème proposé

Même échelle que les fiches officielles : note sur 6, `Note = 1 + (% obtenu / 100) × 5`, seuil de
réussite **4.0/6** (60 %). La répartition ci-dessous est une proposition à valider avec le
formateur, qui peut l'ajuster.

| Critère | Pondération |
|---|---|
| Jour 1 — S3 + CloudFront (bucket privé, HTTPS, tests) | 10% |
| Jour 2 — VPC et preuves d'isolation | 15% |
| Jour 3 — EC2 + ALB, groupes de sécurité chaînés, répartition prouvée | 15% |
| Jour 4 — RDS privé, flux inter-tiers, application de bout en bout | 20% |
| Jour 5 — Multi-AZ, IAM moindre privilège, CloudWatch, test de panne | 25% |
| Documentation, schéma final, coûts et nettoyage | 15% |

### Si le temps manque

Les jours se construisent les uns sur les autres : mieux vaut un jour 4 terminé et testé qu'un
jour 5 bâclé. Ordre de sacrifice conseillé, à annoncer au formateur plutôt qu'à subir :
1. le bonus d'intégration CloudFront → ALB et l'infrastructure en code ;
2. l'Auto Scaling Group (garder 2 instances fixes, une par AZ) ;
3. le tableau de bord CloudWatch (garder les alarmes) ;
4. en dernier recours, s'arrêter au jour 4 et documenter précisément le jour 5 comme travail
   restant.

## Ressources

- [AWS — Amazon S3 User Guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html)
- [AWS — CloudFront : restreindre l'accès à une origine S3 (OAC)](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
- [AWS — Amazon VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [AWS — Amazon EC2 User Guide](https://docs.aws.amazon.com/ec2/index.html)
- [AWS — Elastic Load Balancing User Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/what-is-load-balancing.html)
- [AWS — Amazon RDS User Guide](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html)
- [AWS — IAM User Guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
- [AWS — Amazon CloudWatch User Guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html)
- [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html)
- [AWS Pricing Calculator](https://calculator.aws/)
