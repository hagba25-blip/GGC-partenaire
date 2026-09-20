"""
GGC PARTENAIRE - Création automatique des 3 comptes admin.
À exécuter UNE SEULE FOIS au déploiement : python seed_admins.py
Les mots de passe sont hashés en bcrypt avant insertion (jamais stockés en clair).
"""
import os
import bcrypt
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]  # clé service, jamais côté client

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

ADMINS = [
    {"username": "GGC PARTENAIRE", "password": "GGCSITEGLOB1415%", "role": "partner"},
    {"username": "GGC DÉVELOPPEUR SITE", "password": "HUBERT100%#", "role": "developer"},
    {"username": "BIENSURWEBWEB", "password": "ADMINFOREVA100%", "role": "admin"},
]

def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

def seed():
    for admin in ADMINS:
        existing = supabase.table("admins").select("id").eq("username", admin["username"]).execute()
        if existing.data:
            print(f"[SKIP] {admin['username']} existe déjà.")
            continue
        supabase.table("admins").insert({
            "username": admin["username"],
            "password_hash": hash_password(admin["password"]),
            "role": admin["role"],
        }).execute()
        print(f"[OK] Compte créé : {admin['username']}")

if __name__ == "__main__":
    seed()
    print("\n⚠️  IMPORTANT : changez ces mots de passe après le premier login en production.")