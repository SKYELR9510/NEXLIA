package com.nexlia.phone

/**
 * Respuestas de Flutter que esperan el resultado de un diálogo del sistema
 * (rol de marcador, permisos, selector de archivos), separadas por código de solicitud.
 *
 * Reemplaza al antiguo `pending` único, que se sobrescribía cuando llegaban dos
 * solicitudes a la vez y dejaba un Future de Dart esperando para siempre.
 * Todas las operaciones son atómicas: se puede usar desde cualquier hilo.
 */
class PendingRequests<T> {
    private val waiting = HashMap<Int, MutableList<T>>()

    /**
     * Registra [reply] para [code]. Devuelve true si es la primera en espera,
     * es decir, si quien llama debe abrir el diálogo del sistema.
     */
    @Synchronized
    fun add(code: Int, reply: T): Boolean {
        val list = waiting.getOrPut(code) { mutableListOf() }
        list.add(reply)
        return list.size == 1
    }

    @Synchronized
    fun isPending(code: Int): Boolean = waiting[code]?.isNotEmpty() == true

    /** Saca todas las respuestas en espera de [code], en orden de llegada. */
    @Synchronized
    fun take(code: Int): List<T> = waiting.remove(code) ?: emptyList()

    /** Saca todas las respuestas en espera, de cualquier código. */
    @Synchronized
    fun takeAll(): List<T> {
        val all = waiting.values.flatten()
        waiting.clear()
        return all
    }
}
