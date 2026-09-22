package com.lyo.app.notifications

import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.lyo.app.MainActivity
import com.lyo.app.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class StudyMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            runCatching { StudyReminders.tokenChanged(token) }
            // A failed refresh is retried next time the authenticated app opens.
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        if (!StudyReminders.mayDisplay(message.data["recipient_id"])) return
        val notifications = NotificationManagerCompat.from(this)
        if (!notifications.areNotificationsEnabled()) return
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("open_test_prep", message.data["action"] == "open_test_prep" ||
                message.data["deep_link"] == "https://lyoai.app/test-prep")
        }
        val id = (message.data["reminder_id"] ?: message.messageId ?: "study").hashCode()
        val pending = PendingIntent.getActivity(this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(this, StudyReminders.CHANNEL)
            .setSmallIcon(R.drawable.ic_launcher_lyo)
            .setContentTitle(message.data["title"] ?: "Lyo")
            .setContentText(message.data["body"] ?: "Your study plan is ready to open.")
            .setStyle(NotificationCompat.BigTextStyle().bigText(message.data["body"]))
            .setContentIntent(pending).setAutoCancel(true).build()
        try { notifications.notify(id, notification) } catch (_: SecurityException) {
            // Permission can change between the check and display.
        }
    }
}
