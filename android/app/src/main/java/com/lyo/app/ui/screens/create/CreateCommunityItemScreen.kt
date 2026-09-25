package com.lyo.app.ui.screens.create

import android.Manifest
import android.annotation.SuppressLint
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.text.format.DateFormat
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CreateCommunityEventRequest
import com.lyo.app.data.api.CreatePrivateLessonRequest
import com.lyo.app.data.api.CreateStudyGroupRequest
import com.lyo.app.data.api.PlaceSuggestionDto
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.screens.community.CommunityDiscovery
import com.lyo.app.ui.screens.community.CommunityMapViewModel
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

private val eventTypes = listOf(
    "workshop" to "Workshop",
    "class" to "Class",
    "lecture" to "Lecture or talk",
    "seminar" to "Seminar",
    "study_session" to "Study session or meetup",
    "discussion" to "Discussion",
    "office_hours" to "Office hours",
    "networking" to "Career or networking",
    "project_showcase" to "Project showcase",
    "other" to "Other learning event",
)

private data class ChosenPlace(val label: String, val name: String, val latitude: Double, val longitude: Double)

private const val MAX_IMAGE_BYTES = 8 * 1024 * 1024

/**
 * Creates account-owned Community items (events, study groups, tutoring) and
 * edits events the learner hosts. Everything is saved to the backend, so the
 * result appears on iOS, Android, and the web.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateCommunityItemScreen(
    nav: NavHostController,
    createGroup: Boolean,
    createTutor: Boolean = false,
    editEventId: String? = null,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val communityEntry = remember(nav) { runCatching { nav.getBackStackEntry(Routes.COMMUNITY) }.getOrNull() }
    val vm: CommunityMapViewModel = if (communityEntry != null) viewModel(viewModelStoreOwner = communityEntry) else viewModel()
    val createEvent = !createGroup && !createTutor
    val editing = editEventId != null
    val zone = remember { ZoneId.systemDefault() }
    val dayFormat = remember { DateTimeFormatter.ofPattern("EEE, MMM d · h:mm a") }
    val defaultStart = remember {
        val tomorrow = ZonedDateTime.now(zone).plusDays(1).withMinute(0).withSecond(0).withNano(0)
        tomorrow.withHour(tomorrow.hour.coerceIn(9, 18))
    }

    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var maximum by remember { mutableStateOf("20") }
    var privateGroup by remember { mutableStateOf(false) }
    var isOnline by remember { mutableStateOf(false) }
    var location by remember { mutableStateOf("") }
    var meetingUrl by remember { mutableStateOf("") }
    var coordinates by remember { mutableStateOf<Pair<Double, Double>?>(null) }
    var subject by remember { mutableStateOf("") }
    var hourlyPrice by remember { mutableStateOf("0") }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    // Event-only state.
    var eventType by remember { mutableStateOf("workshop") }
    var startAt by remember { mutableStateOf(defaultStart) }
    var endAt by remember { mutableStateOf(defaultStart.plusHours(2)) }
    var originalTimes by remember { mutableStateOf<Pair<ZonedDateTime, ZonedDateTime>?>(null) }
    var mode by remember { mutableStateOf("in_person") }
    var place by remember { mutableStateOf<ChosenPlace?>(null) }
    var addressQuery by remember { mutableStateOf("") }
    var suggestions by remember { mutableStateOf<List<PlaceSuggestionDto>>(emptyList()) }
    var searchingAddress by remember { mutableStateOf(false) }
    var venueName by remember { mutableStateOf("") }
    var websiteUrl by remember { mutableStateOf("") }
    var organizerName by remember { mutableStateOf("") }
    var imageUrl by remember { mutableStateOf("") }
    var uploading by remember { mutableStateOf(false) }
    var limitSpots by remember { mutableStateOf(false) }
    var spots by remember { mutableStateOf("20") }
    var paid by remember { mutableStateOf(false) }
    var price by remember { mutableStateOf("") }
    var visibility by remember { mutableStateOf("public") }
    var loadingEdit by remember { mutableStateOf(editing) }
    // One id per form: a double tap or a retry after a timeout returns the
    // event the first submit created instead of a duplicate.
    val requestId = remember { "android-${UUID.randomUUID()}" }

    LaunchedEffect(editEventId) {
        val id = editEventId ?: return@LaunchedEffect
        try {
            val detail = ApiClient.api.learningNodeDetail("event", id)
            val record = detail.event
            if (record == null || !detail.canEdit) {
                error = "Only the host can edit this event."
            } else {
                title = record.title
                description = record.description.orEmpty()
                eventType = record.eventType
                val start = CommunityDiscovery.parseInstant(record.startTime)?.atZone(zone)
                val end = CommunityDiscovery.parseInstant(record.endTime)?.atZone(zone)
                if (start != null && end != null) {
                    startAt = start
                    endAt = end
                    originalTimes = start to end
                }
                mode = record.attendanceMode ?: if (record.isOnline) "online" else "in_person"
                val latitude = record.latitude
                val longitude = record.longitude
                if (latitude != null && longitude != null) {
                    place = ChosenPlace(
                        label = record.address ?: record.location ?: "Event location",
                        name = record.venueName ?: record.location ?: "Event location",
                        latitude = latitude,
                        longitude = longitude,
                    )
                }
                venueName = record.venueName.orEmpty()
                meetingUrl = record.meetingUrl.orEmpty()
                websiteUrl = record.websiteUrl.orEmpty()
                organizerName = record.organizerName.orEmpty()
                imageUrl = record.imageUrl.orEmpty()
                limitSpots = record.maxAttendees != null
                spots = (record.maxAttendees ?: 20).toString()
                paid = record.priceType == "paid"
                price = record.priceAmount?.let { if (it == Math.floor(it)) it.toLong().toString() else it.toString() }.orEmpty()
                visibility = record.visibility ?: "public"
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            error = CommunityDiscovery.friendlyError(e, "load this event").message
        } finally {
            loadingEdit = false
        }
    }

    // Address suggestions from the backend geocoder, biased to the map area.
    LaunchedEffect(addressQuery) {
        val query = addressQuery.trim()
        if (query.length < 3) {
            suggestions = emptyList()
            return@LaunchedEffect
        }
        delay(350)
        searchingAddress = true
        try {
            suggestions = vm.geocode(query)
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            suggestions = emptyList()
        } finally {
            searchingAddress = false
        }
    }

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
            if (createEvent && place == null) {
                place = ChosenPlace("Pinned location", "Pinned location", latest.latitude, latest.longitude)
            }
        } else {
            error = "A current location is not available yet. Search the address instead."
        }
    }

    val locationPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { result ->
        if (result[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            result[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        ) captureLocation()
        else error = "Location permission is needed to use your current location. You can search the address instead."
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

    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        uploading = true
        error = null
        scope.launch {
            try {
                val mime = context.contentResolver.getType(uri) ?: "image/jpeg"
                if (!mime.startsWith("image/")) throw IllegalArgumentException("Choose an image file.")
                val bytes = withContext(Dispatchers.IO) {
                    context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                } ?: throw IllegalStateException("That photo could not be read.")
                if (bytes.size > MAX_IMAGE_BYTES) throw IllegalArgumentException("Images can be up to 8 MB.")
                val part = MultipartBody.Part.createFormData("file", "community-event.${mime.substringAfter('/')}", bytes.toRequestBody(mime.toMediaType()))
                val uploaded = ApiClient.api.uploadMedia(file = part, folder = "community".toRequestBody("text/plain".toMediaType()))
                imageUrl = uploaded.url ?: throw IllegalStateException("The photo service did not return a link.")
            } catch (e: CancellationException) {
                throw e
            } catch (e: IllegalArgumentException) {
                error = e.message
            } catch (_: Exception) {
                error = "We couldn't upload that photo. You can publish without one."
            } finally {
                uploading = false
            }
        }
    }

    fun pickDateTime(initial: ZonedDateTime, onPicked: (ZonedDateTime) -> Unit) {
        DatePickerDialog(
            context,
            { _, year, month, day ->
                TimePickerDialog(
                    context,
                    { _, hour, minute -> onPicked(ZonedDateTime.of(year, month + 1, day, hour, minute, 0, 0, zone)) },
                    initial.hour,
                    initial.minute,
                    DateFormat.is24HourFormat(context),
                ).show()
            },
            initial.year,
            initial.monthValue - 1,
            initial.dayOfMonth,
        ).show()
    }

    val timesChanged = originalTimes?.let { it.first != startAt || it.second != endAt } ?: true
    val normalizedWebsite = websiteUrl.trim().takeIf { it.isNotEmpty() }?.let { site ->
        CommunityDiscovery.safeWebUrl(site) ?: CommunityDiscovery.safeWebUrl("https://$site")
    }

    fun validateEvent(): String? {
        if (title.isBlank()) return "Give your event a title."
        if (!endAt.isAfter(startAt)) return "The event must end after it starts."
        if (!endAt.isAfter(ZonedDateTime.now(zone)) && timesChanged) return "Choose a time in the future."
        if (mode != "online" && place == null) return "Search for the address, then adjust the pin if needed."
        if (mode == "online" && meetingUrl.isBlank()) return "Add the link people will use to join."
        if (meetingUrl.isNotBlank() && CommunityDiscovery.safeWebUrl(meetingUrl.trim()) == null) {
            return "The meeting link must start with https://"
        }
        if (websiteUrl.isNotBlank() && normalizedWebsite == null) return "The website doesn't look like a web address."
        if (paid && price.isNotBlank() && (price.toDoubleOrNull() ?: -1.0) < 0) return "Enter the price as a number."
        return null
    }

    fun submitEvent() {
        val problem = validateEvent()
        if (problem != null) {
            error = problem
            return
        }
        submitting = true
        error = null
        val inPerson = mode != "online"
        val needsLink = mode != "in_person"
        val chosen = place
        val venue = if (inPerson) venueName.trim().ifEmpty { chosen?.name?.takeIf { it != "Pinned location" } } else null
        val locationText = if (inPerson) chosen?.label ?: venue else "Online"
        val capacity = if (limitSpots) spots.toIntOrNull()?.coerceIn(1, 10_000) else null
        val amount = if (paid) price.toDoubleOrNull()?.takeIf { it > 0 } else null
        scope.launch {
            try {
                if (editEventId != null) {
                    // The form shows every field, so an emptied one is sent as null to clear it.
                    val fields = linkedMapOf<String, Any?>(
                        "title" to title.trim(),
                        "description" to description.trim().ifEmpty { null },
                        "event_type" to eventType,
                        "location" to locationText,
                        "is_online" to (mode != "in_person"),
                        "meeting_url" to if (needsLink) meetingUrl.trim().ifEmpty { null } else null,
                        "max_attendees" to capacity,
                        "latitude" to if (inPerson) chosen?.latitude else null,
                        "longitude" to if (inPerson) chosen?.longitude else null,
                        "attendance_mode" to mode,
                        "venue_name" to venue,
                        "address" to if (inPerson) chosen?.label else null,
                        "website_url" to normalizedWebsite,
                        "image_url" to imageUrl.ifBlank { null },
                        "organizer_name" to organizerName.trim().ifEmpty { null },
                        "price_type" to if (paid) "paid" else "free",
                        "price_amount" to amount,
                        "currency" to if (paid) "USD" else null,
                        "visibility" to visibility,
                    )
                    if (timesChanged) {
                        fields["start_time"] = startAt.toInstant().toString()
                        fields["end_time"] = endAt.toInstant().toString()
                        fields["timezone"] = zone.id
                    }
                    vm.updateEvent(editEventId.toLong(), fields)
                    vm.announce("Changes saved")
                    nav.popBackStack()
                } else {
                    val record = vm.createEvent(
                        CreateCommunityEventRequest(
                            title = title.trim(),
                            description = description.trim().ifEmpty { null },
                            eventType = eventType,
                            location = locationText,
                            isOnline = mode != "in_person",
                            meetingUrl = if (needsLink) meetingUrl.trim().ifEmpty { null } else null,
                            maxAttendees = capacity,
                            startTime = startAt.toInstant().toString(),
                            endTime = endAt.toInstant().toString(),
                            timezone = zone.id,
                            latitude = if (inPerson) chosen?.latitude else null,
                            longitude = if (inPerson) chosen?.longitude else null,
                            attendanceMode = mode,
                            venueName = venue,
                            address = if (inPerson) chosen?.label else null,
                            websiteUrl = normalizedWebsite,
                            imageUrl = imageUrl.ifBlank { null },
                            organizerName = organizerName.trim().ifEmpty { null },
                            priceType = if (paid) "paid" else "free",
                            priceAmount = amount,
                            currency = if (paid) "USD" else null,
                            visibility = visibility,
                            clientRequestId = requestId,
                        ),
                    )
                    // A new event opens on its own page, like on the web and iOS.
                    nav.navigate(Routes.communityNode("event", record.id.toString())) {
                        popUpTo(Routes.CREATE_EVENT) { inclusive = true }
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = CommunityDiscovery.friendlyError(e, if (editing) "save your changes" else "publish this event").message
            } finally {
                submitting = false
            }
        }
    }

    fun submit() {
        if (title.isBlank() || submitting) return
        if (createEvent) {
            submitEvent()
            return
        }
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
                } else {
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
                }
            }.onSuccess {
                vm.refreshAll()
                nav.navigate(Routes.COMMUNITY) {
                    popUpTo(Routes.CREATE) { inclusive = false }
                    launchSingleTop = true
                }
            }.onFailure { throwable ->
                error = if (throwable is IllegalArgumentException) {
                    throwable.message
                } else {
                    CommunityDiscovery.friendlyError(throwable, "create this").message
                }
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
                            editing -> "Edit event"
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
        if (loadingEdit) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
            ) { CircularProgressIndicator(color = LyoPurple) }
        } else Column(
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp),
        ) {
            Text(
                text = when {
                    editing -> "Changes are saved to your Lyo account and show on every device."
                    createGroup -> "Create a real Community study group."
                    createTutor -> "Offer a tutoring session that learners can find on the map."
                    else -> "Host a learning event people nearby can find, save, and RSVP to."
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
                label = { Text(if (createEvent) "What will people learn?" else "Description") },
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
                    FilterChip(selected = !privateGroup, onClick = { privateGroup = false }, enabled = !submitting, label = { Text("Public") })
                    FilterChip(selected = privateGroup, onClick = { privateGroup = true }, enabled = !submitting, label = { Text("Private · approval") })
                }
            }

            if (createEvent) {
                FormLabel("Kind of event")
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(eventTypes) { option ->
                        FilterChip(
                            selected = eventType == option.first,
                            onClick = { eventType = option.first },
                            enabled = !submitting,
                            label = { Text(option.second) },
                        )
                    }
                }

                FormLabel("When")
                DateTimeButton("Starts", startAt.format(dayFormat), enabled = !submitting) {
                    pickDateTime(startAt) { picked ->
                        startAt = picked
                        if (!endAt.isAfter(picked)) endAt = picked.plusHours(1)
                    }
                }
                DateTimeButton("Ends", endAt.format(dayFormat), enabled = !submitting) {
                    pickDateTime(endAt) { picked -> endAt = picked }
                }
                Text(
                    "Times are in ${zone.id.replace('_', ' ')}. Everyone sees them in their own time zone.",
                    color = TextSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )

                FormLabel("Where")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("in_person" to "In person", "online" to "Online", "hybrid" to "Hybrid").forEach { (value, label) ->
                        FilterChip(selected = mode == value, onClick = { mode = value }, enabled = !submitting, label = { Text(label) })
                    }
                }
                if (mode != "online") {
                    OutlinedTextField(
                        value = addressQuery,
                        onValueChange = { addressQuery = it },
                        label = { Text(if (place == null) "Search the address" else "Search a different address") },
                        singleLine = true,
                        enabled = !submitting,
                        trailingIcon = {
                            if (searchingAddress) CircularProgressIndicator(color = LyoPurple, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                        },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    suggestions.forEach { suggestion ->
                        Surface(
                            color = SurfaceElevated,
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(min = 48.dp)
                                .clickable {
                                    place = ChosenPlace(suggestion.label, suggestion.name, suggestion.latitude, suggestion.longitude)
                                    if (venueName.isBlank() && suggestion.name != suggestion.label) venueName = suggestion.name
                                    suggestions = emptyList()
                                    addressQuery = ""
                                },
                        ) {
                            Column(modifier = Modifier.padding(12.dp)) {
                                Text(suggestion.name, color = TextPrimary, fontWeight = FontWeight.SemiBold)
                                Text(suggestion.label, color = TextSecondary, style = MaterialTheme.typography.bodySmall)
                            }
                        }
                    }
                    val chosen = place
                    if (chosen == null) {
                        OutlinedButton(onClick = ::useCurrentLocation, enabled = !submitting, modifier = Modifier.fillMaxWidth()) {
                            Text("Use my current location")
                        }
                    } else {
                        Text(chosen.label, color = TextPrimary, style = MaterialTheme.typography.bodyMedium)
                        PinPickerMap(
                            latitude = chosen.latitude,
                            longitude = chosen.longitude,
                            onMoved = { latitude, longitude -> place = chosen.copy(latitude = latitude, longitude = longitude) },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(200.dp),
                        )
                        Text("Tap the map to move the pin to the exact entrance.", color = TextSecondary, style = MaterialTheme.typography.bodySmall)
                    }
                    OutlinedTextField(
                        value = venueName,
                        onValueChange = { venueName = it },
                        label = { Text("Venue name (optional)") },
                        singleLine = true,
                        enabled = !submitting,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                if (mode != "in_person") {
                    OutlinedTextField(
                        value = meetingUrl,
                        onValueChange = { meetingUrl = it },
                        label = { Text(if (mode == "online") "Meeting link" else "Meeting link (optional)") },
                        singleLine = true,
                        enabled = !submitting,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                FormLabel("Host")
                OutlinedTextField(
                    value = organizerName,
                    onValueChange = { organizerName = it },
                    label = { Text("Organizer (you or your organization)") },
                    singleLine = true,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = websiteUrl,
                    onValueChange = { websiteUrl = it },
                    label = { Text("Website (optional)") },
                    singleLine = true,
                    enabled = !submitting,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                    modifier = Modifier.fillMaxWidth(),
                )

                FormLabel("Photo")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    OutlinedButton(
                        onClick = { photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                        enabled = !submitting && !uploading,
                    ) { Text(if (imageUrl.isBlank()) "Add a photo (optional)" else "Replace photo") }
                    if (uploading) CircularProgressIndicator(color = LyoPurple, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
                    if (imageUrl.isNotBlank() && !uploading) {
                        Text("Photo added", color = TextSecondary, modifier = Modifier.weight(1f))
                        androidx.compose.material3.TextButton(onClick = { imageUrl = "" }) { Text("Remove") }
                    }
                }

                FormLabel("Spots and price")
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Limit spots", color = TextPrimary, modifier = Modifier.weight(1f))
                    Switch(checked = limitSpots, onCheckedChange = { limitSpots = it }, enabled = !submitting)
                }
                if (limitSpots) {
                    OutlinedTextField(
                        value = spots,
                        onValueChange = { spots = it.filter(Char::isDigit) },
                        label = { Text("Maximum attendees") },
                        singleLine = true,
                        enabled = !submitting,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = !paid, onClick = { paid = false }, enabled = !submitting, label = { Text("Free") })
                    FilterChip(selected = paid, onClick = { paid = true }, enabled = !submitting, label = { Text("Paid") })
                }
                if (paid) {
                    OutlinedTextField(
                        value = price,
                        onValueChange = { price = it.filter { char -> char.isDigit() || char == '.' } },
                        label = { Text("Price (USD)") },
                        singleLine = true,
                        enabled = !submitting,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                FormLabel("Who can find it")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("public" to "Public", "unlisted" to "Unlisted", "private" to "Private").forEach { (value, label) ->
                        FilterChip(selected = visibility == value, onClick = { visibility = value }, enabled = !submitting, label = { Text(label) })
                    }
                }
                Text(
                    when (visibility) {
                        "unlisted" -> "Only people with the link can open it. It never appears on the map."
                        "private" -> "Only you — a draft until you share it."
                        else -> "On the map and in search for every Lyo learner."
                    },
                    color = TextSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = !isOnline, onClick = { isOnline = false }, enabled = !submitting, label = { Text("In person") })
                    FilterChip(selected = isOnline, onClick = { isOnline = true; coordinates = null }, enabled = !submitting, label = { Text("Online") })
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

                if (createGroup) {
                    OutlinedTextField(
                        value = maximum,
                        onValueChange = { maximum = it.filter(Char::isDigit) },
                        label = { Text("Maximum members") },
                        singleLine = true,
                        enabled = !submitting,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            Text(
                "Everything you publish, and everyone's RSVPs, is saved to Lyo accounts — not this phone — so it appears on iOS, Android, and the web.",
                color = TextSecondary,
                style = MaterialTheme.typography.bodySmall,
            )

            error?.let { message ->
                Text(
                    text = message,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }

            Button(
                onClick = ::submit,
                enabled = title.isNotBlank() && !submitting && !uploading,
                colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp),
            ) {
                if (submitting) {
                    CircularProgressIndicator(
                        color = TextPrimary,
                        strokeWidth = 2.dp,
                        modifier = Modifier
                            .padding(end = 8.dp)
                            .size(18.dp),
                    )
                    Text(if (editing) "Saving…" else "Publishing…")
                } else {
                    Text(
                        when {
                            editing -> "Save changes"
                            createTutor -> "Publish tutoring"
                            createGroup -> "Create group"
                            else -> "Publish event"
                        },
                    )
                }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun FormLabel(text: String) {
    Text(text, color = TextPrimary, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 4.dp))
}

@Composable
private fun DateTimeButton(label: String, value: String, enabled: Boolean, onClick: () -> Unit) {
    OutlinedButton(onClick = onClick, enabled = enabled, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
        Icon(Icons.Default.Schedule, contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text("$label: $value", modifier = Modifier.weight(1f))
    }
}

/** A small map for placing the event pin: tap anywhere to move it. */
@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun PinPickerMap(
    latitude: Double,
    longitude: Double,
    onMoved: (Double, Double) -> Unit,
    modifier: Modifier = Modifier,
) {
    val bridge = remember { PinBridge() }
    bridge.onMoved = onMoved
    var ready by remember { mutableStateOf(false) }
    bridge.onReady = { ready = true }
    var webView by remember { mutableStateOf<WebView?>(null) }
    val initial = remember { latitude to longitude }
    AndroidView(
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                webViewClient = WebViewClient()
                setBackgroundColor(0xFF0B1230.toInt())
                contentDescription = "Map pin for the event location"
                addJavascriptInterface(bridge, "LyoPin")
                loadDataWithBaseURL("https://lyoai.app", pinPickerHtml(initial.first, initial.second), "text/html", "UTF-8", null)
                webView = this
            }
        },
        modifier = modifier,
    )
    LaunchedEffect(ready, latitude, longitude) {
        if (ready) webView?.evaluateJavascript("window.setPin($latitude, $longitude)", null)
    }
    DisposableEffect(Unit) {
        onDispose {
            webView?.removeJavascriptInterface("LyoPin")
            webView?.destroy()
            webView = null
        }
    }
}

