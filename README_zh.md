# RtcRnnoise

[English](README.md)

**RtcRnnoise** 是一个专为 [Flutter WebRTC](https://github.com/flutter-webrtc/flutter-webrtc) 设计的高性能 AI 降噪插件。

插件以 [RNNoise](https://github.com/xiph/rnnoise) C 核心为基础，通过**原生注入**到 WebRTC 音频采集管道实现超低延迟降噪——注入点位于 QMF（正交镜像滤波器）处理之前，确保 RNNoise 在 Android 和 iOS 上均能接收到真实宽带 PCM。

## 核心特性

- **预编译二进制** — 内置优化后的 `.so`（Android）和 `XCFramework`（iOS），无需本地编译源码。
- **原生层处理** — 音频处理完全在 C++ 层完成，不经过 Flutter UI 线程。
- **QMF 前注入** — 在 WebRTC QMF 子带分解之前截获音频，避免相位混叠失真。
- **实时 VAD** — 通过 `EventChannel` 提供 AI 语音活动检测概率。

## 平台支持

| 平台 | 状态 | 注入点 |
| :--- | :--- | :--- |
| **Android** | ✅ 稳定 | `AudioBufferCallback`（QMF 前宽带 PCM，通过反射注入） |
| **iOS** | ✅ 稳定 | `capturePostProcessingAdapter`（宽带浮点缓冲） |

> iOS Simulator 因 WebRTC SDK 限制不支持，需在真机验证。

## 第三方库

| 库 | 版本 | 许可证 | 用途 |
| :--- | :--- | :--- | :--- |
| [RNNoise](https://github.com/xiph/rnnoise) | v0.2 (2024-04) | BSD 3-Clause | AI 降噪 & VAD 引擎 |
| [SpeexDSP](https://github.com/xiph/speexdsp) | 1.2.1 | BSD 3-Clause | 重采样与增益控制 |

---

## 快速开始

### 1. 添加依赖

```yaml
dependencies:
  rtc_rnnoise: ^0.2.0
```

### 2. Android 配置 — `MainActivity.kt`

插件通过反射将 `AudioBufferCallback` 注入 WebRTC 音频采集链路，在 QMF 之前截获宽带 PCM。需在 `configureFlutterEngine` 中注册 `AttachProvider`：

```kotlin
import com.rtc.rnnoise.RnnoiseProcessor
import com.rtc.rnnoise.rtc_rnnoise.RtcRnnoisePlugin
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import org.webrtc.audio.JavaAudioDeviceModule
import java.lang.reflect.Field

class MainActivity : FlutterActivity() {
    private var rnnoiseProcessor: RnnoiseProcessor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val processor = RnnoiseProcessor()
        rnnoiseProcessor = processor
        RtcRnnoisePlugin.activeProcessor = processor

        RtcRnnoisePlugin.attachProvider = object : RtcRnnoisePlugin.AttachProvider {
            override fun onAttach(): Boolean = injectAudioBufferCallback(processor)
        }
    }

    private fun injectAudioBufferCallback(processor: RnnoiseProcessor): Boolean {
        return try {
            val plugin = FlutterWebRTCPlugin.sharedSingleton ?: return false
            val mhField = plugin.javaClass.getDeclaredField("methodCallHandler").apply { isAccessible = true }
            val methodHandler = mhField.get(plugin) ?: return false
            val admField = methodHandler.javaClass.getDeclaredField("audioDeviceModule").apply { isAccessible = true }
            val adm = admField.get(methodHandler) ?: return false
            val audioInput = adm.javaClass.getField("audioInput").get(adm) ?: return false
            val cbField = audioInput.javaClass.getDeclaredField("audioBufferCallback").apply { isAccessible = true }

            val callback = JavaAudioDeviceModule.AudioBufferCallback { buffer, _, channelCount, sampleRate, bytesRead, captureTimestampNs ->
                val safeChannels = channelCount.coerceAtLeast(1)
                processor.processPcmBuffer(buffer, sampleRate, safeChannels, bytesRead / (2 * safeChannels))
                captureTimestampNs
            }
            setFinalField(cbField, audioInput, callback)
            true
        } catch (e: Exception) {
            android.util.Log.e("RNNoise", "inject failed: ${e.message}")
            false
        }
    }

    private fun setFinalField(field: Field, target: Any, value: Any?) {
        try {
            field.set(target, value); return
        } catch (_: IllegalAccessException) {
        } catch (e: RuntimeException) {
            if (e.javaClass.name != "java.lang.reflect.InaccessibleObjectException") throw e
        }
        val unsafeClass = Class.forName("sun.misc.Unsafe")
        val unsafe = unsafeClass.getDeclaredField("theUnsafe").apply { isAccessible = true }.get(null)
        val offset = unsafeClass.getMethod("objectFieldOffset", Field::class.java).invoke(unsafe, field) as Long
        unsafeClass.getMethod("putObject", Any::class.java, Long::class.javaPrimitiveType, Any::class.java)
            .invoke(unsafe, target, offset, value)
    }

    override fun onDestroy() {
        RtcRnnoisePlugin.activeProcessor = null
        RtcRnnoisePlugin.attachProvider = null
        rnnoiseProcessor?.release()
        super.onDestroy()
    }
}
```

### 3. iOS 配置

无需额外原生代码。插件在 Dart 调用 `RtcRnnoise.attach()` 时自动注入到 WebRTC 的 `capturePostProcessingAdapter`。

### 4. Dart 使用

```dart
import 'package:rtc_rnnoise/rtc_rnnoise.dart';

// 在 getUserMedia() / createPeerConnection() 之后调用
await RtcRnnoise.init();
await RtcRnnoise.attach();
await RtcRnnoise.setEnabled(true);
await RtcRnnoise.setSuppressionLevel(0.75); // 0.0 – 1.0

// 监听 VAD 概率（0.0 – 1.0）
RtcRnnoise.vadStream.listen((vad) {
  print('VAD: $vad');
});
```

> **注意**：建议关闭 WebRTC 内置降噪和自动增益，避免干扰 RNNoise：
> ```dart
> mediaConstraints = {
>   'audio': {
>     'googNoiseSuppression': false,
>     'autoGainControl': false,
>   }
> };
> ```

---

## 许可证

BSD 3-Clause License。
