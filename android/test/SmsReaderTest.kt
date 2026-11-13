package com.nexlia.phone

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Agrupación de SMS en hilos (pura, sin Android). Datos de prueba ficticios. */
class SmsReaderTest {
    private fun row(id: Long, thread: Long, date: Long, type: Int = 1, read: Boolean = true, sub: Int = 1, body: String = "m$id") =
        SmsReader.Row(id, thread, "+51900000$thread", body, date, type, read, sub)

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
}
