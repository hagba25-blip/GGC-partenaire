import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'otp_screen.dart';

class InscriptionScreen extends StatefulWidget {
  const InscriptionScreen({super.key});
  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final nomCtrl = TextEditingController();
  final prenomCtrl = TextEditingController();
  final telCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final prixCtrl = TextEditingController();
  DateTime? dateNaissance;
  bool loading = false;

  Future<String> _getImei() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return android.id; // Android ID (l'IMEI réel nécessite une permission système spéciale)
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || dateNaissance == null) return;
    setState(() => loading = true);
    try {
      final imei = await _getImei();
      final res = await ApiService.inscription(
        nom: nomCtrl.text,
        prenom: prenomCtrl.text,
        telephone: telCtrl.text,
        dateNaissance: dateNaissance!.toIso8601String().split('T')[0],
        email: emailCtrl.text,
        prixTotal: double.parse(prixCtrl.text),
        imei: imei,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpScreen(clientId: res["client_id"], email: emailCtrl.text),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GGC PARTENAIRE")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Icon(Icons.phone_android_rounded, size: 72, color: AppColors.skyBlueDark),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text("Inscription", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
                _field(nomCtrl, "Nom"),
                const SizedBox(height: 14),
                _field(prenomCtrl, "Prénom"),
                const SizedBox(height: 14),
                _field(telCtrl, "Numéro de téléphone", type: TextInputType.phone),
                const SizedBox(height: 14),
                _field(emailCtrl, "Email", type: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _field(prixCtrl, "Prix total à payer (FCFA)", type: TextInputType.number),
                const SizedBox(height: 14),
                _datePicker(),
                const SizedBox(height: 28),
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: _submit, child: const Text("S'inscrire")),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type}) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
      validator: (v) => (v == null || v.isEmpty) ? "Champ requis" : null,
    );
  }

  Widget _datePicker() {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          firstDate: DateTime(1940),
          lastDate: DateTime.now(),
          initialDate: DateTime(2000),
        );
        if (d != null) setState(() => dateNaissance = d);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: "Date de naissance"),
        child: Text(dateNaissance == null
            ? "Sélectionner une date"
            : "${dateNaissance!.day}/${dateNaissance!.month}/${dateNaissance!.year}"),
      ),
    );
  }
}
