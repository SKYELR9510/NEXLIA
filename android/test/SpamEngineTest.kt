package com.nexlia.phone

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pruebas de caracterización (Fase 0) de la normalización de números del bloqueador.
 * Fijan el comportamiento ACTUAL; los casos marcados como "limitación" documentan
 * diferencias conocidas, no el comportamiento deseado.
 */
class SpamEngineTest {
    @Test
    fun nationalQuitaElPrefijoDePeru() {
        assertEquals("987654321", SpamEngine.national("+51 987 654 321"))
        assertEquals("987654321", SpamEngine.national("0051987654321"))
        assertEquals("987654321", SpamEngine.national("987-654-321"))
        assertEquals("", SpamEngine.national(""))
    }

    @Test
    fun limitacionSinMasNoSeQuitaEl51() {
        // El sistema puede entregar el número como 51987654321 sin "+".
        // Hoy no se normaliza, y las reglas de prefijo no coinciden en ese caso.
        assertEquals("51987654321", SpamEngine.national("51987654321"))
    }

    @Test
    fun serie500TieneNueveDigitos() {
        val n = SpamEngine.national("+51 500 123 456")
        assertEquals("500123456", n)
        assertTrue(n.length == 9 && n.startsWith("500"))
    }

    @Test
    fun isInternational() {
        assertTrue(SpamEngine.isInternational("+1 305 555 0100"))
        assertTrue(SpamEngine.isInternational("0034911222333"))
        assertFalse(SpamEngine.isInternational("+51 987654321"))
        assertFalse(SpamEngine.isInternational("0051987654321"))
        assertFalse(SpamEngine.isInternational("987654321"))
        assertFalse(SpamEngine.isInternational(""))
    }
}
