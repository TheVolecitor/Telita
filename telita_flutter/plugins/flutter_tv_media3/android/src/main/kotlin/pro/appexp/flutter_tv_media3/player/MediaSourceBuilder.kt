package pro.appexp.flutter_tv_media3.player

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.MergingMediaSource
import androidx.media3.extractor.DefaultExtractorsFactory

private const val TAG = "MediaSourceBuilder"
private const val CONNECT_TIMEOUT_MS = 20_000
private const val READ_TIMEOUT_MS    = 20_000

private val DEFAULT_USER_AGENT =
    "FTVMedia3/1.0 (Android ${android.os.Build.VERSION.RELEASE}) " +
    "ExoPlayerLib/${androidx.media3.common.MediaLibraryInfo.VERSION}"

/**
 * Responsible for creating MediaSource instances for ExoPlayer.
 *
 * Supports:
 * - HTTP/HTTPS video with custom headers and User-Agent
 * - External subtitles (srt, vtt, ttml, etc.)
 * - External audio tracks (mp3, aac, ogg, etc.)
 * - Merging video + audio via MergingMediaSource
 */
@UnstableApi
class MediaSourceBuilder(private val context: Context) {

    private val extractorsFactory = DefaultExtractorsFactory()
        .setConstantBitrateSeekingEnabled(true)

    /**
     * Creates a (HttpFactory, DataSourceFactory) pair with the given headers and user-agent.
     */
    fun createDataSourceFactory(
        headers: Map<String, String>?,
        userAgent: String?
    ): Pair<DefaultHttpDataSource.Factory, DefaultDataSource.Factory> {
        val headersMap = headers?.toMutableMap() ?: mutableMapOf()

        val uaKey = headersMap.keys.find { it.equals("user-agent", ignoreCase = true) }
        val userAgentFromHeaders = uaKey?.let { headersMap[it] }
        val finalUserAgent = userAgent ?: userAgentFromHeaders ?: DEFAULT_USER_AGENT

        if (uaKey != null) headersMap.remove(uaKey)

        val httpFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setUserAgent(finalUserAgent)
            .setConnectTimeoutMs(CONNECT_TIMEOUT_MS)
            .setReadTimeoutMs(READ_TIMEOUT_MS)
            .setDefaultRequestProperties(headersMap)

        val dataFactory = DefaultDataSource.Factory(context, httpFactory)
        return Pair(httpFactory, dataFactory)
    }

    /**
     * Creates the final MediaSource: video + subtitles + optional external audio tracks.
     *
     * @param videoUrl          URL of the video.
     * @param videoMimeType     Optional MIME type of the video.
     * @param subtitleTracks    List of external subtitle tracks.
     * @param audioTracks       List of external audio tracks.
     * @param dataSourceFactory Data source factory to use.
     */
    fun createCombinedMediaSource(
        videoUrl: String,
        videoMimeType: String?,
        subtitleTracks: List<Map<String, Any>>?,
        audioTracks: List<Map<String, Any>>?,
        dataSourceFactory: DefaultDataSource.Factory
    ): MediaSource {
        val mediaSourceFactory = DefaultMediaSourceFactory(dataSourceFactory, extractorsFactory)

        // Subtitles
        val subtitleConfigs = subtitleTracks?.mapNotNull { track ->
            val url      = track["url"] as? String ?: return@mapNotNull null
            val language = track["language"] as? String
            val label    = track["label"] as? String
            val mimeType = (track["mimeType"] as? String)?.takeIf { it.isNotBlank() }
                ?: getMimeTypeFromUrl(url, isSubtitle = true)

            MediaItem.SubtitleConfiguration.Builder(Uri.parse(url))
                .setMimeType(mimeType)
                .setLanguage(language)
                .setLabel(label)
                .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                .setId(url)
                .build()
        } ?: emptyList()

        // Video MediaItem
        val mediaItemBuilder = MediaItem.Builder()
            .setUri(Uri.parse(videoUrl))
            .setSubtitleConfigurations(subtitleConfigs)

        videoMimeType?.takeIf { it.isNotBlank() }?.let { mediaItemBuilder.setMimeType(it) }

        val videoSource = mediaSourceFactory.createMediaSource(mediaItemBuilder.build())

        // External audio tracks
        val audioSources = audioTracks?.mapNotNull { track ->
            val url      = track["url"] as? String ?: return@mapNotNull null
            val mimeType = (track["mimeType"] as? String)?.takeIf { it.isNotBlank() }
                ?: getMimeTypeFromUrl(url, isSubtitle = false)

            val audioItem = MediaItem.Builder()
                .setUri(Uri.parse(url))
                .setMimeType(mimeType)
                .build()

            mediaSourceFactory.createMediaSource(audioItem)
        } ?: emptyList()

        return if (audioSources.isNotEmpty()) {
            MergingMediaSource(videoSource, *audioSources.toTypedArray())
        } else {
            videoSource
        }
    }

    /**
     * Determines the MIME type from the file extension in the URL.
     */
    fun getMimeTypeFromUrl(url: String, isSubtitle: Boolean): String {
        val ext = url.substringBefore("?").substringAfterLast(".", "").lowercase()
        return when (ext) {
            // Subtitles
            "srt"          -> MimeTypes.APPLICATION_SUBRIP
            "vtt", "webvtt"-> MimeTypes.TEXT_VTT
            "ttml", "xml",
            "dfxp"         -> MimeTypes.APPLICATION_TTML
            "scc"          -> MimeTypes.APPLICATION_CEA608
            "cap"          -> MimeTypes.APPLICATION_CEA708
            "dvb"          -> MimeTypes.APPLICATION_DVBSUBS
            "3gpp", "3gp"  -> MimeTypes.APPLICATION_TX3G
            "m4vtt"        -> MimeTypes.APPLICATION_MP4VTT
            // Audio
            "mp3"          -> MimeTypes.AUDIO_MPEG
            "aac"          -> MimeTypes.AUDIO_AAC
            "m4a"          -> MimeTypes.AUDIO_MP4
            "ogg", "oga"   -> MimeTypes.AUDIO_OGG
            "wav"          -> MimeTypes.AUDIO_WAV
            "flac"         -> MimeTypes.AUDIO_FLAC
            "amr"          -> MimeTypes.AUDIO_AMR_NB
            "awb"          -> MimeTypes.AUDIO_AMR_WB
            "pcm"          -> MimeTypes.AUDIO_RAW
            "ac3"          -> MimeTypes.AUDIO_AC3
            "eac3"         -> MimeTypes.AUDIO_E_AC3
            "ac4"          -> MimeTypes.AUDIO_AC4
            "dts"          -> MimeTypes.AUDIO_DTS
            "dtshd"        -> MimeTypes.AUDIO_DTS_HD
            "opus"         -> MimeTypes.AUDIO_OPUS
            "truehd"       -> MimeTypes.AUDIO_TRUEHD
            else -> {
                Log.w(TAG, "Unknown extension '$ext' for url: $url")
                if (isSubtitle) MimeTypes.APPLICATION_SUBRIP else MimeTypes.AUDIO_AAC
            }
        }
    }
}
