package pro.appexp.flutter_tv_media3.manager.audio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings

/**
 * Responsible for reading, changing, and observing system volume (STREAM_MUSIC).
 *
 * @param context        Activity context.
 * @param audioManager   System AudioManager instance.
 * @param onVolumeChanged Callback invoked when volume changes, receiving the current volume state.
 */
class VolumeManager(
    private val context: Context,
    private val audioManager: AudioManager,
    private val onVolumeChanged: (Map<String, Any>) -> Unit
) {

    private var volumeObserver: ContentObserver? = null
    private var lastSentVolumeState: Map<String, Any>? = null

    private val volumeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action
            if (action == "android.media.STREAM_MUTE_CHANGED_ACTION" ||
                action == "android.media.VOLUME_CHANGED_ACTION"
            ) {
                val streamType = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                if (streamType == AudioManager.STREAM_MUSIC) {
                    sendCurrentVolumeState()
                }
            }
        }
    }

    // ─── Registration / Unregistration ────────────────────────────────────────

    fun register() {
        if (volumeObserver == null) {
            volumeObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
                override fun onChange(selfChange: Boolean) {
                    super.onChange(selfChange)
                    sendCurrentVolumeState()
                }
            }
            context.contentResolver.registerContentObserver(
                Settings.System.CONTENT_URI,
                true,
                volumeObserver!!
            )
        }

        val filter = IntentFilter().apply {
            addAction("android.media.STREAM_MUTE_CHANGED_ACTION")
            addAction("android.media.VOLUME_CHANGED_ACTION")
        }
        context.registerReceiver(volumeReceiver, filter)
        sendCurrentVolumeState()
    }

    fun unregister() {
        volumeObserver?.let {
            context.contentResolver.unregisterContentObserver(it)
        }
        try {
            context.unregisterReceiver(volumeReceiver)
        } catch (_: IllegalArgumentException) {
            // Receiver was not registered — ignore
        }
    }

    // ─── State Reading ────────────────────────────────────────────────────────

    /**
     * Returns the current volume state as a Map for passing to Flutter.
     */
    fun getCurrentVolumeState(): Map<String, Any> {
        val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max     = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val isMuted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioManager.isStreamMute(AudioManager.STREAM_MUSIC)
        } else {
            current == 0
        }
        val volume = if (max > 0) current.toDouble() / max.toDouble() else 0.0

        return mapOf(
            "current" to current,
            "max"     to max,
            "isMute"  to isMuted,
            "volume"  to volume
        )
    }

    // ─── Volume Control ───────────────────────────────────────────────────────

    /**
     * Sets volume by a normalized value [0.0 – 1.0].
     */
    fun setVolume(normalizedVolume: Double) {
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val absolute = (normalizedVolume * max).toInt()
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, absolute, AudioManager.FLAG_SHOW_UI)
    }

    /**
     * Enables or disables mute.
     */
    fun setMute(mute: Boolean) {
        audioManager.adjustStreamVolume(
            AudioManager.STREAM_MUSIC,
            if (mute) AudioManager.ADJUST_MUTE else AudioManager.ADJUST_UNMUTE,
            0
        )
    }

    /**
     * Toggles mute and returns the new state (true = muted).
     * Only available on API 23+.
     *
     * @throws UnsupportedOperationException if API < 23
     */
    fun toggleMute(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            throw UnsupportedOperationException("Mute toggle is not supported on API < 23")
        }
        val isMuted = audioManager.isStreamMute(AudioManager.STREAM_MUSIC)
        audioManager.adjustStreamVolume(
            AudioManager.STREAM_MUSIC,
            if (isMuted) AudioManager.ADJUST_UNMUTE else AudioManager.ADJUST_MUTE,
            0
        )
        return !isMuted
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    private fun sendCurrentVolumeState() {
        val state = getCurrentVolumeState()
        if (state != lastSentVolumeState) {
            onVolumeChanged(state)
            lastSentVolumeState = state
        }
    }
}
