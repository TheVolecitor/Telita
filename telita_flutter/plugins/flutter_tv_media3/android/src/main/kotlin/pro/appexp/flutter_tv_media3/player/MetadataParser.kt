package pro.appexp.flutter_tv_media3.player

import androidx.media3.common.Metadata
import androidx.media3.common.Player
import androidx.media3.extractor.metadata.icy.IcyInfo
import androidx.media3.extractor.metadata.id3.TextInformationFrame
import androidx.media3.common.util.UnstableApi

/**
 * Responsible for reading and parsing metadata of the current media item.
 *
 * Stateless — all methods accept player or metadata as parameters.
 */
@UnstableApi
class MetadataParser {

    /**
     * Returns a Map with metadata of the current MediaItem (title, artist, artwork, etc.).
     */
    fun getCurrentMetadata(player: Player): Map<String, Any?> {
        val metadataMap = mutableMapOf<String, Any?>()
        if (player.currentMediaItem == null) return metadataMap

        player.currentMediaItem?.let { mediaItem ->
            val metadata = mediaItem.mediaMetadata
            metadataMap["title"]       = metadata.title?.toString()
            metadataMap["artist"]      = metadata.artist?.toString()
            metadataMap["albumTitle"]  = metadata.albumTitle?.toString()
            metadataMap["albumArtist"] = metadata.albumArtist?.toString()
            metadataMap["genre"]       = metadata.genre?.toString()
            metadataMap["year"]        = metadata.recordingYear
            metadataMap["trackNumber"] = metadata.trackNumber
            metadataMap["artworkUri"]  = metadata.artworkUri?.toString()
            metadataMap["artworkData"] = metadata.artworkData
        }
        return metadataMap
    }

    /**
     * Parses streaming metadata (ICY, ID3) and returns a Map with the extracted data.
     * Returns an empty Map if no useful data is found.
     */
    fun parseStreamingMetadata(metadata: Metadata): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>()
        for (i in 0 until metadata.length()) {
            when (val entry = metadata[i]) {
                is IcyInfo -> {
                    entry.title?.let { result["icyTitle"] = it }
                    entry.url?.let { result["icyUrl"] = it }
                }
                is TextInformationFrame -> {
                    result["id3_${entry.id}"] = entry.value
                }
            }
        }
        return result
    }

    /**
     * Parses a video quality string (e.g. "1080p", "4K", "HD") into a numeric height value.
     * Used for sorting and comparing quality levels.
     *
     * @param sources One or more strings to search (label, url, etc.)
     * @return Numeric height in pixels, or 0 if unrecognized
     */
    fun parseQuality(vararg sources: String): Int {
        val kRegex = "(\\d)[Kk]".toRegex()
        val pRegex = "(\\d{3,4})p?".toRegex()

        for (source in sources) {
            val lower = source.lowercase().replace(" ", "")

            if (lower.contains("fullhd") || lower.contains("fhd")) return 1080
            if (lower.contains("uhd"))                              return 2160
            if (lower.matches(Regex(".*\\bhd\\b.*")) || lower.contains("hd")) return 720
            if (lower.contains("sd"))                               return 480

            kRegex.find(lower)?.let { match ->
                return when (match.groupValues[1].toIntOrNull()) {
                    8    -> 4320
                    4    -> 2160
                    2    -> 1440
                    else -> 0
                }
            }

            pRegex.find(lower)?.let { match ->
                val q = match.groupValues[1].toIntOrNull() ?: 0
                if (q in listOf(240, 360, 480, 720, 1080, 1440, 2160, 4320)) return q
            }
        }
        return 0
    }
}
