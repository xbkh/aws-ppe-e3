# Coûts : estimation mensuelle de l'architecture finale

Estimation de l'architecture des briques 4 et 5 (ALB, 2 serveurs en Auto Scaling, NAT Gateway, RDS
PostgreSQL Multi-AZ), en région Zurich (`eu-central-2`), **allumée 24 h sur 24**.

## Prix unitaires relevés

Relevés le 13 novembre 2026 avec l'API de tarification d'AWS (`aws pricing get-products`, région
Zurich, tarif à la demande, en USD) :

| Ressource | Prix unitaire |
|---|---|
| EC2 `t3.micro` Linux | 0,0132 USD par heure |
| RDS PostgreSQL `db.t3.micro`, une zone | 0,023 USD par heure |
| RDS PostgreSQL `db.t3.micro`, **Multi-AZ** | 0,046 USD par heure |
| NAT Gateway | 0,0572 USD par heure, plus 0,0572 USD par Go traité |
| Application Load Balancer | 0,0297 USD par heure, plus les unités de capacité (LCU) |
| Disque EBS gp3 | 0,1142 USD par Go et par mois |

## Estimation sur 730 heures (un mois)

| Poste | Calcul | USD par mois |
|---|---|---|
| 2 serveurs `t3.micro` | 2 × 0,0132 × 730 | 19,27 |
| RDS Multi-AZ | 0,046 × 730 | 33,58 |
| NAT Gateway | 0,0572 × 730 | 41,76 |
| Application Load Balancer | 0,0297 × 730 | 21,68 |
| Disques des serveurs (2 × 8 Go) | 16 × 0,1142 | 1,83 |
| **Total relevé** | | **118,12** |

**Ce qui n'est pas dans ce total** (non relevé via l'API ou négligeable ici) : le stockage RDS de
20 Go en Multi-AZ, les adresses IPv4 publiques (le NAT et l'ALB en utilisent, AWS les facture à
l'heure), le trafic sortant et les données traitées par le NAT, les 5 alarmes et le tableau de bord
CloudWatch, le secret dans Secrets Manager, S3 et CloudFront (quelques fichiers, très peu de
trafic). Le coût réel est donc **un peu supérieur à 118 USD par mois**.

**Conséquence :** laissée allumée en permanence, cette architecture épuiserait les 100 USD de
crédits du plan gratuit en environ 25 jours. D'où le nettoyage systématique après les tests.

## Trois pistes d'optimisation, chiffrées

Chaque économie est calculée seule (elles ne s'additionnent pas simplement).

| # | Piste | Calcul | Économie par mois |
|---|---|---|---|
| 1 | **N'allumer ALB, NAT et serveurs que 10 h par jour, 5 jours par semaine** (environ 217 h au lieu de 730 h) : script de nettoyage et de recréation | (19,27 + 41,76 + 21,68) × (1 − 217/730) | **environ 58 USD** |
| 2 | **RDS en une seule zone hors production** (le Multi-AZ n'est utile que là où une panne de zone est inacceptable) | 0,023 × 730 | **environ 17 USD** |
| 3 | **Un seul serveur au minimum hors production** (Auto Scaling `min = 1`) | (0,0132 × 730) + 8 Go × 0,1142 | **environ 10,5 USD** |

La piste 1 est la plus rentable : la NAT Gateway et l'ALB coûtent plus cher que les deux serveurs.
Elle suppose que l'arrêt de la base, qui n'est pas dans le calcul, reste possible ou acceptable.

## Coût réel du projet

Les ressources facturées à l'heure n'ont existé que pendant les tests, puis ont été supprimées (voir
la brique 5). Le coût exact sera relevé dans **Cost Explorer** une fois les données disponibles
(AWS les publie avec un délai pouvant aller jusqu'à 24 heures) : capture à ajouter ici.
