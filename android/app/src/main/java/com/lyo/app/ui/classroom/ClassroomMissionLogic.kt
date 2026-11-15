package com.lyo.app.ui.classroom

import java.util.Locale

/** Local practice while the server prepares a lesson, never a learner grade. */
internal enum class StarterMissionKind { FAIR_TEST, FRACTIONS, GENERAL }

internal fun starterMissionFor(topic: String): StarterMissionKind {
    val normalized = topic.trim().lowercase(Locale.ROOT)
    return when {
        listOf("science", "biology", "experiment", "plant", "ciencia",
            "biologia", "biología", "experimento", "planta").any { it in normalized } ->
            StarterMissionKind.FAIR_TEST
        listOf("math", "fraction", "matemática", "matematica", "fracción",
            "fraccion", "fracciones").any { it in normalized } ->
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

internal enum class ExperimentVariable { WATER, SUNLIGHT }

/**
 * Two linked challenges: isolate the effect of water, then isolate sunlight.
 * This checks experimental DESIGN only. It never simulates or asserts
 * plant growth or changes the server's learner evidence.
 */
internal fun checkFairExperiment(
    experiment: FairExperiment,
    variable: ExperimentVariable = ExperimentVariable.WATER,
): FairExperimentCheck =
    when (variable) {
        ExperimentVariable.WATER -> when {
            experiment.waterA == experiment.waterB ->
                FairExperimentCheck(false, "Change the water amount for Plant B to test water's effect.")
            experiment.sunlightA != experiment.sunlightB ->
                FairExperimentCheck(false, "Keep sunlight the same for both plants so only water changes.")
            else -> FairExperimentCheck(
                true, "Fair setup! Only water changes. A real test still needs observations.",
            )
        }
        ExperimentVariable.SUNLIGHT -> when {
            experiment.sunlightA == experiment.sunlightB ->
                FairExperimentCheck(false, "Change the sunlight for Plant B to test light's effect.")
            experiment.waterA != experiment.waterB ->
                FairExperimentCheck(false, "Keep water the same for both plants so only sunlight changes.")
            else -> FairExperimentCheck(
                true, "Fair setup! Only sunlight changes. A real test still needs observations.",
            )
        }
    }

internal fun fractionGoalReached(
    numerator: Int,
    denominator: Int = 4,
    targetNumerator: Int = 3,
): Boolean = denominator == 4 && targetNumerator in 0..denominator && numerator == targetNumerator

/** Prefer the lesson's explicitly Spanish topic, or the Android device locale. */
internal fun isSpanishMission(topic: String, languageTag: String): Boolean {
    val normalized = topic.trim().lowercase(Locale.ROOT)
    val spanishTopic = listOf(
        "ciencia", "biologia", "biología", "experimento", "matemática",
        "matematica", "fracción", "fraccion", "fracciones", "historia",
    ).any { it in normalized }
    return spanishTopic || languageTag.lowercase(Locale.ROOT).startsWith("es")
}

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
