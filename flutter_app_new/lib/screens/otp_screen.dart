import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'cgu_screen.dart';

class OtpScreen extends StatefulWidget {
  final String clientId;
  final String email;
  const OtpScreen({super.key, required this.clientId, required this.email});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final codeCtrl = TextEditingController();
  bool loading = false;

  Future<void> _verify() async {
    setState(() => loading = true);
    try {
      await ApiService.verifyOtp(widget.email, codeCtrl.text);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => CguScreen(clientId: widget.clientId),
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
      appBar: AppBar(title: const Text("Vérification")),
      body: Center(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
