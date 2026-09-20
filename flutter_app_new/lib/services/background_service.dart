import 'package:workmanager/workmanager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'device_lock_service.dart';

/// Tâche de fond exécutée UNE FOIS PAR JOUR :
/// 1. Envoie la position actuelle (pas de suivi continu)
/// 2. Vérifie auprès du serveur si l'appareil doit être restreint
/// Aucun accès caméra n'est demandé ni utilisé nulle part dans l'app.
const String dailyTask = "ggc_daily_check";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == dailyTask) {
      await _runDailyCheck();
    }
    return Future.value(true);
  });
}

Future<void> _runDailyCheck() async {
  final prefs = await SharedPreferences.getInstance();
  final deviceId = prefs.getString('device_id');
  if (deviceId == null) return;

  try {
    // Position (nécessite permission ACCESS_FINE_LOCATION, demandée explicitement à l'inscription)
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
    await ApiService.updatePosition(
      deviceId: deviceId,
      lat: position.latitude,
      lng: position.longitude,
    );

    // Vérifie le statut auprès du serveur et applique les restrictions si besoin
    final statut = await ApiService.getDeviceStatut(deviceId);
    if (statut["statut_appareil"] == "restreint") {
      await DeviceLockService.appliquerRestrictions();
    } else {
      await DeviceLockService.leverRestrictions();
    }
  } catch (e) {
    // Échec silencieux : pas de connexion, réessai au prochain cycle
  }
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      "1",
      dailyTask,
      frequency: const Duration(hours: 24),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}