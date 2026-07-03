# FFmpegKit for iOS and macOS

[English](README.md)

本仓库是 FFmpegKit 的 Apple 平台分支，提供 **Swift API** + **C 桥接层**，用于在 iOS / macOS 上调用 FFmpeg / FFprobe。

- Swift Package 提供上层 API（`Sources/`）
- `Frameworks/` 随仓库分发 XCFramework，`Package.swift` 自动链接，无需手动拖 Framework
- 构建脚本可重新编译原生库并更新 `Frameworks/`

## 支持的平台

- iOS 真机：`arm64`
- iOS 模拟器：`arm64`、`x86_64`
- macOS：`arm64`、`x86_64`

不包含 Mac Catalyst、tvOS、Android、Linux、Flutter、React Native。

公开 API 保持原 FFmpegKit 的类名与调用风格（`FFmpegKit`、`FFprobeKit`、Session、回调、日志、统计、取消、媒体信息等）。原 Objective-C 实现已移除。

## 环境要求

- macOS + Xcode 及命令行工具
- `autoconf`、`automake`、`libtool`、`pkg-config`、`curl`、`git`、`cmake`、`nasm`
- 启用 `--full` 构建时还需要 `meson`
- 网络访问（下载 FFmpeg 及依赖库源码）

所有命令均在**仓库根目录**执行。

## 集成

在 Xcode 中添加本仓库为 Swift Package 依赖即可，`Frameworks/` 中的 8 个 XCFramework 由 Package 自动链接。

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

验证 Swift API：

```bash
swift test
```

## 重建原生库并更新 Frameworks/

修改 `apple/src/` 中的 C 代码、升级 FFmpeg 版本，或需要启用 x264 等可选编解码库时，需重新构建并将产物同步到 `Frameworks/` 后提交。

### 构建流程

```
./ios.sh   → prebuilt/bundle-apple-xcframework-ios/
./macos.sh → prebuilt/bundle-apple-xcframework-macos/
./apple.sh → prebuilt/bundle-apple-xcframework/
                ↓
cp 到 Frameworks/  → 提交 git
```

### 步骤 1：清理（可选）

```bash
./tools/clean.sh
```

删除 `prebuilt/`、`.tmp/`、`src/*`、`build.log` 及编译中间产物，不影响 `Sources/` 和 `Frameworks/`。

### 步骤 2：构建

**默认构建**（仅 FFmpeg 核心，LGPL）：

```bash
./ios.sh
./macos.sh
./apple.sh
```

**完整构建**（含 GPL 库如 x264；iOS 与 macOS 必须使用相同的外部库参数）：

```bash
./ios.sh --full --enable-gpl
./macos.sh --full --enable-gpl
./apple.sh
```

更多选项：`./ios.sh --help`、`./macos.sh --help`

### 步骤 3：同步到 Frameworks/

```bash
cp -R prebuilt/bundle-apple-xcframework/*.xcframework Frameworks/
```

确认 8 个 xcframework 齐全：`ffmpegkit`、`libavcodec`、`libavdevice`、`libavfilter`、`libavformat`、`libavutil`、`libswresample`、`libswscale`

### 步骤 4：验证并提交

```bash
swift build && swift test
git add Frameworks/
git commit -m "Update XCFrameworks after native rebuild"
```

### 一键脚本（默认构建）

```bash
./ios.sh && ./macos.sh && ./apple.sh && \
cp -R prebuilt/bundle-apple-xcframework/*.xcframework Frameworks/ && \
swift build && swift test
```

### 常见问题

| 问题 | 处理 |
|------|------|
| `./apple.sh` 报错找不到 Framework | 确认 `ios.sh` 和 `macos.sh` 均已成功，且外部库选项一致 |
| 只想更新某一个库 | 不支持；需完整重跑三步构建 |
| `src/` 是什么 | 构建时下载的 FFmpeg 等源码缓存，可删 |
| `prebuilt/` vs `Frameworks/` | `prebuilt/` 本地构建输出（git 忽略）；`Frameworks/` 提交到仓库供 SPM 分发 |
| 修改了 `apple/src/*.c` | 重跑步骤 2–4 |
| macOS 内置库参数 | 使用 `--enable-macos-*`；iOS 使用 `--enable-ios-*`，不能混用 |