private class PinBridge {
    var onMoved: (Double, Double) -> Unit = { _, _ -> }
    var onReady: () -> Unit = {}
    private val main = Handler(Looper.getMainLooper())

    @JavascriptInterface
    fun moved(latitude: Double, longitude: Double) {
        main.post { onMoved(latitude, longitude) }
    }

    @JavascriptInterface
    fun ready() {
        main.post { onReady() }
    }
}

private fun pinPickerHtml(latitude: Double, longitude: Double): String = """
    <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
    <style>html,body,#map{height:100%;margin:0;background:#0B1230}.pin{display:block;width:28px;height:28px;border:3px solid #fff;border-radius:50% 50% 50% 6px;background:#6366F1;box-shadow:0 6px 18px #0008}</style>
    </head><body><div id="map"></div><script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script><script>
    const map=L.map('map',{zoomControl:true,dragging:false,scrollWheelZoom:false}).setView([$latitude,$longitude],17);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'&copy; OpenStreetMap contributors'}).addTo(map);
    const pin=L.marker([$latitude,$longitude],{icon:L.divIcon({className:'',html:'<span class="pin"></span>',iconSize:[34,34],iconAnchor:[17,32]}),keyboard:false}).addTo(map);
    map.on('click',function(e){pin.setLatLng(e.latlng);LyoPin.moved(e.latlng.lat,e.latlng.lng)});
    window.setPin=function(lat,lng){const here=pin.getLatLng();if(Math.abs(here.lat-lat)<1e-7&&Math.abs(here.lng-lng)<1e-7)return;pin.setLatLng([lat,lng]);map.setView([lat,lng],map.getZoom())};
    LyoPin.ready();
    </script></body></html>
""".trimIndent()
