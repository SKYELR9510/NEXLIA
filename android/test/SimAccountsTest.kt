package com.nexlia.phone

import android.telecom.Call
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SimAccountsTest {

    /** Con una SIM, los estados que ya existían conservan exactamente su nombre. */
    @Test
    fun estadosDeUnaSimNoCambian() {
        assertEquals("ringing", CallStates.name(Call.STATE_RINGING))
        assertEquals("dialing", CallStates.name(Call.STATE_DIALING))
        assertEquals("dialing", CallStates.name(Call.STATE_CONNECTING))
        assertEquals("active", CallStates.name(Call.STATE_ACTIVE))
        assertEquals("holding", CallStates.name(Call.STATE_HOLDING))
        assertEquals("disconnected", CallStates.name(Call.STATE_DISCONNECTED))
        assertEquals("disconnected", CallStates.name(Call.STATE_NEW))
    }

    @Test
    fun elegirCuentaTieneSuPropioEstado() {
        // Antes se mostraba como "dialing" y la llamada quedaba esperando sin selector.
        assertEquals("selectAccount", CallStates.name(Call.STATE_SELECT_PHONE_ACCOUNT))
    }

    @Test
    fun etiquetaVisible() {
        assertEquals("Claro", SimAccounts.displayLabel("Claro", 1))
        assertEquals("Movistar", SimAccounts.displayLabel("  Movistar ", 2))
        assertEquals("SIM 2", SimAccounts.displayLabel("", 2))
        assertEquals("SIM 1", SimAccounts.displayLabel(null, 1))
    }

    @Test
    fun claveDeCuenta() {
        val k = SimAccounts.key("com.android.phone/com.android.services.telephony.TelephonyConnectionService", "8951")
        assertEquals("com.android.phone/com.android.services.telephony.TelephonyConnectionService|8951", k)
        assertEquals("|", SimAccounts.key(null, null))
    }

    @Test
    fun eleccionAutomaticaSoloSiHayUnaSugerenciaClara() {
        assertEquals("a", SimAccounts.autoSelectKey(listOf("a" to true, "b" to false)))
        assertNull(SimAccounts.autoSelectKey(listOf("a" to false, "b" to false)))
        assertNull("dos sugerencias automáticas: preguntar", SimAccounts.autoSelectKey(listOf("a" to true, "b" to true)))
        assertNull(SimAccounts.autoSelectKey(emptyList()))
    }
}
