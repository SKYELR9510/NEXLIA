package com.nexlia.phone

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** Respuesta falsa de Flutter: cuenta cuántas veces se respondió. */
private class FakeReply(val id: Int) {
    val replies = AtomicInteger(0)
    var value: Any? = null
    fun success(v: Any?) {
        value = v
        replies.incrementAndGet()
    }
}

class PendingRequestsTest {
    private val roleCode = 1001
    private val permsCode = 1002
    private val pickCode = 1003

    @Test
    fun soloLaPrimeraSolicitudAbreElDialogo() {
        val p = PendingRequests<FakeReply>()
        assertTrue(p.add(permsCode, FakeReply(1)))
        assertFalse(p.add(permsCode, FakeReply(2)))
        assertTrue(p.isPending(permsCode))
        assertEquals(listOf(1, 2), p.take(permsCode).map { it.id })
        assertFalse(p.isPending(permsCode))
        assertTrue(p.take(permsCode).isEmpty())
    }

    @Test
    fun codigosDistintosNoSeMezclan() {
        val p = PendingRequests<FakeReply>()
        assertTrue(p.add(permsCode, FakeReply(1)))
        assertTrue(p.add(roleCode, FakeReply(2)))
        assertEquals(listOf(2), p.take(roleCode).map { it.id })
        assertEquals(listOf(1), p.take(permsCode).map { it.id })
    }

    /**
     * Caso real que fallaba antes: permisos pedidos al arrancar y, a la vez,
     * el usuario toca "Activar" (rol de marcador). Con un solo `pending`, la
     * respuesta de permisos se perdía. Ahora cada una recibe exactamente una respuesta.
     */
    @Test
    fun permisosYRolAlMismoTiempoRecibenUnaRespuestaCadaUno() {
        val p = PendingRequests<FakeReply>()
        val perms = FakeReply(1)
        val role = FakeReply(2)
        p.add(permsCode, perms)
        p.add(roleCode, role)

        p.take(roleCode).forEach { it.success(true) }
        p.take(permsCode).forEach { it.success(false) }

        assertEquals(1, perms.replies.get())
        assertEquals(false, perms.value)
        assertEquals(1, role.replies.get())
        assertEquals(true, role.value)
    }

    @Test
    fun takeAllVaciaTodo() {
        val p = PendingRequests<FakeReply>()
        p.add(permsCode, FakeReply(1))
        p.add(roleCode, FakeReply(2))
        p.add(pickCode, FakeReply(3))
        assertEquals(setOf(1, 2, 3), p.takeAll().map { it.id }.toSet())
        assertTrue(p.takeAll().isEmpty())
    }

    @Test
    fun altasSimultaneasDesdeVariosHilos() {
        val p = PendingRequests<FakeReply>()
        val threads = 8
        val perThread = 1_000
        val firsts = AtomicInteger(0)
        val start = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(threads)
        repeat(threads) { t ->
            pool.execute {
                start.await()
                repeat(perThread) { i -> if (p.add(permsCode, FakeReply(t * perThread + i))) firsts.incrementAndGet() }
            }
        }
        start.countDown()
        pool.shutdown()
        assertTrue(pool.awaitTermination(30, TimeUnit.SECONDS))

        assertEquals("solo una solicitud debe abrir el diálogo", 1, firsts.get())
        val all = p.take(permsCode)
        assertEquals(threads * perThread, all.size)
        assertEquals(threads * perThread, all.map { it.id }.toSet().size)
    }

    @Test
    fun altasYRespuestasSimultaneasNoPierdenNiDuplican() {
        val p = PendingRequests<FakeReply>()
        val producers = 4
        val perProducer = 2_000
        val delivered = Collections.synchronizedList(mutableListOf<FakeReply>())
        val done = CountDownLatch(producers)
        val pool = Executors.newFixedThreadPool(producers + 1)
        repeat(producers) { t ->
            pool.execute {
                repeat(perProducer) { i -> p.add(permsCode, FakeReply(t * perProducer + i)) }
                done.countDown()
            }
        }
        // Un hilo que responde mientras siguen llegando solicitudes.
        pool.execute {
            while (done.count > 0) {
                p.take(permsCode).forEach { it.success(true); delivered.add(it) }
            }
        }
        pool.shutdown()
        assertTrue(pool.awaitTermination(30, TimeUnit.SECONDS))
        p.take(permsCode).forEach { it.success(true); delivered.add(it) }

        assertEquals(producers * perProducer, delivered.size)
        assertEquals(producers * perProducer, delivered.map { it.id }.toSet().size)
        assertTrue("cada respuesta exactamente una vez", delivered.all { it.replies.get() == 1 })
    }
}
