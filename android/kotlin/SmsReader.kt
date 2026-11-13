package com.nexlia.phone

import android.content.Context
import android.database.Cursor
import android.provider.Telephony
import android.telephony.SubscriptionManager

/**
 * Lectura de SMS del proveedor de Android (solo lectura, Fase 1).
 * NEXLIA no escribe, no copia y no envía SMS desde aquí.
 * Requiere READ_SMS; MainActivity comprueba el permiso antes de llamar.
 */
object SmsReader {
    /** Fila mínima de un SMS (independiente de Android, para poder probarla). */
    data class Row(
        val id: Long,
        val threadId: Long,
        val address: String,
        val body: String,
        val date: Long,
        val type: Int,
        val read: Boolean,
        val subId: Int,
    )

    /**
     * Agrupa SMS en hilos: el más reciente da fragmento, fecha, dirección y SIM;
     * no leídos = recibidos (type 1) sin leer. Ordenados del más reciente al más antiguo.
     */
    fun group(rows: List<Row>): List<Map<String, Any?>> =
        rows.groupBy { it.threadId }
            .map { (thread, list) ->
                val latest = list.maxByOrNull { it.date }!!
                mapOf(
                    "threadId" to thread.toString(),
                    "address" to latest.address,
                    "snippet" to latest.body,
                    "date" to latest.date,
                    "unreadCount" to list.count { it.type == Telephony.Sms.MESSAGE_TYPE_INBOX && !it.read },
                    "subId" to latest.subId,
                )
            }
            .sortedByDescending { it["date"] as Long }

    fun toMap(r: Row): Map<String, Any?> = mapOf(
        "id" to r.id.toString(),
        "threadId" to r.threadId.toString(),
        "address" to r.address,
        "body" to r.body,
        "date" to r.date,
        "type" to r.type,
        "read" to r.read,
        "subId" to r.subId,
    )

    private val baseColumns = arrayOf(
        Telephony.Sms._ID, Telephony.Sms.THREAD_ID, Telephony.Sms.ADDRESS, Telephony.Sms.BODY,
        Telephony.Sms.DATE, Telephony.Sms.TYPE, Telephony.Sms.READ,
    )

    /** Algunos fabricantes no exponen sub_id: entonces se lee sin SIM (-1). */
    private fun query(ctx: Context, selection: String?, args: Array<String>?, limit: Int): List<Row> {
        val withSub = baseColumns + Telephony.Sms.SUBSCRIPTION_ID
        val cursor: Cursor? = try {
            ctx.contentResolver.query(Telephony.Sms.CONTENT_URI, withSub, selection, args, "${Telephony.Sms.DATE} DESC")
        } catch (e: IllegalArgumentException) {
            ctx.contentResolver.query(Telephony.Sms.CONTENT_URI, baseColumns, selection, args, "${Telephony.Sms.DATE} DESC")
        }
        val out = ArrayList<Row>()
        cursor?.use { c ->
            val subIdx = c.getColumnIndex(Telephony.Sms.SUBSCRIPTION_ID)
            while (c.moveToNext() && out.size < limit) {
                out.add(
                    Row(
                        id = c.getLong(0),
                        threadId = c.getLong(1),
                        address = c.getString(2) ?: "",
                        body = c.getString(3) ?: "",
                        date = c.getLong(4),
                        type = c.getInt(5),
                        read = c.getInt(6) == 1,
                        subId = if (subIdx >= 0) c.getInt(subIdx) else -1,
                    )
                )
            }
        }
        return out
    }

    /** Hilos a partir de los últimos [scanLimit] SMS. */
    fun threads(ctx: Context, scanLimit: Int = 3000): List<Map<String, Any?>> =
        group(query(ctx, null, null, scanLimit))

    /** Mensajes de un hilo, del más antiguo al más reciente. */
    fun messages(ctx: Context, threadId: Long, limit: Int = 300): List<Map<String, Any?>> =
        query(ctx, "${Telephony.Sms.THREAD_ID}=?", arrayOf(threadId.toString()), limit)
            .reversed()
            .map { toMap(it) }

    /** SIM activas (sub_id, nombre y ranura). Requiere READ_PHONE_STATE, que la app ya pide. */
    fun subscriptions(ctx: Context): List<Map<String, Any?>> {
        val sm = ctx.getSystemService(SubscriptionManager::class.java) ?: return emptyList()
        val list = try { sm.activeSubscriptionInfoList } catch (e: SecurityException) { null } ?: return emptyList()
        return list.map {
            mapOf(
                "subId" to it.subscriptionId,
                "label" to (it.displayName?.toString() ?: ""),
                "slot" to it.simSlotIndex + 1,
            )
        }
    }
}
