"""Tests de la lecture des identifiants : variables d'environnement ou Secrets Manager (simulé)."""
import json
import sys
import types
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import db  # noqa: E402


def _reinitialiser():
    db._secret["valeur"] = None
    db._secret["heure"] = 0.0


def test_sans_secret_les_identifiants_viennent_de_l_environnement(monkeypatch):
    _reinitialiser()
    monkeypatch.delenv("DB_SECRET_ARN", raising=False)
    monkeypatch.setenv("DB_USER", "alice")
    monkeypatch.setenv("DB_PASSWORD", "mdp-de-test")
    assert db._identifiants() == ("alice", "mdp-de-test")


def test_avec_secret_les_identifiants_viennent_de_secrets_manager(monkeypatch):
    _reinitialiser()
    appels = []

    class ClientFactice:
        def get_secret_value(self, SecretId):
            appels.append(SecretId)
            return {"SecretString": json.dumps({"username": "admin", "password": "secret-aws"})}

    faux_boto3 = types.SimpleNamespace(client=lambda service, region_name=None: ClientFactice())
    monkeypatch.setitem(sys.modules, "boto3", faux_boto3)
    monkeypatch.setenv("DB_SECRET_ARN", "arn:aws:secretsmanager:eu-central-2:000000000000:secret:test")
    monkeypatch.setenv("DB_PASSWORD", "ne-doit-pas-etre-utilise")

    assert db._identifiants() == ("admin", "secret-aws")
    assert db._identifiants() == ("admin", "secret-aws")
    assert appels == ["arn:aws:secretsmanager:eu-central-2:000000000000:secret:test"], "un seul appel grâce au cache"


def test_le_mot_de_passe_n_apparait_pas_dans_les_parametres_par_defaut(monkeypatch):
    _reinitialiser()
    monkeypatch.delenv("DB_SECRET_ARN", raising=False)
    monkeypatch.delenv("DB_PASSWORD", raising=False)
    assert db._parametres()["password"] == ""
    assert db._parametres()["sslmode"] == "prefer"
