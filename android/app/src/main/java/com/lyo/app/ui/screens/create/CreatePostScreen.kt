package com.lyo.app.ui.screens.create

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Close
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
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CommunityCreatePostRequest
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.TextPrimary
import coil.compose.AsyncImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreatePostScreen(nav: NavHostController) {
    var content by remember { mutableStateOf("") }
    var tags by remember { mutableStateOf("") }
    var postType by remember { mutableStateOf("text") }
    var selectedImages by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var pendingCaptureUri by remember { mutableStateOf<Uri?>(null) }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.GetMultipleContents()) { selected ->
        if (selectedImages.size + selected.size > 10) {
            error = "You can attach up to 10 photos."
        } else {
            selectedImages = (selectedImages + selected).distinct()
            error = null
        }
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { captured ->
        if (captured && pendingCaptureUri != null) {
            selectedImages = (selectedImages + pendingCaptureUri!!).distinct().take(10)
            error = null
        } else {
            error = "Photo capture was cancelled."
        }
        pendingCaptureUri = null
    }

    fun takePhoto() {
        if (selectedImages.size >= 10) return
        try {
            val directory = File(context.cacheDir, "create_photos").apply { mkdirs() }
            val destination = File.createTempFile("lyo-photo-", ".jpg", directory)
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", destination)
            pendingCaptureUri = uri
            camera.launch(uri)
        } catch (reason: Exception) {
            pendingCaptureUri = null
            error = reason.message ?: "Unable to open camera."
        }
    }

    fun publish() {
        val trimmedContent = content.trim()
        if (trimmedContent.isEmpty()) {
            error = "Write something before publishing."
            return
        }
        if (submitting) return

        submitting = true
        error = null
        val parsedTags = tags
            .split(',')
            .map { it.trim().removePrefix("#") }
            .filter { it.isNotEmpty() }
            .distinct()
            .take(10)

        scope.launch {
            runCatching {
                val mediaUrls = mutableListOf<String>()
                for ((index, uri) in selectedImages.withIndex()) {
                    val contentType = context.contentResolver.getType(uri) ?: "image/jpeg"
                    if (!contentType.startsWith("image/")) throw IllegalArgumentException("Only images can be attached to a post.")
                    val bytes = withContext(Dispatchers.IO) {
                        context.contentResolver.openInputStream(uri)?.use { stream ->
                            val result = ByteArrayOutputStream()
                            val buffer = ByteArray(8192)
                            while (true) {
                                val read = stream.read(buffer)
                                if (read <= 0) break
                                if (result.size() + read > 10 * 1024 * 1024) throw IllegalArgumentException("Photos must be 10 MB or smaller.")
                                result.write(buffer, 0, read)
                            }
                            result.toByteArray()
                        }
                    } ?: throw IllegalStateException("Photo ${index + 1} could not be read.")
                    val extension = when (contentType) {
                        "image/png" -> "png"
                        "image/webp" -> "webp"
                        "image/heic", "image/heif" -> "heic"
                        else -> "jpg"
                    }
                    val file = MultipartBody.Part.createFormData("file", "lyo-post-${index + 1}.$extension", bytes.toRequestBody(contentType.toMediaType()))
                    val uploaded = ApiClient.api.uploadMedia(file, "community".toRequestBody("text/plain".toMediaType()))
                    mediaUrls.add(uploaded.url ?: throw IllegalStateException("The photo upload did not return a URL."))
                }
                ApiClient.api.createCommunityPost(
                    CommunityCreatePostRequest(
                        content = trimmedContent,
                        tags = parsedTags.takeIf { it.isNotEmpty() },
                        mediaUrls = mediaUrls.takeIf { it.isNotEmpty() },
                        postType = if (postType == "text" && mediaUrls.isNotEmpty()) "image" else postType,
                    ),
                )
            }.onSuccess {
                nav.navigate(Routes.COMMUNITY) {
                    popUpTo(Routes.CREATE) { inclusive = false }
                    launchSingleTop = true
                }
            }.onFailure { throwable ->
                error = throwable.message ?: "The post could not be published."
            }
            submitting = false
        }
    }

    Scaffold(
        containerColor = Background,
        topBar = {
            TopAppBar(
                title = { Text("Create post") },
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
                .background(Background)
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp),
        ) {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(
                    listOf(
                        "text" to "Post",
                        "question_discussion" to "Question",
                        "study_tip" to "Study tip",
                    ),
                ) { option ->
                    FilterChip(
                        selected = postType == option.first,
                        onClick = { postType = option.first },
                        enabled = !submitting,
                        label = { Text(option.second) },
                    )
                }
            }
            OutlinedTextField(
                value = content,
                onValueChange = { content = it },
                label = {
                    Text(if (postType == "question_discussion") "What would you like help with?" else "What do you want to share?")
                },
                minLines = 8,
                maxLines = 14,
                enabled = !submitting,
                modifier = Modifier.fillMaxWidth(),
            )
            Text("Add photos", style = MaterialTheme.typography.titleMedium, color = TextPrimary)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(onClick = ::takePhoto, enabled = !submitting && selectedImages.size < 10, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Filled.CameraAlt, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.size(6.dp))
                    Text("Camera")
                }
                OutlinedButton(onClick = { gallery.launch("image/*") }, enabled = !submitting && selectedImages.size < 10, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Filled.Image, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.size(6.dp))
                    Text("Gallery")
                }
            }
            if (selectedImages.isNotEmpty()) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(selectedImages) { uri ->
                        Column {
                            AsyncImage(model = uri, contentDescription = "Selected photo", contentScale = ContentScale.Crop, modifier = Modifier.size(110.dp).background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(14.dp)))
                            OutlinedButton(onClick = { selectedImages = selectedImages.filterNot { it == uri } }, enabled = !submitting) {
                                Icon(Icons.Filled.Close, contentDescription = null, modifier = Modifier.size(14.dp))
                                Text("Remove")
                            }
                        }
                    }
                }
            }
            OutlinedTextField(
                value = tags,
                onValueChange = { tags = it },
                label = { Text("Tags, separated by commas") },
                supportingText = { Text("Up to 10 tags") },
                singleLine = true,
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
                    enabled = !submitting && content.trim().isNotEmpty(),
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
                        Text("Publish post")
                    }
                }
            }
        }
    }
}
