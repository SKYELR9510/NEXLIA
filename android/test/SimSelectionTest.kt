package com.nexlia.phone

import android.telecom.Call
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SimSelectionTest {

    /** Si NEXLIA ya eligió la SIM, el paso por SELECT_PHONE_ACCOUNT no muestra un segundo selector. */
    @Test
    fun sinSegundoSelectorSiYaSeEligio() {
        assertEquals("dialing", CallStates.visibleName(Call.STATE_SELECT_PHONE_ACCOUNT, alreadySelected = true))
        assertEquals("selectAccount", CallStates.visibleName(Call.STATE_SELECT_PHONE_ACCOUNT, alreadySelected = false))
    }

    @Test
    fun losDemasEstadosNoCambian() {
        for (s in listOf(Call.STATE_RINGING, Call.STATE_DIALING, Call.STATE_CONNECTING, Call.STATE_ACTIVE,
            Call.STATE_HOLDING, Call.STATE_DISCONNECTED)) {
            assertEquals(CallStates.name(s), CallStates.visibleName(s, alreadySelected = true))
            assertEquals(CallStates.name(s), CallStates.visibleName(s, alreadySelected = false))
        }
    }

    @Test
    fun cuentaGuardadaSoloSiSigueDisponible() {
        val disponibles = listOf("tel|1", "tel|2")
        assertEquals("tel|2", SimAccounts.resolve(disponibles, "tel|2"))
        assertNull("SIM desactivada", SimAccounts.resolve(disponibles, "tel|3"))
        assertNull(SimAccounts.resolve(emptyList(), "tel|1"))
        assertNull(SimAccounts.resolve(disponibles, ""))
    }
}
