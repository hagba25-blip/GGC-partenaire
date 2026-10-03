package com.ggc.ggc_partenaire

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.util.Log

/**
 * Reçoit le résultat de chaque installation silencieuse déclenchée par
 * GgcPolicyManager.installerApkSilencieusement(). Journalise uniquement ;
 * en cas d'échec, la prochaine vérification quotidienne retentera.
 */
class GgcInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)

        when (status) {
            PackageInstaller.STATUS_SUCCESS ->
                Log.i("GGC_UPDATE", "Mise à jour installée avec succès.")
            PackageInstaller.STATUS_PENDING_USER_ACTION ->
                Log.w("GGC_UPDATE", "Action utilisateur requise (ne devrait pas arriver en Device Owner).")
            else ->
                Log.e("GGC_UPDATE", "Échec installation silencieuse : $message (code $status)")
        }
    }
}
