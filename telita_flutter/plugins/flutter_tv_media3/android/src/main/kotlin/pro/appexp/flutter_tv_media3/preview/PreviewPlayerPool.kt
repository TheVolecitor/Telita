package pro.appexp.flutter_tv_media3.preview

import android.content.Context
import io.flutter.view.TextureRegistry
import java.util.ArrayDeque

/**
 * Manages a pool of [TexturePreviewPlayer] instances to optimize resource usage on the device.
 *
 * Creating a native player and a Flutter texture is an expensive operation. This pool
 * allows reusing existing [TexturePreviewPlayer] instances, reducing latency and
 * memory pressure, especially in list-based UIs where previews are frequently
 * started and stopped.
 *
 * The pool uses a LIFO (Last-In-First-Out) strategy to reuse the "warmest" player.
 *
 * @property context Android context for player creation.
 * @property textureRegistry Flutter's texture registry for surface management.
 * @property maxSize The maximum number of players to keep in the pool. Default is 6.
 */
class PreviewPlayerPool(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    private val maxSize: Int = 6
) {
    private val pool = ArrayDeque<TexturePreviewPlayer>()

    /**
     * Acquires a [TexturePreviewPlayer] from the pool or creates a new one if the pool is empty.
     *
     * If a player is taken from the pool, its event callback is updated to the new provided [onEvent].
     *
     * @param onEvent Callback for player events (errors, state changes, etc.).
     * @return An available or newly created [TexturePreviewPlayer] instance.
     */
    fun acquire(onEvent: (Long, String, Map<String, Any?>?) -> Unit): TexturePreviewPlayer {
        synchronized(pool) {
            return if (pool.isNotEmpty()) {
                val player = pool.removeLast() // LIFO: reuse the most recently used player (warmer)
                player.updateCallback(onEvent)
                player
            } else {
                TexturePreviewPlayer(context, textureRegistry, onEvent)
            }
        }
    }

    /**
     * Releases a [TexturePreviewPlayer] back into the pool for future reuse.
     *
     * Before being added back, the player's playback is stopped and its resources are cleared
     * via [TexturePreviewPlayer.stopAndClear]. If the pool is at [maxSize], the player's
     * resources are permanently released instead.
     *
     * @param player The [TexturePreviewPlayer] instance to release.
     */
    fun release(player: TexturePreviewPlayer) {
        synchronized(pool) {
            player.stopAndClear()

            if (pool.size >= maxSize) {
                player.releaseResources()
            } else {
                pool.addLast(player)
            }
        }
    }

    /**
     * Permanently releases all players currently in the pool and clears it.
     *
     * Should be called when the plugin is being disposed.
     */
    fun dispose() {
        synchronized(pool) {
            while (pool.isNotEmpty()) {
                pool.removeFirst().releaseResources()
            }
        }
    }
}

