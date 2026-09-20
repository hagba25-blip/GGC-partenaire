import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'inscription_screen.dart';

class EcheancierScreen extends StatefulWidget {
  final String clientId;
  final double montantEcheance;
  const EcheancierScreen({super.key, required this.clientId, required this.montantEcheance});
  @override
  State<EcheancierScreen> createState() => _EcheancierScreenState();
}

class _EcheancierScreenState extends State<EcheancierScreen> {
  List<dynamic> echeances = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getEcheances(widget.clientId);
    setState(() {
      echeances = data;
      loading = false;
    });
  }

  Future<void> _payer(Map e) async {
    final methode = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Choisir un moyen de paiement", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.phone_iphone, color: AppColors.skyBlueDark),
              title: const Text("Mobile Money"),
              onTap: () => Navigator.pop(context, "mobile_money"),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: AppColors.skyBlueDark),
              title: const Text("Carte bancaire"),
              onTap: () => Navigator.pop(context, "carte_bancaire"),
            ),
          ],
        ),
      ),
    );
    if (methode == null) return;

    // Intégration réelle : rediriger vers Stripe Checkout ou l'API Mobile Money (MTN/Moov)
    // ici avant de confirmer le paiement côté backend.
    await ApiService.payer(
      clientId: widget.clientId,
      echeanceId: e["id"],
      methode: methode,
      reference: "TX-${DateTime.now().millisecondsSinceEpoch}",
    );
    _load();
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
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: echeances.length,
                itemBuilder: (_, i) {
                  final e = echeances[i];
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
                },
              ),
            ),
    );
  }
}
