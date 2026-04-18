# Kotlin 1.4.10 Legacy 兼容评估（4个关键包）

更新时间：2026-04-08

## 1. 结论总览

| 包 | Kotlin 1.4.10 兼容可行性 | 直接换版本是否可行 | 主要阻塞 |
|---|---|---|---|
| mic_stream_recorder | 不可行 | 不可行 | 所有已发布版本均为 Kotlin 1.8.22 |
| flutter_foreground_task | 部分可行（仅旧版本） | 当前工程不可行 | 低 Kotlin 版本对应 Dart `<3.0`，与当前 Dart 3.x 冲突 |
| shared_preferences_android | 可行 | 有条件可行 | 2.1.2 可降，但可能与上层 shared_preferences 版本约束冲突 |
| flutter_webrtc | 可行 | 旧版本直降不可行，fork 最新版可行 | 旧版本受 Dart `<3.0` 约束；最新版仍残留 `audioswitch` Kotlin 依赖 |

---

## 1.1 最新进展（flutter_webrtc 1.3.1）

已在独立仓库完成 `flutter_webrtc 1.3.1` 的 phase 1 验证：
- 路径：`/Users/wangxinran/StudioProjects/flutter_webrtc`
- 分支：`phase1-remove-project-kotlin`
- 提交：`0ee4484 phase1: remove plugin kotlin source`

phase 1 已完成内容：
- 将插件自身唯一的 Kotlin 源文件 `SimulcastVideoEncoderFactoryWrapper.kt` 改写为 Java
- 移除 `android/build.gradle` 中的项目级 Kotlin 构建依赖：
  - `kotlin-gradle-plugin`
  - `apply plugin: 'kotlin-android'`
  - 显式 `kotlin-stdlib`
  - `kotlinOptions`

验证结果：
- 在 `flutter_webrtc/example` 下执行 `flutter build apk --debug` 成功
- 结论：`flutter_webrtc` 插件自身已不再依赖项目级 Kotlin plugin 才能完成编译
- 当前剩余 Kotlin 牵连点已收敛到 `audioswitch` 音频路由链路，而不是插件主体

## 1.2 宿主工具链约束同步结论

已知宿主固定条件：
- Kotlin `1.4.10x`
- AGP `3.6.3x`
- Gradle `6.2.2x`
- JDK `1.8.0_171`
- `minSdk 21`
- `compileSdk` 可提高到 `36`
- `targetSdk 22`
- 开启 `R8/ProGuard`
- 接入方式为本地 AAR，且完全离线
- Kotlin / AGP / Gradle / JDK 不能升级

基于当前仓库代码，新增结论如下：

1. `compileSdk 36` 可用后，`compileSdk 30` 限制不再是主要阻塞。
- 但这只是“宿主愿意提高 compileSdk”的项目条件，不代表 `AGP 3.6.x + compileSdk 36` 是官方支持组合。
- 因此，`compileSdk 36` 对本项目应视为“宿主实测验证项”，不能当成通用稳定前提。

2. 除 Kotlin 外，`Java 8 bytecode` 是同级硬阻塞。
- 当前 Flutter 生成工程仍是 Java 17：
  - `flutter_module/.android/Flutter/build.gradle`
- 在 JDK 8 宿主链路下，若 AAR/JAR 中包含 Java 17 class bytecode，编译或 D8/R8 阶段会失败。

3. 交付形态必须满足“真正离线闭包”。
- 当前工程仍依赖 Flutter AAR 仓库解析，而不是单自包含 AAR：
  - `MyApplicationForFlutter/rsc-sdk/build.gradle`
- 对方要求“本地 AAR + 完全离线”，因此 legacy 线必须额外解决：
  - AAR 传递依赖闭包
  - `jniLibs`
  - `flutter_assets`
  - 插件注册与资源文件

4. `minSdk 21` 需要在所有最终交付物上统一保证。
- 当前 `rsc-sdk` 是 `minSdk 21`
- 但 Flutter 产物链历史上曾出现 `flutter_debug.aar minSdk 24` 的问题，因此 legacy 线必须把这条作为硬验收项。