## 视频 / 音频转换应用完整构建

适用于同时发布 **iOS + macOS** 的视频转换、音频转换类 App。启用 x264（H.264 软编）、常见音频编解码器（lame、opus、vorbis 等，由 `--full` 提供）及 Apple 硬件加速（VideoToolbox）。

### 编解码能力说明

| 类别 | 构建参数 | 典型用途 |
|------|----------|----------|
| H.264 软编 | `--enable-gpl --enable-x264` | `-c:v libx264` |
| H.264 硬编/硬解 | `--enable-*-videotoolbox` | `-c:v h264_videotoolbox` |
| MP3 / Opus / Vorbis 等 | `--full`（已含 lame、opus、libvorbis 等） | `-c:a libmp3lame`、`-c:a libopus` |
| 系统音视频 I/O | `--enable-*-audiotoolbox`、`--enable-*-avfoundation` | 麦克风、相机、系统音频 |

> `--enable-macos-coreimage`、`--enable-macos-opencl`、`--enable-macos-opengl` 仅 macOS 可选；iOS 无对应参数。

### 完整构建步骤

在仓库根目录依次执行：

```bash
# 1. 可选：清理旧产物
./tools/clean.sh

# 2. 构建 macOS
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

# 3. 构建 iOS（外部库参数须与 macOS 一致；内置库使用 ios-* 前缀）
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

# 4. 合并为全平台 XCFramework
./apple.sh

# 5. 同步到 SPM 目录
cp -R prebuilt/bundle-apple-xcframework/*.xcframework Frameworks/

# 6. 验证
swift build && swift test

# 7. 提交（如需更新仓库中的二进制）
git add Frameworks/
git commit -m "Update XCFrameworks for video/audio conversion (full + GPL + x264)"
```

iOS 构建通常最耗时（1–3 小时或更长），请保持网络畅通。

### 构建后如何在 App 中使用

**视频转 H.264（软编）：**

```swift
FFmpegKit.execute("-i input.mov -c:v libx264 -preset medium -crf 23 -c:a aac output.mp4")
```

**视频转 H.264（硬件编码）：**

```swift
FFmpegKit.execute("-i input.mov -c:v h264_videotoolbox -b:v 5M -c:a aac output.mp4")
```

**音频转 MP3：**

```swift
FFmpegKit.execute("-i input.wav -c:a libmp3lame -b:a 192k output.mp3")
```

**音频转 Opus：**

```swift
FFmpegKit.execute("-i input.wav -c:a libopus -b:a 128k output.opus")
```

**仅改封装（不重新编码，速度最快）：**

```swift
FFmpegKit.execute("-i input.mkv -c copy output.mp4")
```

### 集成到多个 App

1. 视频转换 App、音频转换 App 均添加本仓库为 Swift Package 依赖（共用同一套 `Frameworks/`）
2. `import ffmpegkit` 即可，无需手动链接 XCFramework
3. 更新 `Frameworks/` 后，在 Xcode 中 **Reset Package Caches** 或更新依赖版本

### 许可证提醒

启用 `--enable-gpl` 与 x264 后，**App 分发须遵守 GPL**（通常要求开源或按 GPL 条款处理）。若某个 App 不能接受 GPL，需单独构建不含 x264 的变体（去掉 `--enable-gpl --enable-x264`）。

## 目录结构

```
ffmpeg-kit/
├── Package.swift              # Swift Package（含 binaryTarget）
├── Frameworks/                # 随仓库分发的 XCFramework（约 70MB+，完整构建更大）
├── README.md / README.zh.md   # 英文 / 中文文档
├── LICENSE
├── ios.sh / macos.sh / apple.sh
│
├── Sources/                   # Swift Package 源码
├── Tests/                     # 单元测试
├── apple/                     # 原生 C 核心（fftools + 运行时）
├── scripts/                   # 构建脚本
├── tools/                     # 构建辅助
│
├── src/                       # 构建时下载的第三方源码（不提交）
└── prebuilt/                  # 本地构建输出（不提交）
```

## 目录与文件说明

### 根目录

