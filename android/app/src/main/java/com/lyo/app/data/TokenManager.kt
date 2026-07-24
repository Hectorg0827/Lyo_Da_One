package com.lyo.app.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Stores JWT access/refresh tokens. Mirrors the web client's
 * localStorage keys (lyo_token / lyo_refresh_token).
 */
object TokenManager {

    private const val PREFS = "lyo_auth"
    private const val KEY_ACCESS = "lyo_token"
    private const val KEY_REFRESH = "lyo_refresh_token"

    private lateinit var prefs: SharedPreferences

    fun init(context: Context) {
        prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    var accessToken: String?
        get() = prefs.getString(KEY_ACCESS, null)
        set(value) = prefs.edit().putString(KEY_ACCESS, value).apply()

    var refreshToken: String?
        get() = prefs.getString(KEY_REFRESH, null)
        set(value) = prefs.edit().putString(KEY_REFRESH, value).apply()

    /** Replace the complete token pair so an older refresh token cannot leak into a new session. */
    fun setTokens(access: String, refresh: String?) {
        prefs.edit()
            .putString(KEY_ACCESS, access)
            .apply {
                if (refresh == null) remove(KEY_REFRESH)
                else putString(KEY_REFRESH, refresh)
            }
            .apply()
    }

    fun clear() {
        prefs.edit().remove(KEY_ACCESS).remove(KEY_REFRESH).apply()
    }

    val hasToken: Boolean get() = accessToken != null
}
