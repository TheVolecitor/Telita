#!/bin/bash

# ==============================================================================
# MEDIA3 LIBS COMPLETE BUILDER (FFmpeg, AV1, VP9, IAMF, MPEG-H) - v 0.0.2
# ==============================================================================

set -euo pipefail

# ==============================================================================
# COLORS AND LOGGING FUNCTIONS
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ==============================================================================
# ARGUMENT PROCESSING
# ==============================================================================

FORCE_REBUILD=false
CLEAN_ALL=false
SKIP_GIT_UPDATE=false
VERBOSE=false

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -f, --force         Force rebuild everything (removes AAR and native libraries)
    -c, --clean         Full cleanup (including Git repositories, SDK, NDK)
    -s, --skip-update   Skip Git repository updates
    -v, --verbose       Verbose output
    -h, --help          Show this help

EXAMPLES:
    $0                       # Normal build
    $0 --force               # Rebuild AAR and FFmpeg
    $0 --clean               # Remove everything and build from scratch
    $0 --skip-update         # Quick build without Git updates

ENVIRONMENT VARIABLES:
    WORK_DIR                 Working directory (default: \$HOME/media3-build)
    ANDROID_SDK              Path to Android SDK (default: \$HOME/android-sdk)
    OUTPUT_COPY_PATH         Additional path for copying AAR
    BUILD_AV1=false          Don't build AV1 decoder
    BUILD_VP9=false          Don't build VP9 decoder
    BUILD_OPUS=false         Don't build Opus decoder
    BUILD_FLAC=false         Don't build FLAC decoder
    BUILD_IAMF=false         Don't build IAMF decoder
    BUILD_MPEGH=false        Don't build MPEG-H decoder

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force) FORCE_REBUILD=true; shift ;;
        -c|--clean) CLEAN_ALL=true; shift ;;
        -s|--skip-update) SKIP_GIT_UPDATE=true; shift ;;
        -v|--verbose) VERBOSE=true; set -x; shift ;;
        -h|--help) show_help ;;
        *)
            error "Unknown parameter: $1. Use --help for reference"
            ;;
    esac
done

# ==============================================================================
# CONFIGURATION
# ==============================================================================

BUILD_LOG="$HOME/media3-build.log"
rm -f "$BUILD_LOG"
exec > >(tee "$BUILD_LOG") 2>&1
echo "=== Build started: $(date) ==="

if [ "$EUID" -eq 0 ]; then
    error "Don't run this script with sudo! Just: ./$(basename "$0")"
fi

export WORK_DIR="${WORK_DIR:-$HOME/media3-build}"
export ANDROID_SDK="${ANDROID_SDK:-$HOME/android-sdk}"
export NDK_VERSION="27.0.12077973"
export NDK_PATH="$ANDROID_SDK/ndk/$NDK_VERSION"
export MEDIA3_PATH="$WORK_DIR/media"
export OUTPUT_AARS="$WORK_DIR/FINAL_AARS"

# OS detection
OS_NAME="$(uname -s)"
ARCH="$(uname -m)"

case "$OS_NAME" in
    Linux*)
        OS_TYPE="linux"
        NDK_HOST="linux-x86_64"
        SDK_TOOLS_SUFFIX="linux"
        ;;
    Darwin*)
        OS_TYPE="macos"
        [ "$ARCH" = "arm64" ] && NDK_HOST="darwin-arm64" || NDK_HOST="darwin-x86_64"
        SDK_TOOLS_SUFFIX="mac"
        ;;
    *)
        error "Unsupported OS: $OS_NAME. Supported: Linux, macOS"
        ;;
esac

log "Platform: $OS_TYPE ($ARCH), NDK: $NDK_HOST"

# Windows path (for WSL)
OUTPUT_COPY_PATH="${OUTPUT_COPY_PATH:-}"
if [ -z "$OUTPUT_COPY_PATH" ]; then
    if [ -d "/mnt/c" ]; then
        OUTPUT_COPY_PATH="/mnt/c/Media3_AAR_Builds"
    elif [ -d "/mnt/d" ]; then
        OUTPUT_COPY_PATH="/mnt/d/Media3_AAR_Builds"
    fi
fi

# FFmpeg parameters
FFMPEG_URL="https://git.ffmpeg.org/ffmpeg.git"
FFMPEG_BRANCH="release/6.0"
ENABLED_DECODERS=(vorbis opus flac alac pcm_mulaw pcm_alaw mp3 amrnb amrwb aac ac3 eac3 dca mlp truehd)

