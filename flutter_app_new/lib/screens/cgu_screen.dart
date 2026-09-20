import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'choix_paiement_screen.dart';

const String texteCgu = """
CONDITIONS D'UTILISATION — GGC PARTENAIRE

En installant cette application sur votre téléphone Android acheté à crédit,
vous acceptez les conditions suivantes :

1. MAINTIEN DE L'APPLICATION
L'application doit rester installée jusqu'au paiement intégral du prix
de votre téléphone. Elle ne peut pas être désinstallée avant le solde complet
de la dette (protection technique de type "Device Admin").
Une fois la dette entièrement payée, cette protection est levée automatiquement
et vous pouvez désinstaller l'application librement.

2. LOCALISATION
Une fois par jour, l'application transmet la position approximative de
l'appareil à GGC PARTENAIRE. Cette information sert uniquement à retrouver
l'appareil en cas de vol ou d'impayé prolongé, jamais à un suivi continu.

3. EN CAS DE RETARD DE PAIEMENT
Si un paiement accuse un retard prolongé (plus de 7 jours) sans régularisation,
GGC PARTENAIRE peut restreindre à distance :
   • le Wifi et les données mobiles,
   • la carte SIM (appels non essentiels),
   • l'écran de l'appareil (affichage d'un message de paiement ;
     les appels d'urgence restent toujours disponibles).

4. CE QUE L'APPLICATION NE FAIT JAMAIS
   • Elle n'active jamais votre caméra, à aucun moment, pour aucune raison.
   • Elle ne lit pas vos messages, photos, contacts ni historique de navigation.
   • Elle ne vous géolocalise pas en continu (1 seule fois par jour).

5. VOS DONNÉES
Nom, prénom, téléphone, email, date de naissance, position quotidienne
approximative et identifiant de l'appareil sont conservés le temps du
contrat et utilisés uniquement dans le cadre du recouvrement de la créance.

En cochant la case ci-dessous, vous confirmez avoir lu et accepté ces conditions.
""";

class CguScreen extends StatefulWidget {
  final String clientId;
  const CguScreen({super.key, required this.clientId});
  @override
  State<CguScreen> createState() => _CguScreenState();
}

class _CguScreenState extends State<CguScreen> {
  bool accepted = false;
  bool loading = false;

  Future<void> _continuer() async {
    setState(() => loading = true);
    try {
      await ApiService.accepterCgu(widget.clientId);
      await SessionService.markCguAccepted();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ChoixPaiementScreen(clientId: widget.clientId),
      ));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conditions d'utilisation")),
      body: FadeIn(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Text(texteCgu, style: const TextStyle(height: 1.5)),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: accepted,
                    onChanged: (v) => setState(() => accepted = v ?? false),
                    title: const Text("J'ai lu et j'accepte les conditions"),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  ElevatedButton(
                    onPressed: accepted && !loading ? _continuer : null,
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Continuer"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
