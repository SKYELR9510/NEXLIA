package com.nexlia.phone

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.telecom.Call
import android.telecom.CallScreeningService
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.UUID

/** Ajustes, lista negra y registro del bloqueador, guardados en el teléfono. */
object SpamStore {
    const val ALLOW = 0
    const val SILENCE = 1
    const val REJECT = 2

    private fun p(ctx: Context) = ctx.getSharedPreferences("spam", Context.MODE_PRIVATE)

    fun settings(ctx: Context): JSONObject =
        try { JSONObject(p(ctx).getString("settings", "{}") ?: "{}") } catch (e: Exception) { JSONObject() }

    fun saveSettings(ctx: Context, json: String) { p(ctx).edit().putString("settings", json).apply() }

    fun blocked(ctx: Context): JSONArray =
        try { JSONArray(p(ctx).getString("blocked", "[]") ?: "[]") } catch (e: Exception) { JSONArray() }

    fun saveBlocked(ctx: Context, json: String) { p(ctx).edit().putString("blocked", json).apply() }

    fun log(ctx: Context): JSONArray =
        try { JSONArray(p(ctx).getString("log", "[]") ?: "[]") } catch (e: Exception) { JSONArray() }

    fun clearLog(ctx: Context) { p(ctx).edit().putString("log", "[]").apply() }

    @Synchronized
    fun addLog(ctx: Context, number: String, reason: String, action: Int) {
        val old = log(ctx)
        val out = JSONArray()
        out.put(JSONObject().put("number", number).put("reason", reason)
            .put("action", action).put("time", System.currentTimeMillis()))
        var i = 0
        while (i < old.length() && i < 199) { out.put(old.get(i)); i++ }
        p(ctx).edit().putString("log", out.toString()).apply()
    }

    fun deviceId(ctx: Context): String {
        val cur = p(ctx).getString("device", null)
        if (cur != null) return cur
        val id = UUID.randomUUID().toString()
        p(ctx).edit().putString("device", id).apply()
        return id
    }

    fun allJson(ctx: Context): String = JSONObject()
        .put("settings", settings(ctx)).put("blocked", blocked(ctx)).put("log", log(ctx)).toString()
}

data class Decision(val action: Int, val reason: String)

/** Reglas del bloqueador. Se evalúan en este orden y gana la primera que coincide. */
object SpamEngine {
    /** Motivo de la última decisión por número, para mostrarlo en la pantalla de llamada. */
    val lastReasons = HashMap<String, String>()

    /** Número en formato nacional peruano: solo dígitos, sin +51. */
    fun national(raw: String): String {
        val t = raw.trim()
        var d = t.filter { it.isDigit() }
        if (t.startsWith("+51")) d = d.removePrefix("51")
        else if (d.startsWith("0051")) d = d.removePrefix("0051")
        return d
    }

    fun isInternational(raw: String): Boolean {
        val t = raw.trim()
        return (t.startsWith("+") && !t.startsWith("+51")) || (t.startsWith("00") && !t.startsWith("0051"))
    }

