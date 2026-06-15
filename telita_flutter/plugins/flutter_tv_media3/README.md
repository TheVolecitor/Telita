# Flutter TV Media3

[![pub package](https://img.shields.io/pub/v/flutter_tv_media3.svg)](https://pub.dev/packages/flutter_tv_media3)

A Flutter plugin for playing video on Android TV using the native Media3 player, which runs in its own `Activity`. 
**Note: This plugin is for Android  only.**
Android (minSdk = 23).
The main difference of this plugin is that the player is launched in a separate native Android window, not as a widget in the Flutter hierarchy. This approach allows for the use of native features like **Auto Frame Rate (AFR) switching** and potential support for **HDR/Dolby Vision**, which may not be available in standard widget-based player implementations.

## Table of Contents

*   [Architecture and Limitations](#architecture-and-limitations)
*   [Key Features](#key-features)
*   [Getting Started](#getting-started)
    *   [Installation](#1-installation)
    *   [Android Configuration](#2-android-configuration)
*   [Basic Usage](#basic-usage)
    *   [Plugin and Controller Initialization](#1-plugin-and-controller-initialization)
    *   [Creating a Playlist](#2-creating-a-playlist)
    *   [Launching the Player](#3-launching-the-player)
*   [Preview Player (Inline Video)](#preview-player-inline-video)
*   [Advanced Usage](#advanced-usage)
    *   [Dynamic Link Resolution (`getDirectLink`)](#dynamic-link-resolution-getdirectlink)
    *   [Full Configuration and Callbacks](#full-configuration-and-callbacks)
    *   [External Control (IP Control)](#external-control-ip-control)
*   [API Reference](#api-reference)
    *   [`FtvMedia3PlayerController`](#ftvmedia3playercontroller)
    *   [`PlaylistMediaItem`](#playlistmediaitem)
    *   [`PlayerSettings`](#playersettings)
*   [Optional Native Libraries (Decoders)](#optional-native-libraries-decoders)
*   [External Subtitle Search Architecture](#external-subtitle-search-architecture)
*   [Auto Frame Rate (AFR)](#auto-frame-rate-afr)
*   [License](#license)


## Architecture and Limitations

Understanding the architecture is key to using this plugin correctly:

*   **Native Window:** The player runs in a separate Android `Activity`. This ensures the best possible performance and access to low-level system features.
*   **Separate UI Engine:** The user interface (UI) for the player is written in Flutter and runs in a separate, isolated `FlutterEngine`.
*   **Programmatic Control:** Interaction with the player from your main application is done exclusively programmatically via the `FtvMedia3PlayerController` singleton.
*   **D-pad and Touch Control:** The player UI is designed for D-pad (remote control's directional pad) navigation and also supports touch input(mouse). 
### Important Limitations

*  **UI is Not Customizable:** The player's UI is an internal part of the plugin. You cannot change its appearance or add your own widgets without modifying the plugin's source code.

## Key Features

*   **AFR Support:** [Automatic frame rate switching](https://developer.android.com/media/optimize/performance/frame-rate) for smooth playback (experimental functionality has been tested on only one device).
*   **Programmatic Control:** Full control over playback (play/pause, seek, track selection) from your application's code. This is primarily intended for implementing IP control.
*   **Playlist Management:** Create and manage playlists using `PlaylistMediaItem` objects.
*   **State Tracking:** Monitor the player's state, metadata, and playback progress through streams. This is primarily intended for implementing IP control.
*   **Dynamic Links:** Support for media that requires dynamically resolving a direct playback URL via an asynchronous callback.
*   **EPG (Electronic Program Guide):** Ability to pass and display a program guide for TV channels. The EPG is activated in the player by pressing the left/right D-pad buttons or on touch panel. To activate this, the `List<EpgProgram>? programs` field must not be `null`.
*   **Settings Persistence:** Callbacks to save player settings (quality, language) and subtitle styles that the user changes in the UI.
<p align="center">
    <a href="screenshots/screen0.png"><img src="https://raw.githubusercontent.com/Farg0k/flutter_tv_media3/master/screenshots/screen0.png" width="400"/></a>
    <a href="screenshots/screen1.png"><img src="https://raw.githubusercontent.com/Farg0k/flutter_tv_media3/master/screenshots/screen1.png" width="400"/></a>
</p>
<p align="center">
    <a href="screenshots/screen2.png"><img src="https://raw.githubusercontent.com/Farg0k/flutter_tv_media3/master/screenshots/screen2.png" width="400"/></a>
    <a href="screenshots/screen3.png"><img src="https://raw.githubusercontent.com/Farg0k/flutter_tv_media3/master/screenshots/screen3.png" width="400"/></a>
</p>
<p align="center">
    <a href="screenshots/screen4.png"><img src="https://raw.githubusercontent.com/Farg0k/flutter_tv_media3/master/screenshots/screen4.png" width="400"/></a>
    <a href="screenshots/screen5.png"><img src="https://raw.githubusercontent.com/Farg0k/flutter_tv_media3/master/screenshots/screen5.png" width="400"/></a>
</p>
<p align="center">
    <a href="screenshots/screen6.png"><img src="https://raw.githubusercontent.com/Farg0k/flutter_tv_media3/master/screenshots/screen6.png" width="400"/></a>
</p>
## Getting Started

### 1. Installation

You can add `flutter_tv_media3` to your project in one of the following ways.

**A) From the command line (recommended):**

Run this command in your project's terminal:

```bash
flutter pub add flutter_tv_media3
```

**B) Manually from `pub.dev`:**

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_tv_media3: ^0.0.1 # Make sure to use the latest version
```

**C) Manually from GitHub (for development versions):**

To use the latest code from the repository, add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_tv_media3:
    git:
      url: https://github.com/Farg0k/flutter_tv_media3.git
      # You can also specify a branch, e.g.:
      # ref: main
```

After adding the dependency manually (options B or C), run `flutter pub get` in your terminal.

### 2. Android Configuration

If you're playing content from the internet, your app must include the following permission in `AndroidManifest.xml` (inside the `<application>` tag):
```
<uses-permission android:name="android.permission.INTERNET" />
```
To play videos from `http` links (not `https`):
```
<application
    ...
    android:usesCleartextTraffic="true">
    ...
</application>
```

## Basic Usage

### 1. Controller Lifecycle: `setConfig()` and `close()`

Properly managing the lifecycle of the `FtvMedia3PlayerController` is crucial for the stability of your application.

*   **`setConfig()`**: This method is used to configure all the necessary callbacks, initial settings, and localization strings. It should be called before launching the player. A good place to call it is in the `initState` of your main widget. The configuration can be updated at any time.
*   **`close()`**: This method should be called when the controller is no longer needed, typically in the `dispose` method of your widget. It closes all internal streams and releases resources, preventing memory leaks.

```dart
@override
void initState() {
  super.initState();
  controller.setConfig(...);
}

@override
void dispose() {
  controller.close();
  super.dispose();
}
```

### 2. Plugin and Controller Initialization

First, get the singleton instance of the `FtvMedia3PlayerController`. It's best to do this in a `StatefulWidget`.

The controller should be configured before launching the player. This is done through the `setConfig()` method, typically in your widget's `initState`.

The `setConfig()` method accepts a variety of parameters to customize the player's behavior and set up callbacks. Below is a complete list of available parameters.

**General Configuration and Callbacks:**

These parameters are detailed in the [Full Configuration and Callbacks](#full-configuration-and-callbacks) section.

*   `localeStrings`: A map to provide localized strings for the player UI. For a complete list of available keys, see the `lib/src/localization/default_locale_strings.dart` file.
*   `subtitleStyle`: The initial `SubtitleStyle` to be applied.
*   `playerSettings`: The initial `PlayerSettings` (e.g., video quality, preferred languages).
*   `clockSettings`: The initial `ClockSettings` (e.g., position, format).
*   `saveSubtitleStyle`: A callback that is triggered when the user changes subtitle settings in the UI.
*   `savePlayerSettings`: A callback that is triggered when the user changes player settings.
*   `saveClockSettings`: A callback that is triggered when the user changes clock settings.
*   `sleepTimerExec`: A callback that is executed when the sleep timer is triggered from the player UI.
*   `directLinkTimeout`: (Optional) A `Duration` that specifies the timeout for resolving dynamic links via `getDirectLink`. Defaults to 15 seconds.

**External Subtitle Search:**

These parameters enable and configure the external subtitle search feature, which is described in detail in the [External Subtitle Search Architecture](#external-subtitle-search-architecture) section.

*   `searchExternalSubtitle`: The main handler function that performs the subtitle search.
*   `findSubtitlesLabel`: The text for the search button in the UI.
*   `findSubtitlesStateInfoLabel`: Optional text displayed below the search button (e.g., API usage).
*   `labelSearchExternalSubtitle`: An optional callback to dynamically update the `findSubtitlesStateInfoLabel` after a search.

**Example:**

```dart
// In your widget's state
final controller = FtvMedia3PlayerController();

@override
void initState() {
  super.initState();
  
  // A comprehensive configuration example
  controller.setConfig(
    // General settings
    localeStrings: {'loading': 'Loading...'},
    clockSettings: ClockSettings(clockPosition: ClockPosition.topLeft),
    
    // Subtitle search settings
    searchExternalSubtitle: _mySubtitleSearchFunction,
    findSubtitlesLabel: 'Search on OpenSubtitles',
  );
}

// Define your callback functions elsewhere
Future<void> _mySaveWatchTimeFunction({required String id, required int duration, required int position, required int playIndex}) async {
  // ... logic to save watch time
}

Future<List<MediaItemSubtitle>?> _mySubtitleSearchFunction({required String id}) async {
  // ... logic to search for subtitles
  return null;
}
```

### 3. Creating a Playlist

A playlist is a list of `PlaylistMediaItem` objects. Each object describes a single media item in detail.

```dart
final List<PlaylistMediaItem> items = [
  // Basic video
  PlaylistMediaItem(
    id: '1',
    url: 'https://example.com/video1.mp4',
    title: 'Video 1',
    mediaItemType: MediaItemType.video,
  ),

  // Video with metadata and watch time saving
  PlaylistMediaItem(
    id: '2',
    url: 'https://example.com/video2.m3u8',
    title: 'Video 2',
    description: 'A description of the video',
    startPosition: 60,
    saveWatchTime: ({required id, required duration, required position, required playIndex}) async {
      // Save progress to your database
    },
  ),

  // Video with external tracks
  PlaylistMediaItem(
    id: '3',
    url: 'https://example.com/video3.mp4',
    title: 'Video 3',
    subtitles: [
      MediaItemSubtitle(url: 'https://example.com/sub.vtt', language: 'en', label: 'English'),
    ],
    audioTracks: [
      MediaItemAudioTrack(
        url: 'https://example.com/audio.mp3',
        language: 'en',
        label: 'English',
        mimeType: 'audio/mpeg',  // Optional: specify MIME type
      ),
    ],
  ),

  // Video with custom labels for internal audio tracks
  // Use this when the media file has multiple audio tracks but their
  // parsed names are not descriptive (e.g., indices like "0", "1", "2")
  PlaylistMediaItem(
    id: '3b',
    url: 'https://example.com/video3b.mkv',
    title: 'Video with Custom Audio Labels',
    // Map track index (0, 1, 2...) or format ID to a custom label
    audioTrackLabels: {
      '0': 'English (Original)',
      '1': 'Español (Doblado)',
      '2': 'Deutsch (Übersetzung)',
    },
  ),

  // Video with explicit MIME type
  // Use this when the player cannot auto-detect the format from the URL
  // For example, when using CDN URLs without file extensions
  PlaylistMediaItem(
    id: '3c',
    url: 'https://cdn.example.com/stream/abc123',
    title: 'HLS Stream',
    // Explicitly set the MIME type for HLS streams
    mimeType: 'application/x-mpegURL',
  ),

  // Video with multiple qualities
  PlaylistMediaItem(
    id: '4',
    url: 'https://example.com/video4_360p.mp4',
    resolutions: {
      '360p': 'https://example.com/video4_360p.mp4',
      '720p': 'https://example.com/video4_720p.mp4',
      '1080p': 'https://example.com/video4_1080p.mp4',
    },
  ),

  // Video with dynamic URL resolution
  PlaylistMediaItem(
    id: '5',
    url: 'myapp://resolve/video',
    getDirectLink: ({required item, onProgress, required requestId}) async {
      onProgress?.call(requestId: requestId, state: 'Loading...', progress: 0.5);
      final directUrl = await resolveUrl(item.id);
      return item.copyWith(url: directUrl);
    },
  ),

  // Audio track
  PlaylistMediaItem(
    id: '6',
    url: 'https://example.com/music.mp3',
    title: 'Song Title',
    artistName: 'Artist',
    albumName: 'Album',
    mediaItemType: MediaItemType.audio,
    updateWatchTime: false,
  ),

  // Live TV stream
  PlaylistMediaItem(
    id: '7',
    url: 'https://example.com/live.m3u8',
    title: 'Live Channel',
    mediaItemType: MediaItemType.tvStream,
    updateWatchTime: false,
  ),
];
```

#### PlaylistMediaItem Field Summary

Here's a quick reference for all available fields in `PlaylistMediaItem`:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | String | Yes | Unique identifier for the media item |
| `url` | String | Yes | URL of the media resource |
| `mediaItemType` | MediaItemType | No | Type: video, audio, or tvStream (default: video) |
| `title` | String? | No | Main title of the media |
| `subTitle` | String? | No | Episode or secondary title |
| `description` | String? | No | Full description |
| `label` | String? | No | Quality label (e.g., "1080p") |
| `coverImg` | String? | No | Cover art URL |
| `placeholderImg` | String? | No | Placeholder image URL |
| `episodeImg` | String? | No | Episode image URL |
| `artistName` | String? | No | Artist name (for audio) |
| `trackName` | String? | No | Track name (for audio) |
| `albumName` | String? | No | Album name (for audio) |
| `albumYear` | String? | No | Album release year (for audio) |
| `startPosition` | int? | No | Initial playback position in seconds |
| `duration` | int? | No | Total duration in seconds |
| `headers` | Map? | No | HTTP headers for requests |
| `userAgent` | String? | No | Custom User-Agent string |
| `mimeType` | String? | No | MIME type of the media file (e.g., "video/mp4", "application/x-mpegURL" for HLS) |
| `resolutions` | Map? | No | Quality options map {"label": "url"} |
| `subtitles` | List? | No | External subtitle tracks |
| `audioTracks` | List? | No | External audio tracks |
| `audioTrackLabels` | Map? | No | Custom labels for internal audio tracks (e.g., `{"0": "English", "1": "Spanish"}`) |
| `updateWatchTime` | bool | No | Update watch time in UI (default: true) |
| `saveWatchTime` | Function? | No | Callback to save progress |
| `getDirectLink` | Function? | No | Callback to resolve direct URL |
| `programs` | List? | No | EPG program list (for TV streams) |
| `media3PreviewConfig` | Media3PreviewConfig? | No | Preview player configuration |

### 4. Launching the Player

There are three ways to launch the player, depending on your needs.

#### Method 1: Launching with the Built-in Loading Screen (Recommended)

This approach provides visual feedback to the user while the native player initializes. It can be done in two ways:

**A) Using the `openPlayer` helper method:**

This is the most convenient way. The `FtvMedia3PlayerController` handles the navigation for you.

```dart
controller.openPlayer(
  context: context,
  playlist: mediaItems,
  initialIndex: 0, // Start with the first item
);
```

**B) Using Flutter's Navigator directly:**

You can also push the `Media3PlayerScreen` widget onto the navigation stack yourself. This gives you more control over the navigation, for example, if you want to use a different page route transition. This is the method used in the example application.

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => Media3PlayerScreen(
      playlist: mediaItems,
      initialIndex: 0,
    ),
  ),
);
```

#### Method 2: `openNativePlayer` (Advanced)

This method directly launches the native Android `Activity` for the player, bypassing the Flutter loading screen. This is useful if you want to implement your own custom loading logic or splash screen.

**Note:** This method does not use Flutter's `Navigator`. It's a direct call to the native side.

```dart
controller.openNativePlayer(
  playlist: mediaItems,
  initialIndex: 0,
);
```

## Preview Player (Inline Video)

The `Media3PreviewPlayer` is a specialized widget for displaying video previews directly within your Flutter UI (e.g., in a list of movies or a focused card). Unlike the main player, which runs in a separate Activity, the Preview Player renders video to a Flutter `Texture`.

### Key Features
*   **Resource Pooling:** Automatically manages a pool of native players to ensure smooth performance and low memory usage.
*   **Visibility Awareness:** Automatically plays/pauses based on its visibility on the screen and the app's lifecycle.
*   **Highly Optimized:** Uses a LIFO pooling strategy on the native side to reuse "warm" player instances.
*   **Clipping Support:** Can play specific segments of a video.

### Basic Usage

```dart
Media3PreviewPlayer(
  url: 'https://example.com/preview.mp4',
  isActive: isFocused, // Only initializes and plays when true
  width: 320,
  height: 180,
  borderRadius: BorderRadius.circular(12),
  volume: 0.0, // Previews are usually muted
  placeholder: Image.network('https://example.com/thumbnail.jpg', fit: BoxFit.cover),
  initDelay: Duration(milliseconds: 500), // Delay before loading to handle fast scrolling
)
```

### Dynamic Link Support

Just like the main player, the Preview Player supports dynamic URL resolution:

```dart
Media3PreviewPlayer(
  url: 'api://video/123',
  getDirectLink: () async {
    final directUrl = await myApi.getLink('123');
    return directUrl;
  },
  isActive: isFocused,
  width: 320,
  height: 180,
)
```

### Media3PreviewConfig

The `Media3PreviewConfig` class is used to configure preview playback within a `PlaylistMediaItem`. This allows you to define preview-specific settings that are separate from the main video playback.

#### Configuration Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `url` | String? | null | Override URL for preview (uses main item URL if null) |
| `width` | double? | null | Desired width of the preview widget |
| `height` | double? | null | Desired height of the preview widget |
| `volume` | double? | 0.0 | Audio volume (0.0 = muted, 1.0 = full) |
| `autoPlay` | bool? | true | Auto-start playback when ready |
| `isRepeat` | bool? | true | Loop playback indefinitely |
| `startTimeSeconds` | int? | null | Start playback from specific time |
| `endTimeSeconds` | int? | null | Stop/restart at specific time (clipping) |
| `placeholderImg` | String? | null | URL for placeholder image during loading |
| `initDelay` | Duration? | 600ms | Delay before initialization (prevents unnecessary loading) |
| `getDirectLink` | Function? | null | Async callback to resolve direct URL |
| `getPreviewDirectLink` | Function? | null | Alternative callback for preview URL resolution |

#### Usage Example

```dart
PlaylistMediaItem(
  id: '1',
  url: 'https://example.com/movie.mp4',
  title: 'Movie',
  media3PreviewConfig: Media3PreviewConfig(
    // Use same URL or specify different preview URL
    url: 'https://example.com/preview.mp4',
    
    // Widget dimensions
    width: 320,
    height: 180,
    
    // Playback settings
    volume: 0.0,  // Muted for preview
    autoPlay: true,
    isRepeat: true,
    
    // Clip to 10-30 second segment
    startTimeSeconds: 10,
    endTimeSeconds: 30,
    
    // Loading delay to handle fast scrolling
    initDelay: Duration(milliseconds: 500),
    
    // Placeholder image
    placeholderImg: 'https://example.com/thumbnail.jpg',
    
    // Dynamic URL resolution for preview
    getPreviewDirectLink: () async {
      return await resolvePreviewUrl('1');
    },
  ),
)
```

#### Best Practices

1. **Always mute previews** (`volume: 0.0`) to avoid audio conflicts
2. **Use clipping** (`startTimeSeconds`, `endTimeSeconds`) to show interesting segments
3. **Set appropriate initDelay** (300-800ms) to prevent loading items that are quickly scrolled past
4. **Provide placeholder images** for better user experience during loading
5. **Use isRepeat: true** for seamless looping previews

## Advanced Usage

### Dynamic Playlist and Pagination

This plugin provides robust features for dynamically managing the playback playlist while the player is active, including adding/removing items and automatic pagination.

#### Dynamic Playlist Management (`addMediaItems`, `removeMediaItem`)

The `FtvMedia3PlayerController` now allows you to modify the playlist after the player has been launched. All changes are synchronized in real-time between your main application, the native Android player, and the Flutter UI overlay.

*   **`addMediaItems({required List<PlaylistMediaItem> items})`**:
    Adds a list of new media items to the end of the current playlist. This is useful for implementing "Add to Queue" functionality or appending content during pagination.
    ```dart
    // Example of adding new items to the playlist
    final newItems = [
      PlaylistMediaItem(id: 'new1', title: 'New Video 1', url: 'https://example.com/new1.mp4'),
      PlaylistMediaItem(id: 'new2', title: 'New Video 2', url: 'https://example.com/new2.mp4'),
    ];
    await controller.addMediaItems(items: newItems);
    ```

*   **`removeMediaItem({required int index})`**:
    Removes the media item at the specified `index` from the playlist. The player will automatically adjust the `playIndex` if the removed item affects the current playback position. If the currently playing item is removed, playback will advance to the next item or stop if no more items are left.
    ```dart
    // Example of removing an item by index (e.g., the 0th item)
    await controller.removeMediaItem(index: 0);
    ```

#### Automatic Pagination (`onLoadMore`, `paginationThreshold`)

To handle large playlists efficiently, the plugin includes a built-in pagination mechanism. You can define a callback that automatically fetches more content when the player approaches the end of the current playlist.

*   **`onLoadMore`** (`Future<List<PlaylistMediaItem>?> Function()?`):
    An asynchronous callback function that is triggered when the player's `playIndex` is within the `paginationThreshold` of the playlist's end. Use this to fetch additional `PlaylistMediaItem` objects and return them to be automatically added to the playlist.

*   **`paginationThreshold`** (`int`):
    Defines how many items from the end of the playlist `onLoadMore` should be triggered. For example, if `paginationThreshold` is `5`, `onLoadMore` will be called when the player starts preparing the 5th item from the end of the current playlist.

**Example of Pagination Setup:**

```dart
// In your widget's state
final controller = FtvMedia3PlayerController();
int _currentPage = 0; // Keep track of the current page

@override
void initState() {
  super.initState();
  // ... other controller configurations

  controller.setConfig(
    onLoadMore: () async {
      print('PAGINATION: Triggered to load more items...');
      // Simulate fetching data from an API
      await Future.delayed(const Duration(seconds: 2));
      
      _currentPage++; // Increment page count for the new items
      final newItems = List.generate(5, (i) => PlaylistMediaItem(
        id: 'page_${_currentPage}_item_${i}',
        title: 'Dynamic Item ${(_currentPage - 1) * 5 + i + 1}',
        url: 'https://storage.googleapis.com/exoplayer-test-media-0/BigBuckBunny_320x180.mp4',
      ));

      print('PAGINATION: Returning ${newItems.length} new items.');
      return newItems;
    },
    paginationThreshold: 3, // Load more when 3 items are left
  );
}
```


### Dynamic Link Resolution (`getDirectLink`)

If the playback URL is not known in advance (e.g., it needs to be fetched from your server), use the `getDirectLink` callback. The plugin will call this function before starting playback.


If the playback URL is not known in advance (e.g., it needs to be fetched from your server), use the `getDirectLink` callback. The plugin will call this function before starting playback.

```
PlaylistMediaItem(
  id: 'secure_stream',
  url: 'secure_api://stream/123',
  title: 'Secure Video',
  getDirectLink: ({ required item, onProgress, required requestId }) async {
    // Show progress to the user
    onProgress?.call(requestId: requestId, state: 'Authorizing...', progress: 0.3);
    
    // Your asynchronous API request
    final String token = await getAuthToken();
    final String directUrl = await fetchSecureUrl(item.id, token);

    onProgress?.call(requestId: requestId, state: 'Loading...', progress: 0.8);

    // Return a copy of the item with the direct link and headers
    return item.copyWith(
      url: directUrl,
      headers: {'Authorization': 'Bearer $token'},
    );
  },
)
```

### Full Configuration and Callbacks

You can configure the player and handle events from its UI by passing all configurations to the `controller.setConfig()` method.

Here is a full example of configuration:

```dart
// In your widget's state
final controller = FtvMedia3PlayerController();

// It's good practice to define callback functions separately
Future<void> _saveSubtitleStyle({required SubtitleStyle subtitleStyle}) async { /* ... */ }
Future<void> _savePlayerSettings({required PlayerSettings playerSettings}) async { /* ... */ }
Future<void> _saveClockSettings({required ClockSettings clockSettings}) async { /* ... */ }
void _sleepTimerExec() { /* ... */ }

@override
void initState() {
  super.initState();
  
  // Call setConfig() with all desired configurations
  controller.setConfig(
    // 1. Localize strings
    localeStrings: const { 'loading': 'Loading...', 'error_title': 'Error' },

    // 2. Initial subtitle style
    subtitleStyle: SubtitleStyle( foregroundColor: BasicColors.yellow, /* ... */ ),

    // 3. Initial player settings
    playerSettings: PlayerSettings( videoQuality: VideoQuality.high, /* ... */ ),

    // 4. Initial clock settings
    clockSettings: ClockSettings(clockPosition: ClockPosition.topLeft),
    
    // 5. Assign callbacks
    savePlayerSettings: _savePlayerSettings,
    saveSubtitleStyle: _saveSubtitleStyle,
    saveClockSettings: _saveClockSettings,
    sleepTimerExec: _sleepTimerExec,
  );
}
```

### Saving Watch Time (Progress)

Unlike other settings, the logic for saving playback progress is configured **per media item**. This provides maximum flexibility, allowing you to use different saving mechanisms for different types of content (e.g., save to a local database for local files, or send an API request for streaming content).

To enable watch time saving for an item, provide a callback function to the `saveWatchTime` property of a `PlaylistMediaItem`.

**Example:**

```dart
// 1. Define your save function
Future<void> _mySaveWatchTimeFunction({
  required String id,
  required int duration,
  required int position,
  required int playIndex,
}) async {
  print('Saving progress for item $id: $position/$duration seconds.');
  // Add your logic here to save the progress to a database or remote server.
}

// 2. Create a PlaylistMediaItem with the callback
final mediaItem = PlaylistMediaItem(
  id: 'video_123',
  url: 'https://.../video.mp4',
  title: 'My Awesome Video',
  // Assign the save function to this specific item
  saveWatchTime: _mySaveWatchTimeFunction,
);

// If you set saveWatchTime to null, progress for that item will not be saved.
final liveStreamItem = PlaylistMediaItem(
  id: 'live_stream_1',
  url: 'https://.../live.m3u8',
  title: 'Live TV Channel',
  saveWatchTime: null, // Disable saving for live streams
);
```

### External Control (IP Control)

The `FtvMedia3PlayerController` is not just for launching the player. Its methods and streams are ideal for implementing **external control**. For example, you could create a remote control in a mobile app that sends commands to the player over the network (IP Control).

This is a two-way communication:
1.  **Sending Commands:** Use controller methods like `playPause()`, `seekTo()`, etc., to control playback.
2.  **Listening to State:** Use controller streams like `playerStateStream` to monitor the player's state and update your external UI accordingly.

### Volume Control

The plugin provides full control over the system's media volume. This includes both programmatic control and tracking changes made using the physical volume buttons on the device or remote.

#### Programmatic Volume Control

You can manage the volume by calling methods on the `FtvMedia3PlayerController` or `Media3UiController` instance:

*   `getVolume()`: Fetches the current volume state (`VolumeState`), which includes the current level, maximum level, mute status, and the current volume as a double between 0.0 and 1.0.
*   `setVolume({required double volume})`: Sets the volume level. The `volume` parameter must be a value between **0.0 (mute)** and **1.0 (maximum)**.
*   `setMute({required bool mute})`: Explicitly mutes or unmutes the audio.
*   `toggleMute()`: Toggles the current mute state.

**Example of Programmatic Control:**

```dart
// Get the controller instance
final controller = FtvMedia3PlayerController();

// Set volume to 50%
await controller.setVolume(volume: 0.5);

// Mute the audio
await controller.setMute(mute: true);

// Toggle the mute state
await controller.toggleMute();
```

#### Tracking Volume Changes

The plugin automatically tracks system volume changes. You can listen to the `playerStateStream` to receive real-time updates. The volume state is stored in the `VolumeState` object within `PlayerState`.

The `VolumeState` object has the following fields:
*   `volume` (double): The current volume level, from 0.0 to 1.0.
*   `current` (int): The current absolute volume level.
*   `max` (int): The maximum possible absolute volume level.
*   `isMute` (bool): `true` if the audio is muted.

**Listening to State Example:**

The controller provides several streams to track the player's state.

*   `playerStateStream`: Emits a complete `PlayerState` object whenever a significant change occurs (track change, pause, error). This is the main stream for tracking the overall state.
*   `playbackStateStream`: Emits a `PlaybackState` object (position, duration) several times per second during playback.
*   `mediaMetadataStream`: Emits the metadata of the current track (`MediaMetadata`) when it changes.

```dart
@override
void initState() {
  super.initState();
  // ... initialization

  controller.playerStateStream.listen((state) {
    // Update the UI, e.g., by highlighting the active track.
    if (mounted) {
      setState(() {
        lastPlayedIndex = state.playIndex;
      });
    }

    // Check for errors
    if (state.lastError != null) {
      print('An error occurred: ${state.lastError}');
      controller.resetError(); // Reset the error after handling it
    }
  });

  controller.playbackStateStream.listen((playback) {
    // print('Position: ${playback.position}, Duration: ${playback.duration}');
  });
}
```

### Error Handling

The plugin provides a mechanism for tracking and handling errors that may occur during playback. This is crucial for building a reliable and user-friendly application.

The primary way to receive error notifications is by listening to the `playerStateStream`. The `PlayerState` object emitted from this stream contains a `lastError` field.

**How It Works:**

1.  **Error Detection:** When an error occurs (e.g., unable to load a video, a network issue, or a decoding problem), information about it is written to the `lastError` field in the `PlayerState` object, and the new state is emitted to the `playerStateStream`.
2.  **Handling the Error:** Your code, subscribed to `playerStateStream`, receives the updated state. You can check if `state.lastError` is not `null`. If an error exists, you can display an appropriate message to the user, attempt to restart playback, or perform other necessary actions.
3.  **Resetting the Error:** After you have handled the error, it is important to "reset" it to prevent it from being processed again on subsequent state updates. This is done using the `controller.resetError()` method. It sets `lastError` back to `null`. If you don't do this, you might handle the same error multiple times.

**Code Example:**

```dart
@override
void initState() {
  super.initState();
  // ... other initialization

  controller.playerStateStream.listen((state) {
    // Check for an unhandled error
    if (state.lastError != null) {
      // Show a notification to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${state.lastError}'),
          backgroundColor: Colors.red,
        ),
      );

      // After handling, reset the error to avoid reacting to it again
      controller.resetError();
    }
  });
}
```

This approach allows for centralized error management and ensures the stable operation of the player in your application.

## API Reference

### `FtvMedia3PlayerController`

A singleton for controlling the player.

**Key Methods:**

*   **`setConfig()`**: **(Lifecycle)** Configures the controller. This method can be called multiple times to set or update configurations incrementally. Each call only modifies the parameters you provide, leaving previously set values intact. For all settings to be applied correctly on the initial launch, ensure this method is called **before launching the player**. Once the native player window is open, any subsequent configuration changes will only take effect the next time the player is launched.
*   `openPlayer()`: **(Core)** Opens the player with a playlist using a built-in loading screen (`Media3PlayerScreen`). This method handles Flutter navigation and is the recommended way to launch the player for most use cases.
*   `openNativePlayer()`: **(Core)** A lower-level alternative to `openPlayer`. It directly triggers the native player activity, bypassing the Flutter loading screen. This is useful if you want to implement a custom loading UI. This method does not manage Flutter navigation.
*   `close()`: **(Lifecycle)** Releases the controller's resources. Must be called in your widget's `dispose` method to prevent memory leaks.

All subsequent methods and streams are **optional** and are primarily intended for advanced scenarios, such as implementing IP control:

**Playback Control:**
*   `playPause()`: Toggles between play and pause.
*   `play()` / `pause()`: Starts or pauses playback.
*   `stop()`: Stops playback and releases player resources.
*   `seekTo(Duration)`: Seeks to the specified position.
*   `playNext()` / `playPrevious()`: Switches to the next/previous item in the playlist.
*   `playSelectedIndex({required int index})`: Plays a specific item from the playlist by its index.
*   `setSpeed({required double speed})`: Sets the playback speed.
*   `setRepeatMode({required PlayerRepeatMode repeatMode})`: Sets the repeat mode (off, one, all).
*   `setShuffleMode(bool enabled)`: Enables or disables shuffle mode.

**Track and Subtitle Management:**
*   `selectAudioTrack(AudioTrack)` / `selectSubtitleTrack(SubtitleTrack)` / `selectVideoTrack(VideoTrack)`: Selects a specific track.
*   `setExternalSubtitles({required List<MediaItemSubtitle> subtitleTracks})`: Programmatically adds a list of external subtitle tracks to the current media item.
*   `setExternalAudio({required List<MediaItemAudioTrack> audioTracks})`: Programmatically adds a list of external audio tracks.

**UI and Display Control:**
*   `setZoom({required PlayerZoom zoom})`: Sets the video zoom/resize mode (e.g., fit, fill).
*   `setScale({required double scaleX, required double scaleY})`: Applies a custom scale to the v allowing for fine-grained zoom control.
*   `sendCustomInfoToOverlay(String text)`: Displays a custom string in the player's timeline panel. Useful for showing dynamic information like network speed or connection status.

**Information Retrieval:**
*   `getMetaData()`: Fetches the latest metadata for the currently playing media item.
*   `getCurrentTracks()`: Returns a list of all available tracks (video, audio, subtitle).
*   `getRefreshRateInfo()`: Gets information about the display's supported and active refresh rates.

**Key Streams (Optional):**
*   `playerStateStateStream`: A stream that emits `PlayerState` objects on any significant state change (e.g., play/pause, track change, error).
*   `playbackStateStream`: A stream that emits `PlaybackState` objects (position, duration) several times per second during playback.
*   `mediaMetadataStream`: A stream that emits `MediaMetadata` objects when the current media item changes.

### `PlaylistMediaItem`

A class to describe a single item in a playlist. Objects of this class are immutable; use the `copyWith` method to create a modified copy.

**Core Properties:**

*   `id` (String): **Required.** A unique identifier for the media item. Used for saving playback progress and identifying the item.
*   `url` (String): **Required.** The URL of the media resource. Can be a direct link or an indirect link that will be processed via `getDirectLink`.
*   `mediaItemType` (`MediaItemType`): The type of the media item (`video`, `audio`, `tvStream`). Defaults to `MediaItemType.video`. This property has two functions: it is used to display a corresponding icon in the playlist UI, and **it can be used to force a specific player interface.** If set to `MediaItemType.audio`, the player will display the audio-only interface. Otherwise, the player will attempt to determine the interface automatically based on the media's tracks.

**UI Metadata:**

*   `title` (String?): The main title of the media (e.g., the name of a movie or series).
*   `subTitle` (String?): A subtitle that can be used as an episode title.
*   `description` (String?): A full description of the media item.
*   `label` (String?): A text label displayed for this item in the playlist UI (e.g., quality label like "1080p" or "HD").
*   `coverImg` (String?): The URL for the cover art image.
*   `placeholderImg` (String?): The URL for a placeholder image shown while the media is loading.
*   `episodeImg` (String?): The URL for an episode image shown in the UI.

**Audio Metadata (for music tracks):**

*   `artistName` (String?): The name of the performer or artist.
*   `trackName` (String?): The name of the track.
*   `albumName` (String?): The name of the album.
*   `albumYear` (String?): The release year of the album.

**Playback Parameters:**

*   `startPosition` (int?): The initial playback position in seconds. Used to resume playback from a specific position.
*   `duration` (int?): The total duration of the media in seconds.
*   `headers` (Map<String, String>?): HTTP headers to be used when requesting the `url` (e.g., Authorization, Referer).
*   `userAgent` (String?): A custom User-Agent string for HTTP requests.
*   `mimeType` (String?): The MIME type of the media file. This helps the player determine how to handle the media. Common values include:
    *   `"video/mp4"` for MP4 files
    *   `"application/x-mpegURL"` for HLS streams
    *   `"application/dash+xml"` for DASH streams
    If not provided, the player will attempt to auto-detect the type from the URL extension.
*   `resolutions` (Map<String, String>?): A map of available video resolutions (e.g., `"1080p": "url..."`). **Note:** The player automatically deduplicates entries by URL. If multiple labels are provided for the same URL, only the first label encountered will be displayed in the UI.
*   `subtitles` (List<`MediaItemSubtitle`>?): A list of external subtitle tracks. Each track requires `url`, `language`, and `label`. You can also specify an optional `mimeType` field (e.g., `text/vtt` for WebVTT, `application/x-subrip` for SRT). If not provided, the player will attempt to auto-detect the type from the URL extension.
*   `audioTracks` (List<`MediaItemAudioTrack`>?): A list of external audio tracks. Each track requires `url`, `language`, and `label`. You can also specify an optional `mimeType` field (e.g., `audio/mp4`, `audio/mpeg`). If not provided, the player will attempt to auto-detect the type from the URL extension.
*   `audioTrackLabels` (Map<String, String>?): A map of custom labels for **internal** audio tracks. This is useful when the media file contains multiple audio tracks but their parsed names are not descriptive (e.g., they appear as indices like "0", "1", "2" instead of "English", "Spanish"). The key can be the track index ("0", "1", etc.) or the format ID, and the value is the display label. **Example:** `{"0": "English (Original)", "1": "Español", "2": "Deutsch"}`. This is an optional field; if not provided, the player will use the names parsed from the media file.

**Watch Time and Progress:**

*   `updateWatchTime` (bool): Whether to update watch time in the UI. Defaults to `true`. Set to `false` for live streams or music.
*   `saveWatchTime` (`SaveWatchTimeSeconds`?): An asynchronous callback to save the playback progress for this specific item. If `null`, progress is not saved. This allows per-item control over saving logic.

**Dynamic Link Resolution:**

*   `getDirectLink` (`GetDirectLinkCallback`?): An asynchronous callback to obtain a direct, playable media link. Useful when the initial `url` is indirect, temporary, or requires server-side generation. The callback receives the item, an optional progress callback, and a request ID.

**TV and EPG:**

*   `programs` (List<`EpgProgram`>?): A list of EPG (Electronic Program Guide) programs associated with this item. If this field is not `null`, the EPG functionality is enabled for this media item. The EPG is activated by pressing left/right D-pad buttons.

**Preview Configuration:**

*   `media3PreviewConfig` (`Media3PreviewConfig`?): Configuration for the `Media3PreviewPlayer` widget. Contains settings like `url`, `width`, `height`, `volume`, `autoPlay`, `startTimeSeconds`, `endTimeSeconds`, `isRepeat`, `placeholderImg`, `initDelay`, and `getPreviewDirectLink`.

### `PlayerSettings`

A class for player configuration.

**Properties:**
*   `videoQuality` (`VideoQuality`): The desired video quality (`low`, `medium`, `high`, `ultraHigh`).
*   `preferredAudioLanguages` (List<String>): A list of language codes for audio tracks (e.g., `['en', 'de']`).
*   `preferredTextLanguages` (List<String>): A list of language codes for subtitles.

## Optional Native Libraries (Decoders)

This plugin uses the native Media3 player from Google. By default, Media3 supports a standard set of audio and video formats. To extend its capabilities and support additional formats like AV1, IAMF, MPEGH, as well as containers and codecs provided by the FFmpeg library (e.g., AC3, EAC3, DTS, TrueHD), you need to add the corresponding decoder libraries to your application.

In the example (`/example/android/app/libs`), you can find the following pre-built libraries:
* `decoder_av1-release.aar`
* `decoder_ffmpeg-release.aar`
* `decoder_iamf-release.aar`
* `decoder_mpegh-release.aar`
* `decoder_vp9-release.aar`
* `decoder_flac-release.aar` 
* `decoder_opus-release.aar`

### Why aren't these libraries included in the plugin?

1.  **Application Size:** Including all decoders would significantly increase the final application size, even if you don't need support for these formats.
2.  **Licensing:** The FFmpeg library is distributed under the LGPL/GPL license. Including it directly in the plugin could create legal complexities for developers. Providing these libraries as an optional component shifts the responsibility for license compliance to the end developer.
3.  **Flexibility:** You can choose exactly which decoders you need for your project.
4.  **Technical Build Limitations:** The Android build system (Gradle) does not allow a plugin to reliably transmit local libraries (`.aar`) to the final application. Explicitly including these files in the application's own `build.gradle` is a Gradle requirement that ensures they are available to the Media3 player at runtime.

### How to add the libraries to your application

1.  **Create a directory:** In your Flutter project, create a directory at `android/app/libs`.

2.  **Copy the files:** Copy the required `.aar` files from this plugin's `example/android/app/libs` directory into your newly created `android/app/libs` folder.

3.  **Add dependencies:** Open the `android/app/build.gradle.kts` file (or `android/app/build.gradle` if you're not using Kotlin Script) and add the dependencies for each library inside the `dependencies` block:

    ```kotlin
    // android/app/build.gradle.kts

    dependencies {
        // ... other dependencies
        implementation(files("libs/decoder_av1-release.aar"))
        implementation(files("libs/decoder_ffmpeg-release.aar"))
        implementation(files("libs/decoder_iamf-release.aar"))
        implementation(files("libs/decoder_mpegh-release.aar"))
    }
    ```

### Where to get the libraries?

*   **From the example:** The easiest way is to copy them from the `example/android/app/libs` folder of this project.
*   **Build them yourself:** You can build the latest versions of the libraries from the official [Google Media3](https://github.com/androidx/media) repository.
*   **FFmpeg:** For formats requiring FFmpeg, you can either:
    *   Use the local `decoder_ffmpeg-release.aar` library found in `example/android/app/libs`.
    *   Alternatively, add a dependency on the [Jellyfin](https://github.com/jellyfin/jellyfin-android) project. This allows you to receive library updates automatically via Gradle. To do this:
        1.  Ensure that `mavenCentral()` is added to the repositories in your `android/settings.gradle.kts` file (or `settings.gradle`):
            ```
            // android/settings.gradle.kts
            pluginManagement {
                repositories {
                    ...
                    mavenCentral() // This line must be present
                    ...
                }
            }
            ```
        2.  Replace the local dependency with the Jellyfin dependency in your `android/app/build.gradle.kts` file:
            ```
            // implementation(files("libs/decoder_ffmpeg-release.aar")) // Comment out or remove this line
            implementation 'org.jellyfin.media3:media3-ffmpeg-decoder:1.6.1+1' // Uncomment or add this line
            ```

## External Subtitle Search Architecture

This document describes the mechanism for searching and integrating external subtitles into the player. The architecture divides responsibilities between the main application, the native player, and the UI overlay.

### Overview

Thture allows a user to initiate a search for subtitles for the current media file. The search is performed by an external service (implemented in the main application), and the results are dynamically added to the list of available subtitle tracks in the player.

### Key Components

1.  **Main App:**
    *   Responsible for implementing the subtitle search logic (e.g., via a third-party service API).
    *   Provides the `FtvMedia3PlayerController` with a `searchExternalSubtitle` handler function.
    *   Passes initial settings (like the search button label) when launching the player.

2.  **Native Player (`PlayerActivity.kt`):**
    *   Acts as a bridge between the UI overlay and the main application.
    *   **Does not implement search logic.**
    *   Receives the `findSubtitles` command from the UI and forwards the `onFindSubtitlesRequested` request to the main app.
    *   Receives search status updates (`onSubtitleSearchStateChanged`) from the main app and broadcasts them to the UI overlay.
    *   Receives the found subtitle tracks (`setExternalSubtitles`) and adds them to the player's media source.

3.  **UI Overlay:**
    *   Contains the user controls (e.g., "Find Subtitles" button).
    *   Initiates the search process by calling `findSubtitles` on the `Media3UiController`.
    *   Reactively updates its state (e.g., shows a loading indicator, errors, or success notifications) based on data from `findSubtitlesStateNotifier`.

### Configuration in the Main Application

To activate the subtitle search functionality, you must pass the following parameters during the initialization of `FtvMedia3PlayerController`:

*   **`searchExternalSubtitle`**:
    *   **Type:** `Future<List<MediaItemSubtitle>?> Function({required String id})`
    *   **Description:** This is the core handler function that implements the subtitle search logic. It accepts the `id` of the current media item and must return a `Future` that resolves to a list of found subtitles (`List<MediaItemSubtitle>`) or `null` if nothing is found or an error occurs. This is where you place the code to interact with your subtitle search API.

*   **`findSubtitlesLabel`**:
    *   **Type:** `String?`
    *   **Description:** The initial static text for the subtitle search button in the player's UI. For example: "Find on OpenSubtitles".

*   **`findSubtitlesStateInfoLabel`**:
    *   **Type:** `String?`
    *   **Description:** Optional. The initial text to display under the button with additional info (e.g., API usage limits like "10/10"). This text can be dynamically updated after each search using the `labelSearchExternalSubtitle` callback.

*   **`labelSearchExternalSubtitle`**:
    *   **Type:** `Future<String> Function()`
    *   **Description:** An optional function that is called *after* every successful or failed search to dynamically update the `findSubtitlesStateInfoLabel` text. This allows displaying up-to-date information, such as API usage limits (e.g., "9/10 searches left") or other service statuses. The function must return a `Future<String>`, the result of which will become the new text for the info label.

### Data Flow

1.  **Initialization:**
    *   The main app, when configuring `FtvMedia3PlayerController`, passes the `searchExternalSubtitle` function and, optionally, `findSubtitlesLabel`, `findSubtitlesStateInfoLabel`, and `labelSearchExternalSubtitle`.
    *   This data is serialized to JSON and passed to `PlayerActivity` as `subtitle_search` on launch.
    *   `PlayerActivity` forwards this data to the UI overlay, where `Media3UiController` initializes `findSubtitlesStateNotifier`.

2.  **Initiating the Search:**
    *   The user presses the "Find Subtitles" button in the UI overlay.
    *   `SubtitleWidget` calls the `controller.findSubtitles()` method.
    *   `Media3UiController` immediately updates `findSubtitlesStateNotifier.value` to the `loading` state and calls the `findSubtitles` method on the `_activityChannel`.
    *   `PlayerActivity` receives the call, sees the `findSubtitles` method, and forwards the request by calling `onFindSubtitlesRequested` on the `methodChannel` leading to the main app, passing the `mediaId` as an argument.

3.  **Processing in the Main App:**
    *   `FtvMedia3PlayerController` receives the `onFindSubtitlesRequested` request.
    *   It calls the user-provided `_searchExternalSubtitle` function, passing it the `mediaId`.
    *   Throughout the process, `FtvMedia3PlayerController` can send intermediate states (e.g., "error", "not found") back to `PlayerActivity` via the `_updateFindSubtitlesState` method.

4.  **State and Result Updates:**
    *   `PlayerActivity` receives these updates via the `onSubtitleSearchStateChanged` method and broadcasts them to the UI overlay.
    *   `Media3UiController` in the overlay receives these states and updates `findSubtitlesStateNotifier`. The `SubtitleWidget` listens to this `ValueNotifier` and rebuilds, showing a loading indicator, error message, etc.
    *   After the search is complete (successful or not), `FtvMedia3PlayerController` calls the `_labelSearchExternalSubtitle` function (if provided) to update the info label's text (`findSubtitlesStateInfoLabel`).
    *   If the search is successful, `FtvMedia3PlayerController` calls `setExternalSubtitles`, passing the list of found `MediaItemSubtitle`.
    *   `PlayerActivity` receives this list, adds it to `currentSubtitleTracks`, and rebuilds the player's `MediaSource` to make the new subtitles available for selection.

5.  **Displaying Results:**
    *   After the `MediaSource` is rebuilt, the player sends an updated list of tracks (`onTracksChanged`).
    *   The UI overlay receives this list, and `SubtitleWidget` displays the new subtitle tracks. The widget also shows a notification that subtitles were successfully added.

### Data Objects

*   **`FindSubtitlesState`**: A class that encapsulates the complete UI state for the search feature. It contains the following fields:
    *   `isVisible`: Whether to show the search button.
    *   `label`: The text on the button.
    *   `stateInfoLabel`: The text to display under the button with additional info.
    *   `errorMessage`: The error message to display.
    *   `status`: The current status (`idle`, `loading`, `error`, `success`).
*   **`MediaItemSubtitle`**: A class representing an external subtitle track, containing `url`, `label`, `language`, and an optional `mimeType` (e.g., `text/vtt`, `application/x-subrip`).


### Screenshots and Thumbnails

There are two primary ways to extract frames from media: user-initiated screenshots via the player UI and programmatic frame extraction for app-internal use (like thumbnails).

#### 1. User-Initiated Screenshots (`onScreenshotTaken`)

This allows the **end-user** to capture a frame while watching a video. This feature is disabled by default and is automatically enabled if you provide the `onScreenshotTaken` callback in `setConfig()`.

*   **How it works in UI:** When enabled, the user can fast double press the **Info** button on the remote to open the info panel. The player will then automatically capture a frame and send it to your app.
*   **Implementation:**
    ```dart
    controller.setConfig(
      onScreenshotTaken: ({required bytes, required item}) async {
        // 'bytes' contains the PNG image data
        // 'item' is the PlaylistMediaItem currently playing
        print('User took a screenshot of: ${item.title}');
        // Logic to save the file or share it
      },
    );
    ```

#### 2. Programmatic Frame Extraction (`getVideoThumbnail`)

This is intended for **internal application use**, such as generating thumbnails for a list of movies or previews, without opening the full player.

*   **How it works:** You can call this method at any time for any media URI. It does not require the player to be active.
*   **Implementation:**
    ```dart
    // Get default thumbnail (usually from the beginning of the video)
    final Uint8List? thumb = await controller.getVideoThumbnail('https://example.com/video.mp4');

    // Extract a specific frame (e.g., at 10.5 seconds)
    final Uint8List? frame = await controller.getVideoThumbnail(
      'https://example.com/video.mp4',
      timeInSeconds: 10.5,
    );
    ```

### Retrieving Media Metadata

You can retrieve detailed information about a media file without actually playing it. This is useful for displaying technical info, duration, or available tracks in your UI.

Use `getMediaMetadata(uri)` to get a full map of technical details:
```dart
final metadata = await controller.getMediaMetadata('https://example.com/video.mp4');

if (metadata != null) {
  print('Duration: ${metadata['durationSeconds']}s');
  print('Total Tracks: ${metadata['totalTracks']}');
  
  final tracks = metadata['tracks'] as List;
  for (var track in tracks) {
    print('Track: ${track['trackType']}, Codec: ${track['codec']}');
  }
}
```

## Auto Frame Rate (AFR)

### Important Notice

This feature has been tested on **only one device**. The implementation may be unstable or may not work on your hardware. Please consider it experimental. Use it at your own risk. We would appreciate your feedback and bug reports to improve this functionality.

### Overview

The Auto Frame Rate (AFR) feature is designed to provide the smoothest possible video playback. It works by synchronizing the display's refresh rate with the original frame rate of the video file (e.g., 23.976, 24, 25, 50, 60 fps). This eliminates judder, which can occur when playing content with a frame rate that is not a multiple of the screen's refresh rate.

This capability is realized because the player runs in a separate native Android window, which provides direct access to control the display modes.

### How It Works

The AFR logic is split between the native side (Kotlin) and the Flutter side (Dart).

#### Native Implementation (Android/Kotlin)

The core logic resides in the `FrameRateManager.kt` class.

1.  **Frame Rate Detection:** When video playback starts, `FrameRateManager` analyzes the video track in `ExoPlayer` and determines its original frame rate (fps).
2.  **Finding a Compatible Mode:** The class retrieves a list of all display modes supported by the device and searches for the best option that is compatible with the video's frame rate. Compatibility is determined by multiplicity or minimal difference between the rates (taking into account standard TV frequencies).
3.  **Switching the Refresh Rate:**
    *   **On Android 11 (API 30) and above:** It uses `Surface.setFrameRate()` to precisely set the refresh rate for the surface on which the video is being rendered. This is the modern and recommended approach.
    *   **On older Android versions (API 23-29):** It chIt changes the overall display mode (`preferredDisplayModeId`), which results in a brief black screen during the switch.
4.  **Resetting:** When playback stops or the AFR feature is disabled, `FrameRateManager` reverts the display's refresh rate to the default value.

The `PlayerActivity.kt` class manages the lifecycle of `FrameRateManager` and enables/disables it according to the settings received from Flutter.

#### Flutter Implementation (Dart)

On the Flutter side, the feature is managed through the UI and controllers.

1.  **Settings:**
    *   In `lib/src/entity/player_settings.dart`, the `PlayerSettings` class contains a boolean field `isAfrEnabled`, which is responsible for enabling or disabling AFR.
    *   The `lib/src/overlay/screens/components/setup_panel/settings_screen/player_settings_widget.dart` widget provides the user with a switch in the UI to control this setting.
2.  **Control:**
    *   When `isAfrEnabled` is `true`, `FrameRateManager` on the native side operates in automatic mode.
    *   When `isAfrEnabled` is `false`, automatic switching is disabled, and the user gets the option to **manually** select the screen's refresh rate.
3.  **Developer API:**
    *   The `FtvMedia3PlayerController` and `Media3UiController` controllers provide two methods for interacting with AFR:
        *   `Future<RefreshRateInfo> getRefreshRateInfo()`: Asynchronously returns a `RefreshRateInfo` object containing a list of supported refresh rates (`supportedRates`) and the currently active rate (`activeRate`).
        *   `Future<void> setManualFrameRate(double rate)`: Allows you to manually set the refresh rate. **This method will only work if AFR is disabled.**

### Usage

1.  **Automatic Mode:**
    *   Navigate to the player settings.
    *   Enable the "Auto Frame Rate (AFR)" switch.
    *   The player will automatically try to match the refresh rate to the content.

2.  **Manual Mode:**
    *   Ensure the "Auto Frame Rate (AFR)" switch is **disabled**.
    *   An active option for manual rate selection will appear in the settings menu.
    *   Call `getRefreshRateInfo()` to get a list of available rates and provide the user with a choice.
    *   Call `setManualFrameRate(rate)` to set the selected rate.


## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.