# RNNoise attach() 始终返回 false — 定位过程记录

日期：2026-04-16  
涉及工程：`rtc_apk_app`、`rtc-rnnoise`、`flutter_module`

---

## 问题现象

`MediaManager.createLocalStream()` 中循环调用 `RtcRnnoise.attach()` 最多 5 次，始终返回 `false`，降噪未生效。

---

## 第一层：日志完全不出现

**现象**：logcat 过滤 `RNNoise-Plugin` 后，`attach` 相关的诊断日志一条都没有。

**排查**：`onMethodCall("attach")` 中有 `Log.e("RNNoise-Plugin", "CRITICAL: onMethodCall received -> attach")`，如果连这条都没有，说明 MethodChannel 消息根本没有到达插件实例，或者日志 tag 对不上。

**根因 A（tag 不一致）**：早期部分诊断日志使用 tag `"RNNoise"` 而非 `"RNNoise-Plugin"`，导致过滤时漏掉。

**修复**：统一所有诊断日志使用 tag `"RNNoise-Plugin"`。

---

## 第二层：setupRnnoiseAttachProvider() 从未被调用

**现象**：补齐 tag 后，`CRITICAL: onMethodCall received -> attach` 出现了，但 `DIAG: onAttach() entered` 没有出现，说明 `attachProvider` 为 null，`onMethodCall` 走了 `attachProvider?.onAttach() ?: false` 的 `false` 分支。

**排查**：`attachProvider` 由 `FlutterEngineHolder.setupRnnoiseAttachProvider()` 设置，而该方法只在 `FlutterEngineHolder.getOrCreate()` 中调用。

**根因 B（debug 入口绕过了 FlutterEngineHolder）**：  
`MainActivity`（debug 入口）直接继承 `FlutterActivity`，`FlutterActivity.onCreate()` 自己创建了 Flutter 引擎，完全绕开了 `FlutterEngineHolder.getOrCreate()`，导致 `setupRnnoiseAttachProvider()` 从未执行，`attachProvider = null`。

**修复**：在 `MainActivity` 中重写 `provideFlutterEngine()` 返回 `FlutterEngineHolder.getOrCreate(context, "/")`, 并重写 `configureFlutterEngine()` 为空（防止插件被重复注册）。

```kotlin
override fun provideFlutterEngine(context: Context): FlutterEngine {
    return FlutterEngineHolder.getOrCreate(context, "/")
}
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    // 插件已在 FlutterEngineHolder.getOrCreate() 中注册，此处不调用 super
}
```

---

## 第三层：NullPointerException — methodCallHandler 为 null

**现象**：修复入口后，`DIAG: onAttach() entered` 和 `DIAG: sharedSingleton=true` 均出现，但随即抛出：

```
❌ FAIL: exception in onAttach: NullPointerException:
Attempt to read from field 'AudioProcessingController
MethodCallHandlerImpl.audioProcessingController' on a null object reference
```

**排查**：`FlutterWebRTCPlugin.getAudioProcessingController()` 内部访问 `methodCallHandler.audioProcessingController`。`methodCallHandler` 在 `onAttachedToEngine()` → `startListening()` 中赋值，但此时它为 null。

追溯原因：`FlutterWebRTCPlugin` 的构造函数中执行 `sharedSingleton = this`（赋值早于 `onAttachedToEngine()`）。

**根因 C（双重注册导致 sharedSingleton 指向残缺实例）**：  
`FlutterEngine(context.applicationContext)` 默认构造函数的第三个参数 `automaticallyRegisterPlugins = true`，会自动调用 `GeneratedPluginRegistrant.registerWith()`，此时创建了 `FlutterWebRTCPlugin` 实例 A，`sharedSingleton = A`，且 A 的 `methodCallHandler` 正常初始化。

随后 `FlutterEngineHolder.getOrCreate()` 又显式调用了一次 `GeneratedPluginRegistrant.registerWith(created)`，创建了实例 B → `sharedSingleton = B`（构造函数里赋值），但 `engine.plugins.add(B)` 因为插件已注册而失败，`B.onAttachedToEngine()` 从未调用，`B.methodCallHandler = null`。

之后 `sharedSingleton.getAudioProcessingController()` 访问的是 B，NPE。

**修复**：创建引擎时禁用自动注册，让注册只发生一次：

```kotlin
// 第三个参数 false = 禁用自动注册插件
val created = FlutterEngine(context.applicationContext, null, false)
```

---

## 第四个问题：关闭麦克风后 VAD 日志持续输出

**现象**：attach 成功后，关闭麦克风，但 `RNNoise_Status: VAD=0.89` 日志仍持续打印。

**根因**：`addProcessor()` 将 RNNoise 注入 WebRTC 的 `capturePostProcessing` 管道后从未移除。`stopLocalStream()` 只调用了 `track.stop()` 和 `stream.dispose()`，WebRTC 底层音频采集管道仍在运行，`process()` 持续被调用，VAD 事件持续上报。

**修复**：在 `stopLocalStream()` 中，检测到停止的流包含音频轨道时，调用 `RtcRnnoise.setEnabled(false)`：

```dart
if (hasAudio) {
  try {
    await RtcRnnoise.setEnabled(false);
  } catch (_) {}
}
```

重新开麦走 `createLocalStream()` 流程，其中已有 `RtcRnnoise.setEnabled(true)` 的调用，无需额外处理。

---

## 根因总结

| 层级 | 根因 | 修复位置 |
|------|------|----------|
| 1 | 日志 tag 不一致，诊断信息不可见 | `FlutterEngineHolder.setupRnnoiseAttachProvider()` |
| 2 | debug `MainActivity` 绕过 `FlutterEngineHolder`，`attachProvider` 从未设置 | `MainActivity.provideFlutterEngine()` |
| 3 | `FlutterEngine` 默认构造函数自动注册插件，显式注册导致 `sharedSingleton` 指向 `methodCallHandler=null` 的残缺实例 | `FlutterEngineHolder.getOrCreate()` — 构造参数 `false` |
| 4 | `stopLocalStream()` 未禁用 RNNoise，底层音频管道持续运行 | `MediaManager.stopLocalStream()` |
