import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Remplacez par l'URL de votre backend déployé (Render, Railway, etc.)
  static const String baseUrl = "https://ggc-partenaire.onrender.com";

  static Future<Map<String, dynamic>> inscription({
    required String nom,
    required String prenom,
    required String telephone,
    required String dateNaissance,
    required String email,
    required double prixTotal,
    required String imei,
    String? modele,
    String? androidVersion,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/client/inscription"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "nom": nom,
        "prenom": prenom,
        "telephone": telephone,
        "date_naissance": dateNaissance,
        "email": email,
        "prix_total": prixTotal,
        "imei": imei,
        "modele": modele,
        "android_version": androidVersion,
      }),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/client/verify-otp"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "otp_code": code}),
    );
    return _handle(res);
  }

  static Future<void> accepterCgu(String clientId) async {
    await http.post(Uri.parse("$baseUrl/api/client/accepter-cgu?client_id=$clientId"));
  }

  static Future<Map<String, dynamic>> choixPaiement({
    required String clientId,
    required String modePaiement,
    required int dureeMois,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/client/choix-paiement"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "client_id": clientId,
        "mode_paiement": modePaiement,
        "duree_mois": dureeMois,
      }),
    );
    return _handle(res);
  }

  static Future<List<dynamic>> getEcheances(String clientId) async {
    final res = await http.get(Uri.parse("$baseUrl/api/client/$clientId/echeances"));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> payer({
    required String clientId,
    required String echeanceId,
    required String methode,
    required String reference,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/client/payer"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "client_id": clientId,
        "echeance_id": echeanceId,
        "methode": methode,
        "reference_transaction": reference,
      }),
    );
    return _handle(res);
  }

  static Future<void> updatePosition({
    required String deviceId,
    required double lat,
    required double lng,
    String? ip,
  }) async {
    await http.post(
      Uri.parse("$baseUrl/api/device/position"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"device_id": deviceId, "lat": lat, "lng": lng, "ip_address": ip}),
    );
  }

  static Future<Map<String, dynamic>> getDeviceStatut(String deviceId) async {
    final res = await http.get(Uri.parse("$baseUrl/api/device/$deviceId/statut"));
    return jsonDecode(res.body);
  }

  static Map<String, dynamic> _handle(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(body["detail"] ?? "Erreur serveur");
    }
    return body;
  }
}
