package com.lyo.app.ui.screens.discover

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CourseDto
import com.lyo.app.data.api.EventDto
import com.lyo.app.data.api.PlaceDto
import com.lyo.app.ui.components.CardGradients
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoAmber
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

private val Tabs = listOf("All", "Places", "Events", "Online")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiscoverScreen(nav: NavHostController) {
    var activeTab by remember { mutableStateOf("All") }
    var places by remember { mutableStateOf<List<PlaceDto>>(emptyList()) }
    var events by remember { mutableStateOf<List<EventDto>>(emptyList()) }
    var classes by remember { mutableStateOf<List<CourseDto>>(emptyList()) }
    var loaded by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        runCatching { ApiClient.api.places(1, 20) }
            .onSuccess { places = it.places ?: emptyList() }
        runCatching { ApiClient.api.events() }
            .onSuccess { events = it }
        runCatching { ApiClient.api.courses(0, 10) }
            .onSuccess { classes = it }
        loaded = true
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
    ) {
        TopAppBar(
            title = { Text("Discover") },
            navigationIcon = {
                IconButton(onClick = { nav.popBackStack() }) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = TextPrimary,
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Background,
                titleContentColor = TextPrimary,
            ),
        )

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(horizontal = 16.dp),
        ) {
            Tabs.forEach { tab ->
                FilterChip(
                    selected = activeTab == tab,
                    onClick = { activeTab = tab },
                    label = { Text(tab) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = LyoPurple.copy(alpha = 0.25f),
                        selectedLabelColor = LyoPurple,
                        labelColor = TextSecondary,
                    ),
                )
            }
        }

        if (!loaded) {
            LoadingBox()
            return
        }

        val showPlaces = activeTab == "All" || activeTab == "Places"
        val showEvents = activeTab == "All" || activeTab == "Events"
        val showOnline = activeTab == "All" || activeTab == "Online"

        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            if (showPlaces && places.isNotEmpty()) {
                item {
                    Text(
                        "Educational Places",
                        style = MaterialTheme.typography.headlineSmall,
                        color = TextPrimary,
                    )
                }
                item {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        items(places) { place -> PlaceCard(place) }
                    }
                }
                item {
                    Text(
                        "Top Rated",
                        style = MaterialTheme.typography.headlineSmall,
                        color = TextPrimary,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
                items(places.sortedByDescending { it.rating ?: 0.0 }.take(5)) { place ->
                    PlaceListRow(place)
                }
            }

            if (showEvents && events.isNotEmpty()) {
                item {
                    Text(
                        "Events",
                        style = MaterialTheme.typography.headlineSmall,
                        color = TextPrimary,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
                items(events) { event -> EventRow(event) }
            }

            if (showOnline && classes.isNotEmpty()) {
                item {
                    Text(
                        "Online Classes",
                        style = MaterialTheme.typography.headlineSmall,
                        color = TextPrimary,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
                items(classes) { course ->
                    GlassCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { nav.navigate(Routes.courseDetail(course.idStr)) },
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Text(
                                text = course.title ?: "Untitled",
                                style = MaterialTheme.typography.titleMedium,
                                color = TextPrimary,
                            )
                            Text(
                                text = course.subject ?: "General",
                                style = MaterialTheme.typography.bodySmall,
                                color = TextSecondary,
                            )
                        }
                    }
                }
            }

            if (places.isEmpty() && events.isEmpty() && classes.isEmpty()) {
                item {
                    EmptyState(
                        title = "Nothing to discover yet",
                        subtitle = "Places, events and classes will appear here.",
                    )
                }
            }

            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun PlaceCard(place: PlaceDto) {
    GlassCard(modifier = Modifier.width(230.dp)) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(110.dp)
                .clip(RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)),
        ) {
            if (!place.imageUrl.isNullOrBlank()) {
                AsyncImage(
                    model = place.imageUrl,
                    contentDescription = place.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            CardGradients[(place.id ?: "").hashCode().mod(CardGradients.size)]
                        ),
                )
            }
        }
        Column(modifier = Modifier.padding(12.dp)) {
            Text(
                text = place.name ?: "Unknown place",
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(top = 4.dp),
            ) {
                Icon(
                    Icons.Filled.Star,
                    contentDescription = null,
                    tint = LyoAmber,
                    modifier = Modifier.size(14.dp),
                )
                Text(
                    text = " ${place.rating ?: 0.0}  ·  ${place.category ?: ""}",
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                )
            }
            Text(
                text = place.address ?: "",
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

@Composable
private fun PlaceListRow(place: PlaceDto) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(52.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(
                        CardGradients[(place.id ?: "").hashCode().mod(CardGradients.size)]
                    ),
            )
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 12.dp),
            ) {
                Text(
                    text = place.name ?: "Unknown place",
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = place.description ?: "",
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.Star,
                    contentDescription = null,
                    tint = LyoAmber,
                    modifier = Modifier.size(14.dp),
                )
                Text(
                    text = " ${place.rating ?: 0.0}",
                    style = MaterialTheme.typography.labelLarge,
                    color = TextPrimary,
                )
            }
        }
    }
}

@Composable
private fun EventRow(event: EventDto) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                text = event.displayTitle,
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
            )
            val meta = listOfNotNull(
                event.startTime?.take(10),
                event.location,
            ).joinToString("  ·  ")
            if (meta.isNotBlank()) {
                Text(
                    text = meta,
                    style = MaterialTheme.typography.bodySmall,
                    color = LyoPurple,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            if (!event.description.isNullOrBlank()) {
                Text(
                    text = event.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}
