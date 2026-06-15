package pro.appexp.flutter_tv_media3.player

import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi

/**
 * Responsible for playlist navigation logic:
 * - current index and playlist length
 * - repeat and shuffle modes
 * - next/previous/selected item transitions
 *
 * @param onRequestMedia  Callback to load media at the given index.
 * @param onMarkWatchTime Callback to save watch time before transitioning.
 * @param onFinish        Callback to close the Activity when the playlist ends.
 */
@UnstableApi
class PlaylistManager(
    private val onRequestMedia: (Int) -> Unit,
    private val onMarkWatchTime: (Int) -> Unit,
    private val onFinish: () -> Unit
) {
    var playlistIndex: Int = -1
    var playlistLength: Int = 0

    @Player.RepeatMode
    var currentRepeatMode: Int = Player.REPEAT_MODE_OFF
        private set

    var isShuffleModeEnabled: Boolean = false
        private set

    private var shuffledIndices: List<Int> = emptyList()
    private var currentShuffledIndex: Int = -1

    // ─── Repeat / Shuffle ─────────────────────────────────────────────────────

    fun setRepeatMode(@Player.RepeatMode mode: Int) {
        currentRepeatMode = mode
    }

    fun setShuffleMode(enabled: Boolean) {
        isShuffleModeEnabled = enabled
        if (enabled) {
            generateShuffledList()
            currentShuffledIndex = 0
        } else {
            currentShuffledIndex = -1
            shuffledIndices = emptyList()
        }
    }

    // ─── Navigation ───────────────────────────────────────────────────────────

    /**
     * Moves to the next track, respecting shuffle/repeat mode.
     * Called externally (e.g. "next" button press).
     */
    fun playNext() {
        onMarkWatchTime(playlistIndex)
        if (isShuffleModeEnabled) {
            if (currentShuffledIndex + 1 < shuffledIndices.size) {
                currentShuffledIndex++
                playlistIndex = shuffledIndices[currentShuffledIndex]
                onRequestMedia(playlistIndex)
            } else {
                if (currentRepeatMode == Player.REPEAT_MODE_ALL) {
                    generateShuffledList()
                    currentShuffledIndex = 0
                    playlistIndex = shuffledIndices[currentShuffledIndex]
                    onRequestMedia(playlistIndex)
                }
            }
        } else {
            if (playlistIndex + 1 < playlistLength) {
                playlistIndex++
                onRequestMedia(playlistIndex)
            } else {
                if (currentRepeatMode == Player.REPEAT_MODE_ALL) {
                    playlistIndex = 0
                    onRequestMedia(playlistIndex)
                }
            }
        }
    }

    /**
     * Moves to the previous track, respecting shuffle/repeat mode.
     */
    fun playPrevious() {
        onMarkWatchTime(playlistIndex)
        if (isShuffleModeEnabled) {
            if (currentShuffledIndex - 1 >= 0) {
                currentShuffledIndex--
                playlistIndex = shuffledIndices[currentShuffledIndex]
                onRequestMedia(playlistIndex)
            }
        } else {
            if (playlistIndex - 1 >= 0) {
                playlistIndex--
                onRequestMedia(playlistIndex)
            } else {
                if (currentRepeatMode == Player.REPEAT_MODE_ALL) {
                    playlistIndex = playlistLength - 1
                    onRequestMedia(playlistIndex)
                }
            }
        }
    }

    /**
     * Jumps to a specific playlist index.
     *
     * @return true if the index is valid and the transition occurred, false otherwise.
     */
    fun playSelectedIndex(newIndex: Int): Boolean {
        if (newIndex < 0 || newIndex >= playlistLength) return false

        onMarkWatchTime(playlistIndex)
        playlistIndex = newIndex

        if (isShuffleModeEnabled) {
            currentShuffledIndex = shuffledIndices.indexOf(newIndex)
            if (currentShuffledIndex == -1) {
                generateShuffledList()
                currentShuffledIndex = 0
            }
        }
        onRequestMedia(newIndex)
        return true
    }

    /**
     * Called automatically when the player finishes playing the current track.
     */
    fun handleTrackEnded() {
        onMarkWatchTime(playlistIndex)
        if (isShuffleModeEnabled) {
            handleNextInShuffleMode()
        } else {
            handleNextInSequentialMode()
        }
    }

    /**
     * Handles removal of a playlist item. Adjusts indices and loads next track if needed.
     *
     * @param removedIndex Index of the removed item.
     * @param newLength    New playlist length after removal.
     * @return Updated current playlistIndex.
     */
    fun handleItemRemoved(removedIndex: Int, newLength: Int): Int {
        when {
            removedIndex < playlistIndex -> {
                playlistIndex--
            }
            removedIndex == playlistIndex -> {
                playlistLength = newLength
                if (newLength > 0) {
                    if (playlistIndex >= newLength) playlistIndex = 0
                    onRequestMedia(playlistIndex)
                } else {
                    onFinish()
                }
                return playlistIndex
            }
        }
        playlistLength = newLength
        return playlistIndex
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    private fun generateShuffledList() {
        val others = (0 until playlistLength).toMutableList().apply { remove(playlistIndex) }
        others.shuffle()
        shuffledIndices = listOf(playlistIndex) + others
    }

    private fun handleNextInShuffleMode() {
        currentShuffledIndex++
        if (currentShuffledIndex < shuffledIndices.size) {
            playlistIndex = shuffledIndices[currentShuffledIndex]
            onRequestMedia(playlistIndex)
        } else {
            if (currentRepeatMode == Player.REPEAT_MODE_ALL) {
                generateShuffledList()
                currentShuffledIndex = 0
                playlistIndex = shuffledIndices[currentShuffledIndex]
                onRequestMedia(playlistIndex)
            } else {
                onFinish()
            }
        }
    }

    private fun handleNextInSequentialMode() {
        when (currentRepeatMode) {
            Player.REPEAT_MODE_ONE -> { /* player handles repeat internally */ }
            Player.REPEAT_MODE_ALL -> {
                playlistIndex = (playlistIndex + 1) % playlistLength
                onRequestMedia(playlistIndex)
            }
            else -> {
                if (playlistIndex + 1 < playlistLength) {
                    playlistIndex++
                    onRequestMedia(playlistIndex)
                } else {
                    onFinish()
                }
            }
        }
    }
}
