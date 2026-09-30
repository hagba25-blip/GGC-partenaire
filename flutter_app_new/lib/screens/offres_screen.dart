import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class OffresScreen extends StatefulWidget {
  final String clientId;
  final VoidCallback onInteretEnvoye;
  const OffresScreen({super.key, required this.clientId, required this.onInteretEnvoye});

  @override
  State<OffresScreen> createState() => _OffresScreenState();
}

class _OffresScreenState extends State<OffresScreen> {
  List<dynamic> offres = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getOffres();
      setState(() { offres = data; loading = false; });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Future<void> _interesser(Map offre) async {
    try {
      await ApiService.signalerInteret(
        clientId: widget.clientId,
        type: "offre",
        itemId: offre["id"],
        itemNom: offre["titre"],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Intérêt envoyé pour \"${offre["titre"]}\". Consultez vos notifications.")),
      );
      widget.onInteretEnvoye();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nos offres")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : offres.isEmpty
              ? const Center(child: Text("Aucune offre disponible pour le moment."))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: offres.length,
                    itemBuilder: (_, i) {
                      final o = offres[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (o["image"] != null)
                              Image.network(
                                o["image"], height: 140, width: double.infinity, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 100, color: AppColors.skyLight,
                                  child: const Icon(Icons.local_offer_rounded, size: 40, color: AppColors.skyBlue),
                                ),
                              )
                            else
                              Container(
                                height: 100, color: AppColors.skyLight,
                                child: const Icon(Icons.local_offer_rounded, size: 40, color: AppColors.skyBlue),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o["titre"] ?? "", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                  if (o["description"] != null) ...[
                                    const SizedBox(height: 6),
                                    Text(o["description"], style: const TextStyle(color: AppColors.textDark)),
                                  ],
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _interesser(o),
                                      child: const Text("Intéressé"),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
