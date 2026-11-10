# Brique 4 — Architecture 3 tiers avec RDS

Projet officiel couvert : projet 4 (architecture 3 tiers avec base de données managée RDS).

> **État : application écrite et testée en local, partie AWS (RDS) pas encore faite.**

## Ce qui a été fait : l'application d'inscription (en local)

Le code est prêt avant de toucher à AWS, pour ne pas y passer de temps facturé : [`app/`](app/).

| Élément | Choix |
|---|---|
| Langage et cadre | Python, Flask, servi par Gunicorn |
| Base de données | **PostgreSQL** (en local dans Docker, sur AWS dans Amazon RDS) |
| Page | `/inscription` : formulaire (événement, nom, e-mail) et liste des dernières inscriptions |
| Contrôle de santé | `/health` répond `ok` sans interroger la base (pour le load balancer) |
| Configuration | variables d'environnement `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` : aucun mot de passe dans le code |

Points de sécurité déjà traités dans le code :

- **Requêtes paramétrées** : aucune valeur du formulaire n'est collée dans le texte SQL (pas d'injection SQL).
- **Échappement HTML** : un nom contenant `<script>` s'affiche comme du texte, il n'est pas exécuté.
- **Validation** côté serveur : événement de la liste, nom de 1 à 100 caractères, adresse e-mail plausible.
- **L'adresse e-mail n'est jamais relue** pour l'affichage de la liste (donnée personnelle).
- **Erreurs de base de données** : le visiteur voit une page 503 générique, sans adresse IP ni message technique ; le détail va dans les journaux.
- **Redirection après envoi** : un rafraîchissement de la page n'enregistre pas deux fois la même inscription.
- **Conteneur sans droits administrateur**.

### Tests

13 tests automatiques (`pytest`), qui remplacent la base par un double : ils vérifient la validation, l'échappement HTML, la redirection, l'absence de l'e-mail dans la page, et le comportement quand la base est en panne.

```bash
cd app
python -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
python -m pytest -v
```

![Résultat des 13 tests](captures/01-tests-unitaires.png)

### Essai avec une vraie base PostgreSQL (à faire)

Pas encore réalisé : le service Docker de ce poste n'était pas démarré (le démarrer demande les droits administrateur).

```bash
cd app
docker compose up --build        # application sur http://127.0.0.1:18080/inscription
```

## À faire sur AWS (préparé, pas encore réalisé)

Les ressources RDS sont facturées à l'heure : elles seront créées et supprimées le jour du test.

- [ ] DB subnet group sur les sous-réseaux privés « données » (`10.0.20.0/24` et `10.0.21.0/24`)
- [ ] RDS PostgreSQL non public, chiffré, mot de passe dans Secrets Manager
- [ ] Groupe de sécurité de la base : entrée uniquement depuis les serveurs applicatifs
- [ ] Serveurs applicatifs qui lisent le secret et lancent l'application
- [ ] Inscription de bout en bout depuis le navigateur, ligne visible en base
- [ ] Base injoignable depuis Internet et depuis un autre sous-réseau

## Problèmes rencontrés

- Le service Docker n'était pas démarré sur le poste de travail ; les tests unitaires, eux, n'en ont
  pas besoin.