5. 混淆兼容必须进入正式适配范围。
- 宿主开启 `R8/ProGuard`
- 当前已有基础 consumer rules：
  - `MyApplicationForFlutter/rsc-sdk/consumer-rules.pro`
- 但在 fat aar / 完整离线闭包场景下，Flutter bridge、WebRTC、插件注册、前台服务、自研插件等规则需要继续补齐并实测。

## 1.3 适配项与优先级

### P0 必须优先完成

1. Kotlin `1.4.10x` 兼容
- 目标：去掉或替换所有要求高版本 Kotlin metadata 的 Android 依赖。

2. Java 8 bytecode 兼容
- 目标：legacy 线所有 Android 产物都降到 Java 8 字节码。
- 当前直接证据：
  - `flutter_module/.android/Flutter/build.gradle` 仍为 `JavaVersion.VERSION_17`

3. 完全离线交付闭包
- 目标：宿主在无网络、仅本地依赖条件下即可构建。
- 需要交付：
  - 单 fat aar，或
  - 完整本地离线 repo 包
- 同时必须包含运行闭包：
  - `jniLibs`
  - `flutter_assets`
  - 插件注册信息
  - 必要资源文件

4. `minSdk 21` 统一
- 目标：所有最终 AAR 都不能再抬高到 `24`
- 当前直接证据：
  - `MyApplicationForFlutter/rsc-sdk/build.gradle` 为 `minSdk 21`
  - `flutter_module/build.sh` 也在生成时写入 `flutter.minSdkVersion=21`

5. `R8/ProGuard` 可用
- 目标：宿主 `release + minifyEnabled true` 下可编译、可运行。
- 当前直接证据：
  - `MyApplicationForFlutter/rsc-sdk/consumer-rules.pro`

### P1 高优先验证/适配

1. `compileSdk 36` 在宿主链路上的实测验证
- 虽然宿主可以提高到 `36`，但 `AGP 3.6.x + compileSdk 36` 不属于官方标准支持组合。
- 因此这条需要在真实宿主工程中验证，而不能只看理论配置。

2. Flutter / WebRTC 运行资源闭包验证
- 重点验证：
  - `.so` 是否完整
  - `flutter_assets` 是否完整
  - 离线情况下插件注册和引擎初始化是否正常

3. MultiDex 风险评估
- Flutter + WebRTC + bridge + 自研插件合并后，方法数可能继续上升。
- `minSdk 21` 下运行风险较低，但仍需判断宿主是否需要显式开启 `multiDexEnabled true`。

### P2 可忽略或无需特别适配

1. 宿主不使用 Jetpack Compose
- 对当前 SDK 没有额外适配影响。

2. 宿主使用 viewBinding
- 对当前 SDK 没有额外适配影响。

---

## 2. 版本核查结果（已记录）

### 2.1 mic_stream_recorder
- 版本：`1.0.0 / 1.1.0 / 1.1.1 / 1.1.2`
- 结论：Android 侧 `kotlin_version` 均为 `1.8.22`，没有 Kotlin 1.4.10 窗口。
- 额外约束：这些版本均要求 Flutter/Dart 3.x（不是旧 Dart 线）。

### 2.2 flutter_foreground_task
- Kotlin 1.4.10 可用窗口：`<= 3.5.5`（`kotlin_version=1.3.50`）
- 边界：`3.6.0` 升到 `1.5.31`，之后持续上升（`8.17.0=1.7.10`，`9.2.2=1.9.10`）
- 关键阻塞：`3.5.5` 的 Dart 约束为 `>=2.12.0 <3.0.0`，与当前工程 Dart 3.x 不兼容。

### 2.3 shared_preferences_android
- Kotlin 1.4.10 可用窗口：`2.1.2`（无 Kotlin 插件依赖）
- 边界：`2.1.3` 开始引入 Kotlin（`1.6.21`），`2.4.7` 为 `2.1.10`
- 约束：`2.1.2` 的 Dart 约束是 `>=2.17.0 <4.0.0`，与 Dart 3.x 可共存。

