package com.nexlia.phone

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Lógica pura de SmsReader (sin Android). Datos de prueba ficticios. */
class SmsReaderTest {
    private fun row(
        id: Long, thread: Long, date: Long, type: Int = 1, read: Boolean = true, sub: Int = 1,
        body: String = "m$id", address: String = "+51900000$thread",
    ) = SmsReader.Row(id, thread, address, body, date, type, read, sub)

    @Test
    fun agrupaPorHiloYOrdenaPorElMasReciente() {
        val t = SmsReader.group(listOf(row(1, 10, 100), row(2, 20, 300), row(3, 10, 200)))
        assertEquals(listOf("20", "10"), t.map { it["threadId"] })
        assertEquals(200L, t[1]["date"])
        assertEquals("m3", t[1]["snippet"])
    }

    @Test
    fun noLeidosSoloCuentaRecibidosSinLeer() {
        val t = SmsReader.group(
            listOf(
                row(1, 10, 100, type = 1, read = false),
                row(2, 10, 110, type = 1, read = false),
                row(3, 10, 120, type = 2, read = false), // enviado: no cuenta
                row(4, 10, 130, type = 1, read = true),
            )
        )
        assertEquals(2, t.single()["unreadCount"])
    }

    @Test
    fun laSimDelHiloEsLaDelMensajeMasReciente() {
        val t = SmsReader.group(listOf(row(1, 10, 100, sub = 1), row(2, 10, 200, sub = 2)))
        assertEquals(2, t.single()["subId"])
    }

    @Test
    fun sinSmsNoHayHilos() {
        assertTrue(SmsReader.group(emptyList()).isEmpty())
    }

    @Test
    fun mapaDeMensajeConservaCampos() {
        val m = SmsReader.toMap(row(7, 10, 500, type = 2, read = false, sub = 3, body = "hola"))
        assertEquals("7", m["id"]); assertEquals("10", m["threadId"]); assertEquals("hola", m["body"])
        assertEquals(2, m["type"]); assertEquals(false, m["read"]); assertEquals(3, m["subId"])
    }

    @Test
    fun borradorSinDireccionUsaLaDireccionDeOtroMensajeDelHilo() {
        val t = SmsReader.group(
            listOf(row(1, 10, 100, address = "+51900000010"), row(2, 10, 200, type = 3, address = ""))
        )
        assertEquals("+51900000010", t.single()["address"])
    }

    @Test
    fun hiloSinNingunaDireccionQuedaVacioSinFallar() {
        val t = SmsReader.group(listOf(row(1, 10, 100, type = 3, address = "")))
        assertEquals("", t.single()["address"])
    }

    @Test
    fun fragmentoLimitado() {
        val t = SmsReader.group(listOf(row(1, 10, 100, body = "x".repeat(1000))))
        assertEquals(SmsReader.SNIPPET_MAX, (t.single()["snippet"] as String).length)
    }

    @Test
    fun subIdNoFiableSeNormalizaAMenosUno() {
        assertEquals(-1, SmsReader.normalizeSubId(null))
        assertEquals(-1, SmsReader.normalizeSubId(-1))
        assertEquals(-1, SmsReader.normalizeSubId(-5))
        assertEquals(-1, SmsReader.normalizeSubId(Int.MAX_VALUE))
        assertEquals(0, SmsReader.normalizeSubId(0))
        assertEquals(3, SmsReader.normalizeSubId(3))
    }

    @Test
    fun smsDisponibleConCualquieraDeLasDosCaracteristicas() {
        // Emulador de Android 13/14: telefonía sí, FEATURE_TELEPHONY_MESSAGING no (visto en CI).
        assertTrue(SmsReader.smsAvailable(hasTelephony = true, hasMessaging = false))
        assertTrue(SmsReader.smsAvailable(hasTelephony = false, hasMessaging = true))
        assertEquals(false, SmsReader.smsAvailable(hasTelephony = false, hasMessaging = false))
    }

    @Test
    fun erroresSeClasificanParaDart() {
        assertEquals("permission", SmsReader.classify(SecurityException("x")))
        assertEquals("permission", SmsReader.classify(SmsReader.ReadError("permission", "x")))
        assertEquals("unavailable", SmsReader.classify(SmsReader.ReadError("unavailable", "x")))
        assertEquals("provider", SmsReader.classify(IllegalStateException("cursor")))
        assertEquals("provider", SmsReader.classify(RuntimeException("base de datos ocupada")))
    }
}
