# flutter_tv_media3_example

Demonstrates how to use the flutter_tv_media3 plugin with comprehensive examples of all `PlaylistMediaItem` features.

## Example Structure

This example app showcases the following `PlaylistMediaItem` configurations:

### Video Examples
- **Basic Video** - Simple video playback with minimal configuration
- **Clipped Segment** - Video playback limited to a specific time range (10s-20s)
- **Full Metadata** - Complete video with all metadata fields and watch time saving
- **External Tracks** - Video with external subtitle and audio tracks
- **Multi-Quality** - Video with multiple resolution options
- **Dynamic Link (Success)** - Video that resolves URL dynamically with progress updates
- **Dynamic Link (Error)** - Video demonstrating error handling in URL resolution
- **Broken Link** - Video with invalid URL for error handling testing
- **VP9 Codec** - WebM/VP9 format video

### Audio Examples
- **Music Track** - Audio track with full metadata (artist, album, track info)

### TV Stream Examples
- **Live TV** - Live HLS stream with EPG support

## Key Features Demonstrated

- **MediaItemType**: Proper usage of `video`, `audio`, and `tvStream` types
- **Metadata**: Complete examples of title, subtitle, description, images
- **Audio Metadata**: Artist name, track name, album name, album year
- **Playback Control**: Start position, duration, watch time saving
- **Network**: HTTP headers, custom User-Agent
- **Quality Selection**: Multiple resolutions with automatic deduplication
- **External Tracks**: Subtitles and audio tracks with language codes
- **Dynamic URLs**: Async link resolution with progress callbacks
- **EPG**: Electronic Program Guide for TV streams
- **Preview Player**: Media3PreviewPlayer configuration for inline video

## Running the Example

```bash
cd example
flutter run
```

## Getting Started

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and an API reference.
