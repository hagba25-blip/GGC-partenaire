import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/inscription_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/cgu_screen.dart';
import 'screens/choix_paiement_screen.dart';
import 'screens/echeancier_screen.dart';
import 'services/background_service.dart';
import 'services/session_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await NotificationService.requestPermissions();
  await BackgroundService.init(); // lance la tâche quotidienne (position + statut)
  runApp(const GgcPartenaireApp());
}

class GgcPartenaireApp extends StatelessWidget {
  const GgcPartenaireApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GGC PARTENAIRE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const StartupRouter(),
    );
  }
}

/// Au lancement de l'app, restaure automatiquement l'écran correspondant
/// à la dernière étape atteinte (OTP, CGU, choix paiement, échéancier).
/// Fermer/rouvrir l'app ne fait donc jamais tout recommencer.
/// Seule "Déconnexion" (dans l'échéancier) efface cette progression.
class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});
  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>?>(
      future: SessionService.getSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.data;
        if (session == null) {
          return const InscriptionScreen();
        }

        return FutureBuilder<bool>(
          future: ApiService.clientExiste(session["client_id"]!),
          builder: (context, existsSnapshot) {
            if (existsSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (existsSnapshot.data == false) {
              // La base a été réinitialisée côté serveur : on efface la
              // session locale et on repart proprement de l'inscription.
              SessionService.clear();
              return const InscriptionScreen();
            }

            switch (session["stage"]) {
              case "otp":
                return OtpScreen(clientId: session["client_id"]!, email: session["email"]!);
              case "cgu":
                return CguScreen(clientId: session["client_id"]!);
              case "paiement":
                return ChoixPaiementScreen(clientId: session["client_id"]!);
              case "echeancier":
                return _EcheancierLoader(clientId: session["client_id"]!);
              default:
                return const InscriptionScreen();
            }
          },
        );
      },
    );
  }
}

/// Recharge le montant d'échéance depuis le serveur avant d'afficher
/// l'échéancier, puisqu'il n'est pas stocké localement.
class _EcheancierLoader extends StatelessWidget {
  final String clientId;
  const _EcheancierLoader({required this.clientId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ApiService.getEcheances(clientId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final echeances = snapshot.data as List;
        final montant = echeances.isNotEmpty ? (echeances[0]["montant"] as num).toDouble() : 0.0;
        return EcheancierScreen(clientId: clientId, montantEcheance: montant);
      },
    );
  }
}
