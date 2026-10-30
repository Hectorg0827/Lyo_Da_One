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
import androidx.compose.ui.unit.dp

/**
 * Android's actual learning entry mirrors web FrontDoor: a topic can go
 * directly into the canonical Classroom. A new learner sees this first,
 * before any empty XP/streak/dashboard cards. Returning learners see a more
 * compact version after their saved course stack.
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
                    listOf(Color(0xFF3C246B), Color(0xFF211238), Color(0xFF150D2E)),
                ),
                shape,
            )
            .padding(if (knownLearner) 18.dp else 22.dp),
        verticalArrangement = Arrangement.spacedBy(13.dp),
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
            label = { Text("A subject, skill or chapter") },
            placeholder = { Text("Try: Teach me fractions") },
            singleLine = true,
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
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        ) {
            listOf("AP Chemistry", "Spanish for my trip", "Teach me fractions").forEach { example ->
                AssistChip(onClick = { topic = example }, label = { Text(example) })
            }
        }
        TextButton(onClick = onOpenChat) {
            Text("Prefer a conversation? Ask LYO in Chat", color = Color(0xFFD8C9FF))
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
