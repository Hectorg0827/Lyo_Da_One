package com.lyo.app.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.tasks.Task
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.lyo.app.BuildConfig
import com.lyo.app.data.Session
import com.lyo.app.data.TokenManager
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.PushRegistration
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Device permission/registration only. The account's plan and schedule stay on the server. */
object StudyReminders {
    const val CHANNEL = "study_reminders"
    private lateinit var prefs: SharedPreferences
    private lateinit var appContext: Context
    private var registrationEpoch = 0
    var openTestPrep by mutableStateOf(false)
    var deliveryEnabled by mutableStateOf(false)
        private set
    var enabled by mutableStateOf(false)
        private set

    fun init(context: Context) {
        appContext = context.applicationContext
        prefs = appContext.getSharedPreferences("study_reminders", Context.MODE_PRIVATE)
        enabled = prefs.getBoolean("enabled", false)
        appContext.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Study reminders", NotificationManager.IMPORTANCE_DEFAULT))
    }

    fun configured(context: Context) = FirebaseApp.getApps(context).isNotEmpty()

    suspend fun enable(context: Context) {
        check(configured(context)) { "Study reminders are not available in this version yet." }
        check(NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            "Allow notifications in your phone settings to receive study reminders."
        }
        val owner = Session.user?.id ?: error("Sign in to enable study reminders.")
        val messaging = FirebaseMessaging.getInstance()
        messaging.isAutoInitEnabled = true
        val token = messaging.token.awaitResult()
        register(token, owner)
    }

    suspend fun refreshIfEnabled(context: Context) {
        if (!enabled || !configured(context) || !TokenManager.hasToken) return
        val owner = Session.user?.id ?: return
        if (owner != prefs.getString("owner", null)) { clearLocalRegistration(); return }
        register(FirebaseMessaging.getInstance().token.awaitResult(), owner)
    }

    suspend fun tokenChanged(token: String) {
        if (!enabled || !TokenManager.hasToken) return
        // Resolve the current authenticated account before assigning a rotated token.
        val owner = ApiClient.api.me().id ?: return
        if (owner != prefs.getString("owner", null)) { clearLocalRegistration(); return }
        register(token, owner)
    }

    private suspend fun register(token: String, owner: String) {
        val epoch = synchronized(this) { registrationEpoch }
        val access = TokenManager.accessToken ?: error("Sign in to enable study reminders.")
        val device = ApiClient.push.register(PushRegistration(token,
            app_version = BuildConfig.VERSION_NAME, os_version = Build.VERSION.RELEASE))
        check(device.is_active) { "Could not register this device. Please retry." }
        synchronized(this) {
            check(epoch == registrationEpoch && TokenManager.hasToken &&
                (Session.user?.id == owner || TokenManager.accessToken == access)) { "Your account changed. Please retry." }
            prefs.edit().putBoolean("enabled", true).putString("owner", owner).putString("device", device.id).apply()
            enabled = true
            deliveryEnabled = device.delivery_enabled
        }
    }

    suspend fun disable() {
        val id = prefs.getString("device", null)
        clearLocalRegistration() // Stop showing messages even if the network is unavailable.
        if (configured(appContext)) {
            FirebaseMessaging.getInstance().isAutoInitEnabled = false
            runCatching { FirebaseMessaging.getInstance().deleteToken().awaitResult() }
        }
        if (id != null && TokenManager.hasToken) runCatching { ApiClient.push.unregister(id) }
    }

    @Synchronized
    fun clearLocalRegistration() {
        registrationEpoch += 1
        if (!::prefs.isInitialized) return
        prefs.edit().clear().apply()
        enabled = false
        deliveryEnabled = false
        openTestPrep = false
        appContext.getSystemService(NotificationManager::class.java).cancelAll()
    }

    fun mayDisplay(recipient: String?): Boolean = ::prefs.isInitialized && reminderMayDisplay(
        TokenManager.hasToken, enabled, prefs.getString("owner", null), recipient)
}

internal fun reminderMayDisplay(hasSession: Boolean, allowed: Boolean, owner: String?, recipient: String?) =
    hasSession && allowed && !owner.isNullOrBlank() && owner == recipient

private suspend fun <T> Task<T>.awaitResult(): T = suspendCancellableCoroutine { continuation ->
    addOnSuccessListener { if (continuation.isActive) continuation.resume(it) }
    addOnFailureListener { if (continuation.isActive) continuation.resumeWithException(it) }
    addOnCanceledListener { continuation.cancel() }
}
