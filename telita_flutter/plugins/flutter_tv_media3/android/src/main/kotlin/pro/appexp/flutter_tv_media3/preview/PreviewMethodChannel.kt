package pro.appexp.flutter_tv_media3.preview

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper

/**
 * Handles [MethodCall]s from Flutter for the preview player functionality.
 *
 * This class is the bridge between Dart and the native [PreviewPlayerPool]. It implements
 * [MethodChannel.MethodCallHandler] to process commands like 'create', 'prepare', 'play', etc.
 * It also handles sending asynchronous events (like playback start or errors) back to
 * the Dart side via the same channel.
 *
 * @param context Android context.
 * @param messenger Binary messenger for creating the MethodChannel.
 * @param textureRegistry Registry for managing Flutter textures.
 */
class PreviewMethodChannel(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger,
    textureRegistry: io.flutter.view.TextureRegistry
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(
        messenger,
        "flutter_tv_media3/preview"
    )

    private val pool = PreviewPlayerPool(context, textureRegistry)
    private val players = mutableMapOf<Long, TexturePreviewPlayer>()

    /**
     * Lambda that handles events from [TexturePreviewPlayer] and forwards them to Flutter.
     *
     * It packages the event type and data into a map and invokes the 'onPlayerEvent'
     * method on the Dart [MethodChannel] using the main thread.
     */
    private val onEvent: (Long, String, Map<String, Any?>?) -> Unit = { id, event, data ->
        val args = mutableMapOf<String, Any?>(
            "textureId" to id,
            "event" to event
        )
        data?.let { args.putAll(it) }

        Handler(Looper.getMainLooper()).post {
            channel.invokeMethod("onPlayerEvent", args)
        }
    }

    init {
        channel.setMethodCallHandler(this)
    }

    /**
     * Disposes of the player pool and clears the method call handler.
     *
     * This method ensures all active players and those in the pool are properly released.
     */
    fun dispose() {
        channel.setMethodCallHandler(null)
        // Explicitly release all active players
        players.values.forEach { it.releaseResources() }
        players.clear()
        pool.dispose()
    }

    /**
     * Entry point for all [MethodCall]s from Dart.
     *
     * Supported methods:
     * - 'create': Acquires a new player from the pool. Returns textureId.
     * - 'prepare': Configures a player with a URL and options.
     * - 'play': Starts playback.
     * - 'pause': Pauses playback.
     * - 'seekTo': Seeks to a position.
     * - 'setVolume': Adjusts volume.
     * - 'setRepeatMode': Toggles looping.
     * - 'release': Returns a player to the pool.
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            "create" -> {
                val player = pool.acquire(onEvent)
                players[player.textureId] = player
                result.success(player.textureId)
            }

            "prepare" -> {
                val id = (call.argument<Any>("textureId") as? Number)?.toLong()!!
                val url = call.argument<String>("url")!!
                val width = (call.argument<Any>("width") as? Number)?.toInt() ?: 0
                val height = (call.argument<Any>("height") as? Number)?.toInt() ?: 0
                val volume = (call.argument<Any>("volume") as? Number)?.toFloat() ?: 0f
                val autoPlay = call.argument<Boolean>("autoPlay") ?: true
                val isRepeat = call.argument<Boolean>("isRepeat") ?: true
                val startTimeSeconds = (call.argument<Any>("startTimeSeconds") as? Number)?.toInt() ?: 0
                val endTimeSeconds = (call.argument<Any>("endTimeSeconds") as? Number)?.toInt() ?: 0
                val repeatMode = if (isRepeat) 1 else 0 // 1: REPEAT_MODE_ONE, 0: REPEAT_MODE_OFF
                players[id]?.prepare(url, width, height, volume, autoPlay, repeatMode, startTimeSeconds, endTimeSeconds)
                result.success(null)
            }

            "play" -> {
                val id = (call.argument<Any>("textureId") as? Number)?.toLong()!!
                players[id]?.play()
                result.success(null)
            }

            "pause" -> {
                val id = (call.argument<Any>("textureId") as? Number)?.toLong()!!
                players[id]?.pause()
                result.success(null)
            }

            "seekTo" -> {
                val id = (call.argument<Any>("textureId") as? Number)?.toLong()!!
                val positionMs = (call.argument<Any>("positionMs") as? Number)?.toLong() ?: 0L
                players[id]?.seekTo(positionMs)
                result.success(null)
            }

            "setVolume" -> {
                val id = (call.argument<Any>("textureId") as? Number)?.toLong()!!
                val volume = (call.argument<Any>("volume") as? Number)?.toFloat() ?: 0f
                players[id]?.setVolume(volume)
                result.success(null)
            }

            "setRepeatMode" -> {
                val id = (call.argument<Any>("textureId") as? Number)?.toLong()!!
                val isRepeat = call.argument<Boolean>("isRepeat") ?: true
                val repeatMode = if (isRepeat) 1 else 0
                players[id]?.setRepeatMode(repeatMode)
                result.success(null)
            }

            "release" -> {
                val id = (call.argument<Any>("textureId") as? Number)?.toLong()!!
                players[id]?.let { pool.release(it) }
                players.remove(id)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}

