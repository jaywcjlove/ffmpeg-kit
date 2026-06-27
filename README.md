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

Rebuild when you change native C code in `apple/src/`, upgrade FFmpeg, or enable optional codecs like x264. Sync the output into `Frameworks/` and commit.

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

**Full build** (all optional libraries including GPL codecs; iOS and macOS must use matching flags):

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

## Project layout

```
ffmpeg-kit/
├── Package.swift              # Swift Package (with binaryTarget)
├── Frameworks/                # Committed XCFrameworks (~70MB)
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