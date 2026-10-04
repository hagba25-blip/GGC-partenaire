import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/notification_service.dart';
import '../services/fcm_service.dart';
import '../theme/app_theme.dart';
import 'inscription_screen.dart';

class EcheancierScreen extends StatefulWidget {
  final String clientId;
  final double montantEcheance;
  final int refreshTrigger;
  const EcheancierScreen({
    super.key,
    required this.clientId,
    required this.montantEcheance,
    this.refreshTrigger = 0,
  });
  @override
  State<EcheancierScreen> createState() => _EcheancierScreenState();
}

class _EcheancierScreenState extends State<EcheancierScreen> with WidgetsBindingObserver {
  List<dynamic> echeances = [];
  List<dynamic> achats = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _envoyerPositionActuelle();
    // Filet de sécurité : garantit que le token push est bien enregistré
    // (utile si l'enregistrement initial avait échoué faute de réseau).
    FcmService.registerTokenIfPossible();
  }

  @override
  void didUpdateWidget(EcheancierScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // IndexedStack ne reconstruit pas les onglets cachés : on force le
    // rechargement quand on revient d'un nouvel achat créé via Produits.
    if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Rafraîchit l'échéancier quand l'utilisateur revient dans l'app
    // après avoir terminé (ou abandonné) le paiement dans le navigateur.
    if (state == AppLifecycleState.resumed) {
      _load();
      _envoyerPositionActuelle();
    }
  }

  Future<void> _envoyerPositionActuelle() async {
    // La tâche de fond quotidienne (WorkManager) est souvent tuée par
    // l'économiseur de batterie Android en usage réel. On rafraîchit donc
    // aussi la position à chaque retour au premier plan, pour rester fiable.
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      if (deviceId == null) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      await ApiService.updatePosition(deviceId: deviceId, lat: position.latitude, lng: position.longitude);
    } catch (_) {}
  }

  Future<void> _load() async {
    final data = await ApiService.getEcheances(widget.clientId);
    List<dynamic> achatsData = [];
    try {
      achatsData = await ApiService.getAchats(widget.clientId);
    } catch (_) {
      // Ne bloque jamais l'affichage de l'échéancier principal si les
      // échéanciers secondaires (produits) échouent à charger.
    }
    setState(() {
      echeances = data;
      achats = achatsData;
      loading = false;
    });
    // Reprogramme les rappels locaux à chaque chargement, pour rester
    // synchronisé avec les paiements effectués entre-temps.
    NotificationService.reprogrammerRappels(data);
  }

  Future<void> _payer(Map e) async {
    try {
      final checkoutUrl = await ApiService.creerPaiement(
        clientId: widget.clientId,
        echeanceId: e["id"],
      );
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Le statut se met à jour via le webhook LeekPay côté serveur ;
        // on rafraîchit l'échéancier au retour sur l'app.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Terminez le paiement, puis revenez ici.")),
          );
        }
      } else {
        throw Exception("Impossible d'ouvrir la page de paiement.");
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString().replaceFirst("Exception: ", ""))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mon échéancier"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Déconnexion",
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Déconnexion"),
                  content: const Text(
                    "Voulez-vous vraiment vous déconnecter ? Vous devrez vous "
                    "réinscrire pour retrouver l'accès à votre compte.",
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Déconnexion")),
                  ],
                ),
              );
              if (confirm == true) {
                await SessionService.clear();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const InscriptionScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : FadeIn(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...echeances.map((e) => _echeanceTile(e)),
                  if (achats.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final achat in achats) _achatSection(achat),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _echeanceTile(Map e) {
    final payee = e["statut"] == "payee";
    final retard = e["statut"] == "en_retard";
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: payee
              ? AppColors.success
              : retard
                  ? AppColors.danger
                  : AppColors.skyBlue,
          child: Icon(
            payee ? Icons.check : Icons.euro_rounded,
            color: Colors.white,
          ),
        ),
        title: Text("Échéance n°${e["numero"]} — ${e["montant"]} FCFA"),
        subtitle: Text("Prévue le ${DateFormat('dd/MM/yyyy').format(DateTime.parse(e["date_prevue"]))}"),
        trailing: payee
            ? const Text("Payée", style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))
            : ElevatedButton(
                onPressed: () => _payer(e),
                child: const Text("Payer"),
              ),
      ),
    );
  }

  /// Échéancier secondaire d'un produit acheté à crédit (ex: "Tecno —
  /// paiement"). Affiché sous l'échéancier principal, avec le même
  /// fonctionnement (même carte, même bouton Payer), sans jamais le modifier.
  Widget _achatSection(Map achat) {
    final echeancesAchat = (achat["echeances"] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            "${achat["nom"]} — Paiement",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.skyBlueDark),
          ),
        ),
        ...echeancesAchat.map((e) => _echeanceTile(e)),
      ],
    );
  }
}
