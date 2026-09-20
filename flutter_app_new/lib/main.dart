import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/inscription_screen.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundService.init(); // lance la tâche quotidienne (position + statut)
  runApp(const GgcPartenaireApp());
}

class GgcPartenaireApp extends StatelessWidget {
  const GgcPartenaireApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GGC PARTENAIRE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const InscriptionScreen(),
    );
  }
}
