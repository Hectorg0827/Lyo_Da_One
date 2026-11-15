package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.theme.LyoVioletLight
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.util.Locale
import kotlin.math.roundToInt

/**
 * A pair of immediate, hands-on tasks while authoritative lesson content loads.
 * No synthetic mastery, grading or learner-record mutations.
 */
@Composable
internal fun ClassroomMission(
    topic: String,
    modifier: Modifier = Modifier,
    onInteraction: () -> Unit = {},
    liveLessonReady: Boolean = false,
    onEnterLive: () -> Unit = {},
) {
    val spanish = isSpanishMission(topic, Locale.getDefault().toLanguageTag())
    when (starterMissionFor(topic)) {
        StarterMissionKind.FAIR_TEST ->
            FairTestMission(topic, modifier, onInteraction, liveLessonReady, onEnterLive, spanish)
        StarterMissionKind.FRACTIONS ->
            FractionBarMission(topic, modifier, onInteraction, liveLessonReady, onEnterLive, spanish)
        StarterMissionKind.GENERAL ->
            ClassroomWarmup(topic, modifier, onInteraction, liveLessonReady, onEnterLive, spanish)
    }
}

@Composable
private fun MissionFrame(
    title: String,
    instruction: String,
    modifier: Modifier,
    spanish: Boolean,
    step: Int,
    liveLessonReady: Boolean,
    onEnterLive: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 14.dp, vertical = 8.dp)
            .background(Surface, RoundedCornerShape(20.dp))
            .border(1.dp, LyoVioletLight.copy(alpha = 0.30f), RoundedCornerShape(20.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            if (spanish) "MISIÓN ${step} DE 2 · PRÁCTICA SIN NOTA"
            else "MISSION ${step} OF 2 · PRACTICE ONLY",
            color = LyoVioletLight,
            style = MaterialTheme.typography.labelSmall,
        )
        Text(title, color = TextPrimary, style = MaterialTheme.typography.titleMedium)
        Text(instruction, color = TextSecondary, style = MaterialTheme.typography.bodyMedium)
        content()
        if (liveLessonReady) {
            Button(onClick = onEnterLive, modifier = Modifier.fillMaxWidth()) {
                Text(if (spanish) "Entrar a la clase" else "Enter live lesson")
            }
        } else {
            Text(
                if (spanish) "Práctica sin calificación. Tu clase se está preparando."
                else "Practice only, not graded. Your lesson is preparing.",
                color = TextSecondary, style = MaterialTheme.typography.labelSmall,
            )
        }
    }
}

@Composable
private fun FairTestMission(
    topic: String,
    modifier: Modifier,
    onInteraction: () -> Unit,
    liveLessonReady: Boolean,
    onEnterLive: () -> Unit,
    spanish: Boolean,
) {
    var step by remember(topic) { mutableIntStateOf(0) }
    var waterB by remember(topic) { mutableIntStateOf(1) }
    var sunlightB by remember(topic) { mutableIntStateOf(6) }
    val variable = if (step == 0) ExperimentVariable.WATER else ExperimentVariable.SUNLIGHT
    val check = checkFairExperiment(
        FairExperiment(waterB = waterB, sunlightB = sunlightB), variable,
    )
    val guidance = if (!spanish) check.guidance else when {
        variable == ExperimentVariable.WATER && waterB == 1 ->
            "Cambia el agua de la planta B para investigar su efecto."
        variable == ExperimentVariable.WATER && sunlightB != 6 ->
            "Mantén igual la luz en ambas plantas. Solo debe cambiar el agua."
        variable == ExperimentVariable.WATER ->
            "¡Buen diseño! Solo cambia el agua. Para saber qué pasa hay que observar."
        sunlightB == 6 ->
            "Cambia la luz que recibe la planta B."
        waterB != 1 ->
            "Mantén igual el agua en ambas plantas. Solo debe cambiar la luz."
        else -> "¡Buen diseño! Solo cambia la luz. El resultado requiere observaciones."
    }

    MissionFrame(
        title = if (spanish) "Diseña un experimento justo" else "Design a fair experiment",
        instruction = if (spanish) {
            if (step == 0) "Reto 1: cambia solo el agua. ¿Puedes mantener iguales las otras condiciones?"
            else "Reto 2: ahora cambia solo la luz. Mantén igual el agua."
        } else {
            if (step == 0) "Challenge 1: change only the water. Keep other conditions the same."
            else "Challenge 2: change only the sunlight. Keep the water equal."
        },
        modifier = modifier,
        spanish = spanish,
        step = step + 1,
        liveLessonReady = liveLessonReady,
        onEnterLive = onEnterLive,
    ) {
        Text(
            if (spanish) "🌱 Planta A: 1 taza de agua · 6 horas de luz"
            else "🌱 Plant A: 1 cup water · 6 hours sunlight",
            color = TextPrimary, style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            if (spanish) "🌿 Planta B: ${waterB} taza(s) de agua · ${sunlightB} horas de luz"
            else "🌿 Plant B: ${waterB} ${if (waterB == 1) "cup" else "cups"} water · ${sunlightB} hours sunlight",
            color = TextPrimary, style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            if (spanish) "Planta B · Agua (${waterB} taza(s))"
            else "Plant B · Water (${waterB} ${if (waterB == 1) "cup" else "cups"})",
            color = TextPrimary,
        )
        Slider(
            value = waterB.toFloat(),
            onValueChange = {
                waterB = it.roundToInt().coerceIn(1, 3)
                onInteraction()
            },
            valueRange = 1f..3f,
            steps = 1,
            modifier = Modifier.semantics {
                contentDescription = if (spanish) "Agua para la planta B en tazas"
                else "Water for Plant B in cups"
            },
        )
        Text(
            if (spanish) "Planta B · Luz (${sunlightB} horas)"
            else "Plant B · Sunlight ($sunlightB hours)",
            color = TextPrimary,
        )
        Slider(
            value = sunlightB.toFloat(),
            onValueChange = {
                sunlightB = it.roundToInt().coerceIn(4, 8)
                onInteraction()
            },
            valueRange = 4f..8f,
            steps = 3,
            modifier = Modifier.semantics {
                contentDescription = if (spanish) "Horas de luz para la planta B"
                else "Sunlight for Plant B in hours"
            },
        )
        Text(
            if (check.ready) "✓ $guidance" else guidance,
            color = if (check.ready) LyoVioletLight else TextSecondary,
            style = MaterialTheme.typography.bodyMedium,
        )
        if (check.ready && step == 0) {
            Button(
                onClick = {
                    step = 1
                    waterB = 1
                    sunlightB = 6
                    onInteraction()
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (spanish) "Siguiente reto: la luz" else "Next challenge: sunlight")
            }
        } else if (check.ready) {
            Text(
                if (spanish) "¡Completaste los dos retos de práctica!"
                else "Both practice challenges complete!",
                color = LyoVioletLight,
                style = MaterialTheme.typography.labelMedium,
            )
        }
    }
}

