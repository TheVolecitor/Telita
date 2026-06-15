package pro.appexp.flutter_tv_media3.activity

import android.net.Uri
import android.util.Log
import androidx.media3.common.PlayerTransferState
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import com.google.common.collect.ImmutableList
import io.flutter.plugin.common.MethodChannel

/**
 * Extension functions for [PlayerActivity] responsible for media loading:
 * - requesting media info from Flutter
 * - building and starting MediaSource
 * - rebuilding source when external tracks are added
 */

// ══════════════════════════════════════════════════════════════════════════════
// Media info request
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Requests media item information from the main Flutter app.
 *
 * Invokes `getMediaInfo` via [methodChannel] and on success parses the response,
 * selects the appropriate URL by quality, then calls [loadAndPlayMedia].
 *
 * @param index The index of the item in the playlist.
 */
@UnstableApi
internal fun PlayerActivity.requestMediaInfo(index: Int) {
    val token = Any().also { currentMediaRequestToken = it }

    invokeOnBothChannels("loadMediaInfo", mapOf("playlist_index" to index))

    methodChannel.invokeMethod("getMediaInfo", mapOf("index" to index), object : MethodChannel.Result {
        override fun success(result: Any?) {
            if (currentMediaRequestToken != token) {
                Log.w(aTag, "Ignored outdated media info success response.")
                return
            }
            if (result is Map<*, *>) {
                val url = result["url"] as? String
                var positionSec = (result["startPosition"] as? Number)?.toLong() ?: 0L
                val durationSec = (result["duration"] as? Number)?.toLong() ?: 0L

                currentHeaders          = result["headers"] as? Map<String, String>
                currentUserAgent        = result["userAgent"] as? String
                currentVideoMimeType    = result["mimeType"] as? String
                currentResolutionsMap   = (result["resolutions"] as? Map<String, String>)
                    ?.entries?.associate { (label, url) -> url to label }
                currentSubtitleTracks   = result["subtitles"] as? List<Map<String, Any>>
                currentAudioTracks      = result["audioTracks"] as? List<Map<String, Any>>
                currentAudioTrackLabels = result["audioTrackLabels"] as? Map<String, String>

                // If near the end — restart from beginning
                if (durationSec > 0 && positionSec > 0 && durationSec - positionSec < 15) {
                    positionSec = 0L
                }

                if (url != null) {
                    resetPlayerViewAppearance()
                    val finalUrl = if (currentResolutionsMap?.isNotEmpty() == true) {
                        trackManager.selectUrlByQuality(currentResolutionsMap!!, url)
                    } else url

                    loadAndPlayMedia(videoUrl = finalUrl, startPosition = positionSec * 1000)
                    invokeOnBothChannels("loadedMediaInfo", mapOf("playlist_index" to index))
                } else {
                    invokeOnBothChannels("onError", mapOf("code" to "INVALID_URL", "message" to "Received null URL for playlist index $index"))
                    finish()
                }
            } else {
                invokeOnBothChannels("onError", mapOf("code" to "INVALID_FORMAT", "message" to "Invalid media info format"))
                finish()
            }
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            if (currentMediaRequestToken != token) {
                Log.w(aTag, "Ignored outdated media info error response.")
                return
            }
            invokeOnBothChannels("onError", mapOf("code" to errorCode, "message" to "Error getting media info: $errorMessage"))
        }

        override fun notImplemented() {
            if (currentMediaRequestToken != token) {
                Log.w(aTag, "Ignored outdated media info notImplemented response.")
                return
            }
            invokeOnBothChannels("onError", mapOf("code" to "NOT_IMPLEMENTED", "message" to "getMediaInfo not implemented"))
            finish()
        }
    })
}

// ══════════════════════════════════════════════════════════════════════════════
// Media source construction & playback
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Loads and starts playing media from the given URL.
 *
 * If a [PlayerTransferState] is provided, it is applied to preserve the player's
 * current state (position, playback speed, etc.) while switching to the new URL.
 */
@UnstableApi
internal fun PlayerActivity.loadAndPlayMedia(
    videoUrl: String,
    startPosition: Long = 0L,
    transferState: PlayerTransferState? = null
) {
    currentVideoUrl = videoUrl

    val (_, dataFactory) = mediaSourceBuilder.createDataSourceFactory(currentHeaders, currentUserAgent)

    if (transferState != null) {
        try {
            val idx   = transferState.currentMediaItemIndex
            val items = transferState.mediaItems.toMutableList()
            if (idx in items.indices) {
                items[idx] = items[idx].buildUpon().setUri(Uri.parse(videoUrl)).build()
                transferState.buildUpon()
                    .setMediaItems(ImmutableList.copyOf(items))
                    .build()
                    .setToPlayer(player)
                player.prepare()
            } else {
                loadWithoutTransferState(videoUrl, startPosition, dataFactory)
            }
        } catch (e: Exception) {
            loadWithoutTransferState(videoUrl, startPosition, dataFactory)
            invokeOnBothChannels("onError", mapOf(
                "code"    to "TRANSFER_STATE_FAILED",
                "message" to "Failed to apply transfer state: ${e.message}"
            ))
        }
    } else {
        loadWithoutTransferState(videoUrl, startPosition, dataFactory)
    }
}

/**
 * Builds a MediaSource from scratch and starts playback at [startPosition].
 * Used when no [PlayerTransferState] is available.
 */
@UnstableApi
internal fun PlayerActivity.loadWithoutTransferState(
    videoUrl: String,
    startPosition: Long,
    dataFactory: DefaultDataSource.Factory
) {
    try {
        val source = mediaSourceBuilder.createCombinedMediaSource(
            videoUrl, currentVideoMimeType, currentSubtitleTracks, currentAudioTracks, dataFactory
        )
        player.setMediaSource(source, startPosition)
        player.prepare()
        player.play()
    } catch (e: Exception) {
        invokeOnBothChannels("onError", mapOf(
            "code"    to "PREPARATION_FAILED",
            "message" to "Failed to create media source: ${e.message}"
        ))
    }
}

/**
 * Rebuilds the current MediaSource (e.g. after external subtitles or audio tracks are added)
 * while preserving the current playback position via [PlayerTransferState].
 */
@UnstableApi
internal fun PlayerActivity.rebuildMediaSourceAndResume() {
    val videoUrl = player.currentMediaItem?.localConfiguration?.uri?.toString() ?: return
    val state    = PlayerTransferState.fromPlayer(player)
    try {
        val (_, dataFactory) = mediaSourceBuilder.createDataSourceFactory(currentHeaders, currentUserAgent)
        val source = mediaSourceBuilder.createCombinedMediaSource(
            videoUrl, currentVideoMimeType, currentSubtitleTracks, currentAudioTracks, dataFactory
        )
        state.setToPlayer(player)
        player.setMediaSource(source, state.currentPosition)
        player.prepare()
    } catch (e: Exception) {
        invokeOnBothChannels("onError", mapOf(
            "code"    to "PREPARATION_FAILED",
            "message" to "Failed to create media source: ${e.message}"
        ))
    }
}
