<div align="center">
  <h1>
    <img src="telita_logo.png" alt="Telita Logo" width="120" align="center" />
    &nbsp;Telita
  </h1>

  <b>A Cross-Platform Media Player Built for Performance!</b>
  <br/><br/>
  
  Offering a native player, torrent/p2p streaming, multi-profiles, and cloud sync. Built to deliver a consistent and premium media experience across desktop, mobile, and televisions.
  
  <br/><br/>

  <p>
    <img src="https://img.shields.io/badge/FLUTTER-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
    <img src="https://img.shields.io/badge/DART-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart" />
    <img src="https://img.shields.io/badge/GO-00ADD8?style=flat-square&logo=go&logoColor=white" alt="Go" />
    <img src="https://img.shields.io/badge/LICENSE-MIT-yellow?style=flat-square" alt="License" />
  </p>
  <p>
    <img src="https://img.shields.io/badge/WINDOWS-0078D6?style=flat-square&logo=windows&logoColor=white" alt="Windows" />
    <img src="https://img.shields.io/badge/ANDROID-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Android" />
    <img src="https://img.shields.io/badge/ANDROID_TV-073042?style=flat-square&logo=android&logoColor=white" alt="Android TV" />
  </p>
</div>

## Features

*   **Cross-Platform Support**: Works seamlessly on Windows, Android mobile, and Android TV.
*   **Torrent Streaming**: Built-in Go backend for fast, on-the-fly peer-to-peer media streaming.
*   **Stremio Addon Ecosystem**: Fully compatible with the Stremio addon architecture, allowing you to easily browse and stream community content.
*   **Cloud Sync**: Automatically syncs your watch history, playlists, and profiles across devices.
*   **Multi-Profile Support**: Create up to 5 individual user profiles under a single account.
*   **Stream Badges**: List key stream specfications in the stream list itself.
*   **Customizable UI**: Features a clean, dynamic interface with an OLED dark mode and advanced subtitle settings. Fully customizable UI coming soon.

## Development Notes

### Architecture Overview
The application consists of two main components:
1.  **Core (Go)**: A local streaming server and torrent client that handles heavy network operations and peer-to-peer logic.
2.  **Frontend (Flutter)**: The user interface and native media player implementation (utilizing media_kit).

### Building the Go Core
Before building the Flutter application, you must compile the native core binaries.

#### Windows (libcore.exe)
1. Ensure you have Go 1.22 or higher installed.
2. Navigate to the `core` directory.
3. Build the executable:
   ```bash
   go build -ldflags="-s -w" -o libcore.exe .
   ```

#### Android (libcore.so)
1. Ensure you have the Android NDK installed and configured.
2. Navigate to the `core` directory.
3. Build the shared library utilizing the NDK toolchain:
   ```bash
   CGO_ENABLED=1 CC=$NDK_PATH/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android33-clang go build -buildmode=c-shared -ldflags="-s -w" -o libcore.so android.go
   ```

#### Linux (libcore)
1. Ensure you have Go 1.22 or higher installed.
2. Navigate to the `core` directory.
3. Build the standalone executable:
   ```bash
   go build -ldflags="-s -w" -o libcore .
   ```

### Building the Flutter App
Once the core binaries are placed in their respective directories (the root directory for Windows, copied to the `build/linux/x64/release/bundle/` directory for Linux, and `android/app/src/main/jniLibs/arm64-v8a/` for Android), you can build the frontend.

1. Navigate to the `telita_flutter` directory.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Build the application for your target platform:
   ```bash
   # For Windows
   flutter build windows

   # For Linux
   flutter build linux

   # For Android
   flutter build apk
   ```

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Disclaimer

Telita is purely a media player software. The developers strictly condemn the streaming, downloading, or distribution of copyrighted media without permission. Users are solely responsible for the content they choose to access through this software. The developers of Telita do not endorse, promote, or facilitate piracy in any form.
