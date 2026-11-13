"""Accès à la base de données PostgreSQL (en local : Docker, sur AWS : Amazon RDS)."""
import json
import os
import time

import psycopg

_schema_pret = False
_secret = {"valeur": None, "heure": 0.0}
_DUREE_CACHE = 300  # secondes : le secret géré par RDS est renouvelé de temps en temps


def _identifiants() -> tuple[str, str]:
    """Utilisateur et mot de passe : Secrets Manager si DB_SECRET_ARN est défini, sinon l'environnement."""
    arn = os.environ.get("DB_SECRET_ARN")
    if not arn:
        return os.environ.get("DB_USER", "inscriptions"), os.environ.get("DB_PASSWORD", "")
    if _secret["valeur"] is None or time.monotonic() - _secret["heure"] > _DUREE_CACHE:
        import boto3  # importé ici : inutile en local sans Secrets Manager

        client = boto3.client("secretsmanager", region_name=os.environ.get("AWS_REGION", "eu-central-2"))
        _secret["valeur"] = json.loads(client.get_secret_value(SecretId=arn)["SecretString"])
        _secret["heure"] = time.monotonic()
    return _secret["valeur"]["username"], _secret["valeur"]["password"]


def _parametres() -> dict:
    """Paramètres de connexion lus dans l'environnement (jamais écrits dans le code)."""
    utilisateur, mot_de_passe = _identifiants()
    return {
        "host": os.environ.get("DB_HOST", "localhost"),
        "port": int(os.environ.get("DB_PORT", "5432")),
        "dbname": os.environ.get("DB_NAME", "inscriptions"),
        "user": utilisateur,
        "password": mot_de_passe,
        "sslmode": os.environ.get("DB_SSLMODE", "prefer"),
        "connect_timeout": 5,
    }


def connecter() -> psycopg.Connection:
    """Ouvre une connexion et crée la table au premier usage."""
    global _schema_pret
    conn = psycopg.connect(**_parametres())
    if not _schema_pret:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS inscriptions (
                id         SERIAL PRIMARY KEY,
                evenement  TEXT NOT NULL,
                nom        TEXT NOT NULL,
                email      TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            """
        )
        conn.commit()
        _schema_pret = True
    return conn


def ajouter_inscription(evenement: str, nom: str, email: str) -> None:
    # Requête paramétrée : aucune valeur n'est collée dans le texte SQL (pas d'injection SQL).
    with connecter() as conn:
        conn.execute(
            "INSERT INTO inscriptions (evenement, nom, email) VALUES (%s, %s, %s)",
            (evenement, nom, email),
        )


def lister_inscriptions(limite: int = 50) -> list[tuple]:
    """Dernières inscriptions. L'adresse e-mail n'est volontairement pas relue pour l'affichage."""
    with connecter() as conn:
        return conn.execute(
            "SELECT id, evenement, nom, created_at FROM inscriptions ORDER BY id DESC LIMIT %s",
            (limite,),
        ).fetchall()
