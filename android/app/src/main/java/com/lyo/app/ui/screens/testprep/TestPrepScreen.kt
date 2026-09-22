package com.lyo.app.ui.screens.testprep

import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.api.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MultipartBody
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.time.*
import java.time.format.DateTimeFormatter
import java.util.UUID

@Composable
fun TestPrepScreen(nav: NavHostController) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var saved by remember { mutableStateOf<PrepSnapshot?>(null) }
    var readiness by remember { mutableStateOf<PrepReadiness?>(null) }
    var draft by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    var loaded by remember { mutableStateOf(false) }
    var materials by remember { mutableStateOf<List<PrepMaterial>>(emptyList()) }
    var retry by remember { mutableStateOf<Pair<String, String>?>(null) }
    var editing by remember { mutableStateOf(false) }
    var subject by remember { mutableStateOf("") }
    var date by remember { mutableStateOf("") }
    var topics by remember { mutableStateOf("") }
    var minutes by remember { mutableStateOf("45") }
    var days by remember { mutableStateOf("5") }

    suspend fun load() {
        try {
            saved = ApiClient.testPrep.state()
            loaded = true
            val plan = saved?.plan
            readiness = if (plan != null) ApiClient.testPrep.readiness(plan.id) else null
        } catch (_: Exception) { error = "Could not refresh your saved test prep. Please retry." }
    }
    LaunchedEffect(Unit) { load() }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null && !busy) scope.launch {
            busy = true; error = null
            try {
                val resolver = context.contentResolver
                val mime = resolver.getType(uri) ?: "application/octet-stream"
                val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                    if (it.moveToFirst()) it.getString(0) else "Study material"
                } ?: "Study material"
                val bytes = withContext(Dispatchers.IO) {
                    resolver.openInputStream(uri)?.use { input ->
                        val output = java.io.ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (output.size() <= 10 * 1024 * 1024) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    } ?: throw IllegalStateException("Cannot read file")
                }
                require(bytes.size <= 10 * 1024 * 1024) { "Files must be under 10 MB" }
                val upload = ApiClient.api.uploadMedia(MultipartBody.Part.createFormData("file", name,
                    bytes.toRequestBody(mime.toMediaType())), "test-prep".toRequestBody("text/plain".toMediaType()))
                val material = PrepMaterial(name, upload.url, if (mime.startsWith("image/")) "IMAGE" else "DOCUMENT", mime)
                val snapshot = saved
                val profile = snapshot?.profile
                if (snapshot != null && profile != null) {
                    ApiClient.testPrep.edit(profile.id, PrepEdit(snapshot.revision, materials = profile.materials + material))
                    load()
                } else materials = materials + material
            } catch (_: Exception) { error = "Could not add the file. Try a photo, PDF or text file under 10 MB." }
            finally { busy = false }
        }
    }

    LazyColumn(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            TextButton(onClick = { nav.popBackStack() }) { Text("Back") }
            Text(saved?.profile?.subject?.takeUnless { it == "Pending Test" } ?: "Get ready for your test", style = MaterialTheme.typography.headlineMedium)
            Text("Your plan and progress follow your account on every device.")
            if (busy) LinearProgressIndicator(Modifier.fillMaxWidth())
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            notice?.let { Text(it) }
            TextButton(enabled = !busy, onClick = { scope.launch { error = null; load() } }) { Text("Refresh") }
        }
        if (loaded && saved?.plan == null) {
            items(saved?.profile?.intake_transcript ?: emptyList()) { turn ->
                Card(Modifier.fillMaxWidth()) { Text(turn.content, Modifier.padding(12.dp)) }
            }
            item {
                if (saved?.profile?.intake_complete == true) {
                    Button(enabled = !busy, onClick = { scope.launch {
                        busy = true; error = null
                        try { ApiClient.testPrep.generate(saved!!.profile!!.id); load() }
                        catch (_: Exception) { error = "Your details are saved. Could not build the schedule; please retry." }
                        finally { busy = false }
                    } }) { Text("Build my saved plan") }
                }
                OutlinedTextField(draft, { draft = it }, label = { Text("Tell me about your test") }, modifier = Modifier.fillMaxWidth(), enabled = !busy)
                Button(enabled = !busy && draft.isNotBlank(), onClick = { scope.launch {
                    busy = true; error = null
                    val text = draft.trim()
                    if (retry?.first != text) retry = text to UUID.randomUUID().toString()
                    try {
                        val reply = ApiClient.testPrep.intake(PrepIntake(text, saved?.profile?.id, retry!!.second, materials = materials))
                        retry = null; draft = ""; materials = emptyList()
                        if (reply.intake_complete) ApiClient.testPrep.generate(reply.test_profile_id)
                        load()
                    } catch (_: Exception) { error = "Could not finish that step. Your saved answers are preserved."; load() }
                    finally { busy = false }
                } }) { Text("Continue") }
            }
        }
        if (saved?.profile?.intake_complete == true) item {
                TextButton(enabled = !busy, onClick = {
                    saved?.profile?.let { subject = it.subject; date = it.test_date; topics = it.topics.joinToString("\n") { t -> t.name }; minutes = it.daily_minutes_available.toString(); days = it.study_days_per_week.toString() }
                    editing = !editing
                }) { Text(if (editing) "Close details" else "Edit test details") }
                if (editing) {
                    Text("Rebuild upcoming sessions while keeping completed work.")
                    OutlinedTextField(subject, { subject = it }, label = { Text("Subject") })
                    OutlinedTextField(date, { date = it }, label = { Text("Test date YYYY-MM-DD") })
                    OutlinedTextField(topics, { topics = it }, label = { Text("Topics, one per line") })
                    OutlinedTextField(minutes, { minutes = it }, label = { Text("Minutes per day") })
                    OutlinedTextField(days, { days = it }, label = { Text("Days per week") })
                    Button(enabled = !busy, onClick = { scope.launch {
                        busy = true; error = null
                        try {
                            val snapshot = saved!!; val profile = snapshot.profile!!
                            val result = ApiClient.testPrep.edit(profile.id, PrepEdit(snapshot.revision,
                                subject, date, topics.lines().filter { it.isNotBlank() }.map { PrepTopic(it.trim()) },
                                minutes.toInt(), days.toInt(), ZoneId.systemDefault().id))
                            if (result.needs_plan) ApiClient.testPrep.generate(profile.id)
                            editing = false; load()
                        } catch (_: Exception) { error = "Could not update your plan. Check the date and availability, then refresh."; load() }
                        finally { busy = false }
                    } }) { Text("Save and update schedule") }
                }
        }
        if (saved?.plan != null) {
            item {
                val ready = readiness
                Text(when {
                    ready == null -> "Readiness unavailable"
                    ready.topics_assessed == 0 -> "Not assessed yet"
                    ready.readiness == null -> "No readiness to report yet"
                    else -> "${(ready.readiness * 100).toInt()}% ready"
                }, style = MaterialTheme.typography.titleLarge)
                ready?.days_remaining?.let { Text("$it days until your test") }
                ready?.topics?.forEach { Text("${it.topic}: ${it.mastery?.let { value -> "${(value * 100).toInt()}%" } ?: "Not started"}") }
                ready?.focus_next?.firstOrNull()?.let { Text("Focus next: $it") }
                Text("Full schedule · ${saved?.timezone}", style = MaterialTheme.typography.titleMedium)
                saved?.plan?.weekly_milestones?.forEach { Text("Week ${it.week}: ${it.focus}") }
            }
            items(saved?.sessions ?: emptyList(), key = { it.id }) { session ->
                Card(Modifier.fillMaxWidth()) { Column(Modifier.padding(14.dp)) {
                    Text(session.topic, style = MaterialTheme.typography.titleMedium)
                    val whenText = runCatching {
                        val raw = session.scheduled_at
                        Instant.parse(if (raw.endsWith("Z")) raw else raw + "Z")
                            .atZone(ZoneId.of(saved?.timezone ?: ZoneId.systemDefault().id))
                            .format(DateTimeFormatter.ofPattern("MMM d, h:mm a"))
                    }.getOrDefault(session.scheduled_at)
                    Text("$whenText · ${session.duration_minutes} min · ${session.session_type}")
                    if (session.status in listOf("scheduled", "in_progress")) Row {
                        TextButton(enabled = !busy, onClick = {
                            val mode = if (session.session_type == "review") "review" else "solo"
                            nav.navigate("test-prep/classroom/${session.id}?topic=${Uri.encode(session.topic)}&mode=$mode")
                        }) { Text("Start") }
                        TextButton(enabled = !busy, onClick = { scope.launch {
                            busy = true; error = null
                            try {
                                val outcome = ApiClient.testPrep.complete(session.id)
                                notice = outcome.performance_score?.let { "${(it * 100).toInt()}% from ${outcome.graded} graded answers." }
                                    ?: "Marked done. Nothing was graded, so there is no score."
                                load()
                            } catch (_: Exception) { error = "Could not mark this session done. Please retry." }
                            finally { busy = false }
                        } }) { Text("Done") }
                    } else Text(session.status)
                } }
            }
        }
        if (loaded) item {
            (saved?.profile?.materials.orEmpty() + materials).forEach { Text(it.name) }
            OutlinedButton(enabled = !busy, onClick = { picker.launch(arrayOf("image/*", "application/pdf", "text/plain")) }) { Text("Add photo, PDF or notes") }
        }
    }
}
