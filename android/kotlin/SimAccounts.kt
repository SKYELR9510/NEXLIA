package com.nexlia.phone

import android.content.Context
import android.os.Bundle
import android.telecom.Call
import android.telecom.PhoneAccountHandle
import android.telecom.PhoneAccountSuggestion
import android.telecom.TelecomManager

/** Una cuenta telefónica (normalmente una SIM) tal como se muestra en pantalla. */
data class SimInfo(val key: String, val label: String, val number: String, val slot: Int) {
    fun toMap(): Map<String, Any?> = mapOf("key" to key, "label" to label, "number" to number, "slot" to slot)
}

/** Nombres de estado que recibe Flutter. Con una sola SIM nunca aparece "selectAccount". */
object CallStates {
    fun name(state: Int): String = when (state) {
        Call.STATE_RINGING -> "ringing"
        Call.STATE_SELECT_PHONE_ACCOUNT -> "selectAccount"
        Call.STATE_DIALING, Call.STATE_CONNECTING -> "dialing"
        Call.STATE_ACTIVE -> "active"
        Call.STATE_HOLDING -> "holding"
        else -> "disconnected"
    }

    /**
     * Estado que ve la pantalla. Si NEXLIA ya eligió la SIM para esta llamada
     * (selector previo o sugerencia automática), el paso breve por
     * SELECT_PHONE_ACCOUNT se muestra como "dialing": así nunca aparecen dos selectores.
     */
    fun visibleName(state: Int, alreadySelected: Boolean): String =
        if (state == Call.STATE_SELECT_PHONE_ACCOUNT && alreadySelected) "dialing" else name(state)
}

/**
 * Cuentas telefónicas del equipo (TelecomManager). Requiere READ_PHONE_STATE,
 * que la app ya pide; sin ese permiso devuelve listas vacías y no se muestra nada nuevo.
 */
object SimAccounts {
    /** Extra con las cuentas disponibles para una llamada que espera elegir SIM. */
    private const val EXTRA_AVAILABLE = "selectPhoneAccountAccounts" // Call.AVAILABLE_PHONE_ACCOUNTS

    fun key(component: String?, id: String?): String = (component ?: "") + "|" + (id ?: "")

    fun key(h: PhoneAccountHandle): String = key(h.componentName.flattenToString(), h.id)

    /** Etiqueta del sistema (operador o "SIM 1") o, si no hay, "SIM n". */
    fun displayLabel(systemLabel: String?, slot: Int): String {
        val l = systemLabel?.trim().orEmpty()
        return if (l.isEmpty()) "SIM $slot" else l
    }

    /** Clave de la sugerencia que el sistema marca para elegir sola, si hay exactamente una. */
    fun autoSelectKey(suggestions: List<Pair<String, Boolean>>): String? =
        suggestions.filter { it.second }.map { it.first }.distinct().singleOrNull()

    fun list(ctx: Context): List<SimInfo> {
        val tm = ctx.getSystemService(TelecomManager::class.java) ?: return emptyList()
        val handles = try { tm.callCapablePhoneAccounts } catch (e: SecurityException) { emptyList() }
        return handles.mapIndexed { i, h ->
            val acc = try { tm.getPhoneAccount(h) } catch (e: Exception) { null }
            SimInfo(
                key = key(h),
                label = displayLabel(acc?.label?.toString(), i + 1),
                number = acc?.address?.schemeSpecificPart.orEmpty(),
                slot = i + 1,
            )
        }
    }

    /** [wanted] si sigue entre las cuentas disponibles; si no (SIM retirada o desactivada), null. */
    fun resolve(available: List<String>, wanted: String): String? =
        if (wanted.isNotEmpty() && wanted in available) wanted else null

    fun handleFor(ctx: Context, key: String): PhoneAccountHandle? {
        val tm = ctx.getSystemService(TelecomManager::class.java) ?: return null
        val handles = try { tm.callCapablePhoneAccounts } catch (e: SecurityException) { emptyList() }
        return handles.firstOrNull { key(it) == key }
    }

    /** Cuentas que Telecom ofrece para esta llamada (si las informa). */
    @Suppress("DEPRECATION")
    fun availableFor(call: Call?): List<PhoneAccountHandle> {
        val extras: Bundle = call?.details?.intentExtras ?: return emptyList()
        return try { extras.getParcelableArrayList<PhoneAccountHandle>(EXTRA_AVAILABLE) ?: emptyList() } catch (e: Exception) { emptyList() }
    }

    @Suppress("DEPRECATION")
    fun suggestionsFor(call: Call?): List<PhoneAccountSuggestion> {
        val extras: Bundle = call?.details?.intentExtras ?: return emptyList()
        return try {
            extras.getParcelableArrayList<PhoneAccountSuggestion>(Call.EXTRA_SUGGESTED_PHONE_ACCOUNTS) ?: emptyList()
        } catch (e: Exception) { emptyList() }
    }

    /** Opciones para el selector: las que ofrece Telecom, o todas las del equipo si no informa. */
    fun choicesFor(ctx: Context, call: Call): List<SimInfo> {
        val all = list(ctx)
        val offered = availableFor(call).map { key(it) }.toSet()
        return if (offered.isEmpty()) all else all.filter { it.key in offered }.ifEmpty { all }
    }
}
