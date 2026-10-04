import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Écran affiché quand le client clique "Oui, créez-moi un paiement" sur
/// un produit. Le client choisit uniquement le délai (jour/semaine/mois)
/// et la durée (3/6/8 mois) ; le prix et le nom du produit sont repris
/// automatiquement. Crée un échéancier SECONDAIRE, indépendant du crédit
/// téléphone principal.
class ChoixPaiementProduitScreen extends StatefulWidget {
  final String clientId;
  final Map produit;
  final VoidCallback? onAchatCree;

  const ChoixPaiementProduitScreen({
    super.key,
    required this.clientId,
    required this.produit,
    this.onAchatCree,
  });

  @override
  State<ChoixPaiementProduitScreen> createState() => _ChoixPaiementProduitScreenState();
}

class _ChoixPaiementProduitScreenState extends State<ChoixPaiementProduitScreen> {
  String modePaiement = "mois";
  int dureeMois = 3;
  bool loading = false;

  double get _prix => (widget.produit["prix_normal"] as num).toDouble();

  int get _nbEcheances {
    if (modePaiement == "mois") return dureeMois;
    if (modePaiement == "semaine") return dureeMois * 4;
    return dureeMois * 30; // jour
  }

  double get _montantEcheance => _prix / _nbEcheances;

  Future<void> _confirmer() async {
    setState(() => loading = true);
    try {
      await ApiService.creerAchatProduit(
        clientId: widget.clientId,
        produitId: widget.produit["id"],
        modePaiement: modePaiement,
        dureeMois: dureeMois,
      );
      if (!mounted) return;
      widget.onAchatCree?.call();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          "Échéancier créé pour ${widget.produit["nom"]}. "
          "Retrouvez-le dans 'Mon échéancier'.",
        )),
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString().replaceFirst("Exception: ", ""))),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Plan de paiement")),
      body: FadeIn(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.produit["nom"] ?? "",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_prix.toStringAsFixed(0)} FCFA",
                        style: const TextStyle(fontSize: 16, color: AppColors.skyBlueDark),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text("Délai de paiement", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text("Par jour"),
                    selected: modePaiement == "jour",
                    onSelected: (_) => setState(() => modePaiement = "jour"),
                  ),
                  ChoiceChip(
                    label: const Text("Par semaine"),
                    selected: modePaiement == "semaine",
                    onSelected: (_) => setState(() => modePaiement = "semaine"),
                  ),
                  ChoiceChip(
                    label: const Text("Par mois"),
                    selected: modePaiement == "mois",
                    onSelected: (_) => setState(() => modePaiement = "mois"),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text("Durée", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [3, 6, 8].map((d) {
                  return ChoiceChip(
                    label: Text("$d mois"),
                    selected: dureeMois == d,
                    onSelected: (_) => setState(() => dureeMois = d),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Card(
                color: AppColors.skyLight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$_nbEcheances échéance(s) de ${_montantEcheance.toStringAsFixed(0)} FCFA"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : _confirmer,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Confirmer le plan de paiement"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
