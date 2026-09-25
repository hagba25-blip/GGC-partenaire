import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'otp_screen.dart';

class ConnexionScreen extends StatefulWidget {
  const ConnexionScreen({super.key});
  @override
  State<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends State<ConnexionScreen> {
  final emailCtrl = TextEditingController();
  bool loading = false;

  Future<void> _connecter() async {
    if (emailCtrl.text.isEmpty || !emailCtrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir une adresse email valide.")),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final res = await ApiService.connexion(emailCtrl.text);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpScreen(
          clientId: res["client_id"],
          email: emailCtrl.text,
          deviceId: res["device_id"],
          stageApresVerification: res["stage_apres_verification"],
        ),
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
      appBar: AppBar(title: const Text("Connexion")),
      body: Center(
        child: FadeInUp(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.login_rounded, size: 72, color: AppColors.skyBlueDark),
                const SizedBox(height: 16),
                const Text(
                  "Retrouvez votre compte",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Saisissez l'email utilisé lors de votre inscription.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textDark),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
                const SizedBox(height: 20),
                loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(onPressed: _connecter, child: const Text("Recevoir un code")),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
