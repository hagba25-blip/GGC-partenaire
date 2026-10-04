import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Enregistre le token Firebase Cloud Messaging de cet appareil auprès du
/// serveur, pour que l'admin puisse déclencher une restriction (écran,
/// Wifi, SIM) en quelques secondes au lieu d'attendre jusqu'à 24h la
/// tâche de fond quotidienne (souvent tuée par les gestionnaires de
/// batterie Tecno/Infinix/itel).
class FcmService {
  static bool _listenerActif = false;

  /// À appeler une fois, au démarrage de l'app (après Firebase.initializeApp()).
  static Future<void> init() async {
    if (!_listenerActif) {
      FirebaseMessaging.instance.onTokenRefresh.listen((nouveauToken) {
        _enregistrerSiPossible(nouveauToken);
      });
      _listenerActif = true;
    }
    await registerTokenIfPossible();
  }

  /// Récupère le token actuel et l'enregistre si un device_id est déjà
  /// connu localement (après inscription). Sans effet sinon — sera
  /// réessayé au prochain appel (ex: à l'ouverture de l'échéancier).
  static Future<void> registerTokenIfPossible() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _enregistrerSiPossible(token);
      }
    } catch (_) {
      // Pas bloquant : la vérification quotidienne reste le filet de sécurité.
    }
  }

  static Future<void> _enregistrerSiPossible(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      if (deviceId == null) return;
      await ApiService.enregistrerFcmToken(deviceId: deviceId, fcmToken: token);
    } catch (_) {}
  }
}
