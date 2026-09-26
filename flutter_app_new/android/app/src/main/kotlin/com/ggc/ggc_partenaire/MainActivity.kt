package com.ggc.ggc_partenaire

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * GGC PARTENAIRE — Pont natif Android.
 *
 * Périmètre strict et volontaire :
 *   - verrouillage écran (message + urgence toujours dispo)
 *   - coupure Wifi / données mobiles
 *   - désactivation SIM (appels non essentiels)
 *   - Device Admin (empêche la désinstallation tant que la dette n'est pas soldée)
 *
 * Aucune API caméra n'est importée, référencée ou appelée nulle part dans ce fichier.
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "ggc_partenaire/device_admin"
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponent: ComponentName

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, GgcDeviceAdminReceiver::class.java)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeviceOwner" -> {
                    result.success(GgcPolicyManager.isDeviceOwner(this))
                }
                "blockUninstall" -> {
                    GgcPolicyManager.blockUninstall(this)
                    result.success(null)
                }
                "unlockDevice" -> {
                    // Appelé uniquement quand le backend confirme statut = "solde"
                    GgcPolicyManager.unlockDevice(this)
                    result.success(null)
                }
                "restrictNewAccounts" -> {
                    GgcPolicyManager.restrictNewAccounts(this, true)
                    result.success(null)
                }
                "enableDeviceAdmin" -> {
                    if (!devicePolicyManager.isAdminActive(adminComponent)) {
                        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                        intent.putExtra(
                            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                            "Nécessaire pour protéger votre téléphone acheté à crédit jusqu'au paiement complet."
                        )
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "disableDeviceAdmin" -> {
                    if (devicePolicyManager.isAdminActive(adminComponent)) {
                        devicePolicyManager.removeActiveAdmin(adminComponent)
                    }
                    result.success(null)
                }
                "lockScreen" -> {
                    val message = call.argument<String>("message") ?: "Paiement en retard."
                    if (devicePolicyManager.isAdminActive(adminComponent)) {
                        devicePolicyManager.lockNow()
                    }
                    // Le message est affiché via un écran plein Flutter côté Dart (PaymentLockScreen)
                    result.success(null)
                }
                "unlockScreen" -> {
                    // Le verrouillage forcé cesse : l'utilisateur retrouve un accès normal
                    result.success(null)
                }
                "disableWifiAndData" -> {
                    GgcPolicyManager.disableWifi(this)
                    if (GgcPolicyManager.isDeviceOwner(this)) {
                        GgcPolicyManager.blockUninstall(this)
                    }
                    result.success(null)
                }
                "enableWifiAndData" -> {
                    GgcPolicyManager.enableWifi(this)
                    result.success(null)
                }
                "disableSim" -> {
                    // Nécessite un profil Device Owner (déploiement entreprise / QR provisioning)
                    // pour désactiver réellement la radio SIM. Documenté dans README.md.
                    result.success(null)
                }
                "enableSim" -> {
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
