package com.lyo.app.ui.screens.create

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CreateCommunityEventRequest
import com.lyo.app.data.api.CreatePrivateLessonRequest
import com.lyo.app.data.api.CreateStudyGroupRequest
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateCommunityItemScreen(
    nav: NavHostController,
    createGroup: Boolean,
    createTutor: Boolean = false,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val formatter = remember { DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm") }
    val initialStart = remember {
        LocalDateTime.now().plusDays(1).withSecond(0).withNano(0)
    }

    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var maximum by remember { mutableStateOf("20") }
    var privateGroup by remember { mutableStateOf(false) }
    var isOnline by remember { mutableStateOf(false) }
    var location by remember { mutableStateOf("") }
    var meetingUrl by remember { mutableStateOf("") }
    var coordinates by remember { mutableStateOf<Pair<Double, Double>?>(null) }
    var eventType by remember { mutableStateOf("study_session") }
    var subject by remember { mutableStateOf("") }
    var hourlyPrice by remember { mutableStateOf("0") }
    var starts by remember { mutableStateOf(initialStart.format(formatter)) }
    var ends by remember { mutableStateOf(initialStart.plusHours(1).format(formatter)) }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    @SuppressLint("MissingPermission")
    fun captureLocation() {
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val latest = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            .filter { provider -> runCatching { manager.isProviderEnabled(provider) }.getOrDefault(false) }
            .mapNotNull { provider -> runCatching { manager.getLastKnownLocation(provider) }.getOrNull() }
            .maxByOrNull { it.time }
        if (latest != null) {
            coordinates = latest.latitude to latest.longitude
            if (location.isBlank()) location = "Current location"
        } else {
            error = "A current location is not available yet. Add a location name or try again."
        }
    }

    val locationPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { result ->
        if (result[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            result[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        ) captureLocation()
        else error = "Location permission is needed to place this learning node on the map."
    }

    fun useCurrentLocation() {
        val granted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) captureLocation()
        else locationPermission.launch(
            arrayOf(
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ),
        )
    }

    fun submit() {
        if (title.isBlank() || submitting) return
        submitting = true
        error = null

        scope.launch {
            runCatching {
                if (createTutor) {
                    require(subject.isNotBlank()) { "Add the subject you teach." }
                    ApiClient.api.createPrivateLesson(
                        CreatePrivateLessonRequest(
                            title = title.trim(),
                            description = description.trim().ifEmpty { null },
                            subject = subject.trim(),
                            pricePerHour = hourlyPrice.toDoubleOrNull()?.coerceAtLeast(0.0) ?: 0.0,
                            location = location.trim().ifEmpty { null },
                            latitude = if (isOnline) null else coordinates?.first,
                            longitude = if (isOnline) null else coordinates?.second,
                            isOnline = isOnline,
                            meetingUrl = meetingUrl.trim().ifEmpty { null },
                        ),
                    )
                } else if (createGroup) {
                    ApiClient.api.createStudyGroup(
                        CreateStudyGroupRequest(
                            name = title.trim(),
                            description = description.trim().ifEmpty { null },
                            privacy = if (privateGroup) "private" else "public",
                            maxMembers = maximum.toIntOrNull()?.coerceIn(2, 1_000) ?: 20,
                            requiresApproval = privateGroup,
                            location = location.trim().ifEmpty { null },
                            isOnline = isOnline,
                            meetingUrl = meetingUrl.trim().ifEmpty { null },
                            latitude = if (isOnline) null else coordinates?.first,
                            longitude = if (isOnline) null else coordinates?.second,
                        ),
                    )
                } else {
                    val zone = ZoneId.systemDefault()
                    val start = LocalDateTime.parse(starts.trim(), formatter).atZone(zone).toInstant()
                    val end = LocalDateTime.parse(ends.trim(), formatter).atZone(zone).toInstant()
                    require(end.isAfter(start)) { "The event must end after it starts." }

                    ApiClient.api.createCommunityEvent(
                        CreateCommunityEventRequest(
                            title = title.trim(),
                            description = description.trim().ifEmpty { null },
                            eventType = eventType,
                            location = location.trim().ifEmpty { null },
                            isOnline = isOnline,
                            meetingUrl = meetingUrl.trim().ifEmpty { null },
                            maxAttendees = maximum.toIntOrNull()?.coerceIn(1, 10_000) ?: 20,
                            startTime = start.toString(),
                            endTime = end.toString(),
                            timezone = zone.id,
                            latitude = if (isOnline) null else coordinates?.first,
                            longitude = if (isOnline) null else coordinates?.second,
                        ),
                    )
                }
            }.onSuccess {
                nav.navigate(Routes.COMMUNITY) {
                    popUpTo(Routes.CREATE) { inclusive = false }
                    launchSingleTop = true
                }
            }.onFailure { throwable ->
                error = throwable.localizedMessage ?: "This item could not be created."
            }
            submitting = false
        }
    }

    Scaffold(
        containerColor = Background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        when {
                            createTutor -> "Offer tutoring"
                            createGroup -> "Create study group"
                            else -> "Create event"
                        },
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }, enabled = !submitting) {
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
        },
    ) { padding ->
        Column(
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp, vertical = 12.dp),
        ) {
            Text(
                text = if (createGroup) {
                    "Create a real Community study group."
                } else if (createTutor) {
                    "Offer a tutoring session that learners can find on the map."
                } else {
                    "Schedule a real Community learning event."
                },
                style = MaterialTheme.typography.bodyMedium,
                color = TextSecondary,
            )

            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = {
                    Text(
                        when {
                            createTutor -> "Lesson title"
                            createGroup -> "Group name"
                            else -> "Event title"
                        },
                    )
                },
                singleLine = true,
                enabled = !submitting,
                modifier = Modifier.fillMaxWidth(),
            )

            OutlinedTextField(
                value = description,
                onValueChange = { description = it },
                label = { Text("Description") },
                minLines = 3,
                enabled = !submitting,
                modifier = Modifier.fillMaxWidth(),
            )

            if (createTutor) {
                OutlinedTextField(
                    value = subject,
                    onValueChange = { subject = it },
                    label = { Text("Subject") },
                    singleLine = true,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = hourlyPrice,
                    onValueChange = { hourlyPrice = it.filter { char -> char.isDigit() || char == '.' } },
                    label = { Text("Hourly price (USD, 0 for free)") },
                    singleLine = true,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth(),
                )
            } else if (createGroup) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    FilterChip(
                        selected = !privateGroup,
                        onClick = { privateGroup = false },
                        enabled = !submitting,
                        label = { Text("Public") },
                    )
                    FilterChip(
                        selected = privateGroup,
                        onClick = { privateGroup = true },
                        enabled = !submitting,
                        label = { Text("Private · approval") },
                    )
                }
            } else {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(
                        listOf(
                            "study_session" to "Study session",
                            "workshop" to "Workshop",
                            "class" to "Class",
                            "seminar" to "Seminar",
                            "office_hours" to "Office hours",
                        ),
                    ) { option ->
                        FilterChip(
                            selected = eventType == option.first,
                            onClick = { eventType = option.first },
                            enabled = !submitting,
                            label = { Text(option.second) },
                        )
                    }
                }
                OutlinedTextField(
                    value = starts,
                    onValueChange = { starts = it },
                    label = { Text("Starts · yyyy-MM-dd HH:mm") },
                    singleLine = true,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = ends,
                    onValueChange = { ends = it },
                    label = { Text("Ends · yyyy-MM-dd HH:mm") },
                    singleLine = true,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = !isOnline,
                    onClick = { isOnline = false },
                    enabled = !submitting,
                    label = { Text("In person") },
                )
                FilterChip(
                    selected = isOnline,
                    onClick = { isOnline = true; coordinates = null },
                    enabled = !submitting,
                    label = { Text("Online") },
                )
            }

            if (isOnline) {
                OutlinedTextField(
                    value = meetingUrl,
                    onValueChange = { meetingUrl = it },
                    label = { Text("Meeting link (optional)") },
                    singleLine = true,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth(),
                )
            } else {
                OutlinedTextField(
                    value = location,
                    onValueChange = { location = it },
                    label = { Text("Location") },
                    singleLine = true,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedButton(
                    onClick = ::useCurrentLocation,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (coordinates == null) "Place on map using current location" else "Map location added")
                }
            }

            if (!createTutor) {
                OutlinedTextField(
                    value = maximum,
                    onValueChange = { maximum = it.filter(Char::isDigit) },
                    label = {
                        Text(if (createGroup) "Maximum members" else "Maximum attendees")
                    },
                    singleLine = true,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            error?.let { message ->
                Text(
                    text = message,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                )
            }

            Button(
                onClick = ::submit,
                enabled = title.isNotBlank() && !submitting,
                colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (submitting) {
                    CircularProgressIndicator(
                        color = TextPrimary,
                        strokeWidth = 2.dp,
                        modifier = Modifier.padding(end = 8.dp),
                    )
                    Text("Creating…")
                } else {
                    Text(
                        when {
                            createTutor -> "Publish tutoring"
                            createGroup -> "Create group"
                            else -> "Create event"
                        },
                    )
                }
            }
        }
    }
}
