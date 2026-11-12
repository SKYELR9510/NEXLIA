package com.nexlia.phone

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telecom.Call
import android.telecom.CallAudioState
import android.os.Handler
import android.os.Looper
import android.telecom.InCallService
import android.telecom.TelecomManager

/** Android enlaza este servicio cuando la app es el Teléfono predeterminado. */
class CallService : InCallService() {
    private val ringChannel = "entrantes"
    private val ongoingChannel = "en_curso"
    private val notifId = 51

    override fun onCreate() {
        super.onCreate()
        CallManager.appContext = applicationContext
        CallManager.service = this
        val nm = getSystemService(NotificationManager::class.java)
        nm.deleteNotificationChannel("llamadas")
        val ring = NotificationChannel(ringChannel, "Llamadas entrantes", NotificationManager.IMPORTANCE_HIGH)
        ring.setSound(null, null) // el timbre lo pone el sistema
        nm.createNotificationChannel(ring)
        // Sin aviso emergente: la pantalla de llamada ya esta a la vista.
        val ongoing = NotificationChannel(ongoingChannel, "Llamada en curso", NotificationManager.IMPORTANCE_LOW)
        nm.createNotificationChannel(ongoing)
    }

    override fun onDestroy() {
        getSystemService(NotificationManager::class.java).cancel(notifId)
        CallManager.service = null
        super.onDestroy()
    }

    override fun onCallAdded(call: Call) {
        val number = CallManager.numberOf(call)
        val key = SpamEngine.national(number)
        val screened = System.currentTimeMillis() - (SpamEngine.screenedAt[key] ?: 0L) < 20000
        if (call.state != Call.STATE_RINGING || screened) {
            show(call)
            return
        }
        // Segundo filtro: si el sistema no consultó al bloqueador (pasa en algunos
        // teléfonos), la llamada se evalúa aquí antes de mostrarla.
        val ctx = applicationContext
        Thread {
            val d = try { SpamEngine.evaluate(ctx, number) } catch (e: Exception) { Decision(SpamStore.ALLOW, "") }
            if (d.action != SpamStore.ALLOW) {
                SpamEngine.lastReasons[key] = d.reason
                SpamStore.addLog(ctx, number, d.reason, d.action)
            } else SpamEngine.lastReasons.remove(key)
            Handler(Looper.getMainLooper()).post {
                when (d.action) {
                    SpamStore.REJECT -> try { call.reject(false, null) } catch (e: Exception) { show(call) }
                    SpamStore.SILENCE -> {
                        try { getSystemService(TelecomManager::class.java).silenceRinger() } catch (e: Exception) { }
                        show(call)
                    }
                    else -> show(call)
                }
            }
        }.start()
    }

    private fun show(call: Call) {
        if (call.state == Call.STATE_DISCONNECTED) return
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
        val b = Notification.Builder(this, if (state == "ringing") ringChannel else ongoingChannel)
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
            b.setContentText(
                when (state) {
                    "dialing" -> "Llamando…"
                    "selectAccount" -> "Elige una SIM para llamar"
                    else -> "Llamada en curso"
                }
            )
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
