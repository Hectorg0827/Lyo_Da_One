package com.lyo.app.data.classroom

import android.content.Context
import android.content.SharedPreferences

/**
 * Starting a class, starting it over, and noticing when it has stopped.
 *
 * The Kotlin twin of `web/src/lib/classroom-contract.mjs` and iOS's
 * `ClassroomSessionContract.swift`. The rules here are not presentation: the
 * session id decides whether the backend teaches a lesson or resumes one, and
 * the stall thresholds decide when a class stops claiming the next step is
 * coming. Three platforms disagreeing about either is three different
 * products, so the numbers and the copy live in one place per platform and
 * are held together by `scripts/verify-classroom-parity.mjs`.
 */

/** A live session a learner could still return to. */
data class ClassroomSavedSession(
    val id: String,
    val startedAt: Long,
    val generation: Int,
    /** The class reached its end, so it is not an unfinished one to resume. */
    val finished: Boolean = false,
)

/** Which session this entry connects with, and whether it is a continuation. */
data class ClassroomSessionStart(
    val sessionId: String,
    val generation: Int,
    val resumed: Boolean,
)

/**
 * How far past "the next step is coming" a wait has gone.
 *
 * [SLOW] is still a wait. [STALLED] is the admission that the step is not
 * arriving, and is the only one that puts recovery controls on screen.
 */
enum class ClassroomStallPhase { NONE, SLOW, STALLED }

/** What the learner is told before the teaching starts. */
data class ClassroomOpening(
    val title: String,
    val objective: String,
    val facts: List<String>,
    val note: String,
    val resumed: Boolean,
)

object ClassroomSessionContract {
    /**
     * How long a half-finished class stays worth offering back. Past this,
     * "pick up where you left off" is a promise about a lesson the learner no
     * longer remembers sitting, so the class simply starts.
     */
    const val RESUME_WINDOW_MS = 6L * 60L * 60L * 1000L

    /** Say out loud that this step is taking longer than it should. */
    const val STALL_NOTICE_MS = 12_000L

    /**
     * The step is not coming: ask after it once, then hand the learner
     * controls that can actually get the class moving again.
     */
    const val STALL_RECOVERY_MS = 30_000L

    const val STALL_NOTICE = "This step is taking longer than it should. Still working on it…"
    const val STALL_RECOVERY =
        "The next step didn't arrive. Nothing you've done is lost, and this is not a wrong answer."
    const val OPENING_NOTE =
        "You can stop Lyo at any time — raise your hand, ask a question, or say you are lost."

    private val KNOWN_MODES = setOf("solo", "classroom", "challenge", "review")

    /**
     * Free-topic entries can arrive as `GENERATE:<topic>` (iOS's shape, which
     * reaches shared storage keys); the stored key is the topic itself, so the
     * same topic finds its own history whichever door it came through.
     */
    fun normalizedSessionId(rawSessionId: String): String =
        if (rawSessionId.startsWith("GENERATE:")) rawSessionId.removePrefix("GENERATE:")
        else rawSessionId

    fun courseKey(courseId: String?, topic: String?): String {
        val course = courseId.orEmpty().trim()
        if (course.isNotEmpty()) return normalizedSessionId(course)
        val subject = topic.orEmpty().trim()
        return if (subject.isEmpty()) "general" else normalizedSessionId(subject)
    }

    fun storageKey(courseKey: String): String = "lyo_classroom_session:$courseKey"

    fun canResume(saved: ClassroomSavedSession?, now: Long = System.currentTimeMillis()): Boolean {
        if (saved == null || saved.id.isEmpty()) return false
        // A class that reached its end is not unfinished, however recent.
        if (saved.finished) return false
        val age = now - saved.startedAt
        return age in 0..RESUME_WINDOW_MS
    }

