package com.ggc.ggc_partenaire

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Receiver requis par l'API Android Device Admin.
 * Permet uniquement : verrouillage écran + blocage désinstallation.
 * N'implémente aucune capacité caméra, micro ou lecture de données personnelles.
 */
class GgcDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        return "Attention : désactiver cette protection est possible uniquement après " +
                "le paiement intégral de votre crédit."
    }
}