# Modules to build
BUILD_AV1="${BUILD_AV1:-true}"
BUILD_VP9="${BUILD_VP9:-true}"
BUILD_OPUS="${BUILD_OPUS:-true}"
BUILD_FLAC="${BUILD_FLAC:-true}"
BUILD_IAMF="${BUILD_IAMF:-true}"
BUILD_MPEGH="${BUILD_MPEGH:-true}"

# Cleanup handler
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        error "Build failed with error (code: $exit_code). Log: $BUILD_LOG"
    fi
}
trap cleanup EXIT

mkdir -p "$WORK_DIR" "$OUTPUT_AARS"

# ==============================================================================
# DECODER SETUP FUNCTIONS
# ==============================================================================

setup_av1_dependencies() {
    local av1_module="$MEDIA3_PATH/libraries/decoder_av1/src/main"
    local av1_jni="$av1_module/jni"

    mkdir -p "$av1_jni"
    cd "$av1_jni"

    # 1. Clone dav1d
    if [ ! -d "dav1d" ]; then
        log "Cloning dav1d 1.4.3..."
        git clone https://code.videolan.org/videolan/dav1d.git --branch 1.4.3 --depth 1
    fi

    # 2. Clone cpu_features
    if [ ! -d "cpu_features" ]; then
        log "Cloning cpu_features..."
        git clone https://github.com/google/cpu_features.git --depth 1
    fi

    # 3. FIX: Generate extended version.h for dav1d 1.4.3
    local version_h="dav1d/include/dav1d/version.h"
    log "Generating compatible version.h..."
    mkdir -p "$(dirname "$version_h")"
    cat > "$version_h" <<'EOF'
#ifndef DAV1D_VERSION_H
#define DAV1D_VERSION_H

#define DAV1D_API_VERSION_MAJOR 7
#define DAV1D_API_VERSION_MINOR 0
#define DAV1D_API_VERSION_PATCH 0

/* Macros expected by dav1d.c (extraction macros) */
#define DAV1D_API_MAJOR(v) (((v) >> 16) & 0xFF)
#define DAV1D_API_MINOR(v) (((v) >>  8) & 0xFF)
#define DAV1D_API_PATCH(v) (((v) >>  0) & 0xFF)

/* Variants with _VERSION_ for compatibility with other Media3 parts */
#define DAV1D_API_VERSION_MAJOR_OF(v) DAV1D_API_MAJOR(v)
#define DAV1D_API_VERSION_MINOR_OF(v) DAV1D_API_MINOR(v)
#define DAV1D_API_VERSION_PATCH_OF(v) DAV1D_API_PATCH(v)

#define DAV1D_API_VERSION_INT ((DAV1D_API_VERSION_MAJOR << 16) | \
                                (DAV1D_API_VERSION_MINOR <<  8) | \
                                (DAV1D_API_VERSION_PATCH <<  0))

#endif /* DAV1D_VERSION_H */
EOF
    ok "version.h updated"

    # 4. Meson crossfiles
    local cross_dir="dav1d/package/crossfiles"
    if [ ! -d "$cross_dir" ]; then
        mkdir -p "$cross_dir"
        create_meson_file() {
            cat > "$1" <<EOF
[binaries]
c = 'placeholder'
cpp = 'placeholder'
ar = 'placeholder'
strip = 'placeholder'
[host_machine]
system = 'android'
cpu_family = '$2'
cpu = '$3'
endian = 'little'
EOF
        }
        create_meson_file "$cross_dir/arm-android.meson" "arm" "armv7-a"
        create_meson_file "$cross_dir/aarch64-android.meson" "aarch64" "armv8-a"
        create_meson_file "$cross_dir/x86-android.meson" "x86" "i686"
        create_meson_file "$cross_dir/x86_64-android.meson" "x86_64" "x86-64"
    fi

    # 5. Compile dav1d
    if [ ! -f "nativelib/arm64-v8a/libdav1d.a" ]; then
        log "Compiling dav1d..."
        rm -rf /tmp/meson-* 2>/dev/null || true

        if [ -f "build_dav1d.sh" ]; then
            dos2unix build_dav1d.sh 2>/dev/null || true
            chmod +x build_dav1d.sh
            local full_module_path=$(realpath "$av1_module")
            ./build_dav1d.sh "$full_module_path" "$NDK_PATH" "$NDK_HOST"
        fi

        if [ ! -f "nativelib/arm64-v8a/libdav1d.a" ]; then
             error "dav1d compilation succeeded by code, but libdav1d.a not found."
        fi
    fi

    ok "AV1 decoder configured"
}

