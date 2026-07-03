# FFmpegKit for iOS and macOS

[中文文档](README.zh.md)

This fork builds FFmpegKit for iOS and macOS with a Swift API and a minimal C bridge to FFmpeg.

- Swift Package provides the public API (`Sources/`)
- `Frameworks/` ships XCFrameworks; `Package.swift` links them automatically — no manual framework dragging in Xcode
- Build scripts can rebuild native libraries and refresh `Frameworks/`

## Supported slices

- iOS device: `arm64`
- iOS simulator: `arm64`, `x86_64`
- macOS: `arm64`, `x86_64`

Mac Catalyst, tvOS, Android, Linux, Flutter and React Native are not included.

The public API keeps the original FFmpegKit class names and method style, including `FFmpegKit`, `FFprobeKit`, sessions, callbacks, logs, statistics, cancellation and media information. The previous Objective-C implementation has been removed.

## Requirements

- macOS with Xcode and the Xcode command-line tools
- `autoconf`, `automake`, `libtool`, `pkg-config`, `curl`, `git`, `cmake`, `nasm`
- `meson` when using `--full` builds
- Network access for downloading FFmpeg and optional library sources

Run every command from the repository root.

## Integration

Add this repository as a Swift Package dependency. The eight XCFrameworks in `Frameworks/` are linked automatically.

```swift
import ffmpegkit

let session = FFmpegKit.execute("-i input.mp4 output.mov")
if ReturnCode.isSuccess(session.getReturnCode()) {
    print(session.getOutput())
}

FFmpegKit.executeAsync("-i input.mp4 output.mov") { session in
    print(session.getReturnCode() as Any)
}

let information = FFprobeKit.getMediaInformation("input.mp4").getMediaInformation()
```

Validate the Swift API:

```bash
swift test
```

## Rebuilding Native Libraries

Rebuild when you change native C code in `apple/src/`, upgrade FFmpeg, or enable optional codecs. Sync the output into `Frameworks/` and commit.

### Build flow

```
./ios.sh   → prebuilt/bundle-apple-xcframework-ios/
./macos.sh → prebuilt/bundle-apple-xcframework-macos/
./apple.sh → prebuilt/bundle-apple-xcframework/
                ↓
copy to Frameworks/  →  commit
```

### Step 1: Clean (optional)

```bash
./tools/clean.sh
```

Removes `prebuilt/`, `.tmp/`, `src/*`, `build.log`, and compile artifacts. Does not affect `Sources/` or `Frameworks/`.

### Step 2: Build

**Default build** (FFmpeg core only, LGPL):

```bash
./ios.sh
./macos.sh
./apple.sh
```

**Full build** (all optional libraries including GPL codecs; iOS and macOS must use matching external-library flags):

```bash
./ios.sh --full --enable-gpl
./macos.sh --full --enable-gpl
./apple.sh
```

See `./ios.sh --help` and `./macos.sh --help` for more options.

### Step 3: Sync to Frameworks/

```bash
cp -R prebuilt/bundle-apple-xcframework/*.xcframework Frameworks/
```

Expect eight xcframeworks: `ffmpegkit`, `libavcodec`, `libavdevice`, `libavfilter`, `libavformat`, `libavutil`, `libswresample`, `libswscale`.

### Step 4: Verify and commit

```bash
swift build && swift test
git add Frameworks/
git commit -m "Update XCFrameworks after native rebuild"
```

### One-liner (default build)

```bash
./ios.sh && ./macos.sh && ./apple.sh && \
cp -R prebuilt/bundle-apple-xcframework/*.xcframework Frameworks/ && \
swift build && swift test
```

### FAQ

| Question | Answer |
|----------|--------|
| `./apple.sh` fails to find frameworks | Ensure `ios.sh` and `macos.sh` both succeeded with matching library options |
| Update a single library only | Not supported; rerun the full three-step build |
| What is `src/`? | Downloaded FFmpeg and dependency sources during build; safe to delete |
| `prebuilt/` vs `Frameworks/` | `prebuilt/` is local build output (gitignored); `Frameworks/` is committed for SPM |
| Changed `apple/src/*.c` | Rerun steps 2–4 |
| Apple built-in flags | Use `--enable-macos-*` on macOS and `--enable-ios-*` on iOS; do not mix prefixes |

