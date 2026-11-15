package com.lyo.app.ui.screens.classroom

import android.content.Context
import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.ResolvingDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.ProgressiveMediaSource

/**
 * Opt-in staging experiment: authenticated HTTP POST progressive MP3 playback.
 *
 * A normal MediaItem streams with GET, but /api/v1/tts/synthesize/stream is
 * deliberately POST-only so that learner text and bearer credentials never
 * enter URL query parameters or proxy access-log paths. ResolvingDataSource
 * converts ExoPlayer's initial DataSpec to an authenticated JSON POST.
 *
 * NOTE: The provider must support MP3 frames delivered progressively.
 * An error before *any* audio plays may fall back once to the existing
 * full-MP3 endpoint; a mid-speech error must not replay already-heard words.
 */
@OptIn(UnstableApi::class)
internal fun classroomVoicePostSpec(dataSpec: DataSpec, requestBytes: ByteArray): DataSpec =
    dataSpec.buildUpon()
        .setHttpMethod(DataSpec.HTTP_METHOD_POST)
        .setHttpBody(requestBytes)
        .build()

@OptIn(UnstableApi::class)
internal class ClassroomProgressiveTtsStream(
    context: Context,
    url: String,
    requestJson: String,
    token: String,
    private val onAudioStarted: () -> Unit,
    private val onFinished: () -> Unit,
    private val onFailure: (audioHadStarted: Boolean) -> Unit,
    // Enables a local loopback-only fixture on debuggable emulator builds.
    // Production and staged real-service audio must still use HTTPS.
    allowDebugLoopbackHttp: Boolean = false,
) {
    private var started = false
    private var finished = false

    private val player: ExoPlayer

    init {
        require(token.isNotBlank()) { "Authenticated Classroom voice required" }
        val uri = Uri.parse(url)
        val debugLoopback = allowDebugLoopbackHttp && com.lyo.app.BuildConfig.DEBUG &&
            uri.scheme == "http" && uri.host in setOf("localhost", "127.0.0.1")
        require(uri.scheme == "https" || debugLoopback) {
            "Classroom voice must use HTTPS"
        }
        val headers = mapOf(
            "Authorization" to "Bearer $token",
            "Content-Type" to "application/json",
            "Accept" to "audio/mpeg",
        )
        val requestBytes = requestJson.toByteArray(Charsets.UTF_8)
        val httpFactory = DefaultHttpDataSource.Factory()
            .setConnectTimeoutMs(10_000)
            .setReadTimeoutMs(20_000)
            .setDefaultRequestProperties(headers)

        val dataSourceFactory = ResolvingDataSource.Factory(httpFactory) { dataSpec: DataSpec ->
            // Never put learner text or credentials in a query string.
            classroomVoicePostSpec(dataSpec, requestBytes)
        }
        val mediaSource = ProgressiveMediaSource.Factory(dataSourceFactory)
            .createMediaSource(MediaItem.fromUri(Uri.parse(url)))

        // Security guards and request-source construction precede allocation.
        player = ExoPlayer.Builder(context).build()
        player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                if (isPlaying && !started && !finished) {
                    started = true
                    onAudioStarted()
                }
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_ENDED && !finished) {
                    finished = true
                    onFinished()
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                if (!finished) {
                    finished = true
                    onFailure(started)
                }
            }
        })
        player.setMediaSource(mediaSource)
        player.prepare()
        player.playWhenReady = true
    }

    fun release() = player.release()
}