setup_vp9_dependencies() {
    local vp9_module="$MEDIA3_PATH/libraries/decoder_vp9/src/main"
    local vp9_jni="$vp9_module/jni"
    local libvpx_dir="$vp9_jni/libvpx"

    mkdir -p "$vp9_jni"
    cd "$vp9_jni" || exit 1

    # ------------------------------------------------------------------
    # Clone libvpx
    # ------------------------------------------------------------------
    if [ ! -d "$libvpx_dir" ]; then
        log "Cloning libvpx v1.14.1"
        git clone https://chromium.googlesource.com/webm/libvpx \
            --branch v1.14.1 \
            --depth 1
    fi

    # ------------------------------------------------------------------
    # Android NDK toolchain
    # ------------------------------------------------------------------
    local TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/$NDK_HOST"
    export PATH="$TOOLCHAIN/bin:$PATH"

    local API=21
    mkdir -p "$vp9_jni/nativelib"

    # ------------------------------------------------------------------
        # Build function for libvpx
        # ------------------------------------------------------------------
        build_vpx() {
            local abi=$1
            local target=$2
            local triple=$3
            local cpu=$4
            local enable_asm=$5

            log "Building libvpx for $abi"

            local build_dir="$vp9_jni/build-$abi"
            rm -rf "$build_dir"
            mkdir -p "$build_dir"
            cd "$build_dir" || exit 1

            # Setup toolchain paths
            export CC="$TOOLCHAIN/bin/${triple}${API}-clang"
            export CXX="$TOOLCHAIN/bin/${triple}${API}-clang++"
            export AR="$TOOLCHAIN/bin/llvm-ar"
            export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
            export STRIP="$TOOLCHAIN/bin/llvm-strip"
            export NM="$TOOLCHAIN/bin/llvm-nm"

            # FIX: Add "-c" to the assembler (AS).
            # Prevents "undefined symbol: main" error in NDK 27+
            export AS="$TOOLCHAIN/bin/${triple}${API}-clang -c"

            # Setup assembly flags based on architecture
            local ASM_FLAGS=""
            if [ "$enable_asm" = "no" ]; then
                if [[ "$abi" == "x86" ]] || [[ "$abi" == "x86_64" ]]; then
                    # libvpx uses specific flags to disable x86 optimizations
                    ASM_FLAGS="--disable-mmx --disable-sse --disable-sse2 --disable-sse3 --disable-ssse3 --disable-sse4_1 --disable-avx --disable-avx2 --disable-avx512"
                else
                    # For other architectures, this is the generic way to reduce optimizations
                    ASM_FLAGS="--disable-optimizations"
                fi
            elif [ "$abi" = "armeabi-v7a" ]; then
                # Fix for ARMv7: disable standalone NEON assembly but keep C intrinsics
                ASM_FLAGS="--disable-neon-asm"
            fi

            # Run libvpx configure script
            CROSS="$TOOLCHAIN/bin/" \
            CFLAGS="-fPIC" \
            "$libvpx_dir/configure" \
                --target="$target" \
                --libc="$TOOLCHAIN/sysroot" \
                --disable-examples \
                --disable-unit-tests \
                --disable-tools \
                --disable-docs \
                --disable-shared \
                --enable-static \
                --enable-pic \
                --enable-vp8 \
                --enable-vp9 \
                --enable-realtime-only \
                --size-limit=16384x16384 \
                --cpu="$cpu" \
                $ASM_FLAGS

            # Perform the build
            make clean || true

            # CPU count detection for Linux & macOS
            local JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
            make -j"$JOBS"

            # Validation and deployment
            mkdir -p "$vp9_jni/nativelib/$abi"
            if [ -f "libvpx.a" ]; then
                cp libvpx.a "$vp9_jni/nativelib/$abi/"
                ok "libvpx.a successfully built for $abi"
            else
                error "Build finished but libvpx.a not found for $abi"
            fi

            cd "$vp9_jni" || exit 1
        }

        # ------------------------------------------------------------------
        # ABI matrix (Media3-safe execution)
        # ------------------------------------------------------------------

        # ARM64: Safe to use full assembly
        build_vpx arm64-v8a  arm64-android-gcc   aarch64-linux-android   cortex-a57  yes

        # ARMv7: Use "yes" here because build_vpx() will automatically
        # handle --disable-neon-asm for stability while keeping C-optimizations.
        build_vpx armeabi-v7a armv7-android-gcc  armv7a-linux-androideabi cortex-a8  yes

        # x86/x86_64: Assembly disabled to avoid dependency on NASM/YASM in toolchain
        build_vpx x86     x86-android-gcc     i686-linux-android     atom    no
        build_vpx x86_64  x86_64-android-gcc  x86_64-linux-android  x86-64  no

    # ------------------------------------------------------------------
    # Validation
    # ------------------------------------------------------------------
    if [ ! -f "$vp9_jni/nativelib/arm64-v8a/libvpx.a" ]; then
        error "VP9 build failed"
    fi

    ok "VP9 decoder configured successfully"
}