@Composable
private fun FractionBarMission(
    topic: String,
    modifier: Modifier,
    onInteraction: () -> Unit,
    liveLessonReady: Boolean,
    onEnterLive: () -> Unit,
    spanish: Boolean,
) {
    var step by remember(topic) { mutableIntStateOf(0) }
    var numerator by remember(topic) { mutableIntStateOf(1) }
    val target = if (step == 0) 3 else 2
    val correct = fractionGoalReached(numerator, targetNumerator = target)
    MissionFrame(
        title = if (spanish) {
            if (step == 0) "Construye tres cuartos" else "Construye un medio"
        } else {
            if (step == 0) "Build three quarters" else "Build one half"
        },
        instruction = if (spanish) {
            if (step == 0) "Mueve el control para sombrear 3 de 4 partes iguales."
            else "Ahora representa 1/2 usando las mismas cuatro partes."
        } else {
            if (step == 0) "Drag the slider to shade exactly 3 out of 4 equal parts."
            else "Now make one half using the same four equal parts."
        },
        modifier = modifier,
        spanish = spanish,
        step = step + 1,
        liveLessonReady = liveLessonReady,
        onEnterLive = onEnterLive,
    ) {
        Text(
            if (spanish) "${numerator}/4 del total" else "${numerator}/4 of a whole",
            color = TextPrimary, style = MaterialTheme.typography.titleMedium,
        )
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(4) { index ->
                Box(
                    modifier = Modifier.weight(1f)
                        .background(
                            if (index < numerator) LyoVioletLight
                            else TextSecondary.copy(alpha = 0.15f),
                            RoundedCornerShape(5.dp),
                        )
                        .border(
                            1.dp, LyoVioletLight.copy(alpha = 0.45f),
                            RoundedCornerShape(5.dp),
                        )
                        .padding(vertical = 16.dp),
                )
            }
        }
        Text(
            if (spanish) "Partes sombreadas: $numerator"
            else "Shaded parts: $numerator",
            color = TextPrimary,
        )
        Slider(
            value = numerator.toFloat(),
            onValueChange = {
                numerator = it.roundToInt().coerceIn(0, 4)
                onInteraction()
            },
            valueRange = 0f..4f,
            steps = 3,
            modifier = Modifier.semantics {
                contentDescription = if (spanish) "Número de cuartos sombreados"
                else "Number of shaded quarters"
            },
        )
        Text(
            if (correct) {
                if (spanish) {
                    if (step == 0) "✓ ¡Lograste 3/4! Las cuatro partes tienen el mismo tamaño."
                    else "✓ ¡Lograste 1/2! Dos de cuatro partes equivalen a la mitad."
                } else {
                    if (step == 0) "✓ You built 3/4. Each of the four parts has the same size."
                    else "✓ You built 1/2. Two of four equal parts make one half."
                }
            } else {
                if (spanish) "Sombrea la cantidad correcta de partes iguales."
                else "Try shading the right number of equal parts.",
            },
            color = if (correct) LyoVioletLight else TextSecondary,
            style = MaterialTheme.typography.bodyMedium,
        )
        if (correct && step == 0) {
            Button(
                onClick = {
                    numerator = 0
                    step = 1
                    onInteraction()
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (spanish) "Siguiente reto: la mitad" else "Next challenge: one half")
            }
        } else if (correct) {
            Text(
                if (spanish) "¡Completaste los dos retos de práctica!"
                else "Both practice challenges complete!",
                color = LyoVioletLight, style = MaterialTheme.typography.labelMedium,
            )
        }
    }
}
