package com.lyo.app.ui.screens.create

import android.net.Uri
import android.widget.VideoView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.ClipCreateRequest
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateClipScreen(nav: NavHostController) {
    var videoUri by remember { mutableStateOf<Uri?>(null) }
    var title by remember { mutableStateOf("") }
    var subject by remember { mutableStateOf("") }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var pickerOpened by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            videoUri = uri
            error = null
        }
    }

    LaunchedEffect(Unit) {
        if (!pickerOpened) {
            pickerOpened = true
            picker.launch("video/*")
        }
    }

    fun publish() {
        val uri = videoUri
        if (uri == null) {
            error = "Choose a video before publishing."
            return
        }
        if (title.trim().isEmpty()) {
            error = "Add a title before publishing."
            return
        }
        if (submitting) return

        submitting = true
        error = null
        scope.launch {
            runCatching {
                val contentType = context.contentResolver.getType(uri) ?: "video/mp4"
                val bytes = withContext(Dispatchers.IO) {
                    context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                } ?: throw IllegalStateException("The selected video could not be read.")

                val extension = when (contentType) {
                    "video/quicktime" -> "mov"
                    "video/webm" -> "webm"
                    else -> "mp4"
                }
                val file = MultipartBody.Part.createFormData(
                    "file",
                    "clip.$extension",
                    bytes.toRequestBody(contentType.toMediaType()),
                )
                val uploaded = ApiClient.api.uploadMedia(
                    file = file,
                    folder = "clips".toRequestBody("text/plain".toMediaType()),
                )
                val videoUrl = uploaded.url
                    ?: throw IllegalStateException("The media service did not return a video URL.")

                ApiClient.api.createClip(
                    ClipCreateRequest(
                        title = title.trim(),
                        description = subject.trim().takeIf { it.isNotEmpty() },
                        videoUrl = videoUrl,
                    ),
                )
            }.onSuccess {
                nav.navigate(Routes.CLIPS) {
                    popUpTo(Routes.CREATE) { inclusive = false }
                    launchSingleTop = true
                }
            }.onFailure { throwable ->
                error = throwable.message ?: "The clip could not be published."
            }
            submitting = false
        }
    }

    Scaffold(
        containerColor = Background,
        topBar = {
            TopAppBar(
                title = { Text("Create clip") },
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
        },
    ) { padding ->
        Column(
            verticalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp, vertical = 12.dp),
        ) {
            val selectedUri = videoUri
            if (selectedUri != null) {
                AndroidView(
                    factory = { viewContext ->
                        VideoView(viewContext).apply {
                            setVideoURI(selectedUri)
                            setOnPreparedListener { player ->
                                player.isLooping = true
                                start()
                            }
                        }
                    },
                    update = { view ->
                        view.setVideoURI(selectedUri)
                        view.setOnPreparedListener { player ->
                            player.isLooping = true
                            view.start()
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(280.dp)
                        .clip(RoundedCornerShape(18.dp))
                        .background(Color.Black),
                )
            } else {
                Column(
                    verticalArrangement = Arrangement.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(220.dp)
                        .clip(RoundedCornerShape(18.dp))
                        .background(Color.White.copy(alpha = 0.05f))
                        .padding(24.dp),
                ) {
                    Text(
                        text = "No video selected",
                        style = MaterialTheme.typography.titleMedium,
                        color = TextPrimary,
                    )
                    Text(
                        text = "Android will open your system video picker. Camera recording will remain separate until a production CameraX workflow is implemented.",
                        style = MaterialTheme.typography.bodySmall,
                        color = TextSecondary,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
            }

            OutlinedButton(
                onClick = { picker.launch("video/*") },
                enabled = !submitting,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Filled.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.size(8.dp))
                Text(if (videoUri == null) "Choose video" else "Choose another video")
            }

            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("Title") },
                singleLine = true,
                enabled = !submitting,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = subject,
                onValueChange = { subject = it },
                label = { Text("Learning context or description") },
                minLines = 3,
                enabled = !submitting,
                modifier = Modifier.fillMaxWidth(),
            )

            error?.let { message ->
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFFFF9A9A),
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(
                    onClick = { nav.popBackStack() },
                    enabled = !submitting,
                    modifier = Modifier.weight(1f),
                ) {
                    Text("Cancel")
                }
                Button(
                    onClick = ::publish,
                    enabled = !submitting && videoUri != null && title.trim().isNotEmpty(),
                    colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
                    modifier = Modifier.weight(1.5f),
                ) {
                    if (submitting) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            color = Color.White,
                            strokeWidth = 2.dp,
                        )
                        Spacer(Modifier.size(8.dp))
                        Text("Publishing…")
                    } else {
                        Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.size(8.dp))
                        Text("Publish clip")
                    }
                }
            }
        }
    }
}
