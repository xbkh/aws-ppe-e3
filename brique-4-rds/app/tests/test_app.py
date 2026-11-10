"""Tests de l'application, sans base de données : les accès à la base sont remplacés par des doubles."""
import datetime
import sys
from pathlib import Path

import psycopg
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import app as appli  # noqa: E402
import db  # noqa: E402

EVENEMENT = appli.EVENEMENTS[0]


@pytest.fixture
def client(monkeypatch):
    """Client de test avec une base factice qui mémorise les inscriptions."""
    base = {"lignes": []}

    def ajouter(evenement, nom, email):
        base["lignes"].append((evenement, nom, email))

    def lister(limite=50):
        return [
            (i, ev, nom, datetime.datetime(2026, 11, 10, 12, 0))
            for i, (ev, nom, _mail) in enumerate(base["lignes"], start=1)
        ]

    monkeypatch.setattr(db, "ajouter_inscription", ajouter)
    monkeypatch.setattr(db, "lister_inscriptions", lister)
    c = appli.create_app().test_client()
    c.base = base
    return c


def poster(client, **champs):
    donnees = {"evenement": EVENEMENT, "nom": "Alice Martin", "email": "alice@example.org"}
    donnees.update(champs)
    return client.post("/inscription", data=donnees)


def test_health_ne_depend_pas_de_la_base(monkeypatch):
    def panne(*a, **k):
        raise AssertionError("la base ne doit pas être appelée")

    monkeypatch.setattr(db, "connecter", panne)
    reponse = appli.create_app().test_client().get("/health")
    assert reponse.status_code == 200 and reponse.data == b"ok"


def test_accueil_redirige_vers_le_formulaire(client):
    reponse = client.get("/")
    assert reponse.status_code == 302 and reponse.headers["Location"].endswith("/inscription")


def test_formulaire_liste_les_evenements(client):
    page = client.get("/inscription").get_data(as_text=True)
    for evenement in appli.EVENEMENTS:
        assert evenement in page


def test_inscription_valide_est_enregistree_puis_redirigee(client):
    reponse = poster(client)
    assert reponse.status_code == 302 and "ok=1" in reponse.headers["Location"]
    assert client.base["lignes"] == [(EVENEMENT, "Alice Martin", "alice@example.org")]
    page = client.get("/inscription?ok=1").get_data(as_text=True)
    assert "bien été enregistrée" in page and "Alice Martin" in page


def test_l_adresse_email_n_est_pas_affichee(client):
    poster(client)
    assert "alice@example.org" not in client.get("/inscription").get_data(as_text=True)


@pytest.mark.parametrize(
    "champ, valeur",
    [
        ("nom", ""),
        ("nom", "   "),
        ("nom", "x" * 101),
        ("email", "pas-un-email"),
        ("email", "a@b"),
        ("evenement", "Événement inconnu"),
    ],
)
def test_donnees_invalides_refusees_sans_enregistrement(client, champ, valeur):
    reponse = poster(client, **{champ: valeur})
    assert reponse.status_code == 200
    assert 'role="alert"' in reponse.get_data(as_text=True)
    assert client.base["lignes"] == []


def test_les_balises_html_sont_echappees(client):
    poster(client, nom="<script>alert(1)</script>")
    page = client.get("/inscription").get_data(as_text=True)
    assert "<script>alert(1)</script>" not in page
    assert "&lt;script&gt;" in page


def test_base_indisponible_donne_une_page_503_sans_detail(monkeypatch):
    def panne(*a, **k):
        raise psycopg.OperationalError("connexion refusée vers 10.0.20.5 mot de passe incorrect")

    monkeypatch.setattr(db, "ajouter_inscription", panne)
    monkeypatch.setattr(db, "lister_inscriptions", panne)
    client = appli.create_app().test_client()
    for reponse in (poster(client), client.get("/inscription")):
        assert reponse.status_code == 503
        texte = reponse.get_data(as_text=True)
        assert "momentanément indisponible" in texte
        assert "10.0.20.5" not in texte and "mot de passe" not in texte
