package pro.appexp.flutter_tv_media3.manager.subtitle

import android.graphics.Color
import android.graphics.Typeface
import androidx.media3.common.util.UnstableApi
import androidx.media3.ui.CaptionStyleCompat
import androidx.media3.ui.PlayerView
import androidx.media3.ui.SubtitleView

/**
 * Responsible for applying and managing subtitle styles.
 *
 * @param playerView The PlayerView to apply styles to.
 * @param onUiThread Lambda for running code on the UI thread (pass activity.runOnUiThread).
 */
@UnstableApi
class SubtitleStyleManager(
    private val playerView: PlayerView,
    private val onUiThread: (() -> Unit) -> Unit
) {

    companion object {
        val DEFAULT_STYLE: Map<String, Any> = mapOf(
            "applyEmbeddedStyles" to true,
            "foregroundColor"     to "#FFFFFFFF",
            "backgroundColor"     to "#00000000",
            "windowColor"         to "#00000000",
            "edgeType"            to CaptionStyleCompat.EDGE_TYPE_DROP_SHADOW,
            "edgeColor"           to "#FF000000",
            "textSizeFraction"    to 1.0
        )
    }

    /**
     * Applies the given style to the SubtitleView.
     * Missing keys fall back to default values.
     *
     * @param newStyleSettings Style map from Flutter (may be null).
     * @return The final applied style (merge of defaults + provided settings).
     */
    fun applySubtitleStyle(newStyleSettings: Map<String, Any>?): Map<String, Any> {
        val finalStyle = DEFAULT_STYLE + (newStyleSettings ?: emptyMap())
        val subtitleView = playerView.subtitleView ?: return DEFAULT_STYLE

        onUiThread {
            subtitleView.apply {
                setApplyEmbeddedStyles(finalStyle["applyEmbeddedStyles"] as Boolean)

                val sizeMultiplier = (finalStyle["textSizeFraction"] as Double).toFloat()
                setFractionalTextSize(SubtitleView.DEFAULT_TEXT_SIZE_FRACTION * sizeMultiplier)

                val style = CaptionStyleCompat(
                    Color.parseColor(finalStyle["foregroundColor"] as String),
                    Color.parseColor(finalStyle["windowColor"] as String),
                    Color.parseColor(finalStyle["backgroundColor"] as String),
                    finalStyle["edgeType"] as Int,
                    Color.parseColor(finalStyle["edgeColor"] as String),
                    Typeface.DEFAULT
                )
                setStyle(style)
            }

            val top    = (finalStyle["topPadding"]    as? Number)?.toInt() ?: 0
            val bottom = (finalStyle["bottomPadding"] as? Number)?.toInt() ?: 0
            val left   = (finalStyle["leftPadding"]   as? Number)?.toInt() ?: 0
            val right  = (finalStyle["rightPadding"]  as? Number)?.toInt() ?: 0

            subtitleView.setPadding(left, top, right, bottom)
        }

        return finalStyle
    }
}
