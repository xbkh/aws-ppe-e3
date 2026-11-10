# Captures de la console AWS

La console web demande une connexion : ses captures sont faites à la main par l'étudiant. Les
captures du terminal et du site sont déjà dans les dossiers `captures/` de chaque brique.

**Avant de publier une capture :** l'identifiant de compte à 12 chiffres apparaît en haut à droite
de la console, dans le tableau de bord IAM et dans les ARN. Recadrer ou masquer cette zone.

## Déjà ajoutées

| Brique | Fichier | Contenu |
|---|---|---|
| 0 | `10-console-budgets.png` | budget `ppe-e3-budget-mensuel`, état Healthy |
| 0 | `11-console-utilisateurs-iam.png` | utilisateur `ppe-e3-etudiant` avec MFA (passkey) et connexion console |
| 0 | `12-console-mfa-racine.png` | « Root user has MFA » (recadrée pour masquer l'identifiant de compte) |
| 1 | `06-console-s3-bucket.png` | le bucket à Zurich |
| 1 | `07-console-cloudfront-distribution.png` | la distribution activée, avec son origine |
| 1 | `08-url-cloudfront-navigateur.png` | l'adresse du site dans le navigateur |

## Encore à faire (facultatif, mais utile pour la brique 1)

| Fichier | Page de la console | Ce qui doit être visible |
|---|---|---|
| `brique-1-s3-cloudfront/captures/09-console-s3-blocage-public.png` | S3, le bucket, onglet Permissions | « Block all public access : On » |
| `brique-1-s3-cloudfront/captures/10-console-cloudfront-origine-oac.png` | CloudFront, la distribution, onglet Origins, l'origine ouverte | l'Origin Access Control `ppe-e3-oac` |
| `brique-1-s3-cloudfront/captures/11-site-https-cadenas.png` | le navigateur sur le site | l'adresse avec le cadenas (la capture actuelle de la barre d'adresse ne montre pas le `https`) |

## Brique 2 (facultatif)

| Fichier | Page de la console | Ce qui doit être visible |
|---|---|---|
| `brique-2-vpc/captures/04-console-vpc-resource-map.png` | VPC, Your VPCs, `ppe-e3-vpc`, onglet Resource map | les 6 sous-réseaux, les 3 tables de routage et l'Internet Gateway |

Pour la brique 1, la preuve du blocage public et de l'OAC existe déjà en ligne de commande
(capture 05) : les captures de la console la complètent.

## Ensuite

Déposer les fichiers dans les dossiers indiqués, puis ajouter une ligne `![…](captures/…)` dans le
README de la brique concernée.
