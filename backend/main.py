"""
GGC PARTENAIRE - Backend Python (FastAPI)
Gère : inscription client + OTP, plan de paiement, paiements,
authentification admin, restrictions d'appareil, localisation quotidienne.
"""
import os
import random
import string
import requests
from datetime import datetime, timedelta, date, timezone
from typing import Optional, Literal

import bcrypt
import jwt
from fastapi import FastAPI, HTTPException, Depends, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

# ---------------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------------
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
JWT_SECRET = os.environ["JWT_SECRET"]
RESEND_API_KEY = os.environ.get("RESEND_API_KEY", "")
RESEND_FROM_EMAIL = os.environ.get("RESEND_FROM_EMAIL", "onboarding@resend.dev")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

app = FastAPI(title="GGC PARTENAIRE API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # à restreindre au domaine du site admin en prod
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# SCHEMAS
# ---------------------------------------------------------------------------
class InscriptionRequest(BaseModel):
    nom: str
    prenom: str
    telephone: str
    date_naissance: date
    email: EmailStr
    prix_total: float
    imei: str
    modele: Optional[str] = None
    android_version: Optional[str] = None

class VerifyOtpRequest(BaseModel):
    email: EmailStr
    otp_code: str

class ResendOtpRequest(BaseModel):
    email: EmailStr

class ChoixPaiementRequest(BaseModel):
    client_id: str
    mode_paiement: Literal["jour", "semaine", "mois"]
    duree_mois: Literal[6, 8, 10]

class AdminLoginRequest(BaseModel):
    username: str
    password: str

class RestrictionRequest(BaseModel):
    client_id: str
    action: Literal["lock_wifi", "lock_sim", "lock_ecran", "unlock_all", "unlock_partiel"]
    raison: Optional[str] = None

class PositionUpdate(BaseModel):
    device_id: str
    lat: float
    lng: float
    ip_address: Optional[str] = None

class PaiementRequest(BaseModel):
    client_id: str
    echeance_id: str
    methode: Literal["mobile_money", "carte_bancaire"]
    reference_transaction: str

# ---------------------------------------------------------------------------
# UTILITAIRES
# ---------------------------------------------------------------------------
def generate_otp() -> str:
    return "".join(random.choices(string.digits, k=6))

def send_otp_email(email: str, otp: str):
    """
    Envoie l'OTP via l'API HTTPS de Resend (pas de SMTP : Render Free
    bloque les connexions SMTP sortantes, l'API HTTP fonctionne toujours).
    Si RESEND_API_KEY n'est pas configurée, le code s'affiche dans les
    logs serveur pour permettre de tester sans email réel.
    """
    if not RESEND_API_KEY:
        print(f"[DEV] RESEND_API_KEY non configurée. OTP pour {email} : {otp}")
        return
    try:
        response = requests.post(
            "https://api.resend.com/emails",
            headers={
                "Authorization": f"Bearer {RESEND_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "from": f"GGC PARTENAIRE <{RESEND_FROM_EMAIL}>",
                "to": [email],
                "subject": "GGC PARTENAIRE - Code de vérification",
                "html": f"<p>Votre code de vérification est : <strong>{otp}</strong></p><p>Valide 10 minutes.</p>",
            },
            timeout=10,
        )
        if response.status_code >= 400:
            print(f"[ERREUR RESEND] {response.status_code} : {response.text}")
            print(f"[DEV FALLBACK] OTP pour {email} : {otp}")
    except Exception as e:
        # Ne bloque JAMAIS l'inscription si l'envoi d'email échoue.
        print(f"[ERREUR EMAIL] Échec envoi OTP à {email} : {e}")
        print(f"[DEV FALLBACK] OTP pour {email} : {otp}")

def create_admin_jwt(admin_id: str, username: str, role: str) -> str:
    payload = {
        "sub": admin_id,
        "username": username,
        "role": role,
        "exp": datetime.utcnow() + timedelta(hours=8),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

def get_current_admin(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        return payload
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Session invalide, reconnectez-vous.")

def calculer_echeances(prix_total: float, mode: str, duree_mois: int):
    """Calcule le nombre et montant des échéances selon le mode de paiement."""
    if mode == "mois":
        nb_echeances = duree_mois
    elif mode == "semaine":
        nb_echeances = duree_mois * 4
    else:  # jour
        nb_echeances = duree_mois * 30
    montant_echeance = round(prix_total / nb_echeances, 2)
    return nb_echeances, montant_echeance

# ---------------------------------------------------------------------------
# ROUTES CLIENT — Inscription
# ---------------------------------------------------------------------------
@app.post("/api/client/inscription")
def inscription(data: InscriptionRequest, request: Request):
    existing = supabase.table("clients").select("id").eq("email", data.email).execute()
    if existing.data:
        raise HTTPException(400, "Cet email est déjà inscrit.")

    otp = generate_otp()
    client = supabase.table("clients").insert({
        "nom": data.nom,
        "prenom": data.prenom,
        "telephone": data.telephone,
        "date_naissance": data.date_naissance.isoformat(),
        "email": data.email,
        "otp_code": otp,
        "otp_expires_at": (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat(),
        "prix_total": data.prix_total,
        "mode_paiement": "mois",     # valeur par défaut, sera mise à jour après choix
        "duree_mois": 6,
        "montant_echeance": 0,
    }).execute()

    client_id = client.data[0]["id"]

    # Capture l'IP réelle du client à l'inscription (utile pour l'admin)
    client_ip = request.client.host if request.client else None
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        client_ip = forwarded.split(",")[0].strip()

    device = supabase.table("devices").insert({
        "client_id": client_id,
        "imei": data.imei,
        "modele": data.modele,
        "android_version": data.android_version,
        "ip_address": client_ip,
    }).execute()

    send_otp_email(data.email, otp)
    return {
        "client_id": client_id,
        "device_id": device.data[0]["id"],
        "message": "Code de vérification envoyé par email.",
    }

@app.post("/api/client/verify-otp")
def verify_otp(data: VerifyOtpRequest):
    res = supabase.table("clients").select("*").eq("email", data.email).execute()
    if not res.data:
        raise HTTPException(404, "Client introuvable.")
    client = res.data[0]

    if client["otp_code"] != data.otp_code:
        raise HTTPException(400, "Code incorrect.")
    expires_at = datetime.fromisoformat(client["otp_expires_at"])
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        raise HTTPException(400, "Code expiré, redemandez-en un.")

    supabase.table("clients").update({
        "email_verified": True,
        "otp_code": None,
    }).eq("id", client["id"]).execute()

    return {"message": "Email vérifié avec succès.", "client_id": client["id"]}

@app.post("/api/client/resend-otp")
def resend_otp(data: ResendOtpRequest):
    res = supabase.table("clients").select("*").eq("email", data.email).execute()
    if not res.data:
        raise HTTPException(404, "Client introuvable.")
    client = res.data[0]

    if client["email_verified"]:
        raise HTTPException(400, "Cet email est déjà vérifié.")

    otp = generate_otp()
    supabase.table("clients").update({
        "otp_code": otp,
        "otp_expires_at": (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat(),
    }).eq("id", client["id"]).execute()

    send_otp_email(data.email, otp)
    return {"message": "Nouveau code envoyé."}

@app.post("/api/client/accepter-cgu")
def accepter_cgu(client_id: str):
    supabase.table("clients").update({
        "cgu_acceptees": True,
        "cgu_accepted_at": datetime.utcnow().isoformat(),
    }).eq("id", client_id).execute()
    return {"message": "Conditions acceptées."}

@app.post("/api/client/choix-paiement")
def choix_paiement(data: ChoixPaiementRequest):
    client_res = supabase.table("clients").select("*").eq("id", data.client_id).execute()
    if not client_res.data:
        raise HTTPException(404, "Client introuvable.")
    client = client_res.data[0]

    nb_echeances, montant = calculer_echeances(client["prix_total"], data.mode_paiement, data.duree_mois)

    supabase.table("clients").update({
        "mode_paiement": data.mode_paiement,
        "duree_mois": data.duree_mois,
        "montant_echeance": montant,
    }).eq("id", data.client_id).execute()

    # Génération du plan d'échéances
    today = date.today()
    for i in range(1, nb_echeances + 1):
        if data.mode_paiement == "jour":
            date_prevue = today + timedelta(days=i)
        elif data.mode_paiement == "semaine":
            date_prevue = today + timedelta(weeks=i)
        else:
            date_prevue = today + timedelta(days=30 * i)

        supabase.table("echeances").insert({
            "client_id": data.client_id,
            "numero": i,
            "montant": montant,
            "date_prevue": date_prevue.isoformat(),
        }).execute()

    return {"message": "Plan de paiement créé.", "nb_echeances": nb_echeances, "montant_echeance": montant}

@app.get("/api/client/{client_id}/echeances")
def get_echeances(client_id: str):
    res = supabase.table("echeances").select("*").eq("client_id", client_id).order("numero").execute()
    return res.data

@app.post("/api/client/payer")
def payer_echeance(data: PaiementRequest):
    supabase.table("paiements").insert({
        "client_id": data.client_id,
        "echeance_id": data.echeance_id,
        "montant": supabase.table("echeances").select("montant").eq("id", data.echeance_id).execute().data[0]["montant"],
        "methode": data.methode,
        "reference_transaction": data.reference_transaction,
    }).execute()

    supabase.table("echeances").update({
        "statut": "payee",
        "date_payee": datetime.utcnow().isoformat(),
    }).eq("id", data.echeance_id).execute()

    # Si le client était bloqué et vient de payer, on lève une restriction partielle
    restantes = supabase.table("echeances").select("id").eq("client_id", data.client_id).eq("statut", "a_payer").execute()
    if not restantes.data:
        supabase.table("clients").update({"statut": "solde"}).eq("id", data.client_id).execute()
        device = supabase.table("devices").select("id").eq("client_id", data.client_id).execute()
        if device.data:
            supabase.table("devices").update({
                "device_admin_actif": False,  # le client peut désinstaller l'app
                "statut_appareil": "normal",
            }).eq("id", device.data[0]["id"]).execute()

    return {"message": "Paiement enregistré."}

# ---------------------------------------------------------------------------
# ROUTES DEVICE — Localisation quotidienne (1x/jour, pas de surveillance continue)
# ---------------------------------------------------------------------------
@app.post("/api/device/position")
def update_position(data: PositionUpdate):
    supabase.table("devices").update({
        "derniere_position_lat": data.lat,
        "derniere_position_lng": data.lng,
        "derniere_position_at": datetime.utcnow().isoformat(),
        "ip_address": data.ip_address,
    }).eq("id", data.device_id).execute()
    return {"message": "Position mise à jour."}

@app.get("/api/device/{device_id}/statut")
def get_device_statut(device_id: str):
    """L'app Flutter appelle ceci pour savoir si elle doit restreindre l'appareil."""
    res = supabase.table("devices").select("*").eq("id", device_id).execute()
    if not res.data:
        raise HTTPException(404, "Appareil introuvable.")
    return res.data[0]

# ---------------------------------------------------------------------------
# ROUTES ADMIN — Login (comptes créés uniquement via seed_admins.py)
# ---------------------------------------------------------------------------
@app.post("/api/admin/login")
def admin_login(data: AdminLoginRequest):
    res = supabase.table("admins").select("*").eq("username", data.username).execute()
    if not res.data:
        raise HTTPException(401, "Identifiants incorrects.")
    admin = res.data[0]

    if not bcrypt.checkpw(data.password.encode(), admin["password_hash"].encode()):
        raise HTTPException(401, "Identifiants incorrects.")

    supabase.table("admins").update({"last_login": datetime.utcnow().isoformat()}).eq("id", admin["id"]).execute()

    token = create_admin_jwt(admin["id"], admin["username"], admin["role"])
    return {"token": token, "username": admin["username"], "role": admin["role"]}

# ---------------------------------------------------------------------------
# ROUTES ADMIN — Dashboard (protégées par JWT)
# ---------------------------------------------------------------------------
@app.get("/api/admin/clients")
def list_clients(admin=Depends(get_current_admin)):
    res = supabase.table("clients").select("*, devices(*)").order("created_at", desc=True).execute()
    return res.data

@app.get("/api/admin/clients/{client_id}")
def get_client_detail(client_id: str, admin=Depends(get_current_admin)):
    client = supabase.table("clients").select("*, devices(*)").eq("id", client_id).execute()
    echeances = supabase.table("echeances").select("*").eq("client_id", client_id).order("numero").execute()
    paiements = supabase.table("paiements").select("*").eq("client_id", client_id).execute()
    if not client.data:
        raise HTTPException(404, "Client introuvable.")
    return {
        "client": client.data[0],
        "echeances": echeances.data,
        "paiements": paiements.data,
    }

@app.post("/api/admin/restriction")
def appliquer_restriction(data: RestrictionRequest, admin=Depends(get_current_admin)):
    """
    Actions autorisées : verrouillage écran, coupure wifi/data, blocage SIM.
    La caméra n'est JAMAIS activée ni contrôlée à distance — hors périmètre du système.
    """
    device_res = supabase.table("devices").select("*").eq("client_id", data.client_id).execute()
    if not device_res.data:
        raise HTTPException(404, "Appareil introuvable.")
    device = device_res.data[0]

    if data.action in ("lock_wifi", "lock_sim", "lock_ecran"):
        nouveau_statut = "restreint"
    else:
        nouveau_statut = "normal"

    supabase.table("devices").update({"statut_appareil": nouveau_statut}).eq("id", device["id"]).execute()

    supabase.table("actions_admin").insert({
        "admin_id": admin["sub"],
        "client_id": data.client_id,
        "device_id": device["id"],
        "action": data.action,
        "raison": data.raison,
    }).execute()

    return {"message": f"Action '{data.action}' appliquée."}

@app.get("/api/admin/actions/{client_id}")
def historique_actions(client_id: str, admin=Depends(get_current_admin)):
    res = supabase.table("actions_admin").select("*").eq("client_id", client_id).order("created_at", desc=True).execute()
    return res.data

# ---------------------------------------------------------------------------
# TÂCHE PLANIFIÉE — à lancer via cron externe (ex: 1x/jour)
# ---------------------------------------------------------------------------
@app.post("/api/cron/verifier-retards")
def verifier_retards():
    """
    À appeler une fois par jour (cron / scheduler externe, ex. GitHub Actions ou Render Cron).
    Marque les échéances en retard, envoie des rappels, et restreint automatiquement
    les clients qui dépassent 7 jours de retard.
    """
    today = date.today().isoformat()
    en_retard = supabase.table("echeances").select("*, clients(*)") \
        .eq("statut", "a_payer").lt("date_prevue", today).execute()

    for ech in en_retard.data:
        supabase.table("echeances").update({"statut": "en_retard"}).eq("id", ech["id"]).execute()
        client = ech["clients"]

        jours_retard = (date.today() - date.fromisoformat(ech["date_prevue"])).days
        supabase.table("notifications").insert({
            "client_id": client["id"],
            "message": f"Échéance en retard de {jours_retard} jour(s). Merci de régulariser.",
            "type": "retard",
        }).execute()

        if jours_retard >= 7:
            supabase.table("clients").update({"statut": "bloque"}).eq("id", client["id"]).execute()
            device = supabase.table("devices").select("id").eq("client_id", client["id"]).execute()
            if device.data:
                supabase.table("devices").update({"statut_appareil": "restreint"}).eq("id", device.data[0]["id"]).execute()
                supabase.table("actions_admin").insert({
                    "client_id": client["id"],
                    "device_id": device.data[0]["id"],
                    "action": "lock_wifi",
                    "raison": f"Auto : {jours_retard} jours de retard",
                }).execute()

    return {"message": f"{len(en_retard.data)} échéance(s) traitée(s)."}

@app.get("/")
def health():
    return {"status": "ok", "project": "GGC PARTENAIRE"}