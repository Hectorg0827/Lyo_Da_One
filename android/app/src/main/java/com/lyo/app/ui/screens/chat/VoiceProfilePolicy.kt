package com.lyo.app.ui.screens.chat

import java.util.Locale

/**
 * Keep the selected Android TTS voice stable when speech recognition changes
 * only the region tag (for example, en-US -> en-GB). A real language change
 * may select a different, previously pinned voice for that language.
 */
internal object VoiceProfilePolicy {
    fun languageKey(tag: String): String =
        Locale.forLanguageTag(tag).language.lowercase(Locale.ROOT)

    fun shouldChangeLanguage(current: String, requested: String): Boolean =
        requested.isNotBlank() && current != requested
}
