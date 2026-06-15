package pro.appexp.flutter_tv_media3.activity

import pro.appexp.flutter_tv_media3.R

import android.content.Context
import android.media.AudioManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.C
import androidx.media3.common.Metadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import pro.appexp.flutter_tv_media3.manager.FrameRateManager
import pro.appexp.flutter_tv_media3.manager.audio.VolumeManager
import pro.appexp.flutter_tv_media3.player.MediaSourceBuilder
import pro.appexp.flutter_tv_media3.player.MetadataParser
import pro.appexp.flutter_tv_media3.player.ExoPlayerFactory
import pro.appexp.flutter_tv_media3.player.PlaylistManager
import pro.appexp.flutter_tv_media3.player.TrackManager
import pro.appexp.flutter_tv_media3.manager.subtitle.SubtitleStyleManager

/**
 * The main Activity responsible for video playback and displaying the UI.
 *
 * This Activity is responsible only for:
 * - Lifecycle management (onCreate/onPause/onResume/onDestroy)
 * - ExoPlayer and FlutterEngine initialization
 * - Bridging MethodChannel calls to the appropriate delegates
 *
 * All business logic is delegated to:
 * - [PlaylistManager]      — playlist navigation, shuffle, repeat
 * - [TrackManager]         — track reading and selection
 * - [MediaSourceBuilder]   — MediaSource construction
 * - [SubtitleStyleManager] — subtitle styling
 * - [VolumeManager]        — system volume control
 * - [MetadataParser]       — media metadata parsing
 */
@UnstableApi
class PlayerActivity : AppCompatActivity() {

    // ─── ExoPlayer & UI ───────────────────────────────────────────────────────
    internal lateinit var player: ExoPlayer
    internal lateinit var trackSelector: DefaultTrackSelector
    internal lateinit var playerView: PlayerView
    internal lateinit var playerListener: Player.Listener
    internal lateinit var frameRateManager: FrameRateManager

    // ─── Flutter ──────────────────────────────────────────────────────────────
    internal lateinit var flutterEngine: FlutterEngine
    internal lateinit var flutterAppEngine: FlutterEngine
    internal lateinit var methodChannel: MethodChannel
    internal lateinit var methodUIChannel: MethodChannel
    internal lateinit var flutterEngineId: String
    internal lateinit var flutterAppEngineId: String

    // ─── Delegates ────────────────────────────────────────────────────────────
    internal lateinit var playlistManager: PlaylistManager
    internal lateinit var trackManager: TrackManager
    internal lateinit var mediaSourceBuilder: MediaSourceBuilder
    internal lateinit var subtitleStyleManager: SubtitleStyleManager
    internal lateinit var volumeManager: VolumeManager
    internal val metadataParser = MetadataParser()

    // ─── Media state ──────────────────────────────────────────────────────────
    internal var playerSettings: Map<String, Any>? = null
    internal var currentResolutionsMap: Map<String, String>? = null
    internal var currentVideoUrl: String? = null
    internal var currentVideoMimeType: String? = null
    internal var currentHeaders: Map<String, String>? = null
    internal var currentUserAgent: String? = null
    internal var currentSubtitleTracks: List<Map<String, Any>>? = null
    internal var currentAudioTracks: List<Map<String, Any>>? = null
    internal var currentAudioTrackLabels: Map<String, String>? = null

    // ─── Player state ─────────────────────────────────────────────────────────
    internal var isAfrEnabled: Boolean = false
    internal var currentMediaRequestToken: Any? = null
    internal var lastActiveSubtitleId: String? = null
    internal var stuckRetryCount = 0
    internal var wakeLock: PowerManager.WakeLock? = null

    internal val positionHandler = Handler(Looper.getMainLooper())
    internal val aTag = "Media3Activity"
    private val activityChannelName   = "app_player_plugin_activity"
    private val activityChannelUIName = "ui_player_plugin_activity"

    // ══════════════════════════════════════════════════════════════════════════
    // Lifecycle
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Called when the Activity is first created.
     *
     * Performs all major initializations:
     * - Retrieves FlutterEngine instances from the cache.
     * - Creates and configures ExoPlayer and PlayerView.
     * - Adds a FlutterFragment to display the UI overlay.
     * - Sets up MethodChannels for bidirectional communication.
     * - Initializes all delegate classes.
     * - Requests the first media item and applies initial settings.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (!initFlutterEngines()) return
        if (!initPlayer()) return
        if (!initFlutterFragment()) return

