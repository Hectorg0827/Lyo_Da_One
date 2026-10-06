package com.lyo.app.ui.screens.clips

/**
 * Teach-it prompt — what the app says when a learner finishes something, and
 * how long the clip it asks for may run.
 *
 * A new video feed's hardest problem is supply, not demand: an empty Discover
 * is a dead Discover. Finishing a lesson is the one moment a learner has
 * something specific to say and feels good enough to say it, and the app
 * already knows what they just covered — so the invitation can name it
 * instead of asking into the void.
 *
 * Mirrors iOS `ClipPrompt` and web `teach-it.mjs`.
 */
object ClipPrompt {

    /**
     * How long a single-take clip may run, in seconds.
     *
     * Shared with the recorder, so the invitation cannot promise a length the
     * camera will not allow.
     */
    const val QUICK_TAKE_SECONDS = 60

    /** What the finish screen offers. */
    const val CALL_TO_ACTION = "Teach it"

    /**
     * The sentence above the button.
     *
     * A known topic is named, because "teach Organic Chemistry" is far easier
     * to act on than "teach something". An unknown one is not invented — a
     * prompt that confidently names the wrong course is worse than one that
     * names none.
     */
    fun invitation(topic: String?): String {
        val name = trimmed(topic)
        return if (name != null) {
            "You just finished $name. Teach it in $QUICK_TAKE_SECONDS seconds?"
        } else {
            "Teach what you just learned in $QUICK_TAKE_SECONDS seconds?"
        }
    }

    /**
     * The title the composer opens with, or null to leave it empty.
     *
     * Null rather than a placeholder when the topic is unknown: a title the
     * learner did not write and did not mean is published under their name.
     */
    fun draftTitle(topic: String?): String? {
        val name = trimmed(topic) ?: return null
        return "What I learned about $name"
    }

    /** The subject the composer tags the clip with, or null when unknown. */
    fun draftSubject(topic: String?): String? = trimmed(topic)

    private fun trimmed(text: String?): String? = text?.trim()?.takeIf { it.isNotEmpty() }
}
