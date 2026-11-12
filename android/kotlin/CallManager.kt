package com.nexlia.phone

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.PhoneAccountHandle
import android.telecom.VideoProfile

/** Estado compartido de las llamadas entre el servicio, la actividad y Flutter. */
object CallManager {
    var appContext: Context? = null
    var service: CallService? = null
    var listener: ((Map<String, Any?>) -> Unit)? = null
    private val calls = mutableListOf<Call>()
    private val names = HashMap<String, String>()
    private val main = Handler(Looper.getMainLooper())

    /** Llamadas para las que ya se intentó la elección automática de SIM. */
    private val autoTried = HashSet<Call>()

    /** Llamadas cuya SIM ya eligió NEXLIA (no deben mostrar el selector). */
    private val autoSelected = HashSet<Call>()

    /** SIM elegida en el selector previo para la próxima llamada saliente. */
    private var preselected: PhoneAccountHandle? = null
    private var preselectedAt = 0L

    /** La registra MainActivity justo antes de placeCall con EXTRA_PHONE_ACCOUNT_HANDLE. */
    fun preselect(handle: PhoneAccountHandle) {
        preselected = handle
        preselectedAt = System.currentTimeMillis()
    }

    private val callback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            maybeAutoSelect(call)
            notifyChange()
        }
        override fun onDetailsChanged(call: Call, details: Call.Details) = notifyChange()
    }

    val current: Call?
        get() = calls.lastOrNull { it.state != Call.STATE_DISCONNECTED } ?: calls.lastOrNull()

    val hasCall: Boolean get() = calls.isNotEmpty()

    fun add(call: Call) {
        calls.add(call)
        call.registerCallback(callback)
        maybeAutoSelect(call)
        // La llamada saliente ya salió con su SIM: la preselección queda usada.
        if (call.details?.callDirection == Call.Details.DIRECTION_OUTGOING &&
            call.state != Call.STATE_SELECT_PHONE_ACCOUNT
        ) preselected = null
        notifyChange()
    }

    fun remove(call: Call) {
        call.unregisterCallback(callback)
        calls.remove(call)
        autoTried.remove(call)
        autoSelected.remove(call)
        notifyChange()
    }

    /**
     * Si Telecom pide elegir SIM y sugiere exactamente una para elegir sola
     * (p. ej. por preferencia del contacto), se usa sin mostrar el selector.
     */
    private fun maybeAutoSelect(call: Call) {
        if (call.state != Call.STATE_SELECT_PHONE_ACCOUNT || !autoTried.add(call)) return
        // 1. El usuario ya eligió la SIM en el selector previo de NEXLIA: se usa esa,
        //    sin mostrar un segundo selector (si Telecom la ofrece).
        val pre = preselected
        if (pre != null && System.currentTimeMillis() - preselectedAt < 30_000) {
            preselected = null
            val offered = SimAccounts.availableFor(call).map { SimAccounts.key(it) }
            if (offered.isEmpty() || SimAccounts.key(pre) in offered) {
                autoSelected.add(call)
                call.phoneAccountSelected(pre, false)
                return
            }
        }
        // 2. Sugerencia del sistema marcada para elegir sola.
        val suggestions = SimAccounts.suggestionsFor(call)
        val pick = SimAccounts.autoSelectKey(suggestions.map { SimAccounts.key(it.phoneAccountHandle) to it.shouldAutoSelect() })
            ?: return
        val handle = suggestions.firstOrNull { SimAccounts.key(it.phoneAccountHandle) == pick }?.phoneAccountHandle ?: return
        autoSelected.add(call)
        call.phoneAccountSelected(handle, false)
    }

    /** El usuario eligió una SIM en el selector. */
    fun selectAccount(key: String): Boolean {
        val c = calls.lastOrNull { it.state == Call.STATE_SELECT_PHONE_ACCOUNT } ?: return false
        val ctx = appContext ?: return false
        val handle = SimAccounts.availableFor(c).firstOrNull { SimAccounts.key(it) == key }
            ?: SimAccounts.handleFor(ctx, key) ?: return false
        c.phoneAccountSelected(handle, false)
        return true
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
        val state = CallStates.visibleName(c.state, c in autoSelected)
        val audio = service?.callAudioState
        val ctx = appContext
        // Etiqueta de SIM solo si el equipo tiene más de una cuenta: con una SIM no cambia nada.
        val sims = ctx?.let { SimAccounts.list(it) } ?: emptyList()
        val handle = c.details?.accountHandle
        val sim = if (sims.size >= 2 && handle != null) {
            sims.firstOrNull { it.key == SimAccounts.key(handle) }?.label.orEmpty()
        } else ""
        val accounts = if (state == "selectAccount" && ctx != null) {
            SimAccounts.choicesFor(ctx, c).map { it.toMap() }
        } else emptyList()
        return mapOf(
            "type" to "call",
            "state" to state,
            "number" to number,
            "name" to name,
            "muted" to (audio?.isMuted ?: false),
            "speaker" to (audio?.route == CallAudioState.ROUTE_SPEAKER),
            "connectTime" to (c.details?.connectTimeMillis ?: 0L),
            "spam" to (SpamEngine.lastReasons[SpamEngine.national(number)] ?: ""),
            "count" to calls.count { it.parent == null },
            "conference" to (c.details?.hasProperty(Call.Details.PROPERTY_CONFERENCE) ?: false),
            "bluetooth" to (audio?.route == CallAudioState.ROUTE_BLUETOOTH),
            "btAvailable" to (((audio?.supportedRouteMask ?: 0) and CallAudioState.ROUTE_BLUETOOTH) != 0),
            "sim" to sim,
            "accounts" to accounts
        )
    }

    fun answer() { current?.answer(VideoProfile.STATE_AUDIO_ONLY) }

    fun hangup() {
        val c = current ?: return
        if (c.state == Call.STATE_RINGING) c.reject(false, null) else c.disconnect()
    }

    /** Rechaza la llamada entrante y le envía un SMS a quien llama. */
    fun rejectWithMessage(text: String) {
        val c = current ?: return
        if (c.state == Call.STATE_RINGING) c.reject(true, text)
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

    /** Con dos llamadas: pasa a la que está en espera. */
    fun swap() { calls.firstOrNull { it.state == Call.STATE_HOLDING }?.unhold() }

    /** Con dos llamadas: las une en una conferencia (si el operador lo permite). */
    fun merge() {
        val active = calls.firstOrNull { it.state == Call.STATE_ACTIVE } ?: return
        val held = calls.firstOrNull { it.state == Call.STATE_HOLDING } ?: return
        active.conference(held)
    }

    fun setBluetooth(on: Boolean) {
        service?.setAudioRoute(if (on) CallAudioState.ROUTE_BLUETOOTH else CallAudioState.ROUTE_WIRED_OR_EARPIECE)
    }

    fun setMuted(on: Boolean) { service?.setMuted(on) }

    fun setSpeaker(on: Boolean) {
        service?.setAudioRoute(if (on) CallAudioState.ROUTE_SPEAKER else CallAudioState.ROUTE_WIRED_OR_EARPIECE)
    }
}
