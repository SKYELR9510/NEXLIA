package com.nexlia.phone

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

class SpamConcurrencyTest {

    @Test
    fun ventanaDeVeinteSegundos() {
        val r = ScreenedRegistry()
        r.mark("987654321", now = 1_000)
        assertTrue(r.wasScreened("987654321", now = 1_000))
        assertTrue(r.wasScreened("987654321", now = 20_999))
        assertFalse(r.wasScreened("987654321", now = 21_000))
        assertFalse(r.wasScreened("111111111", now = 1_000))
    }

    @Test
    fun descartaEntradasAntiguas() {
        val r = ScreenedRegistry(windowMs = 20_000, keepMs = 120_000, maxEntries = 64)
        repeat(100) { r.mark("viejo$it", now = 0) }
        r.mark("nuevo", now = 200_000)
        assertEquals(1, r.size())
        assertTrue(r.wasScreened("nuevo", now = 200_000))
    }

    @Test
    fun registroConcurrenteSinErrores() {
        val r = ScreenedRegistry()
        val error = AtomicReference<Throwable?>(null)
        val threads = 16
        val start = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(threads)
        repeat(threads) { t ->
            pool.execute {
                try {
                    start.await()
                    repeat(5_000) { i ->
                        val key = "9${(t * 5_000 + i) % 500}"
                        r.mark(key)
                        r.wasScreened(key)
                    }
                } catch (e: Throwable) {
                    error.set(e)
                }
            }
        }
        start.countDown()
        pool.shutdown()
        assertTrue(pool.awaitTermination(30, TimeUnit.SECONDS))
        assertEquals(null, error.get())
    }

    @Test
    fun motivosDeSpamSonUnMapaConcurrente() {
        assertTrue(SpamEngine.lastReasons is ConcurrentHashMap<*, *>)
    }

    /** Escrituras desde hilos de fondo (filtros) y lecturas desde el principal (pantalla). */
    @Test
    fun motivosDeSpamConEscriturasYLecturasSimultaneas() {
        val error = AtomicReference<Throwable?>(null)
        val threads = 12
        val start = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(threads)
        repeat(threads) { t ->
            pool.execute {
                try {
                    start.await()
                    repeat(5_000) { i ->
                        val key = "prueba$t-${i % 50}"
                        when (i % 3) {
                            0 -> SpamEngine.lastReasons[key] = "Número desconocido"
                            1 -> SpamEngine.lastReasons.remove(key)
                            else -> SpamEngine.lastReasons[key]
                        }
                        // Recorrido como el que haría una lectura completa del mapa.
                        if (i % 500 == 0) SpamEngine.lastReasons.entries.count()
                    }
                } catch (e: Throwable) {
                    error.set(e)
                }
            }
        }
        start.countDown()
        pool.shutdown()
        assertTrue(pool.awaitTermination(30, TimeUnit.SECONDS))
        assertEquals(null, error.get())
        SpamEngine.lastReasons.keys.removeIf { it.startsWith("prueba") }
    }
}
