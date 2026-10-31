package com.lyo.app.ui.screens.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.lyo.app.data.api.UserDto
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

private const val XP_PER_LEVEL = 5000

/**
 * Native counterpart to Web's ProfileHeader. Keeps all identity and progress
 * numbers grounded in the real profile instead of inventing decorative data.
 * The action slot retains the existing Settings/Follow integration.
 */
@Composable
internal fun ProfileHero(
    user: UserDto,
    action: @Composable () -> Unit,
) {
    val level = user.resolvedLevel.coerceAtLeast(1)
    val totalXp = user.resolvedXp.coerceAtLeast(0)
    val xpInLevel = (totalXp - (level - 1) * XP_PER_LEVEL).coerceAtLeast(0)
    val progress = (xpInLevel.toFloat() / XP_PER_LEVEL).coerceIn(0f, 1f)
    val glassShape = RoundedCornerShape(24.dp)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(glassShape)
            .background(Color(0xFF131A31))
            .border(1.dp, Color.White.copy(alpha = 0.1f), glassShape),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(174.dp)
                .background(
                    Brush.linearGradient(
                        listOf(
                            Color(0xFF6366F1),
                            Color(0xFF8B5CF6),
                            Color(0xFFEC4899),
                            Color(0xFFF59E0B),
                        ),
                    ),
                ),
        ) {
            Box(
                modifier = Modifier
                    .size(152.dp)
                    .offset(x = 240.dp, y = (-28).dp)
                    .background(Color(0x44F9A8D4), RoundedCornerShape(76.dp)),
            )
            if (user.isPremium == true) {
                Text(
                    "♛ Premium",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(16.dp)
                        .background(
                            Brush.horizontalGradient(listOf(Color(0xFFF59E0B), Color(0xFFEF4444))),
                            RoundedCornerShape(24.dp),
                        )
                        .padding(horizontal = 12.dp, vertical = 7.dp),
                )
            }
        }

        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp).padding(bottom = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().height(64.dp),
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Box(
                    modifier = Modifier
                        .offset(y = (-43).dp)
                        .requiredSize(100.dp)
                        .clip(RoundedCornerShape(21.dp))
                        .background(Brush.linearGradient(listOf(Color(0xFF6366F1), Color(0xFFEC4899))))
                        .padding(3.dp),
                ) {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .fillMaxSize()
                            .clip(RoundedCornerShape(17.dp))
                            .background(Color(0xFF28214B)),
                    ) {
                        if (!user.avatarUrl.isNullOrBlank()) {
                            AsyncImage(
                                model = user.avatarUrl,
                                contentDescription = user.displayName,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier.fillMaxSize(),
                            )
                        } else {
                            Text(
                                user.displayName.firstOrNull()?.uppercase() ?: "L",
                                fontWeight = FontWeight.Black,
                                color = Color.White,
                                fontSize = 37.sp,
                            )
                        }
                    }
                }
                Column(modifier = Modifier.padding(bottom = 4.dp)) { action() }
            }

            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    user.displayName,
                    color = Color(0xFFDFD7FF),
                    fontWeight = FontWeight.ExtraBold,
                    style = MaterialTheme.typography.headlineMedium,
                )
                user.username?.takeIf { it.isNotBlank() }?.let {
                    Text("@$it", color = TextSecondary, style = MaterialTheme.typography.bodySmall)
                }
                user.bio?.takeIf { it.isNotBlank() }?.let {
                    Text(it, color = TextSecondary, style = MaterialTheme.typography.bodyMedium)
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    "ϟ Level $level",
                    color = Color(0xFFC4B5FD),
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier
                        .background(Color(0x336366F1), RoundedCornerShape(10.dp))
                        .border(1.dp, Color(0x556366F1), RoundedCornerShape(10.dp))
                        .padding(horizontal = 11.dp, vertical = 7.dp),
                )
                Text("$totalXp total XP", color = TextSecondary, style = MaterialTheme.typography.labelSmall)
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.White.copy(alpha = 0.035f))
                    .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(16.dp)),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                listOf(
                    (user.followersCount ?: 0) to "Followers",
                    (user.followingCount ?: 0) to "Following",
                    (user.coursesCompleted ?: 0) to "Courses",
                ).forEachIndexed { index, pair ->
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.weight(1f).padding(vertical = 12.dp),
                    ) {
                        Text(
                            pair.first.toString(),
                            color = TextPrimary,
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 18.sp,
                        )
                        Text(pair.second, color = TextSecondary, style = MaterialTheme.typography.labelSmall)
                    }
                    if (index < 2) {
                        Spacer(Modifier.width(1.dp).height(36.dp).background(Color.White.copy(alpha = 0.08f)))
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text("Progress to Level ${level + 1}", color = TextSecondary,
                        style = MaterialTheme.typography.labelSmall)
                    Text("$xpInLevel / $XP_PER_LEVEL XP", color = TextSecondary,
                        style = MaterialTheme.typography.labelSmall)
                }
                Box(
                    modifier = Modifier.fillMaxWidth().height(8.dp)
                        .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(12.dp)),
                ) {
                    Box(
                        modifier = Modifier.fillMaxWidth(progress).height(8.dp)
                            .background(
                                Brush.horizontalGradient(listOf(Color(0xFF6366F1), Color(0xFFA78BFA))),
                                RoundedCornerShape(12.dp),
                            ),
                    )
                }
            }

            Text(
                "🔥  ${user.streak ?: 0} day streak",
                color = Color(0xFFFF9C54),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0x1FEF9A28), RoundedCornerShape(14.dp))
                    .border(1.dp, Color(0x33F59E0B), RoundedCornerShape(14.dp))
                    .padding(horizontal = 14.dp, vertical = 11.dp),
            )
        }
    }
}