## Full build for video / audio conversion apps

Use this when shipping **both iOS and macOS** video or audio conversion apps. Enables x264 (H.264 software encoding), common audio codecs via `--full` (lame, opus, vorbis, etc.), and Apple hardware acceleration (VideoToolbox).

### Codec coverage

| Category | Build flags | Typical usage |
|----------|-------------|---------------|
| H.264 software encode | `--enable-gpl --enable-x264` | `-c:v libx264` |
| H.264 hardware encode/decode | `--enable-*-videotoolbox` | `-c:v h264_videotoolbox` |
| MP3 / Opus / Vorbis, etc. | `--full` (includes lame, opus, libvorbis, etc.) | `-c:a libmp3lame`, `-c:a libopus` |
| System audio/video I/O | `--enable-*-audiotoolbox`, `--enable-*-avfoundation` | Microphone, camera, system audio |

> `--enable-macos-coreimage`, `--enable-macos-opencl`, and `--enable-macos-opengl` are macOS-only and optional. iOS has no matching flags.

### Complete build steps

Run from the repository root:

```bash
# 1. Optional: clean previous artifacts
./tools/clean.sh

# 2. Build macOS
./macos.sh \
  --enable-macos-videotoolbox \
  --enable-macos-avfoundation \
  --enable-macos-audiotoolbox \
  --enable-macos-bzip2 \
  --enable-macos-zlib \
  --enable-macos-libiconv \
  --enable-libvorbis \
  --enable-libtheora \
  --enable-opus \
  --enable-opencore-amr \
  --enable-libvpx \
  --enable-speex \
  --enable-lame \
  --enable-gpl --enable-x264

# 3. Build iOS (same external-library flags; use ios-* for Apple built-ins)
./ios.sh --full --enable-gpl --enable-x264 \
  --enable-ios-videotoolbox \
  --enable-ios-audiotoolbox \
  --enable-ios-avfoundation \
  --enable-ios-bzip2 \
  --enable-ios-zlib \
  --enable-ios-libiconv \
  --enable-libvorbis \
  --enable-libtheora \
  --enable-opus \
  --enable-opencore-amr \
  --enable-libvpx \
  --enable-speex \
  --enable-lame

# 4. Merge into universal XCFrameworks
./apple.sh

# 5. Sync into the SPM directory
cp -R prebuilt/bundle-apple-xcframework/*.xcframework Frameworks/

# 6. Verify
swift build && swift test

# 7. Commit (if updating binaries in the repo)
git add Frameworks/
git commit -m "Update XCFrameworks for video/audio conversion (full + GPL + x264)"
```

The iOS build is usually the longest step (often 1–3+ hours). Keep network access available.

### Usage in your apps

**Video to H.264 (software):**

```swift
FFmpegKit.execute("-i input.mov -c:v libx264 -preset medium -crf 23 -c:a aac output.mp4")
```

**Video to H.264 (hardware):**

```swift
FFmpegKit.execute("-i input.mov -c:v h264_videotoolbox -b:v 5M -c:a aac output.mp4")
```

**Audio to MP3:**

```swift
FFmpegKit.execute("-i input.wav -c:a libmp3lame -b:a 192k output.mp3")
```

**Audio to Opus:**

```swift
FFmpegKit.execute("-i input.wav -c:a libopus -b:a 128k output.opus")
```

**Remux only (no re-encode, fastest):**

```swift
FFmpegKit.execute("-i input.mkv -c copy output.mp4")
```

### Using in multiple apps

1. Add this repository as a Swift Package dependency in both your video and audio conversion apps (same `Frameworks/`)
2. `import ffmpegkit` — no manual XCFramework linking
3. After updating `Frameworks/`, **Reset Package Caches** in Xcode or bump the dependency

### Licensing note

With `--enable-gpl` and x264 enabled, **app distribution must comply with GPL** (typically requiring source disclosure or GPL-compliant distribution). If one app cannot accept GPL, build a separate variant without `--enable-gpl --enable-x264`.

## Project layout

