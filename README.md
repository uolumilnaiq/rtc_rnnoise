# rtc_rnnoise

一个专为 Flutter WebRTC 打造的工业级高性能 AI 降噪插件。基于 [RNNoise](https://github.com/xiph/rnnoise) 原生 C 内核，通过原生层注入（Native Injection）实现极致的低延迟音频增强。

## 🌟 核心特性

*   **极致性能**：在 C++ 层闭环处理，绕过 Flutter UI 线程，零延迟感知。
*   **数学级对齐**：直通 10ms 音频处理流，移除 RingBuffer 以消除额外延迟。
*   **智能适配**：自动识别 Float32/Int16 格式，完美兼容 WebRTC 多态数据流。
*   **AI 人声检测**：实时输出 VAD (Voice Activity Detection) 概率，支持 UI 联动。
*   **干湿混合**：支持降噪强度（Dry/Wet Mix）调节，平衡音质与降噪效果。

## 📊 平台支持状态

| 平台 | 状态 | 备注 |
| :--- | :--- | :--- |
| **Android** | ✅ 已验证 | 已在真机通过 WebRTC Loopback 测试，运行稳定。 |
| **iOS** | ⚠️ 待验证 | 代码架构已对齐，环境搭建已就绪，等待真机测试。 |

---

## 🚀 集成指南

### 1. 引用插件

在你的 `pubspec.yaml` 中添加引用：

```yaml
dependencies:
  rtc_rnnoise:
    git:
      url: https://github.com/你的用户名/rtc_rnnoise.git
      ref: main
```

### 2. Android 端配置 (必须)

由于该插件采用“原生注入”模式，你需要在宿主应用的 `MainActivity.kt` 中手动挂载处理器。

在 `MainActivity.kt` 中添加以下逻辑：

```kotlin
import com.rtc.rnnoise.RnnoiseProcessor
import com.rtc.rnnoise.rtc_rnnoise.RtcRnnoisePlugin
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.audio.AudioProcessingAdapter
import java.nio.ByteBuffer
import android.os.Handler
import android.os.Looper

class MainActivity: FlutterActivity() {
    private var rnnoiseProcessor: RnnoiseProcessor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 1. 初始化降噪处理器并关联到插件
        val processor = RnnoiseProcessor()
        rnnoiseProcessor = processor
        RtcRnnoisePlugin.activeProcessor = processor
        
        // 2. 轮询注入 WebRTC 音频管道 (Post-AEC 节点)
        val handler = Handler(Looper.getMainLooper())
        val runnable = object : Runnable {
            override fun run() {
                val controller = FlutterWebRTCPlugin.sharedSingleton?.audioProcessingController
                if (controller != null) {
                    controller.capturePostProcessing.addProcessor(object : AudioProcessingAdapter.ExternalAudioFrameProcessing {
                        override fun initialize(rate: Int, channels: Int) = processor.initialize(rate, channels)
                        override fun reset(rate: Int) = processor.reset(rate)
                        override fun process(bands: Int, frames: Int, buffer: ByteBuffer) = processor.process(bands, frames, buffer)
                    })
                    return 
                }
                handler.postDelayed(this, 1000)
            }
        }
        handler.post(runnable)
    }
}
```

### 3. WebRTC 调用约束 (关键)

在 Flutter 侧调用 `getUserMedia` 时，必须显式**关闭 WebRTC 原生降噪**，否则会产生双重处理导致的机械音。

```dart
final Map<String, dynamic> constraints = {
  'audio': {
    'googNoiseSuppression': false, // 必须设为 false
    'googEchoCancellation': true,  // 建议保留 AEC
    'echoCancellation': true,
  },
  'video': false,
};
```

---

## 🛠️ Dart API 示例

```dart
import 'package:rtc_rnnoise/rtc_rnnoise.dart';

// 初始化
await RtcRnnoise.init();

// 开启/关闭降噪
await RtcRnnoise.setEnabled(true);

// 调节强度 (0.0 ~ 1.0)
await RtcRnnoise.setSuppressionLevel(0.8);

// 监听实时人声检测 (VAD)
RtcRnnoise.vadStream.listen((vad) {
  print("当前人声概率: ${vad * 100}%");
});
```

---

## 📝 许可证 (License)

本项目采用 **BSD 3-Clause License**。

### 依赖项声明：
本插件包含了以下遵循 BSD 3-Clause 许可的开源组件：
*   **RNNoise**: Copyright (c) Xiph.Org Foundation.
*   **SpeexDSP**: Copyright (c) Xiph.Org Foundation.
