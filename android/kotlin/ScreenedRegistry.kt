package com.nexlia.phone

import java.util.concurrent.ConcurrentHashMap

/**
 * Números que el filtro del sistema (SpamScreeningService) ya evaluó hace poco,
 * para que CallService no los vuelva a evaluar.
 *
 * Lo escriben hilos de fondo y lo lee el hilo principal: usa un mapa concurrente.
 * Las entradas antiguas se descartan para que no crezca sin límite.
 */
class ScreenedRegistry(
    private val windowMs: Long = 20_000,
    private val keepMs: Long = 120_000,
    private val maxEntries: Int = 64,
) {
    private val at = ConcurrentHashMap<String, Long>()

    fun mark(key: String, now: Long = System.currentTimeMillis()) {
        at[key] = now
        if (at.size > maxEntries) at.entries.removeIf { now - it.value > keepMs }
    }

    /** Mismo criterio que antes: evaluado hace menos de [windowMs]. */
    fun wasScreened(key: String, now: Long = System.currentTimeMillis()): Boolean {
        val t = at[key] ?: return false
        return now - t < windowMs
    }

    fun size(): Int = at.size
}
