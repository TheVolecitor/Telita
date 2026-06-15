package pro.appexp.flutter_tv_media3.activity

import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import androidx.media3.common.C
import androidx.media3.common.Metadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.PlayerTransferState
import androidx.media3.common.Timeline
import androidx.media3.common.Tracks
import androidx.media3.common.util.StuckPlayerException
import androidx.media3.common.util.UnstableApi

/**
 * Extension function for [PlayerActivity] that creates and returns
 * a [Player.Listener] reacting to all ExoPlayer events.
 *
 * Responsibilities:
 * - Wake lock / screen-on management
 * - Playback state changes → Flutter notifications
 * - Track changes → sending current tracks to Flutter
 * - Metadata and streaming metadata updates
 * - Error recovery: stuck player retries, HLS recoverable errors
 */
@UnstableApi
internal fun PlayerActivity.createPlayerListener(): Player.Listener = object : Player.Listener {

    // ─── Wake lock ────────────────────────────────────────────────────────────
    
    private var hasShownHdrToast = false

    private fun updateWakeLock() {
        val hasVideo = player.currentTracks.groups.any { it.type == C.TRACK_TYPE_VIDEO && it.isSelected }
        if (player.isPlaying && hasVideo) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) = updateWakeLock()

    // ─── Playback state ───────────────────────────────────────────────────────

    override fun onPlaybackStateChanged(playbackState: Int) {
        val state = notifyStateChanged(player)

        if (playbackState == Player.STATE_ENDED) playlistManager.handleTrackEnded()

        if ((state == "playing" || state == "buffering") && playbackState != Player.STATE_ENDED) {
            positionHandler.removeCallbacks(positionRunnable)
            positionHandler.post(positionRunnable)
        } else {
            positionHandler.removeCallbacks(positionRunnable)
        }
    }

    override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
        if (playWhenReady) dismissScreensaver()
        notifyStateChanged(player)
        if (playWhenReady && (player.playbackState == Player.STATE_READY || player.playbackState == Player.STATE_BUFFERING)) {
            positionHandler.removeCallbacks(positionRunnable)
            positionHandler.post(positionRunnable)
        } else {
            positionHandler.removeCallbacks(positionRunnable)
        }
    }

    // ─── Metadata ─────────────────────────────────────────────────────────────

    override fun onTimelineChanged(timeline: Timeline, reason: Int) {
        invokeOnBothChannels("onMetadataChanged", metadataParser.getCurrentMetadata(player))
    }

    override fun onMetadata(metadata: Metadata) {
        val update = metadataParser.parseStreamingMetadata(metadata)
        if (update.isNotEmpty()) invokeOnBothChannels("onStreamingMetadataUpdated", update)
    }

    // ─── Tracks ───────────────────────────────────────────────────────────────

    override fun onTracksChanged(tracks: Tracks) {
        sendCurrentTracksToDart()

        val currentSubtitle = tracks.groups
            .firstOrNull { it.type == C.TRACK_TYPE_TEXT && it.isSelected }
            ?.let { group ->
                val selectedIndex = (0 until group.length).firstOrNull { group.isTrackSelected(it) }
                if (selectedIndex != null) group.getTrackFormat(selectedIndex) else null
            }

        val currentSubtitleId = currentSubtitle?.id

        if (currentSubtitleId != lastActiveSubtitleId && currentSubtitle != null) {
            val externalUrls = currentSubtitleTracks?.mapNotNull { it["url"] as? String }?.toSet() ?: emptySet()
            val isExternal   = externalUrls.any { url -> currentSubtitle.id?.contains(url) == true }
            if (isExternal) methodChannel.invokeMethod("onExternalSubtitleSelected", null)
        }
        lastActiveSubtitleId = currentSubtitleId

        if (trackManager.isAfrEnabled) frameRateManager.onPossibleFrameRateChange()
    }

    override fun onRenderedFirstFrame() {
        updateWakeLock()
        sendCurrentTracksToDart()
        if (trackManager.isAfrEnabled) frameRateManager.onPossibleFrameRateChange()
        checkHdrSupport()
    }

    // ─── Errors ───────────────────────────────────────────────────────────────

    override fun onPlayerError(error: PlaybackException) {
        val stuckError = error.cause as? StuckPlayerException
        if (stuckError != null) {
            handleStuckPlayer(error, stuckError)
            return
        }

        if (isRecoverableHlsError(error)) {
            recoverFromHlsError(error)
            return
        }

        invokeOnBothChannels("onError", mapOf("code" to error.errorCodeName, "message" to error.localizedMessage))
        positionHandler.removeCallbacks(positionRunnable)
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    /**
     * Attempts to recover from a stuck player by restoring state via [PlayerTransferState].
     * Gives up after 2 failed retries and reports the error to Flutter.
     */
    private fun handleStuckPlayer(error: PlaybackException, stuckError: StuckPlayerException) {
        if (stuckRetryCount > 1) {
            invokeOnBothChannels("onError", mapOf("code" to error.errorCodeName, "message" to error.localizedMessage))
            stuckRetryCount = 0
            positionHandler.removeCallbacks(positionRunnable)
            return
        }
        stuckRetryCount++
        Log.d(aTag, "Stuck retry attempt $stuckRetryCount for stuckType=${stuckError.stuckType}")
        try {
            val transferState = PlayerTransferState.fromPlayer(player)
            transferState.setToPlayer(player)
            player.prepare()
            if (transferState.playWhenReady) player.play()
            Handler(Looper.getMainLooper()).postDelayed({
                if (player.isPlaying) {
                    stuckRetryCount = 0
                    Log.d(aTag, "Stuck recovered after retry")
                }
            }, 3000)
        } catch (e: Exception) {
            Log.e(aTag, "Failed to recover from stuck: ${e.message}")
            stuckRetryCount = 0
            player.seekToDefaultPosition()
            player.prepare()
            player.play()
        }
    }

    /**
     * Attempts to recover from a recoverable HLS error (e.g. BehindLiveWindowException)
     * by restoring state via [PlayerTransferState].
     */
    private fun recoverFromHlsError(error: PlaybackException) {
        try {
            val transferState = PlayerTransferState.fromPlayer(player)
            transferState.setToPlayer(player)
            player.prepare()
            if (transferState.playWhenReady) player.play()
        } catch (e: Exception) {
            Log.e(aTag, "Failed to restore state after HLS error: ${e.message}")
            player.seekToDefaultPosition()
            player.prepare()
            player.play()
        }
    }

    private fun sendCurrentTracksToDart() {
        invokeOnBothChannels("setCurrentTracks", getCurrentTracksFromDelegate())
    }

    private fun checkHdrSupport() {
        if (hasShownHdrToast) return

        val videoTrack = player.currentTracks.groups.firstOrNull { it.type == C.TRACK_TYPE_VIDEO && it.isSelected }
        if (videoTrack != null && videoTrack.length > 0) {
            val format = videoTrack.getTrackFormat(0)
            val colorInfo = format.colorInfo
            
            val isHdr = (colorInfo != null && (
                colorInfo.colorTransfer == C.COLOR_TRANSFER_ST2084 || 
                colorInfo.colorTransfer == C.COLOR_TRANSFER_HLG
            )) || format.codecs?.contains("dvh1") == true || format.codecs?.contains("dvhe") == true
            
            if (isHdr) {
                val windowManager = this@createPlayerListener.getSystemService(android.content.Context.WINDOW_SERVICE) as android.view.WindowManager
                val hdrCapabilities = windowManager.defaultDisplay.hdrCapabilities
                val supportsHdr = hdrCapabilities?.supportedHdrTypes?.isNotEmpty() == true
                
                if (!supportsHdr) {
                    hasShownHdrToast = true
                    android.widget.Toast.makeText(this@createPlayerListener, "HDR is not supported on this display. Tone-mapping to SDR.", android.widget.Toast.LENGTH_LONG).show()
                }
            }
        }
    }
}
