package pro.appexp.flutter_tv_media3.player

import android.content.Context
import android.content.Intent
import androidx.media3.common.AudioAttributes
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector

/**
 * The result of [ExoPlayerFactory.create].
 *
 * @param player        The fully configured [ExoPlayer] instance.
 * @param trackSelector The [DefaultTrackSelector] attached to the player.
 */
data class ExoPlayerResult(
    val player: ExoPlayer,
    val trackSelector: DefaultTrackSelector
)

/**
 * Factory responsible for creating and configuring an [ExoPlayer] instance.
 *
 * Reads timeout overrides from the launching [Intent] so that the host app
 * can tune stuck-detection thresholds without changing native code.
 *
 * @param context Application or Activity context.
 * @param intent  The Intent that started the Activity (used to read timeout extras).
 */
@UnstableApi
class ExoPlayerFactory(
    private val context: Context,
    private val intent: Intent
) {

    /**
     * Creates a fully configured [ExoPlayer] with [DefaultTrackSelector].
     *
     * Configuration includes:
     * - Preferred audio MIME types (lossless first)
     * - Enlarged buffer sizes for smoother streaming
     * - Extension renderer mode (prefers hardware decoders from extensions)
     * - Decoder fallback enabled
     * - Exact seek parameters
     * - Stuck player detection timeouts (overridable via Intent extras)
     */
    fun create(): ExoPlayerResult {
        val trackSelector = buildTrackSelector()
        val loadControl   = buildLoadControl()
        val renderersFactory = buildRenderersFactory()

        val player = ExoPlayer.Builder(context)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .setAudioAttributes(AudioAttributes.DEFAULT, true)
            .setHandleAudioBecomingNoisy(true)
            .setSeekParameters(SeekParameters.EXACT)
            .setRenderersFactory(renderersFactory)
            .setStuckBufferingDetectionTimeoutMs(
                intent.getIntExtra("stuck_buffering_detection_timeout_ms", 240_000)
            )
            .setStuckPlayingDetectionTimeoutMs(
                intent.getIntExtra("stuck_playing_detection_timeout_ms", 120_000)
            )
            .setStuckPlayingNotEndingTimeoutMs(
                intent.getIntExtra("stuck_playing_not_ending_timeout_ms", 180_000)
            )
            .setStuckSuppressedDetectionTimeoutMs(
                intent.getIntExtra("stuck_suppressed_detection_timeout_ms", 480_000)
            )
            .build()

        return ExoPlayerResult(player, trackSelector)
    }

    // ─── Private builders ─────────────────────────────────────────────────────

    private fun buildTrackSelector() = DefaultTrackSelector(context).apply {
        parameters = buildUponParameters()
            .setPreferredAudioMimeTypes(
                "audio/true-hd",
                "audio/vnd.dts.hd",
                "audio/eac3",
                "audio/vnd.dts",
                "audio/ac3",
                "audio/opus",
                "audio/mp4a-latm",
                "audio/mpeg"
            )
            .setAllowMultipleAdaptiveSelections(true)
            .build()
    }

    private fun buildLoadControl() = DefaultLoadControl.Builder()
        .setBufferDurationsMs(
            DefaultLoadControl.DEFAULT_MIN_BUFFER_MS * 4,
            DefaultLoadControl.DEFAULT_MAX_BUFFER_MS * 4,
            DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS * 4,
            DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS * 4
        )
        .setTargetBufferBytes(DefaultLoadControl.DEFAULT_TARGET_BUFFER_BYTES * 2)
        .setPrioritizeTimeOverSizeThresholds(true)
        .build()

    private fun buildRenderersFactory() = DefaultRenderersFactory(context)
        .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
        .setEnableDecoderFallback(true)
        .setMediaCodecSelector(object : androidx.media3.exoplayer.mediacodec.MediaCodecSelector {
            override fun getDecoderInfos(
                mimeType: String,
                requiresSecureDecoder: Boolean,
                requiresTunnelingDecoder: Boolean
            ): MutableList<androidx.media3.exoplayer.mediacodec.MediaCodecInfo> {
                val decoders = androidx.media3.exoplayer.mediacodec.MediaCodecUtil.getDecoderInfos(
                    mimeType, requiresSecureDecoder, requiresTunnelingDecoder
                ).toMutableList()
                
                if (mimeType == androidx.media3.common.MimeTypes.VIDEO_DOLBY_VISION) {
                    decoders.addAll(
                        androidx.media3.exoplayer.mediacodec.MediaCodecUtil.getDecoderInfos(
                            androidx.media3.common.MimeTypes.VIDEO_H265, requiresSecureDecoder, requiresTunnelingDecoder
                        )
                    )
                }
                return decoders
            }
        })
}
