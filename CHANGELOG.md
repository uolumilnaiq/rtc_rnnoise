## 0.2.0

* **Android 降噪方案重构**：从 `ExternalAudioFrameProcessing`（QMF 子带数据）切换为 `AudioBufferCallback` 注入点，在 QMF 之前处理完整宽带 PCM，彻底解决子带处理导致的相位混叠问题。
* **Android 反射注入链**：通过 `FlutterWebRTCPlugin → methodCallHandler → audioDeviceModule → audioInput → audioBufferCallback` 注入，兼容 Android 12+ 的 `InaccessibleObjectException`，提供 `sun.misc.Unsafe` 降级路径。
* **Android 线程安全**：`RnnoiseProcessor` 使用 `AtomicLong` + `getAndSet(0)` CAS 防止音频线程与主线程 `release()` 并发导致的 use-after-free。
* **JNI 接口更新**：`nativeProcess` 返回值从 `void` 改为 `jfloat`，直接传回 VAD 概率值。
* **iOS 降噪保持不变**：通过 `capturePostProcessingAdapter` 注入，处理宽带浮点（Q15）信号，与本版 Android 方案对齐。
* **全平台重新编译**：Android（arm64-v8a / armeabi-v7a / x86_64）和 iOS（device arm64 / simulator arm64）均重新编译。

## 0.1.0

* **RNNoise Upgrade**: Updated core engine to **v0.2** (April 2024), featuring performance optimizations and improved AI models.
* **Option B (Binary Only)**: Shifted to pre-compiled binaries for much faster builds and smaller package size.
* **Android**: Includes `librtc_rnnoise.so` for `arm64-v8a`, `armeabi-v7a`, and `x86_64`.
* **iOS**: Includes `RtcRnnoiseNative.xcframework` for `arm64` (physical devices).
* Updated documentation with third-party library credits.
* Improved Native Injection logic for Flutter WebRTC.

## 0.0.1

* Initial development release.
