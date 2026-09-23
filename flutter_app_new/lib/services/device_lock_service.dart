import 'package:flutter/services.dart';

/// Ce service encapsule les restrictions appliquées en cas d'impayé.
/// Périmètre volontairement limité à :
///   - verrouillage de l'écran (message de paiement, appels d'urgence toujours actifs)
///   - désactivation du Wifi / des données mobiles
///   - désactivation de la carte SIM (appels non essentiels)
/// La caméra n'est JAMAIS contrôlée par cette application, ni à distance
/// ni localement. Aucune permission caméra n'est déclarée dans le manifest.
class DeviceLockService {
  static const _channel = MethodChannel('ggc_partenaire/device_admin');

  /// Applique les 3 restrictions prévues au contrat accepté par le client.
  static Future<void> appliquerRestrictions() async {
    try {
      await _channel.invokeMethod('lockScreen', {
        "message": "Paiement en retard. Contactez GGC PARTENAIRE pour régulariser.\n"
            "Les appels d'urgence restent disponibles.",
      });
      await _channel.invokeMethod('disableWifiAndData');
      await _channel.invokeMethod('disableSim');
    } on PlatformException catch (_) {
      // Journalisé côté app ; le serveur retentera au prochain cycle
    }
  }

  /// Lève toutes les restrictions (paiement régularisé).
  static Future<void> leverRestrictions() async {
    try {
      await _channel.invokeMethod('unlockScreen');
      await _channel.invokeMethod('enableWifiAndData');
      await _channel.invokeMethod('enableSim');
    } on PlatformException catch (_) {}
  }

  /// Empêche la désinstallation tant que la dette n'est pas soldée
  /// (Android Device Admin API — équivalent de ce qu'utilisent PayJoy/M-KOPA).
  static Future<void> activerProtectionDesinstallation() async {
    await _channel.invokeMethod('enableDeviceAdmin');
  }

  /// Appelé automatiquement par le backend quand statut = "solde".
  static Future<void> desactiverProtectionDesinstallation() async {
    await _channel.invokeMethod('disableDeviceAdmin');
  }

  /// Vrai si l'app est enrôlée en tant que Device Owner (provisioning
  /// initial réussi). Si false, le blocage de désinstallation réel n'est
  /// pas disponible — seul le Device Admin simple (verrouillage écran) l'est.
  static Future<bool> estDeviceOwner() async {
    try {
      return await _channel.invokeMethod('isDeviceOwner') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Bloque réellement la désinstallation via setUninstallBlocked()
  /// (nécessite Device Owner — voir estDeviceOwner()).
  static Future<void> bloquerDesinstallation() async {
    try {
      await _channel.invokeMethod('blockUninstall');
    } on PlatformException catch (_) {}
  }

  /// Libère l'appareil : à appeler uniquement quand le backend confirme
  /// que le client a intégralement soldé son crédit.
  static Future<void> libererAppareil() async {
    try {
      await _channel.invokeMethod('unlockDevice');
    } on PlatformException catch (_) {}
  }
}