### 2.4 flutter_webrtc
- Kotlin 1.4.10 可用窗口：`<= 0.8.2`（`kotlin_version=1.3.50`）
- 边界：`0.8.3` 开始升到 `1.6.10`，`1.2.1` 为 `1.8.10`
- 关键阻塞：`0.8.2` 的 Dart 约束为 `>=2.12.0 <3.0.0`，与当前工程 Dart 3.x 不兼容。
- 最新补充：基于 `1.3.1` fork 做 phase 1 后，插件主体 Kotlin 已清理完成，剩余阻塞点是 `audioswitch` 依赖链。

---

## 3. 结合当前代码的回退影响

## 3.1 mic_stream_recorder 回退/替换影响面

当前使用点：
- `flutter_module/lib/features/media_devices/ui/AudioInputDetector.dart`：
  - `startRecording()`
  - `amplitudeStream.listen(...)`
  - `stopRecording()`
- `flutter_module/lib/screens/room/ui/device_detection_dialog.dart`：
  - 同样的启动/监听/停止逻辑
- `flutter_module/lib/features/rtc/instance.dart`：
  - `startDetectAudioVolume()` / `stopDetectLocalAudioInVolume()`

业务影响判断：
- 影响的是“麦克风输入电平检测”与调试观测，不是核心入会信令/媒体主链路。
- 但会影响：
  - 设备检测面板中的音量条实时显示
  - 旧 `RtcInstance` 的音量检测日志能力

### 3.2 flutter_foreground_task 回退到 3.5.5 的影响

当前代码依赖的 9.x API 形态：
- `TaskHandler.onStart(DateTime, TaskStarter)`
- `TaskHandler.onRepeatEvent(...)`
- `ForegroundTaskOptions(eventAction: ForegroundTaskEventAction.repeat(...), allowWakeLock, allowWifiLock, ...)`

回退到 3.5.5 时的主要不兼容：
- `TaskHandler` 变更：
  - `onRepeatEvent` -> `onEvent`
  - `onStart` 第二参数从 `TaskStarter` 变为 `SendPort?`
  - `onDestroy` 签名也不同
- `ForegroundTaskOptions` 变更：
  - 无 `eventAction`，使用 `interval`
  - 无 `allowWakeLock`
- 受影响代码：
  - `flutter_module/lib/main.dart` 的 `MyTaskHandler` 与 `_initForegroundTask()`
  - `room_client_entrance_v2*.dart` / `v2/managers/media_manager.dart` 中 `startService/restartService/stopService`

此外，即使改完 API，也会被 Dart `<3.0` 约束阻断。

### 3.3 shared_preferences_android 回退到 2.1.2 的影响

当前工程中没有直接 `import package:shared_preferences` 的业务调用，主要是插件间接依赖。

可能回退内容：
- 缺少新版本 DataStore 相关增强（2.4.x）
- 缺少后续 `SharedPreferencesAsyncAndroid` 新能力
- 一些 `List<String>` 编码行为修复不再具备

但就当前业务代码而言，直接影响较小，重点在依赖约束是否允许 override。

### 3.4 flutter_webrtc 回退到 0.8.2 的影响

核心结论：当前工程大量依赖 `flutter_webrtc`，即使 API 在旧版多数仍可找到，**Dart `<3.0` 约束已使“直接换版本”不可行**。

即便强行 fork 以适配 Dart 3，仍有高行为回退风险：
- Android 构建链从 `compileSdk 36` 回到 `30`
- libwebrtc 依赖从 `137.x` 回到 `93.x`
- 会失去大量近版本 Android 端修复（包括摄像头、投屏、恢复等稳定性修复）

因此，`flutter_webrtc` 的推荐路线已经从“尝试回退版本”调整为：
- 保持最新稳定线 `1.3.1`
- 分阶段剥离 Android 侧 Kotlin 依赖

### 3.5 flutter_webrtc 1.3.1 去 Kotlin 当前状态

