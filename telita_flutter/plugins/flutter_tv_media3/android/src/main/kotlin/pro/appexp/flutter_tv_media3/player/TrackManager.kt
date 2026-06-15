package pro.appexp.flutter_tv_media3.player

import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector

private const val TAG = "TrackManager"

/**
 * Responsible for reading current tracks, applying track selections,
 * applying track selector settings (quality, languages, subtitles),
 * and selecting the best URL from a resolution map.
 *
 * @param getPlayer        Lambda to retrieve the current ExoPlayer instance.
 * @param getTrackSelector Lambda to retrieve the DefaultTrackSelector instance.
 * @param metadataParser   Used for quality string parsing in [selectUrlByQuality].
 * @param onAfrStateChanged Callback invoked when isAfrEnabled changes (true = enabled).
 */
@UnstableApi
class TrackManager(
    private val getPlayer: () -> ExoPlayer,
    private val getTrackSelector: () -> DefaultTrackSelector,
    private val metadataParser: MetadataParser,
    private val onAfrStateChanged: (enabled: Boolean) -> Unit
) {

    // ─── Quality state ────────────────────────────────────────────────────────

    var isAfrEnabled: Boolean = false
        private set

    var currentVideoQualityIndex: Int = 0
        private set

    var currentVideoWidth: Int = 0
        private set

    var currentVideoHeight: Int = 0
        private set

    var currentForceHighestBitrate: Boolean = true
        private set

    /**
     * Returns a list of all tracks in a format suitable for passing to Flutter.
     *
     * @param currentSubtitleTracks  External subtitles (used to mark isExternal).
     * @param currentAudioTracks     External audio tracks (used to fill label/language).
     * @param currentAudioTrackLabels Custom labels for embedded audio tracks.
     * @param currentResolutionsMap  Map of URL → label for external video quality options.
     * @param currentVideoUrl        Current video URL (used to identify the active quality).
     */
    fun getCurrentTracks(
        currentSubtitleTracks: List<Map<String, Any>>?,
        currentAudioTracks: List<Map<String, Any>>?,
        currentAudioTrackLabels: Map<String, String>?,
        currentResolutionsMap: Map<String, String>?,
        currentVideoUrl: String?
    ): List<Map<String, Any?>> {
        val player = getPlayer()
        val tracksList = mutableListOf<Map<String, Any?>>()

        val externalSubtitleUrls = currentSubtitleTracks
            ?.mapNotNull { it["url"] as? String }
            ?.toSet() ?: emptySet()

        val currentTracks  = player.currentTracks
        val activeVideoFmt = player.videoFormat

        var externalAudioIdx = 0
        var audioCounter     = 0

        for (group in currentTracks.groups) {
            val trackType = group.type
            if (trackType != C.TRACK_TYPE_VIDEO &&
                trackType != C.TRACK_TYPE_AUDIO &&
                trackType != C.TRACK_TYPE_TEXT
            ) continue

            val trackGroup = group.mediaTrackGroup

            for (i in 0 until trackGroup.length) {
                if (!group.isTrackSupported(i)) {
                    Log.w(TAG, "Track $i in group type $trackType is not supported.")
                    continue
                }

                val format     = trackGroup.getFormat(i)
                val groupIndex = currentTracks.groups.indexOf(group)
                val isSelected = when (trackType) {
                    C.TRACK_TYPE_VIDEO ->
                        (group.isSelected && group.isTrackSelected(i)) ||
                        (activeVideoFmt?.id == format.id)
                    else -> group.isSelected && group.isTrackSelected(i)
                }

                val trackInfo = mutableMapOf<String, Any?>(
                    "index"      to i,
                    "groupIndex" to groupIndex,
                    "id"         to format.id,
                    "trackType"  to trackType,
                    "isSelected" to isSelected,
                    "isExternal" to false
                )

                when (trackType) {
                    C.TRACK_TYPE_VIDEO -> fillVideoTrack(trackInfo, format)
                    C.TRACK_TYPE_AUDIO -> {
                        fillAudioTrack(
                            trackInfo, format, currentAudioTracks, currentAudioTrackLabels,
                            externalAudioIdx, audioCounter
                        )
                        if (isPossiblyExternal(format) && currentAudioTracks != null) externalAudioIdx++
                        audioCounter++
                    }
                    C.TRACK_TYPE_TEXT -> fillTextTrack(trackInfo, format, externalSubtitleUrls)
                }

                tracksList.add(trackInfo)
            }
        }

        appendExternalVideoTracks(tracksList, currentResolutionsMap, currentVideoUrl)

        return tracksList
    }

    /**
     * Applies a track selection by groupIndex / trackIndex.
     * trackIndex == -1 resets the selection to automatic.
     *
     * @return null on success, or an error string if something went wrong.
     */
    fun selectTrack(
        trackType: @C.TrackType Int,
        groupIndex: Int,
        trackIndex: Int
    ): String? {
        val player        = getPlayer()
        val trackSelector = getTrackSelector()
        val builder       = trackSelector.parameters.buildUpon()

        return try {
            if (trackIndex == -1) applyAutoSelection(builder, trackType, player)
            else applyManualSelection(builder, trackType, groupIndex, trackIndex, player)
            trackSelector.parameters = builder.build()
            null
        } catch (e: Exception) {
            "SELECTION_ERROR: ${e.message}"
        }
    }

    // ─── Private helpers: track data filling ──────────────────────────────────

    private fun fillVideoTrack(info: MutableMap<String, Any?>, f: Format) {
        info.putAll(mapOf(
            "label"                 to f.label,
            "width"                 to f.width.takeIf { it != Format.NO_VALUE },
            "height"                to f.height.takeIf { it != Format.NO_VALUE },
            "bitrate"               to f.bitrate.takeIf { it != Format.NO_VALUE },
            "frameRate"             to f.frameRate.takeIf { it != Format.NO_VALUE.toFloat() },
            "sampleMimeType"        to f.sampleMimeType,
            "codecs"                to f.codecs,
            "selectionFlags"        to f.selectionFlags,
            "roleFlags"             to f.roleFlags,
            "pixelWidthHeightRatio" to f.pixelWidthHeightRatio.takeIf { it != Format.NO_VALUE.toFloat() },
            "containerMimeType"     to f.containerMimeType,
            "averageBitrate"        to f.averageBitrate.takeIf { it != Format.NO_VALUE },
            "peakBitrate"           to f.peakBitrate.takeIf { it != Format.NO_VALUE },
            "stereoMode"            to f.stereoMode,
            "colorInfo"             to f.colorInfo?.let { c ->
                mapOf("colorSpace" to c.colorSpace, "colorRange" to c.colorRange, "colorTransfer" to c.colorTransfer)
            }
        ))
    }

    private fun fillAudioTrack(
        info: MutableMap<String, Any?>,
        f: Format,
        externalAudioTracks: List<Map<String, Any>>?,
        audioTrackLabels: Map<String, String>?,
        externalAudioIdx: Int,
        audioCounter: Int
    ) {
        info.putAll(mapOf(
            "label"          to f.label,
            "language"       to f.language,
            "codec"          to f.codecs,
            "mimeType"       to f.sampleMimeType,
            "bitrate"        to f.bitrate.takeIf { it != Format.NO_VALUE },
            "averageBitrate" to f.averageBitrate.takeIf { it != Format.NO_VALUE },
            "peakBitrate"    to f.peakBitrate.takeIf { it != Format.NO_VALUE },
            "sampleRate"     to f.sampleRate,
            "channelCount"   to f.channelCount,
            "selectionFlags" to f.selectionFlags,
            "roleFlags"      to f.roleFlags
        ))

        if (isPossiblyExternal(f) && externalAudioTracks != null) {
            // OLD LOGIC: Check for external audio tracks using heuristics
            val ext = externalAudioTracks.getOrNull(externalAudioIdx)
            if (ext != null) {
                (ext["label"] as? String)?.let { info["label"] = it }
                (ext["language"] as? String)?.let { info["language"] = it }
                info["isExternal"] = true
            }
        } else {
            // NEW LOGIC: Use custom labels for internal tracks
            audioTrackLabels?.let { labels ->
                val byIndex = labels[audioCounter.toString()]
                val byId    = f.id?.let { labels[it] }
                (byIndex ?: byId)?.let { info["label"] = it }
            }
        }
    }

    private fun fillTextTrack(
        info: MutableMap<String, Any?>,
        f: Format,
        externalSubtitleUrls: Set<String>
    ) {
        info.putAll(mapOf(
            "label"             to f.label,
            "language"          to (f.language ?: "unknown"),
            "selectionFlags"    to f.selectionFlags,
            "roleFlags"         to f.roleFlags,
            "codecs"            to f.codecs,
            "containerMimeType" to f.containerMimeType,
            "sampleMimeType"    to f.sampleMimeType
        ))
        if (f.id != null && externalSubtitleUrls.any { f.id!!.contains(it) }) {
            info["isExternal"] = true
        }
    }

    private fun appendExternalVideoTracks(
        tracksList: MutableList<Map<String, Any?>>,
        resolutionsMap: Map<String, String>?,
        currentVideoUrl: String?
    ) {
        if (resolutionsMap == null) return

        val selectedTrack = tracksList.find { it["trackType"] == C.TRACK_TYPE_VIDEO && it["isSelected"] == true }
        val activeLabel   = resolutionsMap[currentVideoUrl]
        var externalIdx   = 1000

        for ((url, label) in resolutionsMap) {
            val isCurrent = url == currentVideoUrl
            when {
                !isCurrent                              -> tracksList.add(externalVideoTrack(externalIdx++, url, label, false))
                selectedTrack == null                   -> tracksList.add(externalVideoTrack(externalIdx++, url, label, true))
                activeLabel != null && selectedTrack != null -> {
                    val idx = tracksList.indexOf(selectedTrack)
                    tracksList.removeAt(idx)
                    tracksList.add(selectedTrack.toMutableMap().apply {
                        this["label"]      = activeLabel
                        this["isSelected"] = true
                    })
                }
            }
        }
    }

    private fun externalVideoTrack(idx: Int, url: String, label: String, selected: Boolean) =
        mapOf(
            "index"      to idx,
            "groupIndex" to -1,
            "id"         to url,
            "trackType"  to C.TRACK_TYPE_VIDEO,
            "label"      to label,
            "url"        to url,
            "isSelected" to selected,
            "isExternal" to true
        )

    // ─── Private helpers: track selection ─────────────────────────────────────

    private fun applyAutoSelection(
        builder: DefaultTrackSelector.Parameters.Builder,
        trackType: @C.TrackType Int,
        player: ExoPlayer
    ) {
        when (trackType) {
            C.TRACK_TYPE_VIDEO -> builder
                .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
                .setRendererDisabled(C.TRACK_TYPE_VIDEO, false)
                .setForceHighestSupportedBitrate(false)
                .setMaxVideoBitrate(Int.MAX_VALUE)

            // Reset to automatic selection: enable the renderer and clear any manual overrides.
            // setRendererDisabled(true) would silence audio entirely, which is wrong for "Auto".
            C.TRACK_TYPE_AUDIO -> builder
                .clearSelectionOverrides(trackType)
                .setRendererDisabled(trackType, false)

            // trackIndex == -1 for TEXT means the user explicitly chose "Off" (no subtitles).
            // Disabling the renderer here is intentional.
            C.TRACK_TYPE_TEXT -> {
                val trackSelector = getTrackSelector()
                (0 until (trackSelector.currentMappedTrackInfo?.rendererCount ?: 0))
                    .filter { player.getRendererType(it) == C.TRACK_TYPE_TEXT }
                    .forEach { pos ->
                        builder.setRendererDisabled(pos, true).clearSelectionOverrides(pos)
                    }
            }
        }
    }

    private fun applyManualSelection(
        builder: DefaultTrackSelector.Parameters.Builder,
        trackType: @C.TrackType Int,
        groupIndex: Int,
        trackIndex: Int,
        player: ExoPlayer
    ) {
        val groups = player.currentTracks.groups
        require(groupIndex in groups.indices) { "Invalid group index: $groupIndex" }

        val group = groups[groupIndex]
        require(group.type == trackType) { "Group type mismatch: expected $trackType, got ${group.type}" }

        val trackGroup = group.mediaTrackGroup
        require(trackIndex in 0 until trackGroup.length && group.isTrackSupported(trackIndex)) {
            "Invalid or unsupported track index: $trackIndex"
        }

        val override = TrackSelectionOverride(trackGroup, listOf(trackIndex))

        if (trackType == C.TRACK_TYPE_TEXT) {
            builder.setOverrideForType(override)
            val mapped = getTrackSelector().currentMappedTrackInfo
            if (mapped != null) {
                for (r in 0 until mapped.rendererCount) {
                    if (mapped.getRendererType(r) == C.TRACK_TYPE_TEXT) {
                        builder.setRendererDisabled(r, false)
                    }
                }
            }
        } else {
            builder.setOverrideForType(override).setRendererDisabled(trackType, false)
        }
    }

    private fun isPossiblyExternal(f: Format): Boolean =
        f.label == null && f.language == null &&
        f.id != null && f.id!!.matches(Regex("\\d+:"))

    // ─── Track selector settings ──────────────────────────────────────────────

    /**
     * Applies player settings (quality, languages, AFR, subtitles) to [DefaultTrackSelector].
     * Safe to call at any lifecycle stage — does not rely on [currentMappedTrackInfo].
     *
     * @param settings Settings map from Flutter (may be null to use current values).
     */
    fun applySettings(settings: Map<String, Any>?) {
        val newAfrState = settings?.get("isAfrEnabled") as? Boolean ?: false
        if (isAfrEnabled != newAfrState) onAfrStateChanged(newAfrState)
        isAfrEnabled = newAfrState

        val s = settings ?: emptyMap()
        currentVideoQualityIndex   = (s["videoQuality"] as? Number)?.toInt() ?: currentVideoQualityIndex
        currentVideoWidth          = (s["width"] as? Number)?.toInt() ?: currentVideoWidth
        currentVideoHeight         = (s["height"] as? Number)?.toInt() ?: currentVideoHeight
        currentForceHighestBitrate = s["forceHighestBitrate"] as? Boolean ?: currentForceHighestBitrate

        val b = getTrackSelector().parameters.buildUpon()

        // Video quality
        when (currentVideoQualityIndex) {
            0    -> b.clearVideoSizeConstraints()
                     .setForceLowestBitrate(false)
                     .setForceHighestSupportedBitrate(currentForceHighestBitrate)
            4    -> b.clearVideoSizeConstraints()
                     .setForceHighestSupportedBitrate(false)
                     .setForceLowestBitrate(true)
            else -> if (currentVideoWidth > 0 && currentVideoHeight > 0) {
                b.setMaxVideoSize(currentVideoWidth, currentVideoHeight)
                 .setForceLowestBitrate(false)
                 .setForceHighestSupportedBitrate(currentForceHighestBitrate)
            } else {
                b.clearVideoSizeConstraints()
                 .setForceLowestBitrate(false)
                 .setForceHighestSupportedBitrate(currentForceHighestBitrate)
            }
        }

        // Language preferences
        (s["preferredAudioLanguages"] as? List<*>)?.let { langs ->
            b.setPreferredAudioLanguages(*langs.mapNotNull { it as? String }.toTypedArray())
        }
        (s["preferredTextLanguages"] as? List<*>)?.let { langs ->
            b.setPreferredTextLanguages(*langs.mapNotNull { it as? String }.toTypedArray())
        }

        // Subtitles — use declarative setTrackTypeDisabled so it works before media is loaded
        val subtitlesEnabled = s["forcedAutoEnable"] as? Boolean ?: true
        if (subtitlesEnabled) {
            b.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
            b.setPreferredTextRoleFlags(C.ROLE_FLAG_MAIN or C.ROLE_FLAG_SUBTITLE)
        } else {
            b.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
        }

        getTrackSelector().parameters = b.build()
    }

    /**
     * Selects the best URL from [resolutionsMap] based on the current quality index.
     *
     * - Index 0 → highest quality
     * - Index 4 → lowest quality
     * - Otherwise → closest match to [currentVideoHeight]
     *
     * @param resolutionsMap Map of URL → quality label.
     * @param defaultUrl     Fallback URL if no match is found.
     */
    fun selectUrlByQuality(resolutionsMap: Map<String, String>, defaultUrl: String): String {
        if (resolutionsMap.isEmpty()) return defaultUrl
        return when (currentVideoQualityIndex) {
            0    -> resolutionsMap.entries
                        .sortedByDescending { metadataParser.parseQuality(it.value, it.key) }
                        .firstOrNull()?.key ?: defaultUrl
            4    -> resolutionsMap.entries
                        .sortedBy { metadataParser.parseQuality(it.value, it.key) }
                        .firstOrNull()?.key ?: defaultUrl
            else -> if (currentVideoHeight > 0) {
                val sorted = resolutionsMap.entries
                    .map { metadataParser.parseQuality(it.value, it.key) to it.key }
                    .sortedBy { it.first }
                sorted.firstOrNull { it.first >= currentVideoHeight }?.second
                    ?: sorted.lastOrNull()?.second
                    ?: defaultUrl
            } else defaultUrl
        }
    }
}