    fun contactName(ctx: Context, number: String): String? {
        if (number.isEmpty()) return null
        if (ctx.checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) return null
        val uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number))
        try {
            ctx.contentResolver.query(uri, arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) return it.getString(0)
            }
        } catch (e: Exception) { }
        return null
    }

    fun evaluate(ctx: Context, raw: String): Decision {
        val s = SpamStore.settings(ctx)
        val spamAction = s.optInt("spamAction", SpamStore.REJECT)
        val nat = national(raw)

        // 1. Lista negra propia: siempre se rechaza.
        val blocked = SpamStore.blocked(ctx)
        for (i in 0 until blocked.length()) {
            val b = national(blocked.optString(i))
            if (b.isNotEmpty() && (b == nat || (b.length >= 9 && nat.length >= 9 && b.takeLast(9) == nat.takeLast(9)))) {
                return Decision(SpamStore.REJECT, "Número bloqueado")
            }
        }

        // 2. Número oculto o privado.
        if (nat.isEmpty()) {
            return if (s.optBoolean("blockHidden", false)) Decision(spamAction, "Número oculto")
            else Decision(SpamStore.ALLOW, "")
        }

        // 3. Los contactos siempre pasan.
        if (contactName(ctx, raw) != null) return Decision(SpamStore.ALLOW, "")

        // 4. Patrones de Perú: serie 500 (llamadas comerciales, D.S. 018-2026-MTC).
        if (s.optBoolean("peru500", true) && nat.length == 9 && nat.startsWith("500")) {
            return Decision(spamAction, "Llamada comercial (serie 500)")
        }

        // 5. Prefijos que el usuario agregó.
        val prefixes = s.optJSONArray("prefixes") ?: JSONArray()
        for (i in 0 until prefixes.length()) {
            val pre = prefixes.optString(i).filter { it.isDigit() }
            if (pre.isNotEmpty() && nat.startsWith(pre)) return Decision(spamAction, "Prefijo $pre")
        }

        // 6. Llamadas del extranjero.
        if (s.optBoolean("blockInternational", false) && isInternational(raw)) {
            return Decision(spamAction, "Llamada internacional")
        }

        // 7. Base de datos en línea.
        if (s.optBoolean("onlineEnabled", false)) {
            val r = lookup(ctx, nat)
            if (r != null && r.optInt("reportes", 0) >= s.optInt("threshold", 3)) {
                val tag = r.optString("etiqueta", "")
                return Decision(spamAction, if (tag.isNotEmpty()) "Reportado: $tag" else "Reportado como spam")
            }
        }

        // 8. Desconocidos (no está en contactos).
        return when (s.optInt("unknownMode", 0)) {
            SpamStore.SILENCE -> Decision(SpamStore.SILENCE, "Número desconocido")
            SpamStore.REJECT -> Decision(SpamStore.REJECT, "Número desconocido")
            else -> Decision(SpamStore.ALLOW, "")
        }
    }

    private fun enc(v: String) = URLEncoder.encode(v, "UTF-8")

    private fun http(url: String, post: String?, timeout: Int): String {
        val c = URL(url).openConnection() as HttpURLConnection
        try {
            c.connectTimeout = timeout
            c.readTimeout = timeout
            if (post != null) {
                c.requestMethod = "POST"
                c.doOutput = true
                c.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                c.outputStream.use { it.write(post.toByteArray()) }
            }
            return c.inputStream.bufferedReader().use { it.readText() }
        } finally {
            c.disconnect()
        }
    }

    /** Consulta rápida: el sistema solo espera unos 5 segundos antes de dejar pasar la llamada. */
    fun lookup(ctx: Context, nat: String): JSONObject? {
        val s = SpamStore.settings(ctx)
        val url = s.optString("serverUrl", "").trim()
        if (url.isEmpty()) return null
        return try {
            val q = "accion=consultar&numero=${enc(nat)}&clave=${enc(s.optString("apiKey", ""))}"
            JSONObject(http(url + (if (url.contains("?")) "&" else "?") + q, null, 1800))
        } catch (e: Exception) { null }
    }

    fun report(ctx: Context, raw: String, label: String): Boolean {
        val s = SpamStore.settings(ctx)
        val url = s.optString("serverUrl", "").trim()
        if (url.isEmpty()) return false
        return try {
            val body = "accion=reportar&numero=${enc(national(raw))}&etiqueta=${enc(label)}" +
                "&dispositivo=${enc(SpamStore.deviceId(ctx))}&clave=${enc(s.optString("apiKey", ""))}"
            JSONObject(http(url, body, 6000)).optBoolean("ok", false)
        } catch (e: Exception) { false }
    }

    fun test(ctx: Context): String {
        val s = SpamStore.settings(ctx)
        val url = s.optString("serverUrl", "").trim()
        if (url.isEmpty()) return "Falta la dirección del servidor"
        return try {
            val q = "accion=estado&clave=${enc(s.optString("apiKey", ""))}"
            val r = JSONObject(http(url + (if (url.contains("?")) "&" else "?") + q, null, 6000))
            if (r.optBoolean("ok", false)) "Conectado · ${r.optInt("numeros", 0)} números en la base"
            else "El servidor respondió: ${r.optString("error", "error")}"
        } catch (e: Exception) { "Sin conexión: ${e.message}" }
    }
}

/** Android consulta este servicio en cada llamada entrante, antes de que suene. */
class SpamScreeningService : CallScreeningService() {
    private val main = Handler(Looper.getMainLooper())

    override fun onScreenCall(details: Call.Details) {
        if (details.callDirection != Call.Details.DIRECTION_INCOMING) {
            respondToCall(details, CallResponse.Builder().build())
            return
        }
        val number = details.handle?.schemeSpecificPart ?: ""
        val ctx = applicationContext
        Thread {
            val d = try { SpamEngine.evaluate(ctx, number) } catch (e: Exception) { Decision(SpamStore.ALLOW, "") }
            val key = SpamEngine.national(number)
            if (d.action == SpamStore.ALLOW) SpamEngine.lastReasons.remove(key)
            else {
                SpamEngine.lastReasons[key] = d.reason
                SpamStore.addLog(ctx, number, d.reason, d.action)
            }
            main.post {
                val b = CallResponse.Builder()
                when (d.action) {
                    SpamStore.REJECT -> b.setDisallowCall(true).setRejectCall(true)
                        .setSkipCallLog(false).setSkipNotification(true)
                    SpamStore.SILENCE -> b.setSilenceCall(true)
                }
                try { respondToCall(details, b.build()) } catch (e: Exception) { }
            }
        }.start()
    }
}
