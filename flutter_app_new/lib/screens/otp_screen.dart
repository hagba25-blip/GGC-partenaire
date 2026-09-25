import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'cgu_screen.dart';
import 'inscription_screen.dart';
import 'choix_paiement_screen.dart';
import 'echeancier_screen.dart';

class OtpScreen extends StatefulWidget {
  final String clientId;
  final String email;
  /// Renseigné uniquement lors d'une reconnexion (pas une inscription) :
  /// indique où naviguer après vérification, et permet de restaurer
  /// device_id/client_id en local puisque la session locale a été perdue.
  final String? deviceId;
  final String? stageApresVerification;

  const OtpScreen({
    super.key,
    required this.clientId,
    required this.email,
    this.deviceId,
    this.stageApresVerification,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final codeCtrl = TextEditingController();
  bool loading = false;
  bool resending = false;

  Future<void> _verify() async {
    setState(() => loading = true);
    try {
      await ApiService.verifyOtp(widget.email, codeCtrl.text);

      if (widget.stageApresVerification != null) {
        // Cas reconnexion : restaure la session locale et va directement
        // à l'étape où le client s'était arrêté.
        final prefs = await SharedPreferences.getInstance();
        if (widget.deviceId != null) {
          await prefs.setString('device_id', widget.deviceId!);
        }
        await prefs.setString('client_id', widget.clientId);
        await SessionService.saveInscription(widget.clientId, widget.deviceId ?? "", widget.email);

        if (!mounted) return;
        switch (widget.stageApresVerification) {
          case "cgu":
            await SessionService.markOtpVerified();
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => CguScreen(clientId: widget.clientId),
            ));
            break;
          case "paiement":
            await SessionService.markOtpVerified();
            await SessionService.markCguAccepted();
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => ChoixPaiementScreen(clientId: widget.clientId),
            ));
            break;
          case "echeancier":
            await SessionService.markOtpVerified();
            await SessionService.markCguAccepted();
            await SessionService.markPaiementChoisi();
            final echeances = await ApiService.getEcheances(widget.clientId);
            final montant = echeances.isNotEmpty ? (echeances[0]["montant"] as num).toDouble() : 0.0;
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => EcheancierScreen(clientId: widget.clientId, montantEcheance: montant),
            ));
            break;
        }
        return;
      }

      // Cas inscription normale
      await SessionService.markOtpVerified();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => CguScreen(clientId: widget.clientId),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => resending = true);
    try {
      await ApiService.resendOtp(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nouveau code envoyé.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      setState(() => resending = false);
    }
  }

  Future<void> _recommencer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Recommencer l'inscription"),
        content: const Text("Vous devrez saisir à nouveau toutes vos informations."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Recommencer")),
        ],
      ),
    );
    if (confirm == true) {
      await SessionService.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const InscriptionScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vérification")),
      body: SingleChildScrollView(
        child: Center(
          child: FadeInUp(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mark_email_read_rounded, size: 72, color: AppColors.skyBlueDark),
                  const SizedBox(height: 16),
                  Text("Code envoyé à ${widget.email}", textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 12),
                    decoration: const InputDecoration(counterText: ""),
                  ),
                  const SizedBox(height: 16),
                  loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(onPressed: _verify, child: const Text("Vérifier")),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: resending ? null : _resend,
                    child: resending
                        ? const SizedBox(
                            height: 16, width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Renvoyer le code"),
                  ),
                  TextButton(
                    onPressed: _recommencer,
                    child: const Text("Mauvais email ? Recommencer l'inscription",
                        style: TextStyle(color: AppColors.textDark)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