    /**
     * The session id this entry should connect with.
     *
     * Every fresh lesson needs a distinct server session, including the first
     * run after reinstall. Otherwise a topic-keyed failed session can be
     * restored despite an empty local store. Resumption remains explicit;
     * progress still belongs to courseKey.
     */
    fun sessionStart(
        courseKey: String,
        saved: ClassroomSavedSession?,
        resume: Boolean = false,
        now: Long = System.currentTimeMillis(),
    ): ClassroomSessionStart {
        val key = courseKey.trim().ifEmpty { "general" }
        if (resume && canResume(saved, now) && saved != null) {
            return ClassroomSessionStart(saved.id, maxOf(1, saved.generation), resumed = true)
        }
        val generation = if (saved == null || saved.id.isEmpty()) 1 else maxOf(1, saved.generation) + 1
        return ClassroomSessionStart("$key~$generation-$now", generation, resumed = false)
    }

    fun opening(
        topic: String?,
        objective: String?,
        durationMinutes: Int?,
        difficulty: String?,
        mode: String?,
        resumed: Boolean = false,
    ): ClassroomOpening {
        val subject = topic.orEmpty().trim().ifEmpty { "this topic" }
        val minutes = (durationMinutes ?: 10).coerceIn(3, 60)
        val facts = mutableListOf("$minutes min")
        difficulty?.takeIf { it.isNotBlank() }?.let { facts += "$it level" }
        val lessonMode = if (mode in KNOWN_MODES) mode!! else "solo"
        if (lessonMode != "solo") facts += "$lessonMode mode"
        return ClassroomOpening(
            title = if (resumed) "Back to $subject" else "Today: $subject",
            objective = objective.orEmpty().trim().ifEmpty { defaultObjective(subject) },
            facts = facts,
            note = OPENING_NOTE,
            resumed = resumed,
        )
    }

    fun defaultObjective(topic: String): String = "Understand and apply $topic"
}

/**
 * Where a surface remembers the last live session for a course.
 *
 * `SharedPreferences` when the app has initialised it (see LyoApplication,
 * which does the same for TokenManager), and an in-memory map otherwise so
 * unit tests and any uninitialised path still behave. An unreadable or absent
 * record simply means this is a first class, which is the behaviour every
 * client had before any of this existed.
 */
object ClassroomSessionStore {
    private const val PREFS = "lyo_classroom_sessions"
    private var prefs: SharedPreferences? = null
    private val fallback = mutableMapOf<String, String>()

    fun init(context: Context) {
        prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    fun saved(courseKey: String): ClassroomSavedSession? {
        val key = ClassroomSessionContract.storageKey(courseKey)
        val raw = prefs?.getString(key, null) ?: fallback[key] ?: return null
        // id\u0000startedAt\u0000generation — a record this small does not need a
        // JSON dependency, and a malformed one reads as "no history", which is
        // the behaviour a first class already has.
        // A record written before `finished` existed has three parts and
        // reads as unfinished, which is what it was.
        val parts = raw.split('\u0000')
        if (parts.size !in 3..4) return null
        val startedAt = parts[1].toLongOrNull() ?: return null
        val generation = parts[2].toIntOrNull() ?: return null
        if (parts[0].isEmpty()) return null
        return ClassroomSavedSession(parts[0], startedAt, generation, parts.getOrNull(3) == "1")
    }

    fun save(session: ClassroomSavedSession, courseKey: String) {
        val key = ClassroomSessionContract.storageKey(courseKey)
        val finished = if (session.finished) "1" else "0"
        val raw = "${session.id}\u0000${session.startedAt}\u0000${session.generation}\u0000$finished"
        val store = prefs
        if (store != null) store.edit().putString(key, raw).apply() else fallback[key] = raw
    }

    /** Mark the stored seat finished, so it stops being offered as unfinished. */
    fun markFinished(sessionId: String, courseKey: String) {
        val seat = saved(courseKey) ?: return
        if (seat.id != sessionId) return
        save(seat.copy(finished = true), courseKey)
    }

    /** Test seam: forget everything this process remembers. */
    fun clearForTests() {
        fallback.clear()
        prefs = null
    }
}
