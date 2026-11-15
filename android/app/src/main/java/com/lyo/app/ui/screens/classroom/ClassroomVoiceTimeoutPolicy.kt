package com.lyo.app.ui.screens.classroom

/**
 * Evidence-based interim timeout for the full-MP3 endpoint.
 *
 * A staging backend speech synthesis was measured at ~9.5 seconds, while
 * Android had been aborting calls after 8 seconds. The extra budget avoids
 * dropping a healthy first provider response and pinning a robotic device
 * voice for the entire lesson. This is NOT a latency improvement. Keep
 * production behavior unchanged pending real-device streaming validation.
 */
internal object ClassroomVoiceTimeoutPolicy {
    const val PRODUCTION_FULL_MP3_SECONDS = 8L
    const val STAGING_FULL_MP3_SECONDS = 15L

    fun fullMp3TimeoutSeconds(apiEnvironment: String): Long =
        if (apiEnvironment.equals("staging", ignoreCase = true)) {
            STAGING_FULL_MP3_SECONDS
        } else {
            PRODUCTION_FULL_MP3_SECONDS
        }
}
