# GGC PARTENAIRE

Système complet de vente de téléphones Android à crédit :
app Flutter (client) + site admin (HTML/CSS/JS) + backend Python (FastAPI) + Supabase.

## Périmètre volontairement respecté
- ✅ Localisation : **1 fois par jour**, pas de suivi continu
- ✅ Restrictions en cas d'impayé : écran, Wifi/data, SIM
- ❌ **Aucun accès caméra**, aucune permission caméra déclarée
- ✅ CGU affichées et acceptées **avant** l'inscription complète
- ✅ Comptes admin créés uniquement via script serveur (pas d'auto-inscription publique)
- ✅ Mots de passe admin hashés en bcrypt (jamais en clair en base)

## Structure
```
ggc_partenaire/
├── supabase/schema.sql       → à exécuter dans l'éditeur SQL Supabase
├── backend/                  → FastAPI (Python)
│   ├── main.py
│   ├── seed_admins.py        → crée les 3 comptes admin (1 seule fois)
│   ├── requirements.txt
│   └── .env.example
├── flutter_app/               → app cliente Flutter
│   ├── lib/
│   └── android/               → code natif Kotlin (Device Admin)
└── admin_web/                 → site admin HTML/CSS/JS
```

## Déploiement — étapes

### 1. Supabase
1. Créez un projet sur supabase.com
2. Exécutez `supabase/schema.sql` dans l'éditeur SQL
3. Récupérez `SUPABASE_URL` et `SUPABASE_SERVICE_ROLE_KEY` (Settings → API)

### 2. Backend Python
```bash
cd backend
cp .env.example .env   # remplissez les vraies valeurs
pip install -r requirements.txt
python seed_admins.py  # crée les 3 comptes admin une seule fois
uvicorn main:app --reload
```
Déployez ensuite sur Render, Railway ou Fly.io. Configurez un **cron externe**
qui appelle `POST /api/cron/verifier-retards` une fois par jour.

### 3. Site admin
Modifiez `admin_web/config.js` avec l'URL de votre backend déployé,
puis hébergez le dossier `admin_web/` sur Netlify, Vercel ou Supabase Storage.

### 4. App Flutter
```bash
cd flutter_app
flutter pub get
```
Modifiez `lib/services/api_service.dart` (baseUrl) puis :
```bash
flutter build apk --release
```

## ⚠️ Points à valider avant mise en production

1. **Blocage SIM réel** : nécessite un déploiement en mode *Device Owner*
   (provisioning par QR code à la première mise en route de l'appareil, avant
   tout compte Google). Le code fourni pose l'architecture ; l'activation
   complète du blocage SIM demande une configuration entreprise (EMM).
2. **IMEI réel** : Android restreint l'accès à l'IMEI depuis Android 10+.
   Le code utilise l'Android ID comme identifiant unique fiable et stable ;
   discutez avec votre juriste si l'IMEI exact est réellement indispensable.
3. **Paiement Mobile Money / carte** : les appels `payer()` sont prêts côté
   backend mais doivent être branchés à un vrai fournisseur (Flutterwave,
   CinetPay, Stripe...) pour valider les transactions avant de marquer
   une échéance comme payée.
4. **Autorisation officielle** : conservez une preuve écrite (contrat client
   signé + éventuelle autorisation des autorités) accessible en cas de
   contrôle. Le champ `cgu_accepted_at` horodate l'acceptation côté client.
5. Changez tous les mots de passe admin par défaut après le premier login.
