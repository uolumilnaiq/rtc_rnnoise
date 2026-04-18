# 方案设计文档：Flutter WebRTC 高性能 RNNoise 降噪库 (rtc_rnnoise) - v3.2 (最终发布版)

## 1. 项目背景与目标
为 Flutter WebRTC 提供工业级的 AI 降噪插件，基于 RNNoise v0.2 原生 C 内核，通过二进制分发实现极致的安装速度与跨平台兼容性。

### 核心设计原则 (v3.2)
*   **二进制分发 (Binary-Only)**：不向最终用户分发庞大的 C 源码，而是提供预编译的 `.so` (Android) 和 `XCFramework` (iOS)。
*   **10ms 帧直通 (Direct 10ms Flow)**：利用 WebRTC 严格的 10ms 步进，移除 RingBuffer 以消除算法延迟。
*   **SIMD 内存安全**：所有内部浮点缓存强制执行 32-byte 对齐，确保 ARM NEON 指令集安全。
*   **解耦式 Hook (Runtime Reflection)**：iOS 端通过 Objective-C Runtime 动态钩入 WebRTC 管道，避免物理依赖 WebRTC 源码或头文件。

## 2. 系统架构

### 2.1 核心数据流
```text
[ WebRTC Audio Thread ]
       |
[ Glue Code (JNI/ObjC) ] -> 调用动态库符号
       |
[ Pre-compiled Native Lib ]
    1. Resampling (10ms in -> 10ms out @ 48k)
    2. RNNoise Process (AI Model: v0.2)
    3. Delay Line Alignment
    4. Dry/Wet Mix
    5. Write Back to WebRTC Buffer
```

## 3. 关键工程实现

### 3.1 跨平台二进制封装
*   **Android**: 提供 `arm64-v8a`, `armeabi-v7a`, `x86_64` 三大架构的 `librtc_rnnoise.so`。
*   **iOS**: 提供 `RtcRnnoiseNative.xcframework`，内部集成 `iphoneos` (arm64) 与 `iphonesimulator` (M3 arm64) 静态库。

### 3.2 内存布局适配器 (`types.h`)
```cpp
typedef struct {
    void* interleaved_data;      // Android: int16_t* (Interleaved)
    void** non_interleaved_data; // iOS: float** (Non-interleaved pointers)
} AudioBufferPtr;
```

## 4. 接口与分发

### 4.1 分发规范
*   **仓库清理**：`src/cpp/third_party` 仅保留头文件，`.c/.cpp` 源码由维护者离线持有。
*   **配置文件**：
    *   `android/build.gradle`: 使用 `jniLibs.srcDirs`。
    *   `ios/rtc_rnnoise.podspec`: 使用 `s.vendored_frameworks`。

### 4.2 挂载策略
*   **Android**: 通过 `AttachProvider` 接口，在 `MainActivity` 中手动将 `RnnoiseProcessor` 注入 `capturePostProcessing`。
*   **iOS**: 利用插件单例，动态钩入 `FlutterWebRTCPlugin.sharedSingleton.audioManager.capturePostProcessingAdapter`。

## 5. 已知限制
*   **iOS 模拟器**：由于 WebRTC iOS SDK 的限制，虚拟音频驱动不触发自定义处理回调，因此模拟器下 VAD 无波动且无降噪效果。建议使用真机验证。
