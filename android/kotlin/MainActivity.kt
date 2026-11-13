package com.nexlia.phone

import android.Manifest
import android.app.role.RoleManager
import android.content.ContentProviderOperation
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.CallLog
import android.provider.ContactsContract
import android.provider.Settings
import android.webkit.MimeTypeMap
import android.telecom.TelecomManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var sink: EventChannel.EventSink? = null
    /** Respuestas que esperan un diálogo del sistema, una lista por código de solicitud. */
    private val pending = PendingRequests<MethodChannel.Result>()
    private var dialNumber: String? = null
    private val io = Executors.newSingleThreadExecutor()

    private val REQ_ROLE = 1001
    private val REQ_PERMS = 1002
    private val REQ_PICK = 1003
    private val REQ_SMS = 1004
    private var pickKind = "image"
    private var pendingShare: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockFlags()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CallManager.appContext = applicationContext
        dialNumber = numberFrom(intent)
        handleShare(intent)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "nexlia/phone").setMethodCallHandler { call, result ->
            try { handle(call, result) } catch (e: Exception) { result.error("error", e.message, null) }
        }
        EventChannel(messenger, "nexlia/phone/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
                pendingShare?.let { events?.success(it) }
                pendingShare = null
            }
            override fun onCancel(arguments: Any?) { sink = null }
        })
        CallManager.listener = { snap ->
            runOnUiThread {
                applyLockFlags()
                sink?.success(snap)
            }
        }
    }

    override fun onDestroy() {
        CallManager.listener = null
        // Ningún Future de Dart debe quedar esperando una pantalla que ya no existe.
        for (r in pending.takeAll()) {
            try { r.error("cancelled", "La pantalla se cerró antes de responder", null) } catch (e: Exception) { }
        }
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyLockFlags()
        handleShare(intent)
        val n = numberFrom(intent)
        if (n != null) sink?.success(mapOf("type" to "dial", "number" to n))
        if (intent.getBooleanExtra("call", false)) sink?.success(CallManager.snapshot())
    }

    /** La pantalla solo se muestra sobre el bloqueo mientras hay una llamada. */
    private fun applyLockFlags() {
        val on = CallManager.hasCall
        setShowWhenLocked(on)
        setTurnScreenOn(on)
    }

    private fun numberFrom(i: Intent?): String? {
        if (i == null) return null
        if (i.action != Intent.ACTION_DIAL && i.action != Intent.ACTION_VIEW) return null
        val d = i.data ?: return null
        return if (d.scheme == "tel") d.schemeSpecificPart else null
    }

    private fun has(p: String) = checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun bg(result: MethodChannel.Result, f: () -> Any?) {
        io.execute {
            try {
                val r = f()
                runOnUiThread { result.success(r) }
            } catch (e: Exception) {
                runOnUiThread { result.error("error", e.message, null) }
            }
        }
    }

    /** Lectura de SMS en segundo plano; los errores llegan a Dart con su código. */
    private fun bgSms(result: MethodChannel.Result, f: () -> Any?) {
        io.execute {
            try {
                if (!has(Manifest.permission.READ_SMS)) throw SmsReader.ReadError("permission", "Sin READ_SMS")
                val r = f()
                runOnUiThread { result.success(r) }
            } catch (e: Exception) {
                runOnUiThread { result.error(SmsReader.classify(e), e.message, null) }
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isDefaultDialer" -> result.success(isDefaultDialer())
            "requestDefaultDialer" -> {
                val rm = getSystemService(RoleManager::class.java)
                if (rm.isRoleAvailable(RoleManager.ROLE_DIALER) && !rm.isRoleHeld(RoleManager.ROLE_DIALER)) {
                    // Si ya hay un diálogo abierto, esta respuesta espera el mismo resultado.
                    if (pending.add(REQ_ROLE, result)) {
                        startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_DIALER), REQ_ROLE)
                    }
                } else result.success(isDefaultDialer())
            }
            "requestPermissions" -> {
                val list = arrayListOf(
                    Manifest.permission.READ_CONTACTS, Manifest.permission.WRITE_CONTACTS,
                    Manifest.permission.READ_CALL_LOG, Manifest.permission.WRITE_CALL_LOG,
                    Manifest.permission.CALL_PHONE, Manifest.permission.READ_PHONE_STATE
                )
                if (Build.VERSION.SDK_INT >= 33) list.add(Manifest.permission.POST_NOTIFICATIONS)
                val missing = list.filter { !has(it) }
                if (missing.isEmpty()) result.success(true)
                else if (pending.add(REQ_PERMS, result)) {
                    requestPermissions(missing.toTypedArray(), REQ_PERMS)
                }
            }
            "getContacts" -> bg(result) { contacts() }
            "getCallLog" -> bg(result) { callLog() }
            "deleteCallLog" -> bg(result) {
                val id = (call.argument<Number>("id") ?: 0).toLong()
                contentResolver.delete(CallLog.Calls.CONTENT_URI, CallLog.Calls._ID + "=?", arrayOf(id.toString()))
                true
            }
            "placeCall" -> {
                val number = call.argument<String>("number") ?: ""
                val account = call.argument<String>("account").orEmpty()
                if (number.isEmpty() || !has(Manifest.permission.CALL_PHONE)) result.success(false)
                else {
                    val extras = Bundle()
                    if (account.isNotEmpty()) {
                        // SIM elegida en NEXLIA antes de llamar. Si ya no existe (retirada o
                        // desactivada), no se usa una cuenta inválida: Flutter vuelve a preguntar.
                        val handle = SimAccounts.handleFor(this, account)
                        if (handle == null) {
                            result.error("sim_unavailable", "La SIM elegida ya no está disponible", null)
                            return
                        }
                        extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, handle)
                        CallManager.preselect(handle)
                    }
                    // Sin "account" (una sola SIM): Bundle vacío, exactamente como antes.
                    getSystemService(TelecomManager::class.java).placeCall(Uri.fromParts("tel", number, null), extras)
                    result.success(true)
                }
            }
            "addContact" -> bg(result) {
                addContact(call.argument<String>("name") ?: "", call.argument<String>("number") ?: "")
                true
            }
            "deleteContact" -> bg(result) {
                val id = (call.argument<String>("id") ?: "0").toLong()
                contentResolver.delete(ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, id), null, null)
                true
            }
            "setStarred" -> bg(result) {
                val id = (call.argument<String>("id") ?: "0").toLong()
                val v = ContentValues()
                v.put(ContactsContract.Contacts.STARRED, if (call.argument<Boolean>("starred") == true) 1 else 0)
                contentResolver.update(ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, id), v, null, null)
                true
            }
            "getContactPhoto" -> bg(result) {
                val id = (call.argument<String>("id") ?: "0").toLong()
                val uri = ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, id)
                ContactsContract.Contacts.openContactPhotoInputStream(
                    contentResolver, uri, call.argument<Boolean>("big") == true
                )?.use { it.readBytes() }
            }
            "getCallState" -> result.success(CallManager.snapshot())
            "answer" -> { CallManager.answer(); result.success(true) }
            "hangup" -> { CallManager.hangup(); result.success(true) }
            "toggleHold" -> { CallManager.toggleHold(); result.success(true) }
            "setMuted" -> { CallManager.setMuted(call.argument<Boolean>("on") == true); result.success(true) }
            "setSpeaker" -> { CallManager.setSpeaker(call.argument<Boolean>("on") == true); result.success(true) }
            "rejectWithMessage" -> {
                CallManager.rejectWithMessage(call.argument<String>("text") ?: "")
                result.success(true)
            }
            "sendSms" -> {
                val n = call.argument<String>("number") ?: ""
                result.success(try {
                    startActivity(Intent(Intent.ACTION_SENDTO, Uri.fromParts("smsto", n, null))); true
                } catch (e: Exception) { false })
            }
            "openWhatsApp" -> {
                var d = (call.argument<String>("number") ?: "").filter { it.isDigit() }
                if (d.length == 9 && d.startsWith("9")) d = "51$d"
                result.success(try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$d"))); true
                } catch (e: Exception) { false })
            }
            "selectPhoneAccount" -> result.success(CallManager.selectAccount(call.argument<String>("key") ?: ""))
            "getSimAccounts" -> result.success(SimAccounts.list(this).map { it.toMap() })
            "swapCalls" -> { CallManager.swap(); result.success(true) }
            "mergeCalls" -> { CallManager.merge(); result.success(true) }
            "setBluetooth" -> { CallManager.setBluetooth(call.argument<Boolean>("on") == true); result.success(true) }
            "dtmf" -> {
                val d = call.argument<String>("digit") ?: ""
                if (d.isNotEmpty()) CallManager.dtmf(d[0])
                result.success(true)
            }
            "takeDialNumber" -> { result.success(dialNumber); dialNumber = null }
            "getPref" -> result.success(
                getSharedPreferences("ui", MODE_PRIVATE).getString(call.argument<String>("key") ?: "", null))
            "setPref" -> {
                getSharedPreferences("ui", MODE_PRIVATE).edit()
                    .putString(call.argument<String>("key") ?: "", call.argument<String>("value")).apply()
                result.success(true)
            }
            "getVersion" -> result.success(packageManager.getPackageInfo(packageName, 0).versionName ?: "")
            "callVoicemail" -> {
                if (!has(Manifest.permission.CALL_PHONE)) result.success(false)
                else {
                    getSystemService(TelecomManager::class.java)
                        .placeCall(Uri.fromParts("voicemail", "", null), Bundle())
                    result.success(true)
                }
            }
            "openSettings" -> {
                val i = when (call.argument<String>("which")) {
                    "notifications" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    "sound" -> Intent(Settings.ACTION_SOUND_SETTINGS)
                    "sim" -> Intent(Settings.ACTION_WIRELESS_SETTINGS)
                    "defaults" -> Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
                    "app" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
                    else -> Intent(Settings.ACTION_SETTINGS)
                }
                try { startActivity(i) } catch (e: Exception) { startActivity(Intent(Settings.ACTION_SETTINGS)) }
                result.success(true)
            }
            "pickMedia" -> {
                // No se pueden abrir dos selectores a la vez.
                if (pending.isPending(REQ_PICK)) {
                    result.error("busy", "Ya hay un selector abierto", null)
                    return
                }
                pickKind = call.argument<String>("kind") ?: "image"
                pending.add(REQ_PICK, result)
                val i = Intent(Intent.ACTION_GET_CONTENT)
                    .setType(when (pickKind) { "video" -> "video/*"; "audio" -> "audio/*"; else -> "image/*" })
                    .addCategory(Intent.CATEGORY_OPENABLE)
                startActivityForResult(i, REQ_PICK)
            }
            "removeMedia" -> {
                val prefix = prefixFor(call.argument<String>("kind") ?: "image")
                filesDir.listFiles()?.filter { it.name.startsWith(prefix) }?.forEach { it.delete() }
                result.success(true)
            }
            "ringerNormal" -> result.success(
                getSystemService(AudioManager::class.java).ringerMode == AudioManager.RINGER_MODE_NORMAL)
            "silenceRinger" -> {
                try { getSystemService(TelecomManager::class.java).silenceRinger() } catch (e: Exception) { }
                result.success(true)
            }
            // ---- SMS de solo lectura (Fase 1). Sin READ_SMS no se lee nada. ----
            "smsPermission" -> result.success(
                when {
                    !SmsReader.hasSmsFeature(this) -> "unavailable"
                    has(Manifest.permission.READ_SMS) -> "granted"
                    else -> "denied"
                }
            )
            "requestSmsPermission" -> {
                if (has(Manifest.permission.READ_SMS)) result.success(true)
                else if (pending.add(REQ_SMS, result)) {
                    requestPermissions(arrayOf(Manifest.permission.READ_SMS), REQ_SMS)
                }
            }
            "getSmsThreads" -> bgSms(result) { SmsReader.threads(this) }
            "getSmsMessages" -> {
                val id = (call.argument<String>("threadId") ?: "").toLongOrNull()
                if (id == null) result.success(emptyList<Map<String, Any?>>())
                else bgSms(result) { SmsReader.messages(this, id) }
            }
            "getSimSubscriptions" -> bg(result) { SmsReader.subscriptions(this) }
            "getSpamData" -> result.success(SpamStore.allJson(this))
            "setSpamSettings" -> { SpamStore.saveSettings(this, call.argument<String>("json") ?: "{}"); result.success(true) }
            "setBlocked" -> { SpamStore.saveBlocked(this, call.argument<String>("json") ?: "[]"); result.success(true) }
            "clearSpamLog" -> { SpamStore.clearLog(this); result.success(true) }
            "reportSpam" -> bg(result) {
                SpamEngine.report(applicationContext, call.argument<String>("number") ?: "", call.argument<String>("label") ?: "")
            }
            "testServer" -> bg(result) { SpamEngine.test(applicationContext) }
            else -> result.notImplemented()
        }
    }

    private fun prefixFor(kind: String) = when (kind) {
        "video" -> "ring_video_"
        "audio" -> "ring_tone_"
        else -> "call_bg_"
    }

    /** Guarda una copia dentro de la app para que siga disponible siempre. */
    private fun importMedia(kind: String, uri: Uri): String {
        val prefix = prefixFor(kind)
        val fromMime = MimeTypeMap.getSingleton().getExtensionFromMimeType(contentResolver.getType(uri))
        val ext = fromMime ?: when (kind) { "video" -> "mp4"; "audio" -> "mp3"; else -> "jpg" }
        val out = File(filesDir, prefix + System.currentTimeMillis() + "." + ext)
        contentResolver.openInputStream(uri)?.use { input ->
            out.outputStream().use { input.copyTo(it) }
        } ?: throw IllegalStateException("No se pudo leer el archivo")
        filesDir.listFiles()?.filter { it.name.startsWith(prefix) && it.name != out.name }?.forEach { it.delete() }
        return out.absolutePath
    }

    /** Video o audio enviado desde otra app con Compartir > NEXLIA. */
    private fun handleShare(i: Intent?) {
        if (i?.action != Intent.ACTION_SEND) return
        @Suppress("DEPRECATION")
        val uri = i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return
        val type = i.type ?: contentResolver.getType(uri) ?: ""
        val kind = when {
            type.startsWith("video/") -> "video"
            type.startsWith("audio/") -> "audio"
            else -> return
        }
        io.execute {
            try {
                val ev = mapOf("type" to "shared", "kind" to kind, "path" to importMedia(kind, uri))
                runOnUiThread { if (sink != null) sink?.success(ev) else pendingShare = ev }
            } catch (e: Exception) { }
        }
    }

    private fun isDefaultDialer(): Boolean =
        getSystemService(TelecomManager::class.java).defaultDialerPackage == packageName

    private fun contacts(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (!has(Manifest.permission.READ_CONTACTS)) return out
        val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
        val cols = arrayOf(
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.STARRED,
            ContactsContract.CommonDataKinds.Phone.PHOTO_THUMBNAIL_URI
        )
        contentResolver.query(uri, cols, null, null,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " COLLATE LOCALIZED ASC")?.use { c ->
            while (c.moveToNext()) {
                out.add(mapOf(
                    "id" to c.getLong(0).toString(),
                    "name" to (c.getString(1) ?: ""),
                    "number" to (c.getString(2) ?: ""),
                    "starred" to (c.getInt(3) == 1),
                    "photo" to (c.getString(4) != null)
                ))
            }
        }
        return out
    }

    private fun callLog(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (!has(Manifest.permission.READ_CALL_LOG)) return out
        val uri = CallLog.Calls.CONTENT_URI.buildUpon()
            .appendQueryParameter(CallLog.Calls.LIMIT_PARAM_KEY, "300").build()
        val cols = arrayOf(
            CallLog.Calls._ID, CallLog.Calls.NUMBER, CallLog.Calls.CACHED_NAME,
            CallLog.Calls.TYPE, CallLog.Calls.DATE, CallLog.Calls.DURATION,
            CallLog.Calls.PHONE_ACCOUNT_COMPONENT_NAME, CallLog.Calls.PHONE_ACCOUNT_ID
        )
        contentResolver.query(uri, cols, null, null, CallLog.Calls.DATE + " DESC")?.use { c ->
            while (c.moveToNext()) {
                out.add(mapOf(
                    "id" to c.getLong(0),
                    "number" to (c.getString(1) ?: ""),
                    "name" to (c.getString(2) ?: ""),
                    "callType" to c.getInt(3),
                    "date" to c.getLong(4),
                    "duration" to c.getLong(5),
                    "account" to SimAccounts.key(c.getString(6), c.getString(7))
                ))
            }
        }
        return out
    }

    private fun addContact(name: String, number: String) {
        val ops = ArrayList<ContentProviderOperation>()
        ops.add(ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
            .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null)
            .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null).build())
        ops.add(ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
            .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
            .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
            .withValue(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, name).build())
        ops.add(ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
            .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
            .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
            .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, number)
            .withValue(ContactsContract.CommonDataKinds.Phone.TYPE, ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE).build())
        contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PICK) {
            val waiting = pending.take(REQ_PICK)
            if (waiting.isEmpty()) return
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) {
                waiting.forEach { it.success(null) }
                return
            }
            val kind = pickKind
            io.execute {
                try {
                    val path = importMedia(kind, uri)
                    runOnUiThread { waiting.forEach { it.success(path) } }
                } catch (e: Exception) {
                    runOnUiThread { waiting.forEach { it.error("error", e.message, null) } }
                }
            }
            return
        }
        if (requestCode == REQ_ROLE) {
            val ok = isDefaultDialer()
            pending.take(REQ_ROLE).forEach { it.success(ok) }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_SMS) {
            val ok = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pending.take(REQ_SMS).forEach { it.success(ok) }
        }
        if (requestCode == REQ_PERMS) {
            // Un resultado vacío significa que el diálogo se interrumpió: no es "todo concedido".
            val ok = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pending.take(REQ_PERMS).forEach { it.success(ok) }
        }
    }
}