| 文件 | 作用 |
|------|------|
| `Package.swift` | 定义 `ffmpegkit`、`CFFmpegBridge` 模块；通过 `binaryTarget` 引用 `Frameworks/` |
| `ios.sh` | iOS 构建入口（arm64 真机 + 模拟器） |
| `macos.sh` | macOS 构建入口（arm64 + x86_64） |
| `apple.sh` | 合并 iOS + macOS 为全平台 XCFramework |
| `.gitignore` | 忽略 `.build/`、`.tmp/`、`prebuilt/`、`src/*` 等 |

### Sources/ — Swift API

| 文件 | 作用 |
|------|------|
| `FFmpegKit.swift` | FFmpeg 执行：`execute`、`executeAsync`、取消 |
| `FFprobeKit.swift` | FFprobe 执行、媒体信息获取 |
| `FFmpegKitConfig.swift` | 全局配置、日志重定向、会话管理 |
| `Session.swift` | 会话协议与 `FFmpegSession`、`FFprobeSession` |
| `Execution.swift` | 原生执行后端 |
| `MediaInformation.swift` | 媒体信息解析 |
| `Types.swift` | `ReturnCode`、`Log`、`Statistics` 等类型 |
| `Support.swift` | 内部辅助函数 |
| `CFFmpegBridge/` | C 桥接层，通过 `dlsym` 调用原生库 |

### apple/src/ — 原生 C 核心

| 文件 | 作用 |
|------|------|
| `ffmpegkit_runtime.c` | 运行时：会话 ID、取消、信号处理、日志转发 |
| `ffmpegkit_exception.h` | `longjmp` 异常处理 |
| `fftools_ffmpeg.c` | 导出 `ffmpeg_execute()` |
| `fftools_ffprobe.c` | 导出 `ffprobe_execute()` |
| `fftools_*.c` | FFmpeg 命令行工具源码 |

### Frameworks/ — SPM 二进制

| XCFramework | 作用 |
|-------------|------|
| `ffmpegkit.xcframework` | FFmpeg/FFprobe 命令执行核心 |
| `libavcodec.xcframework` | 编解码 |
| `libavformat.xcframework` | 封装格式 |
| `libavutil.xcframework` | 工具函数 |
| `libavfilter.xcframework` | 滤镜 |
| `libavdevice.xcframework` | 设备 I/O |
| `libswresample.xcframework` | 音频重采样 |
| `libswscale.xcframework` | 图像缩放 |

每个 XCFramework 含三个 slice：`ios-arm64`、`ios-arm64_x86_64-simulator`、`macos-arm64_x86_64`。

### scripts/ — 构建脚本

| 文件 | 作用 |
|------|------|
| `variable.sh` / `function.sh` | 全局变量与通用函数 |
| `function-ios.sh` / `function-macos.sh` | 平台专属编译配置 |
| `main-ios.sh` / `main-macos.sh` | 单架构构建主流程 |
| `source.sh` | 各库 Git 仓库地址与版本 |
| `apple/*.sh` | 各依赖库的编译脚本（`ffmpeg.sh`、`x264.sh` 等） |

### tools/ — 构建辅助

| 路径 | 作用 |
|------|------|
| `clean.sh` | 清理构建产物 |
| `apple/strip-frameworks.sh` | Xcode 剥离 Framework 多余架构 |
| `license/`、`source/` | GPL 合规文件 |
| `patch/` | 第三方库在 Apple 平台的构建补丁 |

### src/ 与 prebuilt/

- **`src/`**：构建时从 GitHub 下载的 FFmpeg 等源码缓存，不提交 git
- **`prebuilt/`**：本地构建中间产物与输出，不提交 git；最终复制到 `Frameworks/` 后提交

## 运行时调用链

```
Swift API → FFmpegKitConfig / Execution → CFFmpegBridge (dlsym)
    → libffmpegkit (ffmpeg_execute) → FFmpeg XCFrameworks
```

## 清理

```bash
./tools/clean.sh
```

## 许可证

默认构建为 LGPL 3.0。启用 `--enable-gpl` 编译 x264 等 GPL 库后，分发需遵守 GPL 要求。详见 [LICENSE](LICENSE)。