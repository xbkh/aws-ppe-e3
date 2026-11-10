"""Application d'inscription aux événements de l'association Horizon."""
import re
import socket

import psycopg
from flask import Flask, redirect, render_template, request, url_for

import db

EVENEMENTS = [
    "Atelier découverte du cloud",
    "Conférence : le numérique responsable",
    "Sortie raquettes",
]
_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def valider(formulaire) -> tuple[list[str], dict]:
    """Vérifie les champs du formulaire. Renvoie (erreurs, données nettoyées)."""
    evenement = formulaire.get("evenement", "").strip()
    nom = formulaire.get("nom", "").strip()
    email = formulaire.get("email", "").strip()
    erreurs = []
    if evenement not in EVENEMENTS:
        erreurs.append("Choisissez un événement de la liste.")
    if not nom or len(nom) > 100:
        erreurs.append("Le nom est obligatoire (100 caractères au plus).")
    if not _EMAIL.match(email) or len(email) > 200:
        erreurs.append("L'adresse e-mail n'est pas valide.")
    return erreurs, {"evenement": evenement, "nom": nom, "email": email}


def create_app() -> Flask:
    app = Flask(__name__)

    @app.get("/health")
    def health():
        # Contrôle de santé du load balancer : ne dépend volontairement pas de la base.
        return "ok", 200

    @app.get("/")
    def accueil():
        return redirect(url_for("inscription"))

    @app.route("/inscription", methods=["GET", "POST"])
    def inscription():
        erreurs: list[str] = []
        valeurs = {"evenement": "", "nom": "", "email": ""}
        if request.method == "POST":
            erreurs, valeurs = valider(request.form)
            if not erreurs:
                try:
                    db.ajouter_inscription(**valeurs)
                except psycopg.Error:
                    app.logger.exception("échec de l'enregistrement")
                    return _base_indisponible()
                # Redirection après POST : un rafraîchissement n'enregistre pas deux fois.
                return redirect(url_for("inscription", ok=1))
        try:
            inscrits = db.lister_inscriptions()
        except psycopg.Error:
            app.logger.exception("échec de la lecture")
            return _base_indisponible()
        return render_template(
            "inscription.html",
            evenements=EVENEMENTS,
            erreurs=erreurs,
            valeurs=valeurs,
            inscrits=inscrits,
            succes=request.args.get("ok") == "1",
            hote=socket.gethostname(),
        )

    def _base_indisponible():
        # Aucun détail technique n'est renvoyé au visiteur (il est dans les journaux).
        return render_template("erreur.html", hote=socket.gethostname()), 503

    return app


app = create_app()
