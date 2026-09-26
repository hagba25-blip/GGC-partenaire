package com.ggc.ggc_partenaire

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * GGC PARTENAIRE — Receiver Device Owner.
 *
 * Ce receiver devient "Device Owner" uniquement s'il est activé via
 * provisioning (QR code / NFC / adb) sur un appareil sans compte Google
 * préexistant. Une fois Device Owner, l'app peut :
 *   - bloquer la désinstallation (setUninstallBlocked)
 *   - verrouiller l'écran (lockNow)
 *   - désactiver certaines fonctions système (Wifi, apps)
 * Elle NE PEUT PAS et NE DEMANDE PAS : caméra, micro, SMS, contacts.
 */
class GgcDeviceOwnerReceiver : DeviceAdminReceiver() {

    companion object {
        fun getComponentName(context: Context): ComponentName =
            ComponentName(context, GgcDeviceOwnerReceiver::class.java)

        fun isDeviceOwner(context: Context): Boolean {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            return dpm.isDeviceOwnerApp(context.packageName)
        }
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.i("GGC_DPC", "Device Admin activé.")
    }

    override fun onProfileProvisioningComplete(context: Context, intent: Intent) {
        super.onProfileProvisioningComplete(context, intent)
        // Appelé une seule fois, juste après un provisioning Device Owner réussi.
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = getComponentName(context)

        if (dpm.isDeviceOwnerApp(context.packageName)) {
            // Bloque immédiatement la désinstallation dès l'enrôlement,
            // avant même que l'inscription client ne soit terminée.
            dpm.setUninstallBlocked(admin, context.packageName, true)

            // Empêche l'ajout d'autres comptes Google tant que le crédit court
            // (évite un factory reset via un autre compte administrateur).
            dpm.setAccountManagementDisabled(admin, "com.google", true)

            Log.i("GGC_DPC", "Device Owner actif. Désinstallation bloquée.")
        }
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        return "Cette protection ne peut être retirée qu'après le paiement intégral du crédit."
    }
}
