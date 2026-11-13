package com.nexlia.phone

import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.sqlite.SQLiteException
import android.os.Build
import android.provider.Telephony
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager

/**
 * Lectura de SMS del proveedor de Android (solo lectura, Fase 1).
 * NEXLIA no escribe, no copia y no envía SMS desde aquí.
 *
 * Se llama siempre desde un hilo de fondo (MainActivity.bgSms). Los errores se
 * convierten en códigos para Dart: "permission", "provider" o "unavailable".
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

    /** Error de lectura con su código para Dart. */
    class ReadError(val code: String, message: String) : Exception(message)

    /** Máximo de SMS que se recorren para formar hilos (evita consultas enormes). */
    const val SCAN_LIMIT = 3000

    /** Máximo de mensajes por hilo que se muestran (los más recientes). */
    const val THREAD_LIMIT = 300

    /** Máximo de caracteres del fragmento de cada hilo. */
    const val SNIPPET_MAX = 160

    /**
     * sub_id fiable o -1. Android usa -1 (INVALID) y Int.MAX_VALUE (DEFAULT) como
     * "sin SIM concreta"; algunos fabricantes guardan valores negativos o nulos.
     */
    fun normalizeSubId(raw: Int?): Int =
        if (raw == null || raw < 0 || raw == Int.MAX_VALUE) -1 else raw

    /** Código para Dart según el tipo de error. */
    fun classify(e: Throwable): String = when (e) {
        is ReadError -> e.code
        is SecurityException -> "permission"
        else -> "provider"
    }

    /**
     * Agrupa SMS en hilos: el más reciente da fragmento, fecha y SIM; la dirección es
     * la del mensaje más reciente que la tenga (los borradores pueden venir sin ella).
     * No leídos = recibidos (type 1) sin leer. Ordenados del más reciente al más antiguo.
     */
    fun group(rows: List<Row>): List<Map<String, Any?>> =
        rows.groupBy { it.threadId }
            .map { (thread, list) ->
                val byDate = list.sortedByDescending { it.date }
                val latest = byDate.first()
                mapOf(
                    "threadId" to thread.toString(),
                    "address" to (byDate.firstOrNull { it.address.isNotBlank() }?.address ?: ""),
                    "snippet" to latest.body.take(SNIPPET_MAX),
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

    /** El dispositivo tiene mensajería SMS (las tablets sin telefonía no). */
    fun hasSmsFeature(ctx: Context): Boolean {
        val pm = ctx.packageManager
        return if (Build.VERSION.SDK_INT >= 33) pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY_MESSAGING)
        else pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
    }

    private val baseColumns = arrayOf(
        Telephony.Sms._ID, Telephony.Sms.THREAD_ID, Telephony.Sms.ADDRESS, Telephony.Sms.BODY,
        Telephony.Sms.DATE, Telephony.Sms.TYPE, Telephony.Sms.READ,
    )

    /**
     * Consulta del proveedor. Algunos fabricantes no tienen la columna sub_id:
     * entonces se repite sin ella y la SIM queda como -1 ("SIM no identificada").
     */
    private fun query(ctx: Context, selection: String?, args: Array<String>?, limit: Int): List<Row> {
        val order = "${Telephony.Sms.DATE} DESC"
        val cursor: Cursor? = try {
            ctx.contentResolver.query(
                Telephony.Sms.CONTENT_URI, baseColumns + Telephony.Sms.SUBSCRIPTION_ID, selection, args, order,
            )
        } catch (e: SecurityException) {
            throw e
        } catch (e: IllegalArgumentException) {
            ctx.contentResolver.query(Telephony.Sms.CONTENT_URI, baseColumns, selection, args, order)
        } catch (e: SQLiteException) {
            ctx.contentResolver.query(Telephony.Sms.CONTENT_URI, baseColumns, selection, args, order)
        }
        // Cursor nulo: no hay proveedor de SMS o no respondió.
        if (cursor == null) throw ReadError("unavailable", "El proveedor de SMS no respondió")
        val out = ArrayList<Row>()
        cursor.use { c ->
            val subIdx = c.getColumnIndex(Telephony.Sms.SUBSCRIPTION_ID)
            while (out.size < limit && c.moveToNext()) {
                out.add(
                    Row(
                        id = c.getLong(0),
                        threadId = c.getLong(1),
                        address = c.getString(2) ?: "",
                        body = c.getString(3) ?: "",
                        date = c.getLong(4),
                        type = c.getInt(5),
                        read = c.getInt(6) == 1,
                        subId = normalizeSubId(if (subIdx >= 0 && !c.isNull(subIdx)) c.getInt(subIdx) else null),
                    )
                )
            }
        }
        return out
    }

    /** Hilos a partir de los últimos [scanLimit] SMS. */
    fun threads(ctx: Context, scanLimit: Int = SCAN_LIMIT): List<Map<String, Any?>> =
        group(query(ctx, null, null, scanLimit))

    /** Mensajes de un hilo (los [limit] más recientes), del más antiguo al más reciente. */
    fun messages(ctx: Context, threadId: Long, limit: Int = THREAD_LIMIT): List<Map<String, Any?>> =
        query(ctx, "${Telephony.Sms.THREAD_ID}=?", arrayOf(threadId.toString()), limit)
            .reversed()
            .map { toMap(it) }

    /**
     * Ranuras del teléfono y SIM activas. Las ranuras no necesitan permisos; las SIM
     * necesitan READ_PHONE_STATE (si falta, readable=false y la lista va vacía).
     */
    fun subscriptions(ctx: Context): Map<String, Any?> {
        val tm = ctx.getSystemService(TelephonyManager::class.java)
        val slots = try {
            when {
                tm == null -> 0
                Build.VERSION.SDK_INT >= 30 -> tm.activeModemCount
                else -> @Suppress("DEPRECATION") tm.phoneCount
            }
        } catch (e: Exception) { 0 }
        val sm = ctx.getSystemService(SubscriptionManager::class.java)
        var readable = true
        val list = try {
            sm?.activeSubscriptionInfoList ?: emptyList()
        } catch (e: SecurityException) {
            readable = false
            emptyList()
        }
        return mapOf(
            "slots" to slots,
            "readable" to readable,
            "subs" to list.map {
                mapOf(
                    "subId" to it.subscriptionId,
                    "label" to (it.displayName?.toString() ?: ""),
                    "slot" to it.simSlotIndex + 1,
                )
            },
        )
    }
}
