package com.lyo.app.ui.navigation

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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

private data class CreateChoice(
    val label: String,
    val subtitle: String,
    val route: String,
    val icon: ImageVector,
    val accent: Color,
)

private val createChoices = listOf(
    CreateChoice("Post", "Share to your learning feed", Routes.CREATE_POST, Icons.Filled.Add, Color(0xFF3B82F6)),
    CreateChoice("Clip", "Teach in a short video", Routes.CREATE_CLIP, Icons.Filled.PlayCircle, Color(0xFF8B5CF6)),
    CreateChoice("Course", "Build an AI-guided course", Routes.COURSES, Icons.Filled.MenuBook, Color(0xFF10B981)),
    CreateChoice("Event", "Plan a real learning gathering", Routes.CREATE_EVENT, Icons.Filled.Event, Color(0xFFEC4899)),
    CreateChoice("Group", "Start a study community", Routes.CREATE_GROUP, Icons.Filled.Groups, Color(0xFFEC4899)),
)

/**
 * The native equivalent of web CreateSheet. Tapping the mobile Create glyph
 * opens choices in place, not a full-page directory that interrupts the user.
 * All actions land on existing, working Android routes.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun LyoCreateSheet(
    onDismiss: () -> Unit,
    onNavigate: (String) -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF151124),
        contentColor = Color.White,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                "Create something",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
            Text(
                "Choose how you want to share or teach.",
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.6f),
                modifier = Modifier.padding(bottom = 6.dp),
            )
            createChoices.forEach { choice ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    modifier = Modifier.fillMaxWidth()
                        .border(1.dp, Color.White.copy(alpha = 0.1f), RoundedCornerShape(16.dp))
                        .background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(16.dp))
                        .clickable { onNavigate(choice.route) }
                        .padding(14.dp),
                ) {
                    Icon(
                        imageVector = choice.icon,
                        contentDescription = null,
                        tint = choice.accent,
                        modifier = Modifier.size(25.dp),
                    )
                    Column {
                        Text(choice.label, fontWeight = FontWeight.SemiBold, color = Color.White)
                        Text(
                            choice.subtitle,
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.6f),
                        )
                    }
                }
            }
            Spacer(Modifier.size(16.dp))
        }
    }
}
