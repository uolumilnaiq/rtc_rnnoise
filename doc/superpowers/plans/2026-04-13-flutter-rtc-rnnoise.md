# Flutter WebRTC RNNoise 降噪插件实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 开发一个专为 WebRTC 优化的高性能、低延迟 AI 降噪插件，利用原生钩子实现通话降噪。

**Architecture:** 采用 C++ 核心算法引擎（RNNoise + SpeexDSP），通过原生层注入（Android JNI / iOS ObjC++）直接处理 WebRTC 的 10ms 音频帧，支持 Dry/Wet 混合和 VAD 输出。

**Tech Stack:** C++, RNNoise, SpeexDSP, Dart FFI, JNI, Objective-C++, Flutter, WebRTC.

---

### Task 1: C++ 核心引擎开发 (Core Engine)

**Files:**
- Create: `src/cpp/rnnoise_engine.h`
- Create: `src/cpp/rnnoise_engine.cpp`
- Create: `src/cpp/audio_utils.h`
- Create: `src/cpp/types.h`

- [ ] **Step 1: 定义核心结构体与接口**
创建 `types.h` 定义内存布局和格式。
```cpp
enum AudioFormat { FORMAT_INT16, FORMAT_FLOAT32 };
enum MemoryLayout { LAYOUT_INTERLEAVED, LAYOUT_NON_INTERLEAVED };
typedef struct {
    void* interleaved_data;
    void** non_interleaved_data;
} AudioBufferPtr;
```

- [ ] **Step 2: 实现 C++ 引擎类框架**
在 `rnnoise_engine.cpp` 中实现初始化、对齐内存分配。使用 `posix_memalign` 确保 32 字节对齐。

- [ ] **Step 3: 集成 SpeexDSP 重采样逻辑**
实现双向重采样：输入采样率 -> 48kHz (RNNoise) -> 原始采样率。确保 10ms 帧直通。

- [ ] **Step 4: 实现 RNNoise 处理与相位对齐**
实现延迟线（Delay Line）补偿 RNNoise 的算法延迟，并进行 Dry/Wet Mix。

- [ ] **Step 5: 添加整型溢出保护 (Clamping)**
在写回内存前执行 `std::max(-32768.0f, std::min(32767.0f, sample))`。

- [ ] **Step 6: 编写 C-API 导出函数**
导出 `rtc_rnnoise_create`, `rtc_rnnoise_process`, `rtc_rnnoise_destroy`。

---

### Task 2: Android 原生注入实现 (JNI & Java)

**Files:**
- Modify: `android/src/main/cpp/CMakeLists.txt`
- Create: `android/src/main/java/com/rtc/rnnoise/RnnoiseProcessor.java`
- Create: `android/src/main/cpp/jni_bridge.cpp`

- [ ] **Step 1: 配置 CMake 编译 RNNoise 和 SpeexDSP**
将源码加入编译链，生成 `.so` 库。

- [ ] **Step 2: 实现 Java 层的 Processor 接口**
实现 `org.webrtc.ExternalAudioFrameProcessing`。

- [ ] **Step 3: 编写 JNI 桥接代码**
将 Java 的 `ByteBuffer` 地址传给 C++ 引擎。

- [ ] **Step 4: 实现 Android 端的自动/手动挂载逻辑**
提供 `RnnoisePlugin.inject()` 静态方法，获取 `AudioProcessingController` 并挂载。

---

### Task 3: iOS 原生注入实现 (ObjC++)

**Files:**
- Modify: `ios/flutter_rtc_rnnoise.podspec`
- Create: `ios/Classes/RnnoiseProcessor.mm`
- Create: `ios/Classes/RnnoiseProcessor.h`

- [ ] **Step 1: 实现 RTCAudioCustomProcessingDelegate 协议**
创建 ObjC++ 类，处理 `RTCAudioBuffer`。

- [ ] **Step 2: 实现归一化缩放 (x32768)**
在调用 C++ 引擎前，将 iOS 的 float 数据乘以 32768。

- [ ] **Step 3: 实现 iOS 端的 Hook 逻辑**
通过 `LocalAudioTrack` 的 `addProcessing` 接口进行挂载。

---

### Task 4: Flutter 插件层与示例项目

**Files:**
- Modify: `lib/flutter_rtc_rnnoise.dart`
- Modify: `example/lib/main.dart`

- [ ] **Step 1: 封装 Dart API**
通过 `MethodChannel` 提供 `setEnabled` 和 `setSuppressionLevel` 接口。

- [ ] **Step 2: 编写示例项目**
集成 `flutter_webrtc`，在通话中演示降噪效果，并展示 VAD 概率 UI。

- [ ] **Step 3: 验证 WebRTC Constraints**
确保示例项目中显式关闭了 `googNoiseSuppression`。
