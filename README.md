# RtcRnnoise

**RtcRnnoise** is a high-performance, industrial-grade AI noise reduction plugin specifically designed for [Flutter WebRTC](https://github.com/flutter-webrtc/flutter-webrtc). 

It leverages the [RNNoise](https://github.com/xiph/rnnoise) C core and achieves ultra-low latency audio enhancement through **Native Injection** into the WebRTC processing pipeline.

## 🌟 Key Features

*   **Native-Level Performance**: Processing occurs entirely within the C++ layer, bypassing the Flutter UI thread for zero perceived latency.
*   **Mathematical Sample Alignment**: Designed for 10ms frame processing to perfectly align with WebRTC's internal engine.
*   **Zero-Copy RingBuffer**: Eliminates the overhead and latency of traditional RingBuffers by processing audio frames directly in-place.
*   **Intelligent Auto-Adaptation**: Seamlessly handles Float32/Int16 formats and various sample rates (optimized for 48kHz).
*   **Real-time VAD Feedback**: Provides AI-based Voice Activity Detection (VAD) probability, allowing for dynamic UI indicators.
*   **Dry/Wet Mix Control**: Tune the suppression intensity (0.0 to 1.0) to balance noise removal with natural voice quality.

## 📊 Platform Support

| Platform | Status | Implementation Detail |
| :--- | :--- | :--- |
| **Android** | ✅ Stable | Native JNI Injection into `AudioProcessingAdapter`. |
| **iOS** | 🛠️ In Progress | Architecture defined; awaiting full platform-specific implementation. |

---

## 🚀 Integration Guide

### 1. Installation

Add the plugin to your `pubspec.yaml`:

```yaml
dependencies:
  rtc_rnnoise:
    git:
      url: https://github.com/your-repo/rtc_rnnoise.git
      ref: main
```

### 2. Android Configuration (Required)

To enable **Native Injection**, you must manually link the noise processor to the WebRTC engine in your `MainActivity.kt`.

```kotlin
import com.rtc.rnnoise.RnnoiseProcessor
import com.rtc.rnnoise.rtc_rnnoise.RtcRnnoisePlugin
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.audio.AudioProcessingAdapter
import java.nio.ByteBuffer

class MainActivity : FlutterActivity(), RtcRnnoisePlugin.AttachProvider {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register this activity as the provider for 'attach' calls
        RtcRnnoisePlugin.attachProvider = this
    }

    /**
     * Implementation of RtcRnnoisePlugin.AttachProvider.
     * This is called when RtcRnnoise.attach() is invoked in Dart.
     */
    override fun onAttach(): Boolean {
        val controller = FlutterWebRTCPlugin.sharedSingleton?.audioProcessingController ?: return false
        
        // Inject RnnoiseProcessor into the Capture Post-Processing node
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

### 3. WebRTC Constraints (Critical)

When requesting user media, you **must disable** WebRTC's built-in noise suppression to avoid "double-processing," which can cause robotic-sounding audio.

```dart
final Map<String, dynamic> constraints = {
  'audio': {
    'googNoiseSuppression': false, // Disable native NS
    'googEchoCancellation': true,  // Keep AEC enabled
    'echoCancellation': true,
  },
  'video': true,
};
```

---

## 🛠️ Dart API Usage

### Basic Setup
```dart
import 'package:rtc_rnnoise/rtc_rnnoise.dart';

// Initialize the native core
await RtcRnnoise.init();

// Attach to the WebRTC pipeline after getUserMedia()
bool attached = await RtcRnnoise.attach();
```

### Real-time Controls
```dart
// Enable or bypass noise reduction
await RtcRnnoise.setEnabled(true);

// Set suppression intensity (0.0 to 1.0)
await RtcRnnoise.setSuppressionLevel(0.8);
```

### Voice Activity Detection (VAD)
```dart
// Monitor real-time speech probability
RtcRnnoise.vadStream.listen((probability) {
  print("Voice Probability: ${(probability * 100).toStringAsFixed(1)}%");
});
```

---

## 📝 License

This project is licensed under the **BSD 3-Clause License**.

### Acknowledgments
This plugin incorporates the following open-source components:
*   **RNNoise**: Copyright (c) Xiph.Org Foundation.
*   **SpeexDSP**: Copyright (c) Xiph.Org Foundation.
