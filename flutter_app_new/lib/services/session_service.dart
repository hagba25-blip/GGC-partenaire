import 'package:shared_preferences/shared_preferences.dart';

/// Sauvegarde la progression du client à travers les étapes
/// (inscription → OTP → CGU → choix paiement → échéancier) pour que
/// fermer/rouvrir l'app ne fasse jamais recommencer depuis le début.
/// Seul un appui explicite sur "Déconnexion" efface cette progression.
class SessionService {
  static const _kClientId = 'session_client_id';
  static const _kDeviceId = 'session_device_id';
  static const _kEmail = 'session_email';
  static const _kStage = 'session_stage'; // otp | cgu | paiement | echeancier

  static Future<void> saveInscription(String clientId, String deviceId, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClientId, clientId);
    await prefs.setString(_kDeviceId, deviceId);
    await prefs.setString(_kEmail, email);
    await prefs.setString(_kStage, 'otp');
  }

  static Future<void> markOtpVerified() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStage, 'cgu');
  }

  static Future<void> markCguAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStage, 'paiement');
  }

  static Future<void> markPaiementChoisi() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStage, 'echeancier');
  }

  /// Retourne l'état sauvegardé, ou null si aucune inscription en cours.
  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString(_kClientId);
    final stage = prefs.getString(_kStage);
    if (clientId == null || stage == null) return null;
    return {
      "client_id": clientId,
      "device_id": prefs.getString(_kDeviceId) ?? "",
      "email": prefs.getString(_kEmail) ?? "",
      "stage": stage,
    };
  }

  /// Efface toute la session : uniquement appelé par "Déconnexion".
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kClientId);
    await prefs.remove(_kDeviceId);
    await prefs.remove(_kEmail);
    await prefs.remove(_kStage);
  }
}
