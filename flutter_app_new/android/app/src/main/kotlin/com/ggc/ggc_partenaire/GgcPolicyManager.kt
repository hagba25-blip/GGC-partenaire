package com.ggc.ggc_partenaire

import android.app.admin.DevicePolicyManager
import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log

/**
 * GGC PARTENAIRE — Centralise toutes les opérations DevicePolicyManager.
 * Utilisé par MainActivity (MethodChannel) et par le WorkManager de fond.
 *
 * Toute action ici échoue silencieusement (avec log) si l'app n'est pas
 * Device Owner — l'app reste fonctionnelle en mode dégradé (Device Admin
 * simple) sur un appareil déjà enrôlé avec un compte Google, ce qui
 * n'empêche PAS le fonctionnement normal (inscription, paiement, etc.),
 * seulement le blocage anti-désinstallation.
 */
object GgcPolicyManager {
    private const val TAG = "GGC_DPC"

    private fun dpm(context: Context): DevicePolicyManager =
        context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    fun isDeviceOwner(context: Context): Boolean =
        GgcDeviceOwnerReceiver.isDeviceOwner(context)

    /** Bloque la désinstallation. Nécessite Device Owner. */
    fun blockUninstall(context: Context) {
        if (!isDeviceOwner(context)) {
            Log.w(TAG, "Non Device Owner : impossible de bloquer la désinstallation.")
            return
        }
        val admin = GgcDeviceOwnerReceiver.getComponentName(context)
        dpm(context).setUninstallBlocked(admin, context.packageName, true)
    }

    /** Libère l'appareil : appelé uniquement quand le serveur confirme statut = "solde". */
    fun unlockDevice(context: Context) {
        if (!isDeviceOwner(context)) return
        val admin = GgcDeviceOwnerReceiver.getComponentName(context)
        val dpm = dpm(context)

        dpm.setUninstallBlocked(admin, context.packageName, false)
        dpm.setAccountManagementDisabled(admin, "com.google", false)
        try {
            dpm.clearPackagePersistentPreferredActivities(admin, context.packageName)
        } catch (e: Exception) {
            Log.w(TAG, "clearPackagePersistentPreferredActivities: ${e.message}")
        }
        Log.i(TAG, "Appareil libéré : crédit soldé.")
    }

    /** Restriction Wifi/données en cas d'impayé prolongé. */
    fun disableWifi(context: Context) {
        try {
            val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            wifi.isWifiEnabled = false
        } catch (e: Exception) {
            Log.w(TAG, "disableWifi: ${e.message}")
        }
    }

    fun enableWifi(context: Context) {
        try {
            val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            wifi.isWifiEnabled = true
        } catch (e: Exception) {
            Log.w(TAG, "enableWifi: ${e.message}")
        }
    }

    fun lockScreenNow(context: Context) {
        if (!isDeviceOwner(context)) return
        dpm(context).lockNow()
    }

    /** Empêche l'ajout d'un nouveau compte Google (anti factory-reset furtif). */
    fun restrictNewAccounts(context: Context, restrict: Boolean) {
        if (!isDeviceOwner(context)) return
        val admin = GgcDeviceOwnerReceiver.getComponentName(context)
        dpm(context).setAccountManagementDisabled(admin, "com.google", restrict)
    }
}
