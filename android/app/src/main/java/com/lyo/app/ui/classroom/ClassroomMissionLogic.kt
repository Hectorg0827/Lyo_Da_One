package com.lyo.app.ui.classroom

import java.util.Locale

/** Local practice while the server prepares a lesson, never a learner grade. */
internal enum class StarterMissionKind { FAIR_TEST, FRACTIONS, GENERAL }

internal fun starterMissionFor(topic: String): StarterMissionKind {
    val normalized = topic.trim().lowercase(Locale.ROOT)
    return when {
        listOf("science", "biology", "experiment", "plant").any { it in normalized } ->
            StarterMissionKind.FAIR_TEST
        listOf("math", "fraction").any { it in normalized } ->
            StarterMissionKind.FRACTIONS
        else -> StarterMissionKind.GENERAL
    }
}

internal data class FairExperiment(
    val waterA: Int = 1,
    val waterB: Int = 1,
    val sunlightA: Int = 6,
    val sunlightB: Int = 6,
)

internal data class FairExperimentCheck(val ready: Boolean, val guidance: String)

/**
 * Compare one controlled variable; this establishes only that the experiment
 * is designed fairly. It does NOT claim a simulated result proves plant growth.
 */
internal fun checkFairExperiment(experiment: FairExperiment): FairExperimentCheck =
    when {
        experiment.waterA == experiment.waterB ->
            FairExperimentCheck(false, "Change the water amount for Plant B to test water's effect.")
        experiment.sunlightA != experiment.sunlightB ->
            FairExperimentCheck(false, "Keep sunlight the same for both plants so only water changes.")
        else -> FairExperimentCheck(
            true,
            "Fair setup! Only water changes. The real experiment would still need observations.",
        )
    }

internal fun fractionGoalReached(numerator: Int, denominator: Int = 4): Boolean =
    denominator == 4 && numerator == 3

/**
 * A learner who started manipulating a local mission may finish it, but the
 * real teaching scene should never play invisibly behind that activity.
 * Unengaged missions disappear as soon as live content arrives.
 */
internal fun missionShouldBeVisible(
    status: String,
    hasBoardContent: Boolean,
    engaged: Boolean,
    enteredLive: Boolean,
): Boolean = (status == "connecting" || status == "live") &&
    !enteredLive && (!hasBoardContent || engaged)

internal fun missionNeedsNarrationHold(
    hasBoardContent: Boolean,
    engaged: Boolean,
    enteredLive: Boolean,
): Boolean = hasBoardContent && engaged && !enteredLive
