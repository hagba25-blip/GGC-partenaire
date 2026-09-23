import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// Gère les rappels de paiement affichés directement sur l'appareil du
/// client (notifications système), pour qu'il reste à jour même sans
/// ouvrir l'app. Complète les rappels côté serveur (email/SMS futurs).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    // Canal dédié aux rappels de paiement (visible dans les paramètres Android).
    const channel = AndroidNotificationChannel(
      'paiements_ggc',
      'Rappels de paiement',
      description: 'Vous rappelle vos échéances GGC PARTENAIRE',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Demande les permissions (notifications + alarmes exactes). Nécessite
  /// une Activity au premier plan : à appeler uniquement depuis main(),
  /// jamais depuis la tâche de fond (WorkManager n'a pas d'Activity).
  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  /// Reprogramme tous les rappels à partir de l'échéancier actuel.
  /// Appelé à chaque chargement de l'échéancier et par la tâche de fond
  /// quotidienne, pour rester synchronisé avec les paiements déjà faits.
  static Future<void> reprogrammerRappels(List<dynamic> echeances) async {
    await _plugin.cancelAll();

    for (final e in echeances) {
      if (e["statut"] == "payee") continue;

      final datePrevue = DateTime.parse(e["date_prevue"]);
      final numero = e["numero"];
      final montant = e["montant"];
      final id = numero is int ? numero : int.tryParse(numero.toString()) ?? 0;

      // Rappel la veille à 9h
      final rappelVeille = DateTime(datePrevue.year, datePrevue.month, datePrevue.day - 1, 9, 0);
      if (rappelVeille.isAfter(DateTime.now())) {
        await _programmer(
          id: id * 10 + 1,
          titre: "Paiement à venir demain",
          corps: "Échéance n°$numero de $montant FCFA prévue demain.",
          date: rappelVeille,
        );
      }

      // Rappel le jour même à 8h
      final rappelJour = DateTime(datePrevue.year, datePrevue.month, datePrevue.day, 8, 0);
      if (rappelJour.isAfter(DateTime.now())) {
        await _programmer(
          id: id * 10 + 2,
          titre: "Paiement dû aujourd'hui",
          corps: "Échéance n°$numero de $montant FCFA à régler aujourd'hui.",
          date: rappelJour,
        );
      }

      // Si déjà en retard, notification immédiate
      if (e["statut"] == "en_retard") {
        await _plugin.show(
          id * 10 + 3,
          "Paiement en retard",
          "Échéance n°$numero de $montant FCFA en retard. Réglez-la pour éviter une restriction.",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'paiements_ggc', 'Rappels de paiement',
              importance: Importance.high, priority: Priority.high,
            ),
          ),
        );
      }
    }
  }

  static Future<void> _programmer({
    required int id,
    required String titre,
    required String corps,
    required DateTime date,
  }) async {
    await _plugin.zonedSchedule(
      id,
      titre,
      corps,
      tz.TZDateTime.from(date, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'paiements_ggc', 'Rappels de paiement',
          importance: Importance.high, priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
