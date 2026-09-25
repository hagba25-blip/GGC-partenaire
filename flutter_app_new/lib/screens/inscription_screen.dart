import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'otp_screen.dart';
import 'connexion_screen.dart';

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

  Future<Map<String, String>> _getDeviceInfo() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return {
      "imei": android.id,                              // identifiant unique stable
      "modele": "${android.manufacturer} ${android.model}",
      "android_version": "Android ${android.version.release}",
    };
  }

  /// Demande la permission de localisation et envoie une première position
  /// tout de suite après l'inscription, sans attendre le cycle de 24h.
  Future<void> _envoyerPositionInitiale(String deviceId) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // le client peut refuser ; la tâche quotidienne réessaiera
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      await ApiService.updatePosition(
        deviceId: deviceId,
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (_) {
      // Pas bloquant : la tâche de fond quotidienne réessaiera
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || dateNaissance == null) return;
    if (!emailCtrl.text.contains('@') || !emailCtrl.text.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir une adresse email valide.")),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final deviceInfo = await _getDeviceInfo();
      final res = await ApiService.inscription(
        nom: nomCtrl.text,
        prenom: prenomCtrl.text,
        telephone: telCtrl.text,
        dateNaissance: dateNaissance!.toIso8601String().split('T')[0],
        email: emailCtrl.text,
        prixTotal: double.parse(prixCtrl.text),
        imei: deviceInfo["imei"]!,
        modele: deviceInfo["modele"],
        androidVersion: deviceInfo["android_version"],
      );

      // Sauvegarde locale nécessaire pour la tâche de fond quotidienne
      // et pour restaurer l'app à cette étape si elle est fermée/rouverte.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_id', res["device_id"]);
      await prefs.setString('client_id', res["client_id"]);
      await SessionService.saveInscription(res["client_id"], res["device_id"], emailCtrl.text);

      // Première position envoyée immédiatement (l'admin n'a pas à attendre 24h)
      _envoyerPositionInitiale(res["device_id"]);

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpScreen(clientId: res["client_id"], email: emailCtrl.text),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
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
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "Email"),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Champ requis";
                    if (!RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(v)) {
                      return "Email invalide (ex: nom@exemple.com)";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _field(prixCtrl, "Prix total à payer (FCFA)", type: TextInputType.number),
                const SizedBox(height: 14),
                _datePicker(),
                const SizedBox(height: 28),
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: _submit, child: const Text("S'inscrire")),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ConnexionScreen(),
                  )),
                  child: const Text("Déjà inscrit ? Se connecter"),
                ),
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
