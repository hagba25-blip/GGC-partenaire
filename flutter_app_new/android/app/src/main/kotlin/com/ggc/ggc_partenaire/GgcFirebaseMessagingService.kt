package com.ggc.ggc_partenaire

import android.content.Context
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * GGC PARTENAIRE — Réception des commandes de restriction en push.
 *
 * Pourquoi ce fichier existe : auparavant, le téléphone ne vérifiait son
 * statut qu'une fois par 24h via une tâche de fond (WorkManager), souvent
 * tuée par les gestionnaires de batterie Tecno/Infinix/itel — ce qui
 * pouvait laisser un appareil non réglé totalement libre pendant des
 * jours. Ce service reçoit un message silencieux (aucune notification
 * visible) envoyé par le serveur DÈS qu'un admin agit, et applique la
 * restriction en quelques secondes, via GgcPolicyManager.appliquerAction()
 * — exactement le même code que la vérification quotidienne existante,
 * qui reste active comme filet de sécurité.
 *
 * Aucune permission caméra/micro n'est utilisée ici ni ailleurs.
 */
class GgcFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        val action = remoteMessage.data["action"] ?: return
        Log.i("GGC_FCM", "Action reçue par push : $action")
        GgcPolicyManager.appliquerAction(applicationContext, action)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.i("GGC_FCM", "Nouveau token FCM généré.")
        envoyerTokenAuServeur(applicationContext, token)
    }

    companion object {
        /**
         * Envoie le token au backend via une requête HTTP simple, sans
         * dépendre du moteur Flutter (ce service peut tourner même si
         * l'app Flutter n'est pas ouverte). Échoue silencieusement :
         * le prochain démarrage de l'app (ApiService côté Dart) ou le
         * prochain renouvellement de token réessaiera.
         */
        fun envoyerTokenAuServeur(context: Context, token: String) {
            Thread {
                try {
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val deviceId = prefs.getString("flutter.device_id", null) ?: return@Thread

                    val url = URL("https://ggc-partenaire.onrender.com/api/device/fcm-token")
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.doOutput = true
                    conn.connectTimeout = 10000
                    conn.readTimeout = 10000

                    val body = org.json.JSONObject()
                        .put("device_id", deviceId)
                        .put("fcm_token", token)
                        .toString()

                    OutputStreamWriter(conn.outputStream).use { it.write(body) }
                    conn.responseCode // déclenche la requête
                    conn.disconnect()
                } catch (e: Exception) {
                    Log.w("GGC_FCM", "Échec envoi token au serveur : ${e.message}")
                }
            }.start()
        }
    }
}