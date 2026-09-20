import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'echeancier_screen.dart';

class ChoixPaiementScreen extends StatefulWidget {
  final String clientId;
  const ChoixPaiementScreen({super.key, required this.clientId});
  @override
  State<ChoixPaiementScreen> createState() => _ChoixPaiementScreenState();
}

class _ChoixPaiementScreenState extends State<ChoixPaiementScreen> {
  String mode = "mois";
  int duree = 6;
  bool loading = false;

  final modes = [
    {"value": "jour", "label": "Par jour", "icon": Icons.today_rounded},
    {"value": "semaine", "label": "Par semaine", "icon": Icons.date_range_rounded},
    {"value": "mois", "label": "Par mois", "icon": Icons.calendar_month_rounded},
  ];

  Future<void> _valider() async {
    setState(() => loading = true);
    try {
      final res = await ApiService.choixPaiement(
        clientId: widget.clientId, modePaiement: mode, dureeMois: duree,
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => EcheancierScreen(
          clientId: widget.clientId,
          montantEcheance: res["montant_echeance"].toDouble(),
        ),
      ));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mode de paiement")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: FadeInUp(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Préférez-vous payer par :", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ...modes.map((m) => Card(
                    child: RadioListTile<String>(
                      value: m["value"] as String,
                      groupValue: mode,
                      onChanged: (v) => setState(() => mode = v!),
                      title: Text(m["label"] as String),
                      secondary: Icon(m["icon"] as IconData, color: AppColors.skyBlueDark),
                    ),
                  )),
              const SizedBox(height: 24),
              const Text("Durée :", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [6, 8, 10].map((d) => ChoiceChip(
                      label: Text("$d mois"),
                      selected: duree == d,
                      onSelected: (_) => setState(() => duree = d),
                      selectedColor: AppColors.skyBlueDark,
                      labelStyle: TextStyle(color: duree == d ? Colors.white : AppColors.textDark),
                    )).toList(),
              ),
              const SizedBox(height: 32),
              loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _valider, child: const Text("Confirmer")),
            ],
          ),
        ),
      ),
    );
  }
}
