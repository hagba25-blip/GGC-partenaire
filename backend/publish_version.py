"""
GGC PARTENAIRE - Publie une nouvelle version de l'app pour mise à jour
silencieuse automatique sur tous les téléphones déjà déployés.

Usage :
    python publish_version.py chemin/vers/app-release.apk 2 "1.0.1" "Correctif notifications"

Étapes effectuées automatiquement :
  1. Copie l'APK dans backend/static/app-release.apk (écrase l'ancien)
  2. Calcule son checksum SHA-256
  3. Se connecte en tant qu'admin et enregistre la nouvelle version
  4. Régénère aussi le QR code de provisioning (nouveau checksum)

Après exécution, poussez sur git (git add . && git commit && git push)
pour que Render héberge le nouvel APK. Les téléphones déjà en circulation
la détecteront automatiquement sous 24h (tâche de fond quotidienne) et
s'installeront seuls, sans aucune action du client.
"""
import sys
import os
import shutil
import hashlib
import base64
import requests
import getpass

API_BASE_URL = "https://ggc-partenaire.onrender.com"

def compute_checksum(apk_path: str) -> str:
    sha256 = hashlib.sha256()
    with open(apk_path, "rb") as f:
        while chunk := f.read(8192):
            sha256.update(chunk)
    return base64.urlsafe_b64encode(sha256.digest()).decode("utf-8").rstrip("=")

def main():
    if len(sys.argv) < 4:
        print('Usage : python publish_version.py chemin/vers/app-release.apk VERSION_CODE "VERSION_NAME" ["notes"]')
        sys.exit(1)

    apk_path = sys.argv[1]
    version_code = int(sys.argv[2])
    version_name = sys.argv[3]
    notes = sys.argv[4] if len(sys.argv) > 4 else None

    # 1. Copie l'APK
    os.makedirs("static", exist_ok=True)
    dest = "static/app-release.apk"
    shutil.copy(apk_path, dest)
    print(f"[OK] APK copié vers {dest}")

    # 2. Checksum
    checksum = compute_checksum(dest)
    print(f"[OK] Checksum : {checksum}")

    # 3. Connexion admin + publication
    username = input("Nom d'utilisateur admin : ")
    password = getpass.getpass("Mot de passe admin : ")

    login_res = requests.post(f"{API_BASE_URL}/api/admin/login",
                               json={"username": username, "password": password})
    if login_res.status_code != 200:
        print(f"[ERREUR] Connexion admin échouée : {login_res.text}")
        sys.exit(1)
    token = login_res.json()["token"]

    publish_res = requests.post(
        f"{API_BASE_URL}/api/admin/app-version",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "version_code": version_code,
            "version_name": version_name,
            "checksum": checksum,
            "notes": notes,
        },
    )
    if publish_res.status_code != 200:
        print(f"[ERREUR] Publication échouée : {publish_res.text}")
        sys.exit(1)

    print(f"[OK] Version {version_name} (code {version_code}) publiée avec succès.")
    print("\nN'oubliez pas de pousser le nouvel APK sur git :")
    print("  git add . && git commit -m 'Publish v" + version_name + "' && git push")

if __name__ == "__main__":
    main()