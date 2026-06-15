package pro.appexp.flutter_tv_media3.preview

import android.content.Context
import android.view.Surface
import io.flutter.view.TextureRegistry
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.common.C
import android.util.Log

/**
 * Manages an individual ExoPlayer instance for preview purposes, rendering video to a Flutter texture.
 *
 * This class encapsulates the [ExoPlayer] and its connection to a Flutter [TextureRegistry.SurfaceTextureEntry].
 * It handles player lifecycle, media preparation with optional clipping, and reports events (errors,
 * playback state) back to Dart via a callback.
 *
 * To prevent memory leaks and ensure a clean state between different media items, the [ExoPlayer]
 * instance is recreated when [stopAndClear] is called, while the underlying [SurfaceTexture]
 * is kept alive as part of the pool.
 *
 * @property context The Android context used to create the ExoPlayer.
 * @property textureRegistry The registry used to create and manage Flutter textures.
 * @param initialOnEvent Initial callback for player events.
 */
class TexturePreviewPlayer(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    initialOnEvent: (Long, String, Map<String, Any?>?) -> Unit
) {

    private val textureEntry: TextureRegistry.SurfaceTextureEntry = textureRegistry.createSurfaceTexture()

    /**
     * The unique ID of the Flutter texture being managed by this player.
     */
    val textureId: Long = textureEntry.id()

    private val surfaceTexture = textureEntry.surfaceTexture()
    private var surface: Surface? = null

    private var onEvent: (Long, String, Map<String, Any?>?) -> Unit = initialOnEvent
    private var isReleased: Boolean = false
    private var player: ExoPlayer? = null

    /**
     * Updates the event callback for this player and marks it as active (not released).
     *
     * This is called when a player is acquired from the [PreviewPlayerPool].
     *
     * @param newOnEvent The new callback to send events to.
     */
    fun updateCallback(newOnEvent: (Long, String, Map<String, Any?>?) -> Unit) {
        this.onEvent = newOnEvent
        this.isReleased = false
    }

    /**
     * Lazily creates the [ExoPlayer] instance if it doesn't exist.
     *
     * Configures the player with a short buffer suitable for quick previews and
     * adds a listener to propagate events back to Flutter.
     *
     * @return The active [ExoPlayer] instance.
     */
    private fun createPlayerIfNeeded(): ExoPlayer {
        player?.let { return it }

        val newPlayer = ExoPlayer.Builder(context)
            .setRenderersFactory(
                DefaultRenderersFactory(context)
                    .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
                    .setEnableDecoderFallback(true)
            )
            .setLoadControl(
                DefaultLoadControl.Builder()
                    .setBufferDurationsMs(10000, 20000, 1000, 2000)
                    .build()
            )
            .build().apply {
                addListener(object : Player.Listener {
                    override fun onVideoSizeChanged(videoSize: VideoSize) {
                        if (isReleased) return
                        if (videoSize.width > 0 && videoSize.height > 0) {
                            surfaceTexture.setDefaultBufferSize(videoSize.width, videoSize.height)
                        }
                    }

                    override fun onIsPlayingChanged(isPlaying: Boolean) {
                        if (isReleased) return
                        onEvent(textureId, "onIsPlaying", mapOf("isPlaying" to isPlaying))
                    }

                    override fun onRenderedFirstFrame() {
                        if (isReleased) return
                        onEvent(textureId, "onPlaybackStarted", null)
                    }

                    override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                        if (isReleased) return
                        Log.e("ExoPlayer", "Player error: ${error.message}")
                        onEvent(textureId, "onError", mapOf(
                            "errorCode" to error.errorCode,
                            "errorMessage" to error.message
                        ))
                    }
                })
            }
        player = newPlayer
        return newPlayer
    }

    /**
     * Obtains a valid [Surface] from the [surfaceTexture].
     *
     * Recreates the surface if it's no longer valid.
     *
     * @return A valid [Surface] instance.
     */
    private fun getSurface(): Surface {
        if (surface == null || !surface!!.isValid) {
            surface?.release()
            surface = Surface(surfaceTexture)
        }
        return surface!!
    }

    /**
     * Prepares the ExoPlayer with the given URL and playback parameters.
     *
     * This method handles:
     * 1. Setting the default buffer size for the texture.
     * 2. Attaching the player to the surface.
     * 3. Configuring media clipping (start/end time).
     * 4. Setting volume, repeat mode, and auto-play state.
     *
     * @param url The media source URI.
     * @param width Initial width for the surface texture buffer.
     * @param height Initial height for the surface texture buffer.
     * @param volume Playback volume (0.0 to 1.0).
     * @param autoPlay Whether to start playing as soon as prepared.
     * @param repeatMode ExoPlayer repeat mode (e.g., [Player.REPEAT_MODE_ONE]).
     * @param startTimeSeconds Clipping start position in seconds.
     * @param endTimeSeconds Clipping end position in seconds.
     */
    fun prepare(url: String, width: Int = 0, height: Int = 0, volume: Float = 0f, autoPlay: Boolean = true, repeatMode: Int = Player.REPEAT_MODE_ONE, startTimeSeconds: Int = 0, endTimeSeconds: Int = 0) {
        isReleased = false

        if (width > 0 && height > 0) {
            surfaceTexture.setDefaultBufferSize(width, height)
        }

        val p = createPlayerIfNeeded()

        val currentSurface = getSurface()
        p.setVideoSurface(currentSurface)

        val mediaItem = MediaItem.Builder().setUri(url)
            .setClippingConfiguration(
                if (startTimeSeconds > 0 || endTimeSeconds > 0) {
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs((startTimeSeconds * 1000).toLong())
                        .setEndPositionMs(if (endTimeSeconds > 0) (endTimeSeconds * 1000).toLong() else C.TIME_END_OF_SOURCE)
                        .setRelativeToLiveWindow(false)
                        .setRelativeToDefaultPosition(false)
                        .build()
                } else {
                    MediaItem.ClippingConfiguration.Builder().build()
                }
            )
            .build()

        p.setMediaItem(mediaItem)
        p.prepare()
        p.volume = volume
        p.playWhenReady = autoPlay
        p.repeatMode = repeatMode
    }

    /** Starts or resumes playback. */
    fun play() {
        player?.play()
    }

    /** Pauses playback. */
    fun pause() {
        player?.pause()
    }

    /**
     * Stops playback and releases the [ExoPlayer] instance.
     *
     * This ensures no frames or audio from the previous session leak into the next one
     * when this player is returned to the pool. It also releases the [Surface].
     */
    fun stopAndClear() {
        isReleased = true
        player?.let { p ->
            p.stop()
            p.clearMediaItems()
            p.clearVideoSurface(surface)
            p.setVideoSurface(null)
            p.release()
        }
        player = null

        surface?.release()
        surface = null
        surfaceTexture.setDefaultBufferSize(1, 1)
    }


    /**
     * Seeks to the specified position in the media.
     *
     * @param positionMs Position in milliseconds.
     */
    fun seekTo(positionMs: Long) {
        player?.seekTo(positionMs)
    }

    /**
     * Sets the playback volume.
     *
     * @param volume Volume level from 0.0 (silent) to 1.0 (full).
     */
    fun setVolume(volume: Float) {
        player?.volume = volume
    }

    /**
     * Sets the repeat mode for the player.
     *
     * @param repeatMode One of the [Player] repeat modes.
     */
    fun setRepeatMode(repeatMode: Int) {
        player?.repeatMode = repeatMode
    }

    /**
     * Permanently releases all native resources, including the Flutter texture.
     *
     * After calling this, the player instance cannot be reused.
     */
    fun releaseResources() {
        isReleased = true
        player?.release()
        player = null
        surface?.release()
        textureEntry.release()
    }
}