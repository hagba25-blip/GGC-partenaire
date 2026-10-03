import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

/// Vérifie, télécharge et installe silencieusement les mises à jour de
/// l'app (privilège Device Owner). Appelé depuis la tâche de fond
/// quotidienne : aucune action du client n'est nécessaire.
class UpdateService {
  static const _channel = MethodChannel('ggc_partenaire/device_admin');

  static Future<void> verifierEtInstaller() async {
    try {
      final distant = await ApiService.getLatestVersion();
      final packageInfo = await PackageInfo.fromPlatform();
      final versionActuelle = int.tryParse(packageInfo.buildNumber) ?? 0;
      final versionDistante = distant["version_code"] as int;

      if (versionDistante <= versionActuelle) {
        return; // déjà à jour
      }

      final apkUrl = distant["apk_url"] as String;
      final checksumAttendu = distant["checksum"] as String;

      final fichierApk = await _telecharger(apkUrl);
      if (fichierApk == null) return;

      final checksumReel = await _calculerChecksum(fichierApk);
      if (checksumReel != checksumAttendu) {
        // Fichier corrompu ou altéré en transit : on n'installe jamais
        // un APK dont le checksum ne correspond pas exactement.
        await fichierApk.delete();
        return;
      }

      await _channel.invokeMethod('installApkSilently', {"path": fichierApk.path});
    } catch (_) {
      // Échec silencieux : la prochaine vérification quotidienne retentera.
    }
  }

  static Future<File?> _telecharger(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ggc_update.apk');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// SHA-256 encodé en base64 URL-safe sans padding, identique au format
  /// utilisé par generate_provisioning_qr.py et publish_version.py côté serveur.
  static Future<String> _calculerChecksum(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    final b64 = base64Url.encode(digest.bytes);
    return b64.replaceAll('=', ''); // retire le padding, comme côté Python
  }
}