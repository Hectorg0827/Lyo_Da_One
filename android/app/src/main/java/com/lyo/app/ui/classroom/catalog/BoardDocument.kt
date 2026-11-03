package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.lyo.app.data.classroom.ClassroomBoardDocument
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoVioletLight
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

@Composable
fun BoardDocumentView(document: ClassroomBoardDocument) {
    SelectionContainer {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            document.blocks.forEach { block ->
                when (block.kind) {
                    "code" -> Column(Modifier.background(Background, RoundedCornerShape(12.dp)).padding(12.dp)) {
                        if ((looksLikeMathLesson(block.text) || containsLessonMath(block.text)) && (block.language.isBlank() || block.language in listOf("text", "plain", "math", "latex"))) {
                            LessonRichText(block.text)
                        } else {
                            if (block.language.isNotBlank()) Text(block.language.uppercase(), color = LyoVioletLight, style = MaterialTheme.typography.labelSmall)
                            Text(block.text, fontFamily = FontFamily.Monospace, color = TextPrimary, modifier = Modifier.horizontalScroll(rememberScrollState()).padding(top = 8.dp))
                        }
                    }
                    "table" -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        // Mobile-friendly table cards: never crop the final columns
                        // or treat math/Markdown in cells as literal source code.
                        block.rows.forEach { row ->
                            Column(
                                modifier = Modifier.fillMaxWidth()
                                    .background(Background, RoundedCornerShape(12.dp))
                                    .padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp),
                            ) {
                                row.forEachIndexed { col, cell ->
                                    Text(block.headers[col], color = LyoVioletLight, style = MaterialTheme.typography.labelSmall)
                                    LessonRichText(cell, modifier = Modifier.fillMaxWidth())
                                }
                            }
                        }
                    }
                    "steps", "bullets" -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        block.items.forEachIndexed { i, item ->
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text(if (block.kind == "steps") "${i + 1}." else "•", color = LyoVioletLight)
                                LessonRichText(item, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                    else -> LessonRichText(block.text, modifier = Modifier.fillMaxWidth())
                }
            }
        }
    }
}
