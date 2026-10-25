package com.lyo.app.ui.screens.create

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.R
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoBlue
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoPink
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

/** A familiar + Create hub: primary camera and post actions first, then LYO learning tools. */
@Composable
fun CreateScreen(nav: NavHostController) {
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(18.dp),
        modifier = Modifier.fillMaxSize().background(Background),
    ) {
        item {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(start = 20.dp, end = 12.dp, top = 24.dp),
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("LYO CREATE STUDIO", style = MaterialTheme.typography.labelSmall, color = LyoBlue, fontWeight = FontWeight.Bold)
                    Text("What will you create?", style = MaterialTheme.typography.headlineMedium, color = TextPrimary, fontWeight = FontWeight.Bold)
                    Text("Share what you know or build something new with Lyo.", style = MaterialTheme.typography.bodyMedium, color = TextSecondary, modifier = Modifier.padding(top = 6.dp))
                }
                Image(
                    painter = painterResource(R.drawable.mascot_standing),
                    contentDescription = "Lyo learning mascot",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.size(96.dp),
                )
            }
        }

        item {
            Text("START CREATING", style = MaterialTheme.typography.labelMedium, color = TextSecondary, fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 20.dp))
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                PrimaryCreateTile("Clip", "Camera or gallery", Icons.Filled.CameraAlt, LyoPink, Modifier.weight(1f)) { nav.navigate(Routes.CREATE_CLIP) }
                PrimaryCreateTile("Post", "Text and photos", Icons.Filled.EditNote, LyoBlue, Modifier.weight(1f)) { nav.navigate(Routes.CREATE_POST) }
            }
        }

        item {
            Text("MORE WAYS TO CREATE", style = MaterialTheme.typography.labelMedium, color = TextSecondary, fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 20.dp))
        }
        item { SecondaryCreateTile("Course", "Build a personalized course with Lyo", Icons.Filled.School, LyoGreen) { nav.navigate(Routes.COURSES) } }
        item { SecondaryCreateTile("Study group", "Learn together with your community", Icons.Filled.Groups, LyoPurple) { nav.navigate(Routes.CREATE_GROUP) } }
        item { SecondaryCreateTile("Learning event", "Host a class, workshop or meetup", Icons.Filled.Event, LyoBlue) { nav.navigate(Routes.CREATE_EVENT) } }
        item { SecondaryCreateTile("Ask Lyo", "Plan your next learning creation", Icons.Filled.SmartToy, LyoPurple) { nav.navigate(Routes.CHAT) } }
        item { Spacer(Modifier.height(96.dp)) }
    }
}

@Composable
private fun PrimaryCreateTile(title: String, subtitle: String, icon: androidx.compose.ui.graphics.vector.ImageVector, accent: Color, modifier: Modifier = Modifier, onClick: () -> Unit) {
    GlassCard(modifier = modifier.clip(RoundedCornerShape(24.dp)).clickable(onClick = onClick)) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth().padding(16.dp)) {
            Icon(icon, contentDescription = null, tint = accent, modifier = Modifier.size(32.dp))
            Text(title, style = MaterialTheme.typography.titleLarge, color = TextPrimary, fontWeight = FontWeight.Bold)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = TextSecondary)
            Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "Open $title", tint = accent, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
private fun SecondaryCreateTile(title: String, subtitle: String, icon: androidx.compose.ui.graphics.vector.ImageVector, accent: Color, onClick: () -> Unit) {
    GlassCard(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).clickable(onClick = onClick)) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(16.dp)) {
            Icon(icon, contentDescription = null, tint = accent, modifier = Modifier.size(28.dp))
            Spacer(Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium, color = TextPrimary, fontWeight = FontWeight.SemiBold)
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = TextSecondary)
            }
            Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "Open $title", tint = TextSecondary, modifier = Modifier.size(18.dp))
        }
    }
}
