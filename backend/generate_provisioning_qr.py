"""
GGC PARTENAIRE - Génère le QR code de provisioning Device Owner.
À exécuter UNE FOIS après chaque nouveau build d'APK (le checksum change
à chaque nouvelle version signée).

Usage :
    pip install qrcode[pil] --break-system-packages
    python generate_provisioning_qr.py chemin/vers/app-release.apk

Le QR généré (provisioning_qr.png) est à scanner sur chaque téléphone
neuf, au tout premier écran de bienvenue (avant tout compte Google),
en tapant 6 fois sur l'écran pour activer le scan QR de provisioning.
"""
import sys
import json
import hashlib
import base64
import qrcode

APK_URL = "https://ggc-partenaire.onrender.com/app/ggc-partenaire.apk"
PACKAGE_NAME = "com.ggc.ggc_partenaire"
ADMIN_RECEIVER = "com.ggc.ggc_partenaire/.GgcDeviceOwnerReceiver"

def compute_checksum(apk_path: str) -> str:
    """Calcule le SHA-256 de l'APK, encodé en base64 (format requis par Android)."""
    sha256 = hashlib.sha256()
    with open(apk_path, "rb") as f:
        while chunk := f.read(8192):
            sha256.update(chunk)
    digest = sha256.digest()
    return base64.urlsafe_b64encode(digest).decode("utf-8").rstrip("=")

def generate_qr(apk_path: str):
    checksum = compute_checksum(apk_path)

    provisioning_data = {
        "android.app.extra.PROVISIONING_DEVICE_ADMIN_COMPONENT_NAME": ADMIN_RECEIVER,
        "android.app.extra.PROVISIONING_DEVICE_ADMIN_PACKAGE_DOWNLOAD_LOCATION": APK_URL,
        "android.app.extra.PROVISIONING_DEVICE_ADMIN_SIGNATURE_CHECKSUM": checksum,
        "android.app.extra.PROVISIONING_SKIP_ENCRYPTION": False,
        "android.app.extra.PROVISIONING_LEAVE_ALL_SYSTEM_APPS_ENABLED": True,
        "android.app.extra.PROVISIONING_LOCALE": "fr_FR",
    }

    qr_content = json.dumps(provisioning_data)
    img = qrcode.make(qr_content)
    img.save("provisioning_qr.png")

    print(f"Checksum calculé : {checksum}")
    print("QR code généré : provisioning_qr.png")
    print("\nContenu JSON (pour vérification) :")
    print(json.dumps(provisioning_data, indent=2))

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage : python generate_provisioning_qr.py chemin/vers/app-release.apk")
        sys.exit(1)
    generate_qr(sys.argv[1])