setup_opus_dependencies() {
    local opus_module="$MEDIA3_PATH/libraries/decoder_opus/src/main"
    local opus_jni="$opus_module/jni"

    mkdir -p "$opus_jni"
    cd "$opus_jni"

    # Clone libopus
    if [ ! -d "libopus" ]; then
        log "Cloning libopus v1.5.2..."
        git clone https://gitlab.xiph.org/xiph/opus.git libopus --branch v1.5.2 --depth 1
    fi

    # Compile libopus for Android
    if [ ! -f "nativelib/arm64-v8a/libopus.a" ]; then
        log "Compiling libopus..."

        # Check if build script exists
        if [ -f "build_opus.sh" ]; then
            dos2unix build_opus.sh 2>/dev/null || true
            chmod +x build_opus.sh
            local full_module_path=$(realpath "$opus_module")
            ./build_opus.sh "$full_module_path" "$NDK_PATH" "$NDK_HOST"
        else
            # Manual build if script doesn't exist
            warn "build_opus.sh not found, attempting manual build..."

            local TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/$NDK_HOST"
            export PATH="$TOOLCHAIN/bin:$PATH"

            # Generate configure script if needed
            cd "$opus_jni/libopus"
            if [ ! -f "configure" ]; then
                log "Generating configure script for libopus..."
                ./autogen.sh
            fi
            cd "$opus_jni"

            build_opus_arch() {
                local abi=$1
                local api_level=21
                local host_triple=$2

                log "Building libopus for $abi..."

                local build_dir="$opus_jni/libopus-build-$abi"
                rm -rf "$build_dir"
                mkdir -p "$build_dir"
                cd "$build_dir"

                # Set compiler
                case "$abi" in
                    arm64-v8a)
                        export CC="$TOOLCHAIN/bin/aarch64-linux-android${api_level}-clang"
                        export CXX="$TOOLCHAIN/bin/aarch64-linux-android${api_level}-clang++"
                        ;;
                    armeabi-v7a)
                        export CC="$TOOLCHAIN/bin/armv7a-linux-androideabi${api_level}-clang"
                        export CXX="$TOOLCHAIN/bin/armv7a-linux-androideabi${api_level}-clang++"
                        ;;
                    x86)
                        export CC="$TOOLCHAIN/bin/i686-linux-android${api_level}-clang"
                        export CXX="$TOOLCHAIN/bin/i686-linux-android${api_level}-clang++"
                        ;;
                    x86_64)
                        export CC="$TOOLCHAIN/bin/x86_64-linux-android${api_level}-clang"
                        export CXX="$TOOLCHAIN/bin/x86_64-linux-android${api_level}-clang++"
                        ;;
                esac

                export AR="$TOOLCHAIN/bin/llvm-ar"
                export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
                export STRIP="$TOOLCHAIN/bin/llvm-strip"

                # Configure
                CFLAGS="-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
                CPPFLAGS="-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
                "$opus_jni/libopus/configure" \
                    --host="$host_triple" \
                    --disable-shared \
                    --enable-static \
                    --disable-doc \
                    --disable-extra-programs \
                    --enable-float-approx

                # Build
                make clean 2>/dev/null || true
                make -j$(nproc 2>/dev/null || echo 4)

                # Copy library
                mkdir -p "$opus_jni/nativelib/$abi"
                if [ -f ".libs/libopus.a" ]; then
                    cp .libs/libopus.a "$opus_jni/nativelib/$abi/"
                    ok "Built libopus.a for $abi"
                else
                    error "libopus.a not found for $abi"
                fi

                cd "$opus_jni"
            }

            # Build for all architectures
            build_opus_arch "arm64-v8a" "aarch64-linux-android"
            build_opus_arch "armeabi-v7a" "arm-linux-androideabi"
            build_opus_arch "x86" "i686-linux-android"
            build_opus_arch "x86_64" "x86_64-linux-android"
        fi

        if [ ! -f "nativelib/arm64-v8a/libopus.a" ]; then
            error "libopus compilation failed, library not found."
        fi
    fi

    ok "Opus decoder configured"
}

