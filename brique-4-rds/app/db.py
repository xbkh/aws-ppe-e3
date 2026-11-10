"""Accès à la base de données PostgreSQL (en local : Docker, sur AWS : Amazon RDS)."""
import os

import psycopg

_schema_pret = False


def _parametres() -> dict:
    """Paramètres de connexion lus dans l'environnement (jamais écrits dans le code)."""
    return {
        "host": os.environ.get("DB_HOST", "localhost"),
        "port": int(os.environ.get("DB_PORT", "5432")),
        "dbname": os.environ.get("DB_NAME", "inscriptions"),
        "user": os.environ.get("DB_USER", "inscriptions"),
        "password": os.environ.get("DB_PASSWORD", ""),
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
