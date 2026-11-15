package com.nexlia.phone

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Cifrado local exclusivo de NEXLIA Chat. La clave no sale del Android Keystore.
 * No registrar textos ni claves en logs.
 */
internal class ChatSecurePrefs(private val context: Context) {
    private val prefs = context.getSharedPreferences("chat_secure_v1", Context.MODE_PRIVATE)
    private val legacy = context.getSharedPreferences("ui", Context.MODE_PRIVATE)
    private val alias = "nexlia_chat_aes_v1"
    private val prefix = "gcm1:"

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }

    private fun encrypt(name: String, value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        cipher.updateAAD(name.toByteArray(StandardCharsets.UTF_8))
        val data = cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8))
        return prefix + Base64.encodeToString(cipher.iv + data, Base64.NO_WRAP)
    }

    private fun decrypt(name: String, encoded: String): String {
        require(encoded.startsWith(prefix)) { "Formato cifrado no reconocido" }
        val bytes = Base64.decode(encoded.substring(prefix.length), Base64.NO_WRAP)
        require(bytes.size > 28) { "Mensaje cifrado incompleto" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        cipher.updateAAD(name.toByteArray(StandardCharsets.UTF_8))
        return String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), StandardCharsets.UTF_8)
    }

    fun read(name: String): String? {
        prefs.getString(name, null)?.let { return decrypt(name, it) }
        val old = legacy.getString(name, null) ?: return null
        // Migración: escribir y confirmar cifrado ANTES de eliminar el valor sin cifrar.
        check(prefs.edit().putString(name, encrypt(name, old)).commit()) { "Migración cifrada fallida" }
        check(legacy.edit().remove(name).commit()) { "No se pudo retirar el dato anterior" }
        return old
    }

    fun write(name: String, value: String): Boolean {
        val saved = prefs.edit().putString(name, encrypt(name, value)).commit()
        if (saved && legacy.contains(name)) {
            check(legacy.edit().remove(name).commit()) { "No se pudo retirar el dato anterior" }
        }
        return saved
    }
}