setup_flac_dependencies() {
    local flac_jni="$MEDIA3_PATH/libraries/decoder_flac/src/main/jni"
    mkdir -p "$flac_jni" && cd "$flac_jni"

    if [ ! -d "libflac" ]; then
        log "Cloning libflac 1.4.3..."
        git clone https://github.com/xiph/flac.git libflac --branch 1.4.3 --depth 1
    fi

    log "Applying NDK 27 Hard-Fix for FLAC (API 23 compatibility)..."

    # ПРАВИЛЬНИЙ ШЛЯХ: створюємо файл прямо всередині папки libflac
    cat > "libflac/flac_fix.cmake" <<EOF
add_definitions(-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64)
if(ANDROID_ABI STREQUAL "armeabi-v7a" OR ANDROID_ABI STREQUAL "x86")
    add_definitions(-Dfseeko=fseek -Dftello=ftell)
endif()
add_compile_options(-Wno-error=implicit-function-declaration)
EOF

    local cmake_file="libflac/CMakeLists.txt"

    # Вимикаємо асемблер
    sed -i 's/option(ENABLE_ASSEMBLY ".*" ON)/option(ENABLE_ASSEMBLY ".*" OFF)/g' "$cmake_file" || true

    # Вставляємо include (якщо його там ще немає)
    if ! grep -q "flac_fix.cmake" "$cmake_file"; then
        sed -i '2i include(${CMAKE_CURRENT_SOURCE_DIR}/flac_fix.cmake)' "$cmake_file"
    fi

    ok "FLAC patched successfully"
}

setup_iamf_dependencies() {
    local iamf_jni="$MEDIA3_PATH/libraries/decoder_iamf/src/main/jni"
    mkdir -p "$iamf_jni"
    cd "$iamf_jni"

    if [ ! -d "libiamf" ]; then
        git clone https://github.com/AOMediaCodec/libiamf.git --depth 1
    fi

    # CMake for IAMF
    local cmake_file="$MEDIA3_PATH/libraries/decoder_iamf/src/main/cpp/CMakeLists.txt"
    if [ ! -f "$cmake_file" ]; then
        mkdir -p "$(dirname "$cmake_file")"
        cat > "$cmake_file" <<'EOF'
cmake_minimum_required(VERSION 3.10.2)
project("iamf_jni")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(ANDROID)
    set(CMAKE_ANDROID_STL_TYPE c++_shared)
endif()
set(IAMF_ENABLE_TESTS OFF)
set(IAMF_ENABLE_EXAMPLES OFF)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../jni/libiamf)
add_library(iamf_jni SHARED iamf_jni.cc)
target_link_libraries(iamf_jni iamf log)
target_include_directories(iamf_jni PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../jni/libiamf/code/include)
EOF
    fi

    ok "IAMF decoder configured"
}

setup_mpegh_dependencies() {
    local mpegh_jni="$MEDIA3_PATH/libraries/decoder_mpegh/src/main/jni"
    mkdir -p "$mpegh_jni"
    cd "$mpegh_jni"

    if [ ! -d "libmpegh" ]; then
        git clone https://github.com/Fraunhofer-IIS/mpeghdec.git libmpegh --branch r2.0.0 --depth 1
    fi

    ok "MPEG-H decoder configured"
}

# ==============================================================================
# CLEANUP
# ==============================================================================

