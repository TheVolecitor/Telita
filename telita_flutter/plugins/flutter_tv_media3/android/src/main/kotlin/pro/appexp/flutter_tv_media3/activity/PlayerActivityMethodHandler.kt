package pro.appexp.flutter_tv_media3.activity

import pro.appexp.flutter_tv_media3.utils.MediaUtils

import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.common.PlayerTransferState
import androidx.media3.common.util.UnstableApi
import androidx.media3.ui.AspectRatioFrameLayout
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import androidx.lifecycle.lifecycleScope

/**
 * Extension functions for [PlayerActivity] responsible for all Flutter MethodChannel
 * communication: incoming call handling and outgoing channel invocations.
 *
 * Extracted to keep [PlayerActivity] focused on lifecycle and initialization only.
 */

// ══════════════════════════════════════════════════════════════════════════════
// Incoming: MethodChannel call handler
// ══════════════════════════════════════════════════════════════════════════════

/**
 * The central handler for method calls coming from Flutter.
 *
 * Distinguishes commands from the UI overlay and the main app and delegates
 * their execution to the appropriate player methods or delegate classes.
 */
@UnstableApi
internal fun PlayerActivity.handleMethodCall(
    call: MethodCall,
    result: MethodChannel.Result,
    from: MethodChannel
) {
    if (!isPlayerInitialized()) {
        reportErrorToOther(from, result, "PLAYER_NOT_READY", "Player not initialized.")
        return
    }

    when (call.method) {

        "loadMediaInfoState" -> {
            invokeOnBothChannels("loadMediaInfoState", mapOf(
                "state"    to call.argument<String>("state"),
                "progress" to call.argument<Number>("progress")
            ))
        }

        "playPause" -> {
            if (player.isPlaying) {
                player.pause()
                positionHandler.removeCallbacks(positionRunnable)
            } else {
                player.play()
                positionHandler.removeCallbacks(positionRunnable)
                positionHandler.post(positionRunnable)
            }
            result.success(null)
        }

        "play" -> {
            player.play()
            positionHandler.removeCallbacks(positionRunnable)
            positionHandler.post(positionRunnable)
            result.success(null)
        }

        "pause" -> {
            player.pause()
            positionHandler.removeCallbacks(positionRunnable)
            result.success(null)
        }

        "seekTo" -> {
            val positionMs = call.argument<Number>("position")?.toLong()
                ?: return reportErrorToOther(from, result, "INVALID_POSITION", "Position is null")

            val duration = player.duration
            val seekPos  = if (duration > 0) positionMs.coerceIn(0, duration) else positionMs.coerceAtLeast(0)
            player.seekTo(seekPos)

            val finalDuration = if (duration != C.TIME_UNSET) duration else 0L
            invokeOnBothChannels("onPositionChanged", mapOf(
                "position"         to seekPos,
                "bufferedPosition" to player.bufferedPosition.coerceAtLeast(seekPos),
                "duration"         to finalDuration
            ))

            if (player.isPlaying) {
                positionHandler.removeCallbacks(positionRunnable)
                positionHandler.post(positionRunnable)
            }
            result.success(null)
        }

        "stop" -> { finish(); result.success(null) }

        "sleepTimerExec" -> {
            methodChannel.invokeMethod("sleepTimerExec", null)
            finish()
            result.success(null)
        }

        "selectTrack" -> {
            val trackType  = call.argument<Int>("trackType")  ?: return reportErrorToOther(from, result, "INVALID_TYPE", "Missing or invalid trackType")
            val groupIndex = call.argument<Int>("groupIndex") ?: return reportErrorToOther(from, result, "INVALID_INDEX", "Group index is null")
            val trackIndex = call.argument<Int>("trackIndex") ?: return reportErrorToOther(from, result, "INVALID_INDEX", "Track index is null")

            val error = trackManager.selectTrack(trackType, groupIndex, trackIndex)
            if (error != null) reportErrorToOther(from, result, "SELECTION_ERROR", error)
            else result.success(null)
        }

        "selectExternalVideoTrack" -> {
            val url = call.argument<String?>("url")
            if (currentResolutionsMap != null) handleQualitySelection(url, result, from)
            else reportErrorToOther(from, result, "NO_RESOLUTIONS", "Resolution tracks are not available for selection")
        }

        "getThumbnail" -> {
            if (playerSettings?.get("screenshotsEnable") as? Boolean != true) {
                result.error("SCREENSHOTS_DISABLED", "Screenshot functionality is disabled", null)
                return
            }
            val uri = call.argument<String>("uri") ?: return result.error("INVALID_ARGUMENT", "URI is null", null)
            val timeInSeconds = call.argument<Number>("timeInSeconds")?.toDouble()

            lifecycleScope.launch(Dispatchers.Main) {
                val bytes = MediaUtils.getThumbnail(this@handleMethodCall, uri, timeInSeconds)
                if (bytes != null) {
                    result.success(bytes)
                    invokeOnOtherChannel("onScreenshotTaken", mapOf("bytes" to bytes, "playlistIndex" to playlistManager.playlistIndex), from)
                } else {
                    result.error("EXTRACTION_ERROR", "Failed to extract thumbnail", null)
                }
            }
        }

        "getMetadata" -> {
            val meta = metadataParser.getCurrentMetadata(player)
            invokeOnOtherChannel("onMetadataChanged", meta, from)
            result.success(meta)
        }

        "getCurrentTracks" -> {
            val tracks = getCurrentTracksFromDelegate()
            invokeOnOtherChannel("setCurrentTracks", tracks, from)
            result.success(tracks)
        }

        "setResizeMode" -> {
            val modeName = call.argument<String>("mode")
            val resizeMode = when (modeName) {
                "FIT"          -> AspectRatioFrameLayout.RESIZE_MODE_FIT
                "FILL"         -> AspectRatioFrameLayout.RESIZE_MODE_FILL
                "ZOOM"         -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                "FIXED_WIDTH"  -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH
                "FIXED_HEIGHT" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_HEIGHT
                else           -> null
            }
            if (resizeMode != null) {
                playerView.resizeMode = resizeMode
                val res = mapOf("zoom" to modeName)
                invokeOnOtherChannel("setCurrentResizeMode", res, from)
                result.success(res)
            } else {
                reportErrorToOther(from, result, "INVALID_MODE", "Invalid resize mode: $modeName")
            }
        }

        "setScale" -> {
            val scaleX = call.argument<Double>("scaleX")?.toFloat() ?: 1.0f
            val scaleY = call.argument<Double>("scaleY")?.toFloat() ?: 1.0f
            applyZoom(scaleX, scaleY) { success ->
                if (success) {
                    val res = mapOf("zoom" to "SCALE")
                    invokeOnOtherChannel("setCurrentResizeMode", res, from)
                    result.success(res)
                } else {
                    reportErrorToOther(from, result, "VIEW_NOT_INITIALIZED", "videoSurfaceView is null")
                }
            }
        }

        "setSpeed" -> {
            val speed = call.argument<Double>("speed")?.toFloat() ?: 1.0f
            runOnUiThread { player.setPlaybackSpeed(speed) }
            val res = mapOf("speed" to speed)
            invokeOnOtherChannel("setCurrentSpeed", res, from)
            result.success(res)
        }

        "setRepeatMode" -> {
            val modeName = call.argument<String>("mode") ?: "REPEAT_MODE_OFF"
            @Player.RepeatMode val mode = when (modeName) {
                "REPEAT_MODE_ONE" -> Player.REPEAT_MODE_ONE
                "REPEAT_MODE_ALL" -> Player.REPEAT_MODE_ALL
                else              -> Player.REPEAT_MODE_OFF
            }
            runOnUiThread {
                playlistManager.setRepeatMode(mode)
                player.repeatMode = if (mode == Player.REPEAT_MODE_ONE) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
            }
            invokeOnOtherChannel("setRepeatMode", mapOf("status" to "success", "mode" to modeName), from)
            result.success(mapOf("status" to "success", "mode" to modeName))
        }

        "setShuffleMode" -> {
            val enabled = call.argument<Boolean>("enabled") ?: false
            runOnUiThread { playlistManager.setShuffleMode(enabled) }
            invokeOnOtherChannel("setShuffleMode", mapOf("status" to "success", "shuffleEnabled" to enabled), from)
            result.success(mapOf("status" to "success", "shuffleEnabled" to enabled))
        }

        "setSubtitleStyle" -> {
            val applied = subtitleStyleManager.applySubtitleStyle(call.arguments as? Map<String, Any>)
            invokeOnOtherChannel("updateSubtitleStyle", applied, from)
            result.success(applied)
        }

        "saveClockSettings" -> {
            invokeOnOtherChannel("saveClockSettings", mapOf("clock_settings" to call.argument<String?>("clock_settings")), from)
            result.success(null)
        }

        "savePlayerSettings" -> {
            try {
                playerSettings = call.arguments as? Map<String, Any>
                runOnUiThread { trackManager.applySettings(playerSettings) }
                invokeOnOtherChannel("savePlayerSettings", playerSettings, from)
                result.success(true)
            } catch (e: Exception) {
                reportErrorToOther(from, result, "NATIVE_ERROR", "Failed to apply settings", e.message)
            }
        }

        "onLoadMore" -> { methodChannel.invokeMethod("onLoadMore", null); result.success(null) }

        "playNext"     -> { runOnUiThread { playlistManager.playNext() };     result.success(null) }
        "playPrevious" -> { runOnUiThread { playlistManager.playPrevious() }; result.success(null) }

        "playSelectedIndex" -> {
            val newIndex = call.argument<Int>("index")
            if (newIndex != null && playlistManager.playSelectedIndex(newIndex)) {
                if (player.isPlaying) { player.pause(); positionHandler.removeCallbacks(positionRunnable) }
                result.success(null)
            } else {
                reportErrorToOther(from, result, "INVALID_INDEX", "Invalid playlist index: $newIndex")
            }
        }

        /**
         * Handles the "updatePlaylist" method call from Flutter.
         *
         * Invoked when the main Flutter application adds new items to the playlist.
         * Updates the internal playlistLength and notifies both channels.
         */
        "updatePlaylist" -> {
            playlistManager.playlistLength = call.argument<Int>("playlist_length") ?: playlistManager.playlistLength
            invokeOnOtherChannel("onPlaylistUpdated", mapOf(
                "playlist"       to call.argument<String>("playlist"),
                "playlist_index" to playlistManager.playlistIndex
            ), from)
            result.success(null)
        }

        /**
         * Handles the "onItemRemoved" method call from Flutter.
         *
         * Adjusts playlistLength and playlistIndex. If the currently playing item
         * is removed, plays the next available item or closes the player.
         */
        "onItemRemoved" -> {
            val removedIndex = call.argument<Int>("index") ?: -1
            val newLength    = call.argument<Int>("playlist_length") ?: (playlistManager.playlistLength - 1)
            if (removedIndex != -1) {
                val newIdx = playlistManager.handleItemRemoved(removedIndex, newLength)
                invokeOnOtherChannel("onItemRemoved", mapOf(
                    "playlist"       to call.argument<String>("playlist"),
                    "playlist_index" to newIdx
                ), from)
            }
            result.success(null)
        }

        "setExternalSubtitles" -> {
            val newSubtitles = call.argument<List<Map<String, Any>>>("subtitleTracks")
                ?: return reportErrorToOther(from, result, "INVALID_SUBTITLES", "Subtitles list is null")

            val existing     = currentSubtitleTracks ?: emptyList()
            val existingUrls = existing.mapNotNull { it["url"] as? String }.toSet()
            val unique       = newSubtitles.filter { (it["url"] as? String)?.let { u -> u !in existingUrls } == true }

            if (unique.isNotEmpty()) {
                currentSubtitleTracks = existing + unique
                rebuildMediaSourceAndResume()
            }
            result.success(null)
        }

        "setExternalAudio" -> {
            val newAudioTracks = call.argument<List<Map<String, Any>>>("audioTracks")
                ?: return reportErrorToOther(from, result, "INVALID_AUDIO", "Audio tracks list is null")

            currentAudioTracks = (currentAudioTracks ?: emptyList()) + newAudioTracks
            rebuildMediaSourceAndResume()
            result.success(null)
        }

        "onReceiveInfoText" -> {
            invokeOnOtherChannel("onCustomInfoUpdate", mapOf("text" to call.argument<String>("text")), from)
            result.success(null)
        }

        "findSubtitles" -> {
            invokeOnOtherChannel("onFindSubtitlesRequested", mapOf("mediaId" to call.argument<String>("mediaId")), from)
            result.success(null)
        }

        "onSubtitleSearchStateChanged" -> {
            invokeOnOtherChannel("onSubtitleSearchStateChanged", call.arguments as? Map<String, Any>, from)
            result.success(null)
        }

        "getRefreshRateInfo" -> result.success(frameRateManager.getRefreshRateInfo())

        "setManualFrameRate" -> {
            if (trackManager.isAfrEnabled) return reportErrorToOther(from, result, "AFR_ENABLED", "Cannot set manual rate when AFR is enabled")
            val rate = call.argument<Double>("rate")?.toFloat()
                ?: return reportErrorToOther(from, result, "INVALID_RATE", "Rate is null")
            frameRateManager.setManualRefreshRate(rate)
            result.success(null)
        }

        "getVolume" -> result.success(volumeManager.getCurrentVolumeState())

        "setVolume" -> {
            val volume = call.argument<Double>("volume")
                ?: return reportErrorToOther(from, result, "INVALID_VOLUME", "Volume is null")
            volumeManager.setVolume(volume)
            result.success(null)
        }

        "setMute" -> {
            val mute = call.argument<Boolean>("mute")
                ?: return reportErrorToOther(from, result, "INVALID_MUTE", "Mute is null")
            volumeManager.setMute(mute)
            result.success(null)
        }

        "toggleMute" -> {
            try {
                result.success(mapOf("isMute" to volumeManager.toggleMute()))
            } catch (e: UnsupportedOperationException) {
                reportErrorToOther(from, result, "UNSUPPORTED_API", e.message ?: "")
            }
        }

        else -> {
            reportErrorToOther(from, result, "NOT_IMPLEMENTED", "Method ${call.method} not implemented in PlayerActivity channel.")
            result.notImplemented()
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// Outgoing: channel invocation utilities
// ══════════════════════════════════════════════════════════════════════════════

@UnstableApi
internal fun PlayerActivity.invokeOnBothChannels(method: String, arguments: Any?) {
    try { methodChannel.invokeMethod(method, arguments) } catch (e: Exception) { Log.e("Media3Activity", "invokeOnBothChannels: error on methodChannel: ${e.message}") }
    try { methodUIChannel.invokeMethod(method, arguments) } catch (e: Exception) { Log.e("Media3Activity", "invokeOnBothChannels: error on methodUIChannel: ${e.message}") }
}

@UnstableApi
internal fun PlayerActivity.invokeOnOtherChannel(method: String, arguments: Any?, from: MethodChannel) {
    try { if (from != methodChannel) methodChannel.invokeMethod(method, arguments) } catch (e: Exception) { Log.e("Media3Activity", "invokeOnOtherChannel error calling $method: ${e.message}") }
    try { if (from != methodUIChannel) methodUIChannel.invokeMethod(method, arguments) } catch (e: Exception) { Log.e("Media3Activity", "invokeOnOtherChannel error calling $method: ${e.message}") }
}

@UnstableApi
internal fun PlayerActivity.reportErrorToOther(
    from: MethodChannel,
    result: MethodChannel.Result,
    code: String,
    message: String,
    details: Any? = null
) {
    invokeOnOtherChannel("onError", mapOf("code" to code, "message" to message), from = from)
    result.error(code, message, details)
}

@UnstableApi
internal fun PlayerActivity.handleQualitySelection(
    url: String?,
    result: MethodChannel.Result,
    from: MethodChannel
) {
    if (currentResolutionsMap.isNullOrEmpty()) {
        reportErrorToOther(from, result, "NO_RESOLUTIONS", "Resolution tracks are not available for selection")
        return
    }
    val availableUrls = currentResolutionsMap!!.keys.toList()
    val selectedUrl = when {
        url == null                 -> availableUrls.firstOrNull()
        availableUrls.contains(url) -> url
        else -> return reportErrorToOther(from, result, "INVALID_URL", "Provided URL is not among available resolution tracks")
    } ?: return reportErrorToOther(from, result, "NO_VALID_URL", "No valid URL found for selection", null)

    try {
        loadAndPlayMedia(videoUrl = selectedUrl, transferState = PlayerTransferState.fromPlayer(player))
        result.success(null)
    } catch (e: Exception) {
        reportErrorToOther(from, result, "SOURCE_SWITCH_ERROR", "Failed to switch source: ${e.message}")
    }
}
