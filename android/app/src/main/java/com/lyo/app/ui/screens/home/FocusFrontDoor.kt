package com.lyo.app.ui.screens.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp

/**
 * Android's actual learning entry mirrors web FrontDoor: a topic can go
 * directly into the canonical Classroom. Both new and returning learners
 * see this hero before progress and review cards, as on mobile Web.
 */
@Composable
internal fun FocusFrontDoor(
    knownLearner: Boolean,
    onEnterClassroom: (String) -> Unit,
    onStartTestPrep: () -> Unit,
    onOpenChat: () -> Unit,
) {
    var topic by remember { mutableStateOf("") }
    val shape = RoundedCornerShape(28.dp)
    Column(
        modifier = Modifier.fillMaxWidth()
            .border(1.dp, Color.White.copy(alpha = 0.16f), shape)
            .background(
                Brush.linearGradient(
                    listOf(Color(0xFF321B61), Color(0xFF7141BE), Color(0xFF1B1537)),
                ),
                shape,
            )
            .padding(22.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = if (knownLearner) "START A NEW COURSE" else "●  A LIVE TEACHER, NOT A PLAYLIST",
            color = Color(0xFFC8AFFF),
            fontWeight = FontWeight.Bold,
            style = androidx.compose.material3.MaterialTheme.typography.labelSmall,
        )
        Text(
            text = if (knownLearner) "What do you want to learn next?"
                else "What do you want to learn?",
            color = Color.White,
            fontWeight = FontWeight.ExtraBold,
            style = androidx.compose.material3.MaterialTheme.typography.headlineLarge,
        )
        if (!knownLearner) {
            Text(
                "LYO teaches you live, checks what you understand, adapts when you're stuck, and remembers what you've mastered.",
                color = Color.White.copy(alpha = 0.78f),
                style = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
            )
        }
        OutlinedTextField(
            value = topic,
            onValueChange = { topic = it },
            placeholder = { Text("Anything — a subject, a skill, a chapter") },
            singleLine = true,
            shape = RoundedCornerShape(16.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                cursorColor = Color.White,
                focusedPlaceholderColor = Color.White.copy(alpha = 0.62f),
                unfocusedPlaceholderColor = Color.White.copy(alpha = 0.62f),
                focusedBorderColor = Color.White.copy(alpha = 0.48f),
                unfocusedBorderColor = Color.White.copy(alpha = 0.26f),
                focusedContainerColor = Color(0xAA100B24),
                unfocusedContainerColor = Color(0xAA100B24),
            ),
            modifier = Modifier.fillMaxWidth(),
        )
        Button(
            onClick = { if (topic.isNotBlank()) onEnterClassroom(topic.trim()) },
            enabled = topic.isNotBlank(),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.White,
                contentColor = Color(0xFF1B1035),
                disabledContainerColor = Color.White.copy(alpha = 0.12f),
                disabledContentColor = Color.White.copy(alpha = 0.6f),
            ),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
        ) {
            Text("Enter Classroom", fontWeight = FontWeight.Bold)
        }
        Text(
            text = "Live Classroom is a guided lesson with teacher narration, a visual board and check-ins. Prefer asking questions at your own pace?",
            color = Color.White.copy(alpha = 0.75f),
            style = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
        )
        TextButton(onClick = onOpenChat) {
            Text(
                text = "Ask LYO Tutor in chat",
                color = Color(0xFFE0D4FF),
                textDecoration = TextDecoration.Underline,
            )
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        ) {
            Text(
                text = "Try",
                color = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.padding(top = 14.dp),
            )
            listOf("AP Chemistry", "Spanish for my trip", "Teach me fractions").forEach { example ->
                AssistChip(onClick = { topic = example }, label = { Text(example) })
            }
        }
        OutlinedButton(
            onClick = onStartTestPrep,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
        ) {
            Text("I have a test · Start or resume", color = Color.White)
        }
    }
}
