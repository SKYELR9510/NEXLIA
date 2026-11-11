package com.livak.livak_phone

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.InCallService

/** Android enlaza este servicio cuando la app es el Teléfono predeterminado. */
class CallService : InCallService() {
    private val channelId = "llamadas"
    private val notifId = 51

    override fun onCreate() {
        super.onCreate()
        CallManager.appContext = applicationContext
        CallManager.service = this
        val nm = getSystemService(NotificationManager::class.java)
        val ch = NotificationChannel(channelId, "Llamadas", NotificationManager.IMPORTANCE_HIGH)
        ch.setSound(null, null) // el timbre lo pone el sistema
        nm.createNotificationChannel(ch)
    }

    override fun onDestroy() {
        getSystemService(NotificationManager::class.java).cancel(notifId)
        CallManager.service = null
        super.onDestroy()
    }

    override fun onCallAdded(call: Call) {
        CallManager.add(call)
        try {
            startActivity(uiIntent())
        } catch (e: Exception) {
            // Si el sistema no deja abrir la pantalla, queda la notificación a pantalla completa.
        }
    }

    override fun onCallRemoved(call: Call) {
        CallManager.remove(call)
    }

    override fun onCallAudioStateChanged(audioState: CallAudioState?) {
        CallManager.notifyChange()
    }

    private fun uiIntent() = Intent(this, MainActivity::class.java)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        .putExtra("call", true)

    private fun action(name: String, code: Int): PendingIntent = PendingIntent.getBroadcast(
        this, code, Intent(this, CallActionReceiver::class.java).setAction(name),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    fun updateNotification(snap: Map<String, Any?>) {
        val nm = getSystemService(NotificationManager::class.java)
        val state = snap["state"] as? String ?: "none"
        if (state == "none" || state == "disconnected") {
            nm.cancel(notifId)
            return
        }
        val name = (snap["name"] as? String).orEmpty()
        val number = (snap["number"] as? String).orEmpty()
        val who = if (name.isNotEmpty()) name else if (number.isNotEmpty()) number else "Número oculto"
        val open = PendingIntent.getActivity(
            this, 0, uiIntent(), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setContentTitle(who)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_CALL)
            .setContentIntent(open)
        if (state == "ringing") {
            val spam = (snap["spam"] as? String).orEmpty()
            b.setContentText(if (spam.isNotEmpty()) "Posible spam · $spam" else "Llamada entrante")
            b.setFullScreenIntent(open, true)
            b.addAction(Notification.Action.Builder(null, "Rechazar", action("hangup", 1)).build())
            b.addAction(Notification.Action.Builder(null, "Contestar", action("answer", 2)).build())
        } else {
            b.setContentText(if (state == "dialing") "Llamando…" else "Llamada en curso")
            b.addAction(Notification.Action.Builder(null, "Colgar", action("hangup", 1)).build())
        }
        nm.notify(notifId, b.build())
    }
}

/** Botones Contestar / Rechazar / Colgar de la notificación. */
class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            "answer" -> CallManager.answer()
            "hangup" -> CallManager.hangup()
        }
    }
}
