package pro.appexp.flutter_tv_media3.utils

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.inspector.FrameExtractor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

/**
 * Utility class for media-related operations like thumbnail extraction.
 */
@UnstableApi
object MediaUtils {
    private const val TAG = "MediaUtils"

    /**
     * Extracts a thumbnail or a specific frame from a media URI.
     *
     * @param context The application context.
     * @param uri The URI of the media.
     * @param timeInSeconds The time position in seconds for the frame. If null or negative, a default thumbnail is used.
     * @return A byte array containing the PNG compressed image, or null on error.
     */
    suspend fun getThumbnail(
        context: Context,
        uri: String,
        timeInSeconds: Double?
    ): ByteArray? = withContext(Dispatchers.IO) {
        var extractor: FrameExtractor? = null
        try {
            val mediaItem = MediaItem.fromUri(uri)
            extractor = FrameExtractor.Builder(context, mediaItem).build()

            val frame = if (timeInSeconds != null && timeInSeconds >= 0) {
                // FrameExtractor.getFrame uses microseconds (Us)
                val timeUs = (timeInSeconds * 1_000).toLong()
                extractor.getFrame(timeUs).get()
            } else {
                extractor.getThumbnail().get()
            }

            val bitmap = frame.bitmap
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting thumbnail for $uri: ${e.message}", e)
            null
        } finally {
            extractor?.close()
        }
    }
}