phase 1 已完成：
- 插件自身唯一 `.kt` 文件已替换为 Java
- 项目级 Kotlin 构建依赖已删除
- `example` Android 构建成功

当前确认的剩余 Kotlin 依赖点：
- `android/build.gradle`
  - 仍保留 `com.github.davidliu:audioswitch:...`
- `android/src/main/java/com/cloudwebrtc/webrtc/audio/AudioSwitchManager.java`
  - 仍引用 `kotlin.Unit`
  - 仍引用 `kotlin.jvm.functions.Function2`
- `android/src/main/java/com/cloudwebrtc/webrtc/MethodCallHandlerImpl.java`
  - 仍依赖 `com.twilio.audioswitch.AudioDevice`

这说明：
- `flutter_webrtc` 主体编译问题已解决
- 后续工作重点是音频路由层，不是 WebRTC 主链路

---

## 4. mic_stream_recorder 可替代方案

## 方案A：自研轻量插件（推荐，Legacy 最稳）
- 在本仓新增一个极简 Android 插件（Java 实现即可），只做：
  - `start()`
  - `stop()`
  - `EventChannel<double>` 推送归一化音量（0~1）
- 优点：
  - 完全可控，不受第三方 Kotlin 元数据约束
  - 只覆盖当前业务真实需要（音量检测）
- 成本：
  - 需要维护少量原生代码

## 方案B：改用 `mic_stream`
- 能提供 PCM 流，可在 Dart 侧自行计算 RMS/峰值转 0~1。
- 风险：
  - 该库 Android 构建脚本较老（AGP 3.5 体系），接入现代 Flutter 工具链时可能仍需 fork 调整。

## 方案C：仅用 `flutter_webrtc` stats 做入会后音量
- 适用于“已建立发送链路后”的音量估计（通过 RTP stats）。
- 不适合完全替代“设备检测阶段（入会前）”的麦克风电平检测。

## 方案D：`noise_meter`（当前不建议）
- 其依赖 `audio_streamer`，最新 Android 构建链为 Kotlin 2.2.x，不满足 Kotlin 1.4.10 目标。

---

## 5. 推荐落地顺序

1. `mic_stream_recorder` 先替换为“自研轻量 Java 插件”。
2. `flutter_foreground_task` 替换为“最小自研 Java 前台服务插件”，不再依赖第三方 Kotlin Android 实现。
3. `shared_preferences_android` 不单独优先处理，优先观察其是否随 `flutter_foreground_task` 依赖链一起消失。
4. 并行启动 Java 8 bytecode 适配与离线交付方案设计。
5. `flutter_webrtc` 保持 `1.3.1`，继续执行 phase 2：
   - 评估 `AudioSwitchManager` 对 Kotlin function 类型的替换成本
   - 判断 `audioswitch` 是否可局部保留
   - 若目标是彻底去 Kotlin，则改为原生 `AudioManager` / `AudioDeviceInfo` 音频路由实现

## 6. 待做清单（截至当前）

### 6.1 mic_stream_recorder
- 新建最小 Java 插件
- 对外只保留：
  - `start()`
  - `stop()`
  - `EventChannel<double>` 音量流
- 替换当前 Dart 侧 `startRecording / stopRecording / amplitudeStream`

### 6.2 flutter_foreground_task
- 新建最小 Java 前台服务插件
- 覆盖当前业务真实使用面：
  - `init`
  - `setTaskHandler`
  - `isRunningService`
  - `startService`
  - `restartService`
  - `stopService`
- Dart 层增加一层本地封装，避免未来再次直接绑定第三方插件 API

### 6.3 flutter_webrtc
- 已完成 phase 1：插件主体去 Kotlin
- phase 2 待做：
  - 梳理 `audioswitch` 的实际调用面
  - 评估 `AudioSwitchManager` 去掉 `kotlin.Unit / Function2` 的最小改造
  - 决定是“保留 audioswitch 但隔离 Kotlin 影响”，还是“直接替换为原生音频路由”
