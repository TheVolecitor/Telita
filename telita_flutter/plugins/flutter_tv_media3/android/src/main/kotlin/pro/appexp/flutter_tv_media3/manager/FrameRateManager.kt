package pro.appexp.flutter_tv_media3.manager

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import android.view.Surface
import android.view.SurfaceView
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.ui.PlayerView
import kotlin.math.abs
import kotlin.math.round

/**
 * Manages automatic frame rate (AFR) switching for an Android TV device.
 * This version includes fixes for race conditions by waiting for playback to start
 * before measuring frame rate.
 */
class FrameRateManager(
    private val activity: AppCompatActivity,
    private val player: ExoPlayer,
    private val playerView: PlayerView
) : AnalyticsListener {

    private val logTag = "FrameRateManager"
    private val handler = Handler(Looper.getMainLooper())
    private var isMeasurementRunning = false
    private var measurementRunnable: Runnable? = null
    private var isReleased = false
    private var isMeasurementPending = false

    init {
        player.addAnalyticsListener(this)
    }

    //region Lifecycle and Event Listeners

    override fun onVideoSizeChanged(eventTime: AnalyticsListener.EventTime, videoSize: VideoSize) {
        if (isReleased) return
        Log.d(logTag, "AFR: Video available (size: ${videoSize.width}x${videoSize.height}). Determining optimal frame rate.")
        determineBestFrameRate()
    }

    override fun onIsPlayingChanged(eventTime: AnalyticsListener.EventTime, isPlaying: Boolean) {
        if (isReleased) return
        Log.d(logTag, "AFR: isPlaying state changed to: $isPlaying")

        // If playback starts and a measurement was pending, start it now.
        if (isPlaying && isMeasurementPending) {
            Log.i(logTag, "AFR: Playback has started and measurement is pending. Starting real-time measurement now.")
            measureFrameRate()
        }
    }

    override fun onTracksChanged(eventTime: AnalyticsListener.EventTime, tracks: Tracks) {
        if (isReleased) return
        Log.d(logTag, "AFR: Tracks changed. Re-evaluating frame rate.")
        // Re-check frame rate as the video track might have changed.
        determineBestFrameRate()
    }

    fun release() {
        Log.d(logTag, "AFR: Releasing resources and resetting frame rate.")
        isReleased = true
        isMeasurementPending = false

        try {
            player.removeAnalyticsListener(this)
        } catch (e: Exception) {
            Log.w(logTag, "Error removing analytics listener", e)
        }

        measurementRunnable?.let { handler.removeCallbacks(it) }
        handler.removeCallbacksAndMessages(null)
        isMeasurementRunning = false

        resetFrameRate()
    }

    //endregion

    //region Frame Rate Determination Logic

    private fun determineBestFrameRate() {
        if (isReleased) return

        val frameRateFromMeta = getFrameRateFromTracks()

        if (isValidFrameRate(frameRateFromMeta)) {
            Log.d(logTag, "AFR: Found frame rate in track metadata: $frameRateFromMeta Hz.")
            isMeasurementPending = false // Measurement is not needed
            setFrameRate(frameRateFromMeta)
        } else {
            Log.w(logTag, "AFR: Frame rate not in metadata. Measurement will start when playback begins.")
            isMeasurementPending = true
            // If player is already playing (e.g. on quality change), start measurement immediately.
            if (player.isPlaying) {
                Log.d(logTag, "AFR: Player is already playing, starting measurement immediately.")
                measureFrameRate()
            }
        }
    }

    private fun getFrameRateFromTracks(): Float {
        return try {
            val selectedFormat = player.currentTracks.groups
                .firstOrNull { it.type == C.TRACK_TYPE_VIDEO && it.isSelected }
                ?.let { group ->
                    (0 until group.length)
                        .firstOrNull { group.isTrackSelected(it) }
                        ?.let { group.getTrackFormat(it) }
                }
            selectedFormat?.frameRate ?: Format.NO_VALUE.toFloat()
        } catch (e: Exception) {
            Log.w(logTag, "Error getting frame rate from tracks", e)
            Format.NO_VALUE.toFloat()
        }
    }

    private fun measureFrameRate() {
        // We are now attempting the measurement, so reset the pending flag.
        isMeasurementPending = false

        Log.i(logTag, "AFR_MEASURE: Attempting to start frame rate measurement.")

        if (isMeasurementRunning) {
            Log.d(logTag, "AFR_MEASURE: Aborting. Measurement is already in progress.")
            return
        }
        if (isReleased) {
            Log.d(logTag, "AFR_MEASURE: Aborting. FrameRateManager is released.")
            return
        }
        if (!isPlayerReadyForMeasurement()) {
            Log.w(logTag, "AFR_MEASURE: Aborting. Player is not ready for measurement.")
            return
        }

        isMeasurementRunning = true

        val initialCounters = try {
            Log.v(logTag, "AFR_MEASURE: Accessing initial video decoder counters.")
            player.videoDecoderCounters
        } catch (e: Exception) {
            Log.e(logTag, "AFR_MEASURE: CRITICAL: Error accessing initial video decoder counters", e)
            isMeasurementRunning = false
            return
        }

        if (initialCounters == null) {
            Log.w(logTag, "AFR_MEASURE: Initial video decoder counters are null. Cannot proceed.")
            isMeasurementRunning = false
            return
        }

        val initialRenderedFrames = initialCounters.renderedOutputBufferCount
        val startTimeMs = System.currentTimeMillis()
        Log.d(logTag, "AFR_MEASURE: Initial state: Rendered frames=$initialRenderedFrames, Start time=$startTimeMs")

        measurementRunnable = Runnable {
            Log.i(logTag, "AFR_MEASURE: Runnable started to perform final measurement.")
            if (isReleased) {
                Log.w(logTag, "AFR_MEASURE: Aborting runnable. FrameRateManager was released.")
                return@Runnable
            }

            try {
                val finalCounters = player.videoDecoderCounters
                isMeasurementRunning = false
                measurementRunnable = null

                if (finalCounters == null) {
                    Log.w(logTag, "AFR_MEASURE: Final decoder counters became null. Measurement failed.")
                    return@Runnable
                }

                val finalRenderedFrames = finalCounters.renderedOutputBufferCount
                val renderedFrames = finalRenderedFrames - initialRenderedFrames
                val timeElapsedSeconds = (System.currentTimeMillis() - startTimeMs) / 1000.0

                Log.d(logTag, "AFR_MEASURE: Final state: Final frames=$finalRenderedFrames")
                Log.d(logTag, "AFR_MEASURE: Calculation: Rendered=$renderedFrames, Time=%.2fs".format(timeElapsedSeconds))

                if (timeElapsedSeconds > 2 && renderedFrames > 20) {
                    val measuredFps = renderedFrames / timeElapsedSeconds
                    val standardFps = findClosestStandardFrameRate(measuredFps.toFloat())

                    Log.i(logTag, "AFR_MEASURE: SUCCESS. Measured FPS: %.2f. Snapped to: %.3f Hz".format(measuredFps, standardFps))
                    setFrameRate(standardFps)
                } else {
                    Log.w(logTag, "AFR_MEASURE: Measurement inconclusive (frames=$renderedFrames, time=%.2fs)".format(timeElapsedSeconds))
                }
            } catch (e: Exception) {
                Log.e(logTag, "AFR_MEASURE: CRITICAL: Error during runnable execution", e)
                isMeasurementRunning = false
                measurementRunnable = null
            }
        }

        Log.d(logTag, "AFR_MEASURE: Scheduling measurement runnable in 4000ms.")
        handler.postDelayed(measurementRunnable!!, 4000)
    }

    private fun isPlayerReadyForMeasurement(): Boolean {
        Log.d(logTag, "AFR_MEASURE: Checking player readiness for measurement...")
        return try {
            val isPlaying = player.isPlaying
            val playbackState = player.playbackState
            val hasCounters = player.videoDecoderCounters != null

            Log.d(logTag, "AFR_MEASURE: Player state: isPlaying=$isPlaying, playbackState=$playbackState, hasCounters=$hasCounters")

            if (!isPlaying) {
                Log.d(logTag, "AFR_MEASURE: Readiness check failed: Player is not playing.")
                return false
            }
            if (playbackState != Player.STATE_READY) {
                Log.d(logTag, "AFR_MEASURE: Readiness check failed: Not in STATE_READY (state: $playbackState).")
                return false
            }
            if (!hasCounters) {
                Log.d(logTag, "AFR_MEASURE: Readiness check failed: Decoder counters not available.")
                return false
            }

            Log.i(logTag, "AFR_MEASURE: Player is ready for measurement.")
            true
        } catch (e: Exception) {
            Log.w(logTag, "AFR_MEASURE: Error during player readiness check", e)
            false
        }
    }

    //endregion

    //region Display and Surface Control

    private fun setFrameRate(frameRate: Float) {
        if (isReleased) return

        activity.runOnUiThread {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setSurfaceFrameRate(frameRate)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    setDisplayMode(frameRate)
                }
            } catch (e: Exception) {
                Log.e(logTag, "AFR: Error setting frame rate", e)
            }
        }
    }

    private fun setSurfaceFrameRate(frameRate: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val surfaceView = playerView.videoSurfaceView
            if (surfaceView is SurfaceView) {
                val surface = surfaceView.holder.surface
                if (surface?.isValid == true) {
                    Log.d(logTag, "AFR: Setting Surface frame rate to $frameRate Hz (API 30+)")
                    surface.setFrameRate(frameRate, Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE)
                } else {
                    Log.w(logTag, "Surface is not valid for frame rate setting")
                }
            } else {
                Log.w(logTag, "VideoSurfaceView is not a SurfaceView")
            }
        }
    }

    private fun setDisplayMode(frameRate: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val display = getDisplay() ?: run {
                Log.w(logTag, "Display not available for mode switching")
                return
            }

            val bestMode = findBestDisplayMode(display, frameRate)

            if (bestMode != null && bestMode.modeId != display.mode.modeId) {
                Log.d(logTag, "AFR: Switching display mode to ${bestMode.refreshRate} Hz (Mode ID: ${bestMode.modeId})")
                activity.window.apply {
                    attributes = attributes.apply {
                        preferredDisplayModeId = bestMode.modeId
                    }
                }
            } else {
                Log.d(logTag, "No better display mode found for $frameRate Hz or already in best mode.")
            }
        }
    }

    private fun resetFrameRate() {
        activity.runOnUiThread {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    (playerView.videoSurfaceView as? SurfaceView)?.holder?.surface?.let {
                        if (it.isValid) {
                            Log.d(logTag, "AFR: Resetting Surface frame rate to default.")
                            it.setFrameRate(0f, Surface.FRAME_RATE_COMPATIBILITY_DEFAULT)
                        }
                    }
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    activity.window.attributes.let { params ->
                        if (params.preferredDisplayModeId != 0) {
                            Log.d(logTag, "AFR: Resetting preferred display mode to default.")
                            params.preferredDisplayModeId = 0
                            activity.window.attributes = params
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(logTag, "AFR: Error resetting frame rate", e)
            }
        }
    }

    //endregion

    //region Helper and Utility Functions

    private fun isValidFrameRate(frameRate: Float): Boolean {
        return frameRate > 0f && frameRate != Format.NO_VALUE.toFloat() && frameRate.isFinite()
    }

    private fun findClosestStandardFrameRate(measuredFps: Float): Float {
        val standardRates = listOf(23.976f, 24f, 25f, 29.97f, 30f, 50f, 59.94f, 60f, 120f)
        return standardRates.minByOrNull { abs(it - measuredFps) } ?: measuredFps
    }

    private fun getDisplay(): Display? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                activity.display
            } else {
                @Suppress("DEPRECATION")
                activity.windowManager.defaultDisplay
            }
        } catch (e: Exception) {
            Log.e(logTag, "Error getting display", e)
            null
        }
    }

    private fun findBestDisplayMode(display: Display, videoFrameRate: Float): Display.Mode? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null

        return try {
            val supportedModes = display.supportedModes
            val tolerance = 0.1f // Tolerance for comparing frequencies

            // For debugging: output all supported modes
            val supportedRatesString = supportedModes.joinToString(", ") { "%.2fHz".format(it.refreshRate) }
            Log.d(logTag, "AFR: Searching for the best mode for %.3f Hz. Supported TV modes: [%s]".format(videoFrameRate, supportedRatesString))

            // --- Start checking by priority ---

            // Priority 1: Ideal or near-ideal match
            val exactMatch = supportedModes.firstOrNull { abs(it.refreshRate - videoFrameRate) < tolerance }
            if (exactMatch != null) {
                Log.d(logTag, "AFR: Priority 1: Found an ideal match: ${exactMatch.refreshRate} Hz")
                return exactMatch
            }

            // Priority 2: Special handling for 23.976 Hz video
            if (abs(videoFrameRate - 23.976f) < tolerance) {
                // 2a: Look for the standard 59.94 Hz mode (3:2 pulldown)
                val pulldownMatch = supportedModes.firstOrNull { abs(it.refreshRate - 59.94f) < tolerance }
                if (pulldownMatch != null) {
                    Log.d(logTag, "AFR: Priority 2a: Found 59.94 Hz mode for 23.976 Hz video.")
                    return pulldownMatch
                }

                // 2b: (YOUR CONDITION) If not found, look for 24.000 Hz as a fallback
                val fallback24hzMatch = supportedModes.firstOrNull { abs(it.refreshRate - 24.0f) < tolerance }
                if (fallback24hzMatch != null) {
                    Log.i(logTag, "AFR: Priority 2b: Using 24.000 Hz mode as a fallback for 23.976 Hz video.")
                    return fallback24hzMatch
                }
            }

            // Priority 3: Multiple modes (e.g. 25 Hz -> 50 Hz, 30 Hz -> 60 Hz, 24 Hz -> 120 Hz)
            val multipleMatches = supportedModes.filter {
                // Check if the refresh rate is a multiple of the frame rate
                it.refreshRate > videoFrameRate && abs(it.refreshRate / videoFrameRate - round(it.refreshRate / videoFrameRate)) < tolerance
            }
            if (multipleMatches.isNotEmpty()) {
                // Choose the lowest of the multiple modes (e.g. 60 Hz is better than 120 Hz for 30 Hz video)
                val bestMultiple = multipleMatches.minByOrNull { it.refreshRate }!!
                Log.d(logTag, "AFR: Priority 3: Found the best multiple mode: ${bestMultiple.refreshRate} Hz")
                return bestMultiple
            }

            Log.w(logTag, "AFR: No compatible mode found after checking all priorities.")
            null

        } catch (e: Exception) {
            Log.e(logTag, "Error finding best display mode", e)
            null
        }
    }

    private fun isRefreshRateCompatible(refreshRate: Float, frameRate: Float): Boolean {
        // A refresh rate is compatible if it's a multiple of the frame rate.
        val tolerance = 0.1f // Increased tolerance for minor variations

        // Direct multiple check (e.g., 60Hz for 30fps, 50Hz for 25fps)
        if (refreshRate > frameRate - tolerance) {
            val ratio = refreshRate / frameRate
            if (abs(ratio - round(ratio)) < tolerance) {
                return true
            }
        }

        // Common pulldown scenarios (e.g., 23.976fps on a 59.94Hz display)
        if (abs(frameRate - 23.976f) < tolerance && abs(refreshRate - 59.94f) < tolerance) {
            return true
        }

        return false
    }

    //endregion

    //region Public API

    fun getRefreshRateInfo(): Map<String, Any> {
        return try {
            val display = getDisplay() ?: return mapOf("supportedRates" to listOf(60f), "activeRate" to 60f)

            val supportedRates = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                display.supportedModes.map { it.refreshRate }.distinct().sorted()
            } else {
                listOf(display.refreshRate)
            }
            Log.d(logTag, "AFR_INFO: Current display info: ${supportedRates} current : ${display.refreshRate}")
            mapOf(
                "supportedRates" to supportedRates,
                "activeRate" to display.refreshRate
            )
        } catch (e: Exception) {
            Log.e(logTag, "Error getting refresh rate info", e)
            mapOf("supportedRates" to listOf(60f), "activeRate" to 60f)
        }
    }

    fun setManualRefreshRate(frameRate: Float) {
        if (isValidFrameRate(frameRate)) {
            Log.d(logTag, "Manual frame rate setting requested: $frameRate Hz")
            isMeasurementPending = false // Manual override cancels any pending measurement
            setFrameRate(frameRate)
        } else {
            Log.w(logTag, "Invalid frame rate for manual setting: $frameRate")
        }
    }

    fun onPossibleFrameRateChange() {
        if (isReleased) return

        Log.d(logTag, "Possible frame rate change detected, re-evaluating...")
        determineBestFrameRate()
    }

    //endregion
}