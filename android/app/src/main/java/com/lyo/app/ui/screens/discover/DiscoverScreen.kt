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
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.io.IOException
import retrofit2.HttpException

private val Tabs = listOf("All", "Places", "Events", "Online")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiscoverScreen(nav: NavHostController) {
    var activeTab by remember { mutableStateOf("All") }
    var places by remember { mutableStateOf<List<PlaceDto>>(emptyList()) }
    var events by remember { mutableStateOf<List<EventDto>>(emptyList()) }
    var classes by remember { mutableStateOf<List<CourseDto>>(emptyList()) }
    var placesError by remember { mutableStateOf<String?>(null) }
    var eventsError by remember { mutableStateOf<String?>(null) }
    var classesError by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(true) }
    var reloadVersion by remember { mutableStateOf(0) }

    LaunchedEffect(reloadVersion) {
        loading = true
        placesError = null
        eventsError = null
        classesError = null

        runCatching { ApiClient.api.places(1, 20) }
            .onSuccess { places = it.places.orEmpty() }
            .onFailure { placesError = discoverError(it, "places") }
        runCatching { ApiClient.api.events() }
            .onSuccess { events = it }
            .onFailure { eventsError = discoverError(it, "events") }
        runCatching { ApiClient.api.courses(0, 10) }
            .onSuccess { classes = it }
            .onFailure { classesError = discoverError(it, "online classes") }

        loading = false
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

        LazyRow(
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(Tabs) { tab ->
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

        if (loading) {
            LoadingBox()
            return
        }

        val showPlaces = activeTab == "All" || activeTab == "Places"
        val showEvents = activeTab == "All" || activeTab == "Events"
        val showOnline = activeTab == "All" || activeTab == "Online"
        val ratedPlaces = places
            .filter { it.rating != null }
            .sortedByDescending { it.rating }
            .take(5)
        val hasVisibleData =
            (showPlaces && places.isNotEmpty()) ||
                (showEvents && events.isNotEmpty()) ||
                (showOnline && classes.isNotEmpty())
        val hasVisibleError =
            (showPlaces && placesError != null) ||
                (showEvents && eventsError != null) ||
                (showOnline && classesError != null)

        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            if (showPlaces) {
                placesError?.let { message ->
                    item {
                        DiscoverErrorCard(
                            title = "Places unavailable",
                            message = message,
                            onRetry = { reloadVersion += 1 },
                        )
                    }
                }

                if (places.isNotEmpty()) {
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
                    if (ratedPlaces.isNotEmpty()) {
                        item {
                            Text(
                                "Top Rated",
                                style = MaterialTheme.typography.headlineSmall,
                                color = TextPrimary,
                                modifier = Modifier.padding(top = 8.dp),
                            )
                        }
                        items(ratedPlaces) { place -> PlaceListRow(place) }
                    }
                } else if (activeTab == "Places" && placesError == null) {
                    item {
                        EmptyState(
                            title = "No places yet",
                            subtitle = "Published educational places will appear here.",
                        )
                    }
                }
            }

            if (showEvents) {
                eventsError?.let { message ->
                    item {
                        DiscoverErrorCard(
                            title = "Events unavailable",
                            message = message,
                            onRetry = { reloadVersion += 1 },
                        )
                    }
                }

                if (events.isNotEmpty()) {
                    item {
                        Text(
                            "Events",
                            style = MaterialTheme.typography.headlineSmall,
                            color = TextPrimary,
                            modifier = Modifier.padding(top = 8.dp),
                        )
                    }
                    items(events) { event -> EventRow(event) }
                } else if (activeTab == "Events" && eventsError == null) {
                    item {
                        EmptyState(
                            title = "No events yet",
                            subtitle = "Published learning events will appear here.",
                        )
                    }
                }
            }

            if (showOnline) {
                classesError?.let { message ->
                    item {
                        DiscoverErrorCard(
                            title = "Online classes unavailable",
                            message = message,
                            onRetry = { reloadVersion += 1 },
                        )
                    }
                }

                if (classes.isNotEmpty()) {
                    item {
                        Text(
                            "Online Classes",
                            style = MaterialTheme.typography.headlineSmall,
                            color = TextPrimary,
                            modifier = Modifier.padding(top = 8.dp),
                        )
                    }
                    items(classes) { course -> OnlineCourseRow(course, nav) }
                } else if (activeTab == "Online" && classesError == null) {
                    item {
                        EmptyState(
                            title = "No online classes yet",
                            subtitle = "Published courses will appear here.",
                        )
                    }
                }
            }

            if (activeTab == "All" && !hasVisibleData && !hasVisibleError) {
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

private fun discoverError(error: Throwable, source: String): String = when (error) {
    is HttpException -> when (error.code()) {
        401, 403 -> "You are not authorized to load $source."
        404 -> "The $source service is not available."
        else -> "The $source request failed (${error.code()})."
    }
    is IOException -> "Check your connection and retry $source."
    else -> error.localizedMessage ?: "The $source could not be loaded."
}

@Composable
private fun DiscoverErrorCard(
    title: String,
    message: String,
    onRetry: () -> Unit,
) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, color = TextPrimary)
            Text(
                message,
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                modifier = Modifier.padding(top = 4.dp),
            )
            Text(
                "Retry",
                style = MaterialTheme.typography.titleSmall,
                color = LyoPurple,
                modifier = Modifier
                    .padding(top = 10.dp)
                    .clickable(onClick = onRetry)
                    .padding(vertical = 4.dp),
            )
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
            PlaceMetadata(place)
            place.address?.takeIf { it.isNotBlank() }?.let { address ->
                Text(
                    text = address,
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}

@Composable
private fun PlaceMetadata(place: PlaceDto) {
    val category = place.category?.takeIf { it.isNotBlank() }
    val rating = place.rating
    if (rating == null && category == null) return

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(top = 4.dp),
    ) {
        if (rating != null) {
            Icon(
                Icons.Filled.Star,
                contentDescription = null,
                tint = LyoAmber,
                modifier = Modifier.size(14.dp),
            )
            Text(
                text = " $rating",
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
            )
        }
        category?.let {
            Text(
                text = if (rating != null) "  ·  $it" else it,
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
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
                place.description?.takeIf { it.isNotBlank() }?.let { description ->
                    Text(
                        text = description,
                        style = MaterialTheme.typography.bodySmall,
                        color = TextSecondary,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            place.rating?.let { rating ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Filled.Star,
                        contentDescription = null,
                        tint = LyoAmber,
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        text = " $rating",
                        style = MaterialTheme.typography.labelLarge,
                        color = TextPrimary,
                    )
                }
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
            val metadata = listOfNotNull(
                event.startTime?.take(10),
                event.location?.takeIf { it.isNotBlank() },
            ).joinToString("  ·  ")
            if (metadata.isNotBlank()) {
                Text(
                    text = metadata,
                    style = MaterialTheme.typography.bodySmall,
                    color = LyoPurple,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            event.description?.takeIf { it.isNotBlank() }?.let { description ->
                Text(
                    text = description,
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

@Composable
private fun OnlineCourseRow(course: CourseDto, nav: NavHostController) {
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { nav.navigate(Routes.courseDetail(course.idStr)) },
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                text = course.title ?: "Untitled course",
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
            )
            course.subject?.takeIf { it.isNotBlank() }?.let { subject ->
                Text(
                    text = subject,
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}