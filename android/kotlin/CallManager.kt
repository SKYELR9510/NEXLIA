package com.livak.livak_phone

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.VideoProfile

/** Estado compartido de las llamadas entre el servicio, la actividad y Flutter. */
object CallManager {
    var appContext: Context? = null
    var service: CallService? = null
    var listener: ((Map<String, Any?>) -> Unit)? = null
    private val calls = mutableListOf<Call>()
    private val names = HashMap<String, String>()
    private val main = Handler(Looper.getMainLooper())

    private val callback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) = notifyChange()
        override fun onDetailsChanged(call: Call, details: Call.Details) = notifyChange()
    }

    val current: Call?
        get() = calls.lastOrNull { it.state != Call.STATE_DISCONNECTED } ?: calls.lastOrNull()

    val hasCall: Boolean get() = calls.isNotEmpty()

    fun add(call: Call) {
        calls.add(call)
        call.registerCallback(callback)
        notifyChange()
    }

    fun remove(call: Call) {
        call.unregisterCallback(callback)
        calls.remove(call)
        notifyChange()
    }

    fun notifyChange() {
        val snap = snapshot()
        service?.updateNotification(snap)
        listener?.invoke(snap)
    }

    fun numberOf(call: Call): String = call.details?.handle?.schemeSpecificPart ?: ""

    fun snapshot(): Map<String, Any?> {
        val c = current ?: return mapOf("type" to "call", "state" to "none")
        val number = numberOf(c)
        val name = names.getOrPut(number) {
            appContext?.let { SpamEngine.contactName(it, number) } ?: ""
        }
        val state = when (c.state) {
            Call.STATE_RINGING -> "ringing"
            Call.STATE_DIALING, Call.STATE_CONNECTING, Call.STATE_SELECT_PHONE_ACCOUNT -> "dialing"
            Call.STATE_ACTIVE -> "active"
            Call.STATE_HOLDING -> "holding"
            else -> "disconnected"
        }
        val audio = service?.callAudioState
        return mapOf(
            "type" to "call",
            "state" to state,
            "number" to number,
            "name" to name,
            "muted" to (audio?.isMuted ?: false),
            "speaker" to (audio?.route == CallAudioState.ROUTE_SPEAKER),
            "connectTime" to (c.details?.connectTimeMillis ?: 0L),
            "spam" to (SpamEngine.lastReasons[SpamEngine.national(number)] ?: ""),
            "count" to calls.size
        )
    }

    fun answer() { current?.answer(VideoProfile.STATE_AUDIO_ONLY) }

    fun hangup() {
        val c = current ?: return
        if (c.state == Call.STATE_RINGING) c.reject(false, null) else c.disconnect()
    }

    fun toggleHold() {
        val c = current ?: return
        if (c.state == Call.STATE_HOLDING) c.unhold() else if (c.state == Call.STATE_ACTIVE) c.hold()
    }

    fun dtmf(ch: Char) {
        val c = current ?: return
        c.playDtmfTone(ch)
        main.postDelayed({ c.stopDtmfTone() }, 160)
    }

    fun setMuted(on: Boolean) { service?.setMuted(on) }

    fun setSpeaker(on: Boolean) {
        service?.setAudioRoute(if (on) CallAudioState.ROUTE_SPEAKER else CallAudioState.ROUTE_WIRED_OR_EARPIECE)
    }
}