if [ "$CLEAN_ALL" = true ]; then
    warn "FULL CLEANUP MODE!"
    warn "Will be deleted: $WORK_DIR, $ANDROID_SDK, $OUTPUT_AARS"
    read -p "Continue? [y/N] " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$WORK_DIR" "$ANDROID_SDK" "$OUTPUT_AARS"
        mkdir -p "$WORK_DIR" "$OUTPUT_AARS"
        ok "Cleanup complete"
    else
        error "Cancelled by user"
    fi
fi

if [ "$FORCE_REBUILD" = true ]; then
    warn "FORCE REBUILD MODE!"
    rm -rf "$OUTPUT_AARS"/*.aar
    rm -rf "$MEDIA3_PATH"/libraries/decoder_ffmpeg/src/main/jni/ffmpeg/android-libs
    rm -rf "$MEDIA3_PATH"/.gradle "$MEDIA3_PATH"/build
    find "$MEDIA3_PATH"/libraries -type d -name "build" -exec rm -rf {} + 2>/dev/null || true
    ok "Cache cleared"
fi

# ==============================================================================
# TOOLS INSTALLATION
# ==============================================================================

log "Checking system tools..."

# Package manager
if command -v apt >/dev/null 2>&1; then
    PKG_MGR="apt"
    PKG_CMD="sudo apt update && sudo apt install -y"
    PKGS=(build-essential git wget unzip cmake ninja-build yasm nasm python3 python3-pip openjdk-17-jdk dos2unix meson pkg-config automake autoconf libtool libtool-bin gettext)
elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
    PKG_CMD="sudo dnf install -y"
    PKGS=(gcc gcc-c++ make git wget unzip cmake ninja-build yasm nasm python3 python3-pip java-17-openjdk-devel dos2unix meson pkgconfig automake autoconf libtool gettext)
elif command -v pacman >/dev/null 2>&1; then
    PKG_MGR="pacman"
    PKG_CMD="sudo pacman -Sy --noconfirm"
    PKGS=(base-devel git wget unzip cmake ninja yasm nasm python python-pip jdk17-openjdk dos2unix meson pkgconf automake autoconf libtool gettext)
elif command -v brew >/dev/null 2>&1; then
    PKG_MGR="brew"
    PKG_CMD="brew install"
    PKGS=(git wget cmake ninja yasm nasm python3 openjdk@17 dos2unix meson pkg-config automake autoconf libtool gettext)
else
    error "Package manager not found (apt/dnf/pacman/brew)"
fi

log "Package manager: $PKG_MGR"

MISSING=()
for p in "${PKGS[@]}"; do
    PKG_INSTALLED=false

    if [ "$PKG_MGR" = "brew" ]; then
        brew list "$p" &>/dev/null && PKG_INSTALLED=true
    elif [ "$PKG_MGR" = "pacman" ]; then
        pacman -Q "$p" &>/dev/null && PKG_INSTALLED=true
    else
        dpkg -s "$p" &>/dev/null 2>&1 && PKG_INSTALLED=true
    fi

    [ "$PKG_INSTALLED" = false ] && MISSING+=("$p")
done

if [ ${#MISSING[@]} -gt 0 ]; then
    log "Installing: ${MISSING[*]}"
    eval "$PKG_CMD ${MISSING[*]}"
fi

# Java check
if command -v java >/dev/null 2>&1; then
    JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
    [ "$JAVA_VER" -lt 17 ] && warn "Java < 17 (current: $JAVA_VER)"
fi

# ==============================================================================
# NDK SETUP
# ==============================================================================

log "Checking NDK: $NDK_PATH"
if [ -d "$NDK_PATH" ] && [ -f "$NDK_PATH/ndk-build" ]; then
    ok "NDK valid"
else
    log "Installing NDK..."
    mkdir -p "$ANDROID_SDK/cmdline-tools"

    if [ ! -d "$ANDROID_SDK/cmdline-tools/latest" ]; then
        SDK_URL="https://dl.google.com/android/repository/commandlinetools-${SDK_TOOLS_SUFFIX}-11076708_latest.zip"
        wget -q "$SDK_URL" -O /tmp/cmdline.zip
        unzip -q /tmp/cmdline.zip -d /tmp/
        mkdir -p "$ANDROID_SDK/cmdline-tools/latest"
        mv /tmp/cmdline-tools/* "$ANDROID_SDK/cmdline-tools/latest/"
        rm -rf /tmp/cmdline.zip /tmp/cmdline-tools
    fi

    set +o pipefail
    yes | "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_SDK" --licenses &>/dev/null || true
    set -o pipefail

    export JAVA_OPTS="-Xmx2048m"
    "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_SDK" "ndk;$NDK_VERSION"

    [ -f "$NDK_PATH/ndk-build" ] || error "NDK installed but invalid"
    ok "NDK installed"
fi

# ==============================================================================
# REPOSITORY CLONING
# ==============================================================================

smart_clone() {
    local name=$1 path=$2 url=$3 branch=$4

    if [ -d "$path/.git" ]; then
        if [ "$SKIP_GIT_UPDATE" = true ]; then
            ok "$name: skipping update"
        else
            cd "$path"
            git fetch --depth 1 origin "$branch" 2>/dev/null || warn "Failed to update $name"
            git reset --hard "origin/$branch" 2>/dev/null || true
            cd - >/dev/null
            ok "$name: updated"
        fi
    else
        log "Cloning $name..."
        rm -rf "$path"
        git clone --branch "$branch" --depth 1 "$url" "$path" 2>/dev/null || git clone --depth 1 "$url" "$path"
        ok "$name: cloned"
    fi
}

smart_clone "Media3" "$MEDIA3_PATH" "https://github.com/androidx/media.git" "release"
smart_clone "FFmpeg" "$WORK_DIR/ffmpeg" "$FFMPEG_URL" "$FFMPEG_BRANCH"

[ "$BUILD_AV1" = true ] && setup_av1_dependencies
[ "$BUILD_VP9" = true ] && setup_vp9_dependencies
[ "$BUILD_OPUS" = true ] && setup_opus_dependencies
[ "$BUILD_FLAC" = true ] && setup_flac_dependencies
[ "$BUILD_IAMF" = true ] && setup_iamf_dependencies
[ "$BUILD_MPEGH" = true ] && setup_mpegh_dependencies

# ==============================================================================
# FFmpeg BUILD
# ==============================================================================

JNI_FFMPEG="$MEDIA3_PATH/libraries/decoder_ffmpeg/src/main/jni"
mkdir -p "$JNI_FFMPEG"
cd "$JNI_FFMPEG"

# pkg-config fix for NDK 27
log "Configuring pkg-config for NDK..."
NDK_BIN="$NDK_PATH/toolchains/llvm/prebuilt/$NDK_HOST/bin"
SYS_PKG=$(which pkg-config 2>/dev/null || true)

if [ -n "$SYS_PKG" ]; then
    for prefix in arm64-linux-android armv7a-linux-androideabi i686-linux-android x86_64-linux-android; do
        TARGET_PKG="$NDK_BIN/${prefix}-pkg-config"
        if [ ! -f "$TARGET_PKG" ]; then
            ln -sf "$SYS_PKG" "$TARGET_PKG" 2>/dev/null || true
        fi
    done
fi

# Symlink FFmpeg
if [ ! -L ffmpeg ] || [ ! -e ffmpeg ]; then
    rm -f ffmpeg
    ln -sf "$WORK_DIR/ffmpeg" ffmpeg
fi

if [ ! -d "ffmpeg/android-libs" ] || [ "$(find ffmpeg/android-libs -name "libav*" 2>/dev/null | wc -l)" -eq 0 ]; then
    log "Building FFmpeg (10-20 min)..."

    [ -f build_ffmpeg.sh ] || error "build_ffmpeg.sh not found"
    dos2unix build_ffmpeg.sh 2>/dev/null || true

    # Patch for symlink
    if grep -q 'cd "${FFMPEG_MODULE_PATH}/jni/ffmpeg"' build_ffmpeg.sh; then
        sed -i.bak 's|cd "${FFMPEG_MODULE_PATH}/jni/ffmpeg"|cd "${FFMPEG_MODULE_PATH}"|g' build_ffmpeg.sh
    fi

    chmod +x build_ffmpeg.sh
    ./build_ffmpeg.sh "$WORK_DIR/ffmpeg" "$NDK_PATH" "$NDK_HOST" 21 "${ENABLED_DECODERS[@]}"

    # Verification
    LIBS=$(find ffmpeg/android-libs -name "libav*" 2>/dev/null | wc -l)
    [ "$LIBS" -eq 0 ] && error "FFmpeg libraries not created"
    ok "FFmpeg built ($LIBS files)"
else
    ok "FFmpeg already built"
fi

# ==============================================================================
# GRADLE BUILD
# ==============================================================================

cd "$MEDIA3_PATH"

# local.properties
cat > local.properties <<EOF
sdk.dir=$ANDROID_SDK
ndk.dir=$NDK_PATH
EOF

export ANDROID_HOME="$ANDROID_SDK"
export ANDROID_SDK_ROOT="$ANDROID_SDK"

chmod +x gradlew
./gradlew --version || error "Gradle not working"

# Modules - ДОДАНО :lib-decoder-flac ТА :lib-decoder-opus
GRADLE_MODULES=(":lib-decoder-ffmpeg")
[ "$BUILD_AV1" = true ] && GRADLE_MODULES+=(":lib-decoder-av1")
[ "$BUILD_VP9" = true ] && GRADLE_MODULES+=(":lib-decoder-vp9")
[ "$BUILD_OPUS" = true ] && GRADLE_MODULES+=(":lib-decoder-opus")
[ "$BUILD_FLAC" = true ] && GRADLE_MODULES+=(":lib-decoder-flac")
[ "$BUILD_IAMF" = true ] && GRADLE_MODULES+=(":lib-decoder-iamf")
[ "$BUILD_MPEGH" = true ] && GRADLE_MODULES+=(":lib-decoder-mpegh")

log "Building ${#GRADLE_MODULES[@]} modules..."

for gradle_mod in "${GRADLE_MODULES[@]}"; do
    # Convert :lib-decoder-ffmpeg → decoder_ffmpeg
    mod_name="${gradle_mod//:/}"
    mod_name="${mod_name//lib-/}"
    mod_name="${mod_name//-/_}"

    AAR_TARGET="$OUTPUT_AARS/${mod_name}-release.aar"

    if [ -f "$AAR_TARGET" ]; then
        ok "$mod_name: already built"
        continue
    fi

    log "Building $gradle_mod..."

    # Cleanup
    mod_dir="libraries/$mod_name"
    rm -rf "$mod_dir/build/outputs/aar" 2>/dev/null || true

# Gradle збірка з виправленням для fseeko/ftello та вимкненням ASM
./gradlew --no-daemon "${gradle_mod}:assembleRelease" \
        -Pandroid.native.build_arguments="-DENABLE_ASSEMBLY=OFF -DENABLE_ASM=OFF" \
        -Pandroid.native.cflags="-Wno-error=implicit-function-declaration -Dfseeko=fseek -Dftello=ftell" \
        || error "Build $gradle_mod failed"

    # Пошук AAR
    SRC_AAR=$(find "$mod_dir" -name "*-release.aar" -type f 2>/dev/null | head -n 1)

    if [ -n "$SRC_AAR" ] && [ -f "$SRC_AAR" ]; then
        cp "$SRC_AAR" "$AAR_TARGET"
        FILE_SIZE=$(du -h "$AAR_TARGET" | cut -f1)
        ok "✓ ${mod_name}-release.aar ($FILE_SIZE)"
    else
        warn "AAR not found for $gradle_mod"
        error "AAR build failed for $gradle_mod"
    fi
done

# ==============================================================================
# COPYING
# ==============================================================================

if [ -n "$OUTPUT_COPY_PATH" ]; then
    COPY_DIR=$(dirname "$OUTPUT_COPY_PATH" 2>/dev/null || echo "")
    if [ -n "$COPY_DIR" ] && [ -d "$COPY_DIR" ]; then
        mkdir -p "$OUTPUT_COPY_PATH"
        if cp "$OUTPUT_AARS"/*.aar "$OUTPUT_COPY_PATH/" 2>/dev/null; then
            ok "Copied to: $OUTPUT_COPY_PATH"
        fi
    fi
fi

# ==============================================================================
# SUMMARY
# ==============================================================================

echo ""
ok "════════════════════════════════════════"
ok "  BUILD COMPLETED!"
ok "════════════════════════════════════════"
echo ""
echo "📦 AAR files:"
ls -lh "$OUTPUT_AARS"/*.aar 2>/dev/null | awk '{print "   "$9" ("$5")"}' || echo "   No files"
echo ""
echo "🚀 Commands:"
echo "   $0 --help        # Help"
echo "   $0 --force       # Rebuild"
echo "   $0 --clean       # Full cleanup"
echo ""
echo "📋 Log: $BUILD_LOG"
echo "=== Completed: $(date) ==="