package com.nexlia.phone

import android.Manifest
import android.app.role.RoleManager
import android.content.ContentProviderOperation
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.CallLog
import android.provider.ContactsContract
import android.provider.Settings
import android.telecom.TelecomManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var sink: EventChannel.EventSink? = null
    private var pending: MethodChannel.Result? = null
    private var dialNumber: String? = null
    private val io = Executors.newSingleThreadExecutor()

    private val REQ_ROLE = 1001
    private val REQ_PERMS = 1002

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockFlags()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CallManager.appContext = applicationContext
        dialNumber = numberFrom(intent)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "nexlia/phone").setMethodCallHandler { call, result ->
            try { handle(call, result) } catch (e: Exception) { result.error("error", e.message, null) }
        }
        EventChannel(messenger, "nexlia/phone/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
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
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyLockFlags()
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

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isDefaultDialer" -> result.success(isDefaultDialer())
            "requestDefaultDialer" -> {
                val rm = getSystemService(RoleManager::class.java)
                if (rm.isRoleAvailable(RoleManager.ROLE_DIALER) && !rm.isRoleHeld(RoleManager.ROLE_DIALER)) {
                    pending = result
                    startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_DIALER), REQ_ROLE)
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
                else {
                    pending = result
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
                if (number.isEmpty() || !has(Manifest.permission.CALL_PHONE)) result.success(false)
                else {
                    getSystemService(TelecomManager::class.java).placeCall(Uri.fromParts("tel", number, null), Bundle())
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
                    else -> Intent(Settings.ACTION_SETTINGS)
                }
                try { startActivity(i) } catch (e: Exception) { startActivity(Intent(Settings.ACTION_SETTINGS)) }
                result.success(true)
            }
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
            CallLog.Calls.TYPE, CallLog.Calls.DATE, CallLog.Calls.DURATION
        )
        contentResolver.query(uri, cols, null, null, CallLog.Calls.DATE + " DESC")?.use { c ->
            while (c.moveToNext()) {
                out.add(mapOf(
                    "id" to c.getLong(0),
                    "number" to (c.getString(1) ?: ""),
                    "name" to (c.getString(2) ?: ""),
                    "callType" to c.getInt(3),
                    "date" to c.getLong(4),
                    "duration" to c.getLong(5)
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
        if (requestCode == REQ_ROLE) {
            pending?.success(isDefaultDialer())
            pending = null
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_PERMS) {
            pending?.success(grantResults.all { it == PackageManager.PERMISSION_GRANTED })
            pending = null
        }
    }
}
