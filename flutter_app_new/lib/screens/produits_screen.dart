import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'choix_paiement_produit_screen.dart';

class ProduitsScreen extends StatefulWidget {
  final String clientId;
  final VoidCallback onInteretEnvoye;
  final VoidCallback? onAchatCree;
  const ProduitsScreen({
    super.key,
    required this.clientId,
    required this.onInteretEnvoye,
    this.onAchatCree,
  });

  @override
  State<ProduitsScreen> createState() => _ProduitsScreenState();
}

class _ProduitsScreenState extends State<ProduitsScreen> {
  List<dynamic> produits = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getProduits();
      setState(() { produits = data; loading = false; });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  /// Rôle original du bouton "Intéressé" : signale juste l'intérêt du
  /// client, sans créer de paiement. Appelé quand le client choisit
  /// "Non, juste que je suis intéressé" dans la boîte de confirmation.
  Future<void> _signalerInteretSimple(Map produit) async {
    try {
      await ApiService.signalerInteret(
        clientId: widget.clientId,
        type: "produit",
        itemId: produit["id"],
        itemNom: produit["nom"],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Intérêt envoyé pour ${produit["nom"]}. Consultez vos notifications.")),
      );
      widget.onInteretEnvoye();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  /// Nouveau comportement du bouton "Intéressé" : demande d'abord au
  /// client s'il veut qu'on lui crée un paiement pour ce produit, ou
  /// simplement signaler son intérêt comme avant.
  Future<void> _interesser(Map produit) async {
    final choix = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(produit["nom"] ?? "Produit"),
        content: const Text(
          "Voulez-vous que nous vous créions un plan de paiement pour "
          "ce produit, ou juste signaler votre intérêt ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Non, juste intéressé"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Oui, créez-moi un paiement"),
          ),
        ],
      ),
    );

    if (choix == true) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChoixPaiementProduitScreen(
            clientId: widget.clientId,
            produit: produit,
            onAchatCree: widget.onAchatCree,
          ),
        ),
      );
    } else if (choix == false) {
      await _signalerInteretSimple(produit);
    }
    // choix == null (dialogue fermé sans choix) : on ne fait rien,
    // exactement comme si le client n'avait pas cliqué.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nos produits")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : produits.isEmpty
              ? const Center(child: Text("Aucun produit disponible pour le moment."))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: produits.length,
                    itemBuilder: (_, i) => _ProduitCard(
                      produit: produits[i],
                      onInteresser: () => _interesser(produits[i]),
                    ),
                  ),
                ),
    );
  }
}

class _ProduitCard extends StatefulWidget {
  final Map produit;
  final VoidCallback onInteresser;
  const _ProduitCard({required this.produit, required this.onInteresser});

  @override
  State<_ProduitCard> createState() => _ProduitCardState();
}

class _ProduitCardState extends State<_ProduitCard> {
  final _pageController = PageController();
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final images = (widget.produit["images"] as List?) ?? [];
    if (images.length > 1) {
      // Fait défiler automatiquement les images comme un diaporama vidéo.
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        _page = (_page + 1) % images.length;
        _pageController.animateToPage(_page,
            duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produit;
    final images = (p["images"] as List?)?.cast<String>() ?? [];
    final formatter = NumberFormat("#,###", "fr_FR");

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                itemBuilder: (_, i) => Container(
                  // Fond derrière l'image : comble l'espace quand la photo
                  // n'a pas exactement les proportions du cadre, au lieu
                  // de rogner le produit sur les bords (BoxFit.contain
                  // affiche toujours l'image entière, sans rien couper).
                  color: AppColors.skyLight,
                  width: double.infinity,
                  child: Image.network(
                    images[i], fit: BoxFit.contain, width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.skyLight,
                      child: const Icon(Icons.image_not_supported, size: 48, color: AppColors.skyBlue),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 140, color: AppColors.skyLight,
              child: const Center(child: Icon(Icons.phone_android, size: 56, color: AppColors.skyBlue)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p["nom"] ?? "", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (p["description"] != null) ...[
                  const SizedBox(height: 6),
                  Text(p["description"], style: const TextStyle(color: AppColors.textDark)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text("Prix : ${formatter.format(p["prix_normal"])} FCFA",
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                if (p["prix_tontine"] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Prix tontine : ${formatter.format(p["prix_tontine"])} FCFA",
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onInteresser,
                    child: const Text("Intéressé"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
