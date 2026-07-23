package com.lyo.app.ui.screens.create

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cameraswitch
import androidx.compose.material.icons.filled.FlashOff
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.io.File
import java.util.Locale
import java.util.concurrent.Executor

private const val MAX_RECORDING_MILLIS = 180_000L

@Composable
internal fun ClipCameraCapture(
    enabled: Boolean,
    onCaptured: (Uri) -> Unit,
    onOpenLibrary: () -> Unit,
    onError: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val mainExecutor = remember(context) { ContextCompat.getMainExecutor(context) }
    val previewView = remember(context) {
        PreviewView(context).apply {
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
    }

    var cameraPermissionGranted by remember {
        mutableStateOf(context.hasPermission(Manifest.permission.CAMERA))
    }
    var audioPermissionGranted by remember {
        mutableStateOf(context.hasPermission(Manifest.permission.RECORD_AUDIO))
    }
    var permissionRequested by remember { mutableStateOf(false) }
    var cameraReady by remember { mutableStateOf(false) }
    var lensFacing by remember { mutableStateOf(CameraSelector.LENS_FACING_BACK) }
    var camera by remember { mutableStateOf<Camera?>(null) }
    var videoCapture by remember { mutableStateOf<VideoCapture<Recorder>?>(null) }
    var activeRecording by remember { mutableStateOf<Recording?>(null) }
    var recordedMillis by remember { mutableLongStateOf(0L) }
    var torchEnabled by remember { mutableStateOf(false) }
    var discardFinalizedRecording by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { grants ->
        permissionRequested = true
        cameraPermissionGranted = grants[Manifest.permission.CAMERA] == true ||
            context.hasPermission(Manifest.permission.CAMERA)
        audioPermissionGranted = grants[Manifest.permission.RECORD_AUDIO] == true ||
            context.hasPermission(Manifest.permission.RECORD_AUDIO)
        if (!cameraPermissionGranted) {
            onError("Camera access was not granted. You can still choose a video from your library.")
        }
    }

    LaunchedEffect(Unit) {
        if (!cameraPermissionGranted && !permissionRequested) {
            permissionLauncher.launch(
                arrayOf(
                    Manifest.permission.CAMERA,
                    Manifest.permission.RECORD_AUDIO,
                ),
            )
        }
    }

    DisposableEffect(
        cameraPermissionGranted,
        lifecycleOwner,
        lensFacing,
        previewView,
    ) {
        if (!cameraPermissionGranted) {
            cameraReady = false
            onDispose { }
        } else {
            val providerFuture = ProcessCameraProvider.getInstance(context)
            var provider: ProcessCameraProvider? = null

            providerFuture.addListener(
                {
                    runCatching {
                        provider = providerFuture.get()
                        val preview = Preview.Builder().build().also {
                            it.surfaceProvider = previewView.surfaceProvider
                        }
                        val recorder = Recorder.Builder()
                            .setQualitySelector(
                                QualitySelector.from(
                                    Quality.HD,
                                    FallbackStrategy.higherQualityOrLowerThan(Quality.SD),
                                ),
                            )
                            .build()
                        val capture = VideoCapture.withOutput(recorder)
                        val selector = CameraSelector.Builder()
                            .requireLensFacing(lensFacing)
                            .build()

                        provider?.unbindAll()
                        val boundCamera = provider?.bindToLifecycle(
                            lifecycleOwner,
                            selector,
                            preview,
                            capture,
                        ) ?: error("Camera provider could not bind the capture session.")

                        camera = boundCamera
                        videoCapture = capture
                        torchEnabled = false
                        cameraReady = true
                    }.onFailure { error ->
                        cameraReady = false
                        camera = null
                        videoCapture = null
                        onError(
                            error.message
                                ?: "The camera could not be started. Choose a video from your library instead.",
                        )
                    }
                },
                mainExecutor,
            )

            onDispose {
                if (activeRecording != null) {
                    discardFinalizedRecording = true
                    activeRecording?.stop()
                    activeRecording = null
                }
                camera?.cameraControl?.enableTorch(false)
                provider?.unbindAll()
                cameraReady = false
                camera = null
                videoCapture = null
                torchEnabled = false
            }
        }
    }

    fun requestPermissions() {
        permissionLauncher.launch(
            arrayOf(
                Manifest.permission.CAMERA,
                Manifest.permission.RECORD_AUDIO,
            ),
        )
    }

    fun stopRecording() {
        activeRecording?.stop()
    }

    @SuppressLint("MissingPermission")
    fun startRecording() {
        if (!enabled || activeRecording != null) return
        val capture = videoCapture
        if (capture == null || !cameraReady) {
            onError("The camera is still starting.")
            return
        }

        val outputFile = runCatching {
            File.createTempFile("lyo-clip-", ".mp4", context.cacheDir)
        }.getOrElse {
            onError("A temporary recording file could not be created.")
            return
        }

        discardFinalizedRecording = false
        recordedMillis = 0L
        var pending = capture.output.prepareRecording(
            context,
            FileOutputOptions.Builder(outputFile).build(),
        )
        if (audioPermissionGranted) {
            pending = pending.withAudioEnabled()
        }

        activeRecording = pending.start(mainExecutor) { event ->
            when (event) {
                is VideoRecordEvent.Start -> {
                    recordedMillis = 0L
                }

                is VideoRecordEvent.Status -> {
                    recordedMillis = event.recordingStats.recordedDurationNanos / 1_000_000L
                    if (recordedMillis >= MAX_RECORDING_MILLIS) {
                        activeRecording?.stop()
                    }
                }

                is VideoRecordEvent.Finalize -> {
                    activeRecording = null
                    val shouldDiscard = discardFinalizedRecording
                    discardFinalizedRecording = false

                    when {
                        shouldDiscard -> outputFile.delete()
                        event.hasError() -> {
                            outputFile.delete()
                            onError(
                                event.cause?.message
                                    ?: "The video recording could not be completed.",
                            )
                        }
                        outputFile.length() <= 0L -> {
                            outputFile.delete()
                            onError("The recorded video was empty. Please try again.")
                        }
                        else -> onCaptured(Uri.fromFile(outputFile))
                    }
                }
            }
        }
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(Color.Black),
    ) {
        when {
            !cameraPermissionGranted -> PermissionFallback(
                onRequestPermission = ::requestPermissions,
                onOpenLibrary = onOpenLibrary,
                modifier = Modifier.fillMaxSize(),
            )

            else -> {
                AndroidView(
                    factory = { previewView },
                    modifier = Modifier.fillMaxSize(),
                )

                if (!cameraReady) {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.Black.copy(alpha = 0.45f)),
                    ) {
                        CircularProgressIndicator(color = Color.White)
                    }
                }

                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(12.dp),
                ) {
                    val hasFlash = camera?.cameraInfo?.hasFlashUnit() == true &&
                        lensFacing == CameraSelector.LENS_FACING_BACK
                    CameraControlButton(
                        enabled = enabled && activeRecording == null && hasFlash,
                        onClick = {
                            val next = !torchEnabled
                            camera?.cameraControl?.enableTorch(next)
                            torchEnabled = next
                        },
                    ) {
                        Icon(
                            imageVector = if (torchEnabled) Icons.Default.FlashOn else Icons.Default.FlashOff,
                            contentDescription = if (torchEnabled) "Turn flash off" else "Turn flash on",
                            tint = Color.White,
                        )
                    }
                    CameraControlButton(
                        enabled = enabled && activeRecording == null,
                        onClick = {
                            torchEnabled = false
                            lensFacing = if (lensFacing == CameraSelector.LENS_FACING_BACK) {
                                CameraSelector.LENS_FACING_FRONT
                            } else {
                                CameraSelector.LENS_FACING_BACK
                            }
                        },
                    ) {
                        Icon(
                            imageVector = Icons.Default.Cameraswitch,
                            contentDescription = "Switch camera",
                            tint = Color.White,
                        )
                    }
                }

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .background(Color.Black.copy(alpha = 0.42f))
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                ) {
                    if (activeRecording != null) {
                        Text(
                            text = formatRecordingDuration(recordedMillis),
                            style = MaterialTheme.typography.titleMedium,
                            color = Color.White,
                            modifier = Modifier.padding(bottom = 8.dp),
                        )
                    } else if (!audioPermissionGranted) {
                        Text(
                            text = "Microphone access is off; this clip will be silent.",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.78f),
                            modifier = Modifier.padding(bottom = 8.dp),
                        )
                    }

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceEvenly,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        IconButton(
                            onClick = onOpenLibrary,
                            enabled = enabled && activeRecording == null,
                            modifier = Modifier
                                .size(52.dp)
                                .background(Color.Black.copy(alpha = 0.48f), CircleShape)
                                .border(1.dp, Color.White.copy(alpha = 0.35f), CircleShape),
                        ) {
                            Icon(
                                imageVector = Icons.Default.PhotoLibrary,
                                contentDescription = "Choose video from library",
                                tint = Color.White,
                            )
                        }

                        IconButton(
                            onClick = {
                                if (activeRecording == null) startRecording() else stopRecording()
                            },
                            enabled = enabled && cameraReady,
                            modifier = Modifier
                                .size(76.dp)
                                .background(
                                    if (activeRecording == null) Color.Transparent else Color.White,
                                    CircleShape,
                                )
                                .border(
                                    width = 5.dp,
                                    color = Color.White,
                                    shape = CircleShape,
                                ),
                        ) {
                            if (activeRecording != null) {
                                Icon(
                                    imageVector = Icons.Default.Stop,
                                    contentDescription = "Stop recording",
                                    tint = Color.Red,
                                    modifier = Modifier.size(34.dp),
                                )
                            } else {
                                Box(
                                    modifier = Modifier
                                        .size(56.dp)
                                        .background(Color.Red, CircleShape),
                                )
                            }
                        }

                        Spacer(Modifier.size(52.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun PermissionFallback(
    onRequestPermission: () -> Unit,
    onOpenLibrary: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = modifier
            .background(Surface)
            .padding(24.dp),
    ) {
        Text(
            text = "Camera access is off",
            style = MaterialTheme.typography.titleLarge,
            color = TextPrimary,
        )
        Text(
            text = "Enable camera access to record here, or choose an existing video from your device.",
            style = MaterialTheme.typography.bodyMedium,
            color = TextSecondary,
            modifier = Modifier.padding(top = 8.dp, bottom = 18.dp),
        )
        Button(
            onClick = onRequestPermission,
            colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Enable camera")
        }
        Button(
            onClick = onOpenLibrary,
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(Icons.Default.PhotoLibrary, contentDescription = null)
            Spacer(Modifier.size(8.dp))
            Text("Choose from library")
        }
    }
}

@Composable
private fun CameraControlButton(
    enabled: Boolean,
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    IconButton(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .size(44.dp)
            .background(Color.Black.copy(alpha = 0.52f), CircleShape)
            .border(1.dp, Color.White.copy(alpha = 0.22f), CircleShape),
        content = content,
    )
}

private fun Context.hasPermission(permission: String): Boolean =
    ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

private fun formatRecordingDuration(durationMillis: Long): String {
    val totalSeconds = (durationMillis / 1_000L).coerceAtLeast(0L)
    val minutes = totalSeconds / 60L
    val seconds = totalSeconds % 60L
    return String.format(Locale.US, "%02d:%02d / 03:00", minutes, seconds)
}