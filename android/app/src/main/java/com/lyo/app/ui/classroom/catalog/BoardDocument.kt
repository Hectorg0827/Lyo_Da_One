package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
                        if (block.language.isNotBlank()) Text(block.language.uppercase(), color = LyoVioletLight, style = MaterialTheme.typography.labelSmall)
                        Text(block.text, fontFamily = FontFamily.Monospace, color = TextPrimary, modifier = Modifier.horizontalScroll(rememberScrollState()).padding(top = 8.dp))
                    }
                    "table" -> Column(Modifier.horizontalScroll(rememberScrollState()).background(Background, RoundedCornerShape(12.dp)).padding(12.dp)) {
                        Row { block.headers.forEach { Text(it, color = LyoVioletLight, style = MaterialTheme.typography.labelLarge, modifier = Modifier.width(140.dp).padding(8.dp)) } }
                        block.rows.forEach { row -> Row { row.forEach { Text(it, color = TextPrimary, modifier = Modifier.width(140.dp).padding(8.dp)) } } }
                    }
                    "steps", "bullets" -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        block.items.forEachIndexed { i, item ->
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text(if (block.kind == "steps") "${i + 1}." else "•", color = LyoVioletLight)
                                Text(item, color = TextPrimary, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                    else -> Text(block.text, color = TextSecondary)
                }
            }
        }
    }
}
