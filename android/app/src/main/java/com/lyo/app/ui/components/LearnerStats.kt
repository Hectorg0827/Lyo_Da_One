package com.lyo.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.gson.JsonObject
import com.lyo.app.data.api.UserDto
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlin.math.max

/**
 * One factual four-number model for both Focus's compact strip and Profile's
 * detailed grid. Mirrors the Web learner-stats decision: only headline concept
 * mastery when the server reports learned/retained/mastered concepts.
 */
data class LearnerStat(
    val label: String,
    val short: String,
    val value: String,
    val subline: String,
    val tint: Color,
    val trend: String = "",
)

private fun countAt(root: JsonObject?, vararg path: String): Int? {
    if (root == null || path.isEmpty()) return null
    var cursor: JsonObject = root
    for (key in path.dropLast(1)) {
        cursor = runCatching { cursor.getAsJsonObject(key) }.getOrNull() ?: return null
    }
    val element = runCatching { cursor.get(path.last()) }.getOrNull() ?: return null
    if (element.isJsonNull || !element.isJsonPrimitive) return null
    val primitive = element.asJsonPrimitive
    // Null, blank strings and booleans are not measurements of zero.
    if (!primitive.isNumber && !(primitive.isString && primitive.asString.isNotBlank())) return null
    val numeric = runCatching { primitive.asDouble }.getOrNull()
        ?.takeIf { it.isFinite() && it >= 0 } ?: return null
    return numeric.toInt()
}

private fun firstCount(vararg values: Int?): Int = values.firstOrNull { it != null && it >= 0 } ?: 0

fun learnerStats(
    overview: JsonObject?,
    conceptSummary: JsonObject?,
    user: UserDto,
): List<LearnerStat> {
    val streak = firstCount(countAt(overview, "streaks", "current"), user.streak)
    val best = max(streak, firstCount(
        countAt(overview, "streaks", "longest"),
        countAt(overview, "streaks", "best"),
        streak,
    ))
    val streakStat = LearnerStat(
        label = "Streak", short = "Streak", value = "${streak}d",
        subline = "current", tint = Color(0xFFEC4899),
        trend = if (best > streak) "Best: ${best}d" else "",
    )

    val learned = countAt(conceptSummary, "learned") ?: 0
    val retained = countAt(conceptSummary, "retained") ?: 0
    val mastered = countAt(conceptSummary, "mastered") ?: 0
    if (learned > 0 || retained > 0 || mastered > 0) {
        val exploring = countAt(conceptSummary, "exploring") ?: 0
        return listOf(
            LearnerStat("Learned", "Learned", "$learned", "concepts explained",
                Color(0xFF6366F1), if (exploring > 0) "$exploring exploring" else ""),
            LearnerStat("Mastered", "Mastered", "$mastered", "applied, transferred, retained",
                Color(0xFF22C55E)),
            LearnerStat("Retained", "Retained", "$retained", "recalled after a break",
                Color(0xFFF59E0B)),
            streakStat,
        )
    }

    val xp = firstCount(countAt(overview, "xp_summary", "total"), user.resolvedXp)
    val level = firstCount(countAt(overview, "user_level", "level"), user.resolvedLevel).coerceAtLeast(1)
    val hours = countAt(overview, "user_level", "total_hours")
    val completed = firstCount(countAt(overview, "achievements", "completed"), user.coursesCompleted)
    return listOf(
        LearnerStat("Hours Learned", "Hours", hours?.toString() ?: "—",
            if (hours == null) "not tracked" else "total", Color(0xFF6366F1)),
        LearnerStat("Courses Done", "Courses", "$completed", "total completed", Color(0xFF22C55E)),
        LearnerStat("XP Earned", "XP", "$xp", "total", Color(0xFFF59E0B), "Level $level"),
        streakStat,
    )
}

@Composable
fun LearnerStatsStrip(
    stats: List<LearnerStat>,
    onOpenProfile: () -> Unit,
) {
    if (stats.size != 4) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.045f), RoundedCornerShape(16.dp))
            .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(16.dp))
            .clickable(onClick = onOpenProfile)
            .padding(horizontal = 6.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        stats.forEachIndexed { index, stat ->
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    stat.value,
                    color = stat.tint,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 18.sp,
                    maxLines = 1,
                )
                Text(
                    stat.short,
                    color = TextSecondary,
                    style = MaterialTheme.typography.labelSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (index < stats.lastIndex) {
                Spacer(
                    modifier = Modifier
                        .size(width = 1.dp, height = 30.dp)
                        .background(Color.White.copy(alpha = 0.08f)),
                )
            }
        }
    }
}

@Composable
fun LearnerStatsGrid(stats: List<LearnerStat>) {
    if (stats.size != 4) return
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        stats.chunked(2).forEach { pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                pair.forEach { stat ->
                    GlassCard(modifier = Modifier.weight(1f)) {
                        Column(
                            modifier = Modifier.fillMaxWidth().padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(5.dp),
                        ) {
                            Icon(
                                imageVector = when (stat.label) {
                                    "Learned", "Courses Done" -> Icons.Filled.MenuBook
                                    "Retained", "Hours Learned" -> Icons.Filled.Refresh
                                    else -> Icons.Filled.Star
                                },
                                contentDescription = null,
                                tint = stat.tint,
                                modifier = Modifier
                                    .size(33.dp)
                                    .background(stat.tint.copy(alpha = 0.14f), RoundedCornerShape(9.dp))
                                    .padding(8.dp),
                            )
                            Text(
                                stat.value,
                                color = TextPrimary,
                                fontWeight = FontWeight.ExtraBold,
                                fontSize = 25.sp,
                            )
                            Text(stat.label, color = TextSecondary, style = MaterialTheme.typography.labelSmall)
                            Text(
                                stat.subline,
                                color = TextSecondary.copy(alpha = 0.75f),
                                style = MaterialTheme.typography.labelSmall,
                            )
                            if (stat.trend.isNotBlank()) {
                                Text(stat.trend, color = stat.tint, style = MaterialTheme.typography.labelSmall)
                            }
                        }
                    }
                }
            }
        }
    }
}
