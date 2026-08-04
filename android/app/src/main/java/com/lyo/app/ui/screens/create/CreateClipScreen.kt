package com.lyo.app.ui.screens.create

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import android.widget.VideoView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.PhotoLibrary
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
import androidx.compose.runtime.DisposableEffect
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
import java.io.File
import kotlinx.coroutines.launch
import okhttp3.MediaType
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okio.BufferedSink
import okio.source

private const val MAX_CLIP_UPLOAD_BYTES = 200L * 1024L * 1024L

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateClipScreen(nav: NavHostController) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val capturedFileState = remember { mutableStateOf<File?>(null) }

    var selectedVideoUri by remember { mutableStateOf<Uri?>(null) }
    var title by remember { mutableStateOf("") }
    var subject by remember { mutableStateOf("") }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            capturedFileState.value?.delete()
            capturedFileState.value = null
            selectedVideoUri = uri
            error = null
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            capturedFileState.value?.delete()
            capturedFileState.value = null
        }
    }

    fun clearSelection() {
        capturedFileState.value?.delete()
        capturedFileState.value = null
        selectedVideoUri = null
        error = null
    }

    fun publish() {
        val uri = selectedVideoUri
        if (uri == null) {
            error = "Record or choose a video before publishing."
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
                val upload = prepareVideoUpload(context, uri)
                val filePart = MultipartBody.Part.createFormData(
                    "file",
                    upload.fileName,
                    upload.requestBody,
                )
                val uploaded = ApiClient.api.uploadMedia(
                    file = filePart,
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
                capturedFileState.value?.delete()
                capturedFileState.value = null
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
                    IconButton(
                        onClick = {
                            if (!submitting) nav.popBackStack()
                        },
                    ) {
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
        LazyColumn(
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            item {
                val selectedUri = selectedVideoUri
                if (selectedUri == null) {
                    ClipCameraCapture(
                        enabled = !submitting,
                        onCaptured = { uri ->
                            capturedFileState.value?.delete()
                            val file = uri.path?.let(::File)
                            capturedFileState.value = file
                            selectedVideoUri = uri
                            error = null
                        },
                        onOpenLibrary = { picker.launch("video/*") },
                        onError = { message -> error = message },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(470.dp),
                    )
                } else {
                    VideoPreview(
                        uri = selectedUri,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(340.dp),
                    )
                }
            }

            if (selectedVideoUri != null) {
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        OutlinedButton(
                            onClick = ::clearSelection,
                            enabled = !submitting,
                            modifier = Modifier.weight(1f),
                        ) {
                            Icon(
                                Icons.Default.Refresh,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(Modifier.size(8.dp))
                            Text("Record again")
                        }
                        OutlinedButton(
                            onClick = { picker.launch("video/*") },
                            enabled = !submitting,
                            modifier = Modifier.weight(1f),
                        ) {
                            Icon(
                                Icons.Default.PhotoLibrary,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(Modifier.size(8.dp))
                            Text("Library")
                        }
                    }
                }
            }

            item {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it.take(120) },
                    label = { Text("Title") },
                    supportingText = { Text("${title.length}/120") },
                    singleLine = true,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            item {
                OutlinedTextField(
                    value = subject,
                    onValueChange = { subject = it.take(1_000) },
                    label = { Text("Learning context or description") },
                    supportingText = { Text("${subject.length}/1000") },
                    minLines = 3,
                    maxLines = 6,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            error?.let { message ->
                item {
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFFFF9A9A),
                    )
                }
            }

            item {
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
                        enabled = !submitting && selectedVideoUri != null && title.trim().isNotEmpty(),
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
                            Icon(
                                Icons.Default.Check,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(Modifier.size(8.dp))
                            Text("Publish clip")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun VideoPreview(
    uri: Uri,
    modifier: Modifier = Modifier,
) {
    AndroidView(
        factory = { viewContext ->
            VideoView(viewContext).apply {
                setVideoURI(uri)
                setOnPreparedListener { player ->
                    player.isLooping = true
                    start()
                }
            }
        },
        update = { view ->
            view.setVideoURI(uri)
            view.setOnPreparedListener { player ->
                player.isLooping = true
                view.start()
            }
        },
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(Color.Black),
    )
}

private data class PreparedVideoUpload(
    val fileName: String,
    val requestBody: RequestBody,
)

private fun prepareVideoUpload(context: Context, uri: Uri): PreparedVideoUpload {
    val resolver = context.contentResolver
    val metadata = queryVideoMetadata(context, uri)
    if (metadata.size != null && metadata.size > MAX_CLIP_UPLOAD_BYTES) {
        throw IllegalArgumentException("Video too large. Maximum size is 200MB.")
    }

    val contentType = resolver.getType(uri)
        ?.substringBefore(';')
        ?.trim()
        ?.lowercase()
        ?: when (metadata.fileName.substringAfterLast('.', "").lowercase()) {
            "mov" -> "video/quicktime"
            "webm" -> "video/webm"
            else -> "video/mp4"
        }

    if (contentType !in setOf("video/mp4", "video/quicktime", "video/webm")) {
        throw IllegalArgumentException("Choose an MP4, MOV, or WebM video.")
    }

    val fileName = sanitizeVideoFileName(metadata.fileName, contentType)
    return PreparedVideoUpload(
        fileName = fileName,
        requestBody = UriRequestBody(
            context = context,
            uri = uri,
            mediaType = contentType.toMediaType(),
            declaredLength = metadata.size,
        ),
    )
}

private data class VideoMetadata(
    val fileName: String,
    val size: Long?,
)

private fun queryVideoMetadata(context: Context, uri: Uri): VideoMetadata {
    if (uri.scheme == ContentResolver.SCHEME_FILE) {
        val file = uri.path?.let(::File)
            ?: throw IllegalArgumentException("The recorded video path is invalid.")
        return VideoMetadata(file.name, file.length())
    }

    var name: String? = null
    var size: Long? = null
    context.contentResolver.query(
        uri,
        arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
        null,
        null,
        null,
    )?.use { cursor ->
        if (cursor.moveToFirst()) {
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
            if (nameIndex >= 0) name = cursor.getString(nameIndex)
            if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) size = cursor.getLong(sizeIndex)
        }
    }

    return VideoMetadata(
        fileName = name?.takeIf { it.isNotBlank() } ?: "clip.mp4",
        size = size,
    )
}

private fun sanitizeVideoFileName(name: String, contentType: String): String {
    val extension = when (contentType) {
        "video/quicktime" -> "mov"
        "video/webm" -> "webm"
        else -> "mp4"
    }
    val base = name.substringBeforeLast('.', name)
        .replace(Regex("[^A-Za-z0-9_-]"), "-")
        .trim('-')
        .take(80)
        .ifBlank { "clip" }
    return "$base.$extension"
}

private class UriRequestBody(
    private val context: Context,
    private val uri: Uri,
    private val mediaType: MediaType,
    private val declaredLength: Long?,
) : RequestBody() {
    override fun contentType(): MediaType = mediaType

    override fun contentLength(): Long = declaredLength ?: -1L

    override fun writeTo(sink: BufferedSink) {
        val source = if (uri.scheme == ContentResolver.SCHEME_FILE) {
            val path = uri.path ?: throw IllegalStateException("The recorded video path is invalid.")
            File(path).source()
        } else {
            context.contentResolver.openInputStream(uri)?.source()
                ?: throw IllegalStateException("The selected video could not be read.")
        }
        source.use { sink.writeAll(it) }
    }
}