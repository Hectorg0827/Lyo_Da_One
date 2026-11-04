package com.lyo.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.lyo.app.ui.classroom.ClassroomDisplayMode
import com.lyo.app.ui.classroom.ClassroomModePicker
import com.lyo.app.ui.theme.LyoTheme

/** Debug-only, unauthenticated visual test surface for the mode selector.
 * Not packaged in release or staging production variants.
 */
class ClassroomPickerPreviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            LyoTheme {
                var clicked by remember { mutableStateOf(false) }
                if (clicked) {
                    Box(
                        Modifier.fillMaxSize().background(Color(0xFF0A102C)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("START_TAPPED", color = Color.White)
                    }
                } else {
                    ClassroomModePicker(
                        current = null,
                        canDismiss = false,
                        suggested = ClassroomDisplayMode.SOLO,
                        rememberChoice = true,
                        onRememberChoiceChange = {},
                        onChoose = { clicked = true },
                        onDismiss = {},
                    )
                }
            }
        }
    }
}