```
ffmpeg-kit/
├── Package.swift              # Swift Package (with binaryTarget)
├── Frameworks/                # Committed XCFrameworks (~70MB+; larger with full builds)
├── README.md / README.zh.md   # English / Chinese docs
├── LICENSE
├── ios.sh / macos.sh / apple.sh
│
├── Sources/                   # Swift Package source
├── Tests/                     # Unit tests
├── apple/                     # Native C core (fftools + runtime)
├── scripts/                   # Build scripts
├── tools/                     # Build helpers
│
├── src/                       # Downloaded third-party sources (not committed)
└── prebuilt/                  # Local build output (not committed)
```

## Directory reference

### Root

| File | Purpose |
|------|---------|
| `Package.swift` | Defines `ffmpegkit` and `CFFmpegBridge`; references `Frameworks/` via `binaryTarget` |
| `ios.sh` | iOS build entry (arm64 device + simulators) |
| `macos.sh` | macOS build entry (arm64 + x86_64) |
| `apple.sh` | Merges iOS + macOS into universal XCFrameworks |
| `.gitignore` | Ignores `.build/`, `.tmp/`, `prebuilt/`, `src/*`, etc. |

### Sources/ — Swift API

| File | Purpose |
|------|---------|
| `FFmpegKit.swift` | FFmpeg execution: `execute`, `executeAsync`, cancel |
| `FFprobeKit.swift` | FFprobe execution and media information |
| `FFmpegKitConfig.swift` | Global config, log redirection, session management |
| `Session.swift` | Session protocol; `FFmpegSession`, `FFprobeSession` |
| `Execution.swift` | Native execution backend |
| `MediaInformation.swift` | Media info parsing |
| `Types.swift` | `ReturnCode`, `Log`, `Statistics`, etc. |
| `Support.swift` | Internal helpers |
| `CFFmpegBridge/` | C bridge; calls native symbols via `dlsym` |

### apple/src/ — Native C core

| File | Purpose |
|------|---------|
| `ffmpegkit_runtime.c` | Runtime: session ID, cancel, signal handling, log forwarding |
| `ffmpegkit_exception.h` | `longjmp` exception handling |
| `fftools_ffmpeg.c` | Exports `ffmpeg_execute()` |
| `fftools_ffprobe.c` | Exports `ffprobe_execute()` |
| `fftools_*.c` | FFmpeg command-line tool sources |

### Frameworks/ — SPM binaries

| XCFramework | Purpose |
|-------------|---------|
| `ffmpegkit.xcframework` | FFmpeg/FFprobe command core |
| `libavcodec.xcframework` | Codecs |
| `libavformat.xcframework` | Container formats |
| `libavutil.xcframework` | Utilities |
| `libavfilter.xcframework` | Filters |
| `libavdevice.xcframework` | Device I/O |
| `libswresample.xcframework` | Audio resampling |
| `libswscale.xcframework` | Image scaling |

Each XCFramework contains three slices: `ios-arm64`, `ios-arm64_x86_64-simulator`, `macos-arm64_x86_64`.

### scripts/ — Build scripts

| File | Purpose |
|------|---------|
| `variable.sh` / `function.sh` | Global variables and shared functions |
| `function-ios.sh` / `function-macos.sh` | Platform-specific compile settings |
| `main-ios.sh` / `main-macos.sh` | Per-architecture build pipeline |
| `source.sh` | Git repos and versions for each library |
| `apple/*.sh` | Per-library build scripts (`ffmpeg.sh`, `x264.sh`, etc.) |

### tools/ — Build helpers

| Path | Purpose |
|------|---------|
| `clean.sh` | Remove build artifacts |
| `apple/strip-frameworks.sh` | Xcode script to strip extra architectures |
| `license/`, `source/` | GPL compliance files |
| `patch/` | Build patches for third-party libraries on Apple platforms |

### src/ and prebuilt/

- **`src/`**: Downloaded FFmpeg and dependency sources during build; not committed
- **`prebuilt/`**: Local build intermediates and output; not committed — copy to `Frameworks/` before committing

## Runtime call chain

```
Swift API → FFmpegKitConfig / Execution → CFFmpegBridge (dlsym)
    → libffmpegkit (ffmpeg_execute) → FFmpeg XCFrameworks
```

## Clean

```bash
./tools/clean.sh
```

## License

FFmpegKit is licensed under LGPL 3.0 by default. Enabling GPL libraries (e.g. x264 via `--enable-gpl`) changes distribution requirements. See [LICENSE](LICENSE) and the licenses of enabled dependencies before distribution.