        initChannels()
        initDelegates()
        startPlaylist()
        applyInitialSettings()
    }

    /** Intercepts the system back button press and notifies Flutter. */
    override fun onBackPressed() {
        invokeOnBothChannels("onBack", null)
    }

    /**
     * Called when the Activity becomes inactive.
     *
     * Pauses the player, saves watch time, unregisters the volume observer,
     * and stops periodic position updates.
     */
    override fun onPause() {
        super.onPause()
        releaseWakeLock()
        if (this::volumeManager.isInitialized) volumeManager.unregister()
        if (this::player.isInitialized) {
            val hasVideo = player.currentTracks.groups.any {
                it.type == C.TRACK_TYPE_VIDEO && it.isSelected
            }
            if (hasVideo) {
                markWatchTime(playlistManager.playlistIndex)
                player.pause()
            }
        }
        positionHandler.removeCallbacks(positionRunnable)
    }

    /**
     * Called when the Activity becomes active again.
     *
     * Re-registers the volume observer and resumes periodic position updates
     * if the player is ready.
     */
    override fun onResume() {
        super.onResume()
        if (this::volumeManager.isInitialized) volumeManager.register()
        if (this::player.isInitialized && player.playWhenReady) {
            if (player.playbackState == Player.STATE_READY || player.playbackState == Player.STATE_BUFFERING) {
                positionHandler.post(positionRunnable)
            }
        }
    }

    /**
     * Called before the Activity is destroyed.
     *
     * Releases all resources: stops the frame rate manager, releases the player,
     * destroys the FlutterEngine, and clears channel handlers.
     */
    override fun onDestroy() {
        super.onDestroy()
        releaseWakeLock()

        positionHandler.removeCallbacks(positionRunnable)

        if (this::volumeManager.isInitialized) {
            volumeManager.unregister()
        }

        if (this::methodChannel.isInitialized) {
            methodChannel.invokeMethod("onActivityDestroyed", null)
            methodChannel.setMethodCallHandler(null)
        }
        if (this::methodUIChannel.isInitialized) {
            methodUIChannel.setMethodCallHandler(null)
        }

        if (this::playerView.isInitialized) {
            if (this::frameRateManager.isInitialized) frameRateManager.release()
            playerView.player = null
        }
        if (this::player.isInitialized) {
            if (this::playerListener.isInitialized) player.removeListener(playerListener)
            player.release()
        }

        supportFragmentManager.findFragmentById(R.id.media3_flutter_container)?.let { fragment ->
            supportFragmentManager.beginTransaction()
                .remove(fragment)
                .commitNowAllowingStateLoss()
        }

        // flutterAppEngine is intentionally not destroyed here — it is owned and cached
        // globally by the main Flutter app and must outlive this Activity.
        if (this::flutterEngine.isInitialized) {
            flutterEngine.lifecycleChannel.appIsDetached()
            flutterEngine.platformViewsController.detachFromView()
            if (this::flutterEngineId.isInitialized) {
                FlutterEngineCache.getInstance().remove(flutterEngineId)
            }
            flutterEngine.destroy()
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Initialization
    // ══════════════════════════════════════════════════════════════════════════

    private fun initFlutterEngines(): Boolean {
        flutterEngineId = intent.getStringExtra("flutter_engine_id") ?: run {
            Log.e(aTag, "FATAL: FlutterEngine ID not found!"); finish(); return false
        }
        flutterEngine = FlutterEngineCache.getInstance().get(flutterEngineId) ?: run {
            Log.e(aTag, "FATAL: FlutterEngine '$flutterEngineId' not found in cache!"); finish(); return false
        }
        flutterAppEngineId = intent.getStringExtra("app_engine_id") ?: run {
            Log.e(aTag, "FATAL: FlutterAPPEngine ID not found!"); finish(); return false
        }
        flutterAppEngine = FlutterEngineCache.getInstance().get(flutterAppEngineId) ?: run {
            Log.e(aTag, "FATAL: FlutterAPPEngine '$flutterAppEngineId' not found in cache!"); finish(); return false
        }
        return true
    }

    private fun initPlayer(): Boolean {
        playerView = PlayerView(this).apply {
            useController = false
            resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
            setShowBuffering(PlayerView.SHOW_BUFFERING_NEVER)
        }

        val result = ExoPlayerFactory(this, intent).create()
        player        = result.player
        trackSelector = result.trackSelector

        frameRateManager = FrameRateManager(this, player, playerView)
        playerView.player = player

        setContentView(R.layout.activity_player)
        findViewById<FrameLayout>(R.id.media3_player_container).addView(playerView)
        return true
    }

    private fun initFlutterFragment(): Boolean {
        if (!flutterEngine.dartExecutor.isExecutingDart) {
            Log.e(aTag, "FlutterEngine is not executing Dart code!"); finish(); return false
        }
        return try {
            val fragment = FlutterFragment.withCachedEngine(flutterEngineId)
                .renderMode(io.flutter.embedding.android.RenderMode.texture)
                .transparencyMode(io.flutter.embedding.android.TransparencyMode.transparent)
                .build<FlutterFragment>()

            supportFragmentManager.beginTransaction()
                .replace(R.id.media3_flutter_container, fragment)
                .commitNowAllowingStateLoss()
            true
        } catch (e: Exception) {
            Log.e(aTag, "Error adding FlutterFragment: ${e.message}", e); finish(); false
        }
    }

    private fun initChannels() {
        methodChannel = MethodChannel(flutterAppEngine.dartExecutor.binaryMessenger, activityChannelName).also {
            it.setMethodCallHandler { call, result -> handleMethodCall(call, result, from = it) }
        }
        methodUIChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, activityChannelUIName).also {
            it.setMethodCallHandler { call, result -> handleMethodCall(call, result, from = it) }
        }
    }

    private fun initDelegates() {
        mediaSourceBuilder = MediaSourceBuilder(this)

        playlistManager = PlaylistManager(
            onRequestMedia  = { index -> requestMediaInfo(index) },
            onMarkWatchTime = { index -> markWatchTime(index) },
            onFinish        = { finish() }
        )

        trackManager = TrackManager(
            getPlayer         = { player },
            getTrackSelector  = { trackSelector },
            metadataParser    = metadataParser,
            onAfrStateChanged = { enabled ->
                if (!enabled) frameRateManager.release()
                isAfrEnabled = enabled
            }
        )

        subtitleStyleManager = SubtitleStyleManager(
            playerView = playerView,
            onUiThread = { block -> runOnUiThread(block) }
        )

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        volumeManager = VolumeManager(
            context         = this,
            audioManager    = audioManager,
            onVolumeChanged = { state -> invokeOnBothChannels("onVolumeChanged", state) }
        )

        playerListener = createPlayerListener()
        player.addListener(playerListener)
    }

    private fun startPlaylist() {
        val index  = intent.getIntExtra("playlist_index", -1)
        val length = intent.getIntExtra("playlist_length", 0)

        playlistManager.playlistIndex  = index
        playlistManager.playlistLength = length

        if (index >= 0 && length > 0) {
            requestMediaInfo(index)
        } else {
            invokeOnBothChannels("onError", mapOf("code" to "INVALID_PLAYLIST", "message" to "Invalid playlist index or length"))
            finish()
        }
    }

    private fun applyInitialSettings() {
        val subtitleStyle = intent.getBundleExtra("subtitle_style")?.let { b ->
            listOfNotNull(
                b.getString("foregroundColor")?.let { "foregroundColor" to it },
                b.getString("backgroundColor")?.let { "backgroundColor" to it },
                b.getInt("edgeType", -1).takeIf { it != -1 }?.let { "edgeType" to it },
                b.getString("edgeColor")?.let { "edgeColor" to it },
                b.getDouble("textSizeFraction", 0.0).takeIf { it != 0.0 }?.let { "textSizeFraction" to it },
                b.getBoolean("applyEmbeddedStyles", false).takeIf { it }?.let { "applyEmbeddedStyles" to it },
                b.getString("windowColor")?.let { "windowColor" to it }
            ).toMap()
        }
        subtitleStyleManager.applySubtitleStyle(subtitleStyle)

        playerSettings = intent.getBundleExtra("player_settings")?.let { b ->
            listOfNotNull(
                b.getInt("videoQuality", -1).takeIf { it != -1 }?.let { "videoQuality" to it },
                b.getInt("width", -1).takeIf { it != -1 }?.let { "width" to it },
                b.getInt("height", -1).takeIf { it != -1 }?.let { "height" to it },
                b.getStringArrayList("preferredAudioLanguages")?.let { "preferredAudioLanguages" to it },
                b.getStringArrayList("preferredTextLanguages")?.let { "preferredTextLanguages" to it },
                "forcedAutoEnable"    to b.getBoolean("forcedAutoEnable", true),
                "isAfrEnabled"        to b.getBoolean("isAfrEnabled", false),
                "forceHighestBitrate" to b.getBoolean("forceHighestBitrate", true),
                "paginationEnable"    to b.getBoolean("paginationEnable", false),
                b.getInt("paginationThreshold", -1).takeIf { it != -1 }?.let { "paginationThreshold" to it },
                b.getBoolean("screenshotsEnable", false).takeIf { it }?.let { "screenshotsEnable" to it },
                b.getString("deviceLocale")?.let { "deviceLocale" to it }
            ).toMap()
        }
        trackManager.applySettings(playerSettings)

        val initialVolumeState = volumeManager.getCurrentVolumeState()

        invokeOnBothChannels("onActivityReady", mapOf(
            "playlist"        to intent.getStringExtra("playlist"),
            "playlist_index"  to playlistManager.playlistIndex,
            "subtitle_style"  to subtitleStyle,
            "clock_settings"  to intent.getStringExtra("clock_settings"),
            "player_settings" to playerSettings,
            "locale_strings"  to intent.getStringExtra("locale_strings"),
            "subtitle_search" to intent.getStringExtra("subtitle_search"),
            "volume_state"    to initialVolumeState,
        ))
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Helper methods
    // ══════════════════════════════════════════════════════════════════════════

    internal fun isPlayerInitialized() = this::player.isInitialized

    internal fun getCurrentTracksFromDelegate() = trackManager.getCurrentTracks(
        currentSubtitleTracks, currentAudioTracks, currentAudioTrackLabels,
        currentResolutionsMap, currentVideoUrl
    )

    internal fun isRecoverableHlsError(e: PlaybackException): Boolean {
        var cause: Throwable? = e
        while (cause != null) {
            if (cause is androidx.media3.exoplayer.source.BehindLiveWindowException ||
                cause is androidx.media3.exoplayer.hls.playlist.HlsPlaylistTracker.PlaylistResetException
            ) return true
            cause = cause.cause
        }
        return false
    }

    internal fun markWatchTime(playlistIndex: Int) {
        if (!this::player.isInitialized) { Log.e(aTag, "markWatchTime: Player not initialized"); return }
        if (player.isCurrentMediaItemLive) { Log.d(aTag, "markWatchTime: Skipping for live stream"); return }

        val currentPosition = player.currentPosition
        val duration        = player.duration.takeIf { it != C.TIME_UNSET } ?: 0L

        Handler(Looper.getMainLooper()).post {
            invokeOnBothChannels("onWatchTimeMarked", mapOf(
                "position_ms"    to currentPosition,
                "duration_ms"    to duration,
                "playlist_index" to playlistIndex
            ))
        }
    }

    internal fun applyZoom(scaleX: Float, scaleY: Float, onComplete: (Boolean) -> Unit) {
        val videoSurfaceView = playerView.videoSurfaceView
        if (videoSurfaceView == null) { onComplete(false); return }

        val clampedX = scaleX.coerceIn(0.1f, 3.0f)
        val clampedY = scaleY.coerceIn(0.1f, 3.0f)
        runOnUiThread {
            videoSurfaceView.pivotX = videoSurfaceView.width / 2f
            videoSurfaceView.pivotY = videoSurfaceView.height / 2f
            videoSurfaceView.animate()
                .scaleX(clampedX).scaleY(clampedY)
                .setDuration(300)
                .withEndAction { onComplete(true) }
                .start()
        }
    }

    internal fun resetPlayerViewAppearance() {
        player.setPlaybackSpeed(1.0f)
        playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        playerView.videoSurfaceView?.let { it.scaleX = 1.0f; it.scaleY = 1.0f }
    }

    internal fun notifyStateChanged(player: Player): String {
        val state = when (player.playbackState) {
            Player.STATE_IDLE      -> "idle"
            Player.STATE_BUFFERING -> "buffering"
            Player.STATE_READY     -> if (player.playWhenReady) "playing" else "paused"
            Player.STATE_ENDED     -> "ended"
            else                   -> "unknown"
        }
        val repeatModeString = when (playlistManager.currentRepeatMode) {
            Player.REPEAT_MODE_ONE -> "REPEAT_MODE_ONE"
            Player.REPEAT_MODE_ALL -> "REPEAT_MODE_ALL"
            else                   -> "REPEAT_MODE_OFF"
        }
        invokeOnBothChannels("onStateChanged", mapOf(
            "state"          to state,
            "isLive"         to player.isCurrentMediaItemLive,
            "isSeekable"     to player.isCurrentMediaItemSeekable,
            "playlist_index" to playlistManager.playlistIndex,
            "speed"          to player.playbackParameters.speed,
            "repeatMode"     to repeatModeString,
            "shuffleEnabled" to playlistManager.isShuffleModeEnabled
        ))
        return state
    }

    internal val positionRunnable = object : Runnable {
        override fun run() {
            if (!isFinishing && !isDestroyed && this@PlayerActivity::player.isInitialized &&
                player.playbackState != Player.STATE_IDLE
            ) {
                val durationMs = player.duration
                invokeOnBothChannels("onPositionChanged", mapOf(
                    "position"         to player.currentPosition,
                    "bufferedPosition" to player.bufferedPosition,
                    "duration"         to if (durationMs != C.TIME_UNSET) durationMs else 0L
                ))
                positionHandler.postDelayed(this, 500)
            } else {
                // Player is idle or activity is finishing — stop updates silently, no error.
                Log.d(aTag, "PositionRunnable: Stopping updates (activity finishing or player not ready).")
            }
        }
    }

    internal fun dismissScreensaver() {
        releaseWakeLock()
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "MyApp:PlayerWakeLock"
        )
        wakeLock?.acquire(3000)
    }

    internal fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

}
