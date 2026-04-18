# RtcRnnoise

**RtcRnnoise** is a high-performance, industrial-grade AI noise reduction plugin specifically designed for [Flutter WebRTC](https://github.com/flutter-webrtc/flutter-webrtc). 

It leverages the [RNNoise](https://github.com/xiph/rnnoise) C core and achieves ultra-low latency audio enhancement through **Native Injection** into the WebRTC processing pipeline.

## 🌟 Key Features

*   **Pre-compiled Binaries**: Ship with optimized `.so` and `.a` files for all major architectures. No complex build setup required for end users.
*   **Native-Level Performance**: Processing occurs entirely within the C++ layer, bypassing the Flutter UI thread.
*   **Mathematical Sample Alignment**: Designed for 10ms frame processing to perfectly align with WebRTC's internal engine.
*   **Zero-Copy Direct Injection**: Injected into the `AudioProcessingAdapter` of WebRTC for the lowest possible latency.
*   **Real-time VAD Feedback**: Provides AI-based Voice Activity Detection (VAD) probability.
*   **Dry/Wet Mix Control**: Tune the suppression intensity (0.0 to 1.0).

## 🏛️ Third-party Libraries & Credits

This plugin is a bridge to high-quality open-source audio processing engines. We stand on the shoulders of giants:

| Library | Version / Commit | License | Role |
| :--- | :--- | :--- | :--- |
| **[RNNoise](https://github.com/xiph/rnnoise)** | `5a3a59e` (2024-03) | BSD 3-Clause | Core AI noise reduction & VAD engine. |
| **[SpeexDSP](https://github.com/xiph/speexdsp)** | `1.2.1` | BSD 3-Clause | Pre-processing, Resampling, and Gain control. |

---

## 🚀 Quick Start

### 1. Installation

```yaml
dependencies:
  rtc_rnnoise: ^0.1.0
```

### 2. Android Setup

In your `MainActivity.kt`:

```kotlin
class MainActivity : FlutterActivity(), RtcRnnoisePlugin.AttachProvider {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        RtcRnnoisePlugin.attachProvider = this
    }

    override fun onAttach(): Boolean {
        val controller = FlutterWebRTCPlugin.sharedSingleton?.audioProcessingController ?: return false
        val processor = RtcRnnoisePlugin.activeProcessor ?: RnnoiseProcessor()
        RtcRnnoisePlugin.activeProcessor = processor

        controller.capturePostProcessing.addProcessor(object : AudioProcessingAdapter.ExternalAudioFrameProcessing {
            override fun initialize(rate: Int, channels: Int) = processor.initialize(rate, channels)
            override fun reset(rate: Int) = processor.reset(rate)
            override fun process(bands: Int, frames: Int, buffer: ByteBuffer) = processor.process(bands, frames, buffer)
        })
        return true
    }
}
```

### 3. Usage

```dart
import 'package:rtc_rnnoise/rtc_rnnoise.dart';

await RtcRnnoise.init();
bool attached = await RtcRnnoise.attach(); // After getUserMedia()
await RtcRnnoise.setEnabled(true);
```

---

## 📝 License

This project is licensed under the **BSD 3-Clause License**.
