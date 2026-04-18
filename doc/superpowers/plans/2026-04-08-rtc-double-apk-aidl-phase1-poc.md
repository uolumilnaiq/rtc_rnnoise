# RTC Double APK + AIDL Phase 1 PoC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建双 APK + AIDL 最小闭环：宿主通过 `RscRtcBridge` 连接 RTC APK，在宿主前台显式启动 `RtcEntryActivity`，RTC APK 复用单 `FlutterEngine` 进入 Flutter RTC 页面，并能回传连接/入房/离房结果和断线错误。

**Architecture:** 本计划只覆盖 spec 的 Phase 1 最小 PoC，不包含 Phase 2/3 的完整消息、拍照、交付联调。`rtc_apk_app` 采用 native-managed Flutter app 架构；宿主侧通过 `rtc-aidl` library 管理 Activity-first 冷启动、AIDL 连接、callback 接收和命令发送。主路径是“宿主前台显式启动 Activity”，不是“Service 后台拉页”。第一版不自动重放命令或自动重新入房；冷启动时允许在 `RtcEntryActivity` 已被前台显式拉起后，执行有限的 AIDL 绑定重试，用于建立 callback / 命令通道。

**Tech Stack:** Flutter stable app, Android (Kotlin/Java), AIDL, FlutterEngine API, Android Service/Activity, Android Instrumentation Test, Flutter widget/integration test.

---

## Scope Decision

本 spec 覆盖多个阶段，但实现必须先收敛到可交付的 Phase 1 PoC。Phase 2（消息/拍照/权限/FGS 完整化）和 Phase 3（MDM/交付联调）不纳入本计划；PoC 跑通后再单独出后续计划。

## File Structure

### New Project: `rtc_apk_app/`

**Purpose:** 新 Flutter app 工程，承载独立 RTC APK。

**Files to create/own:**
- `rtc_apk_app/pubspec.yaml`
  - Flutter app 依赖声明；第一阶段只接入最小 Flutter 依赖和复用当前 RTC 代码所需依赖。
- `rtc_apk_app/lib/main.dart`
  - Flutter 入口，挂载 PoC 页面和最小路由。
- `rtc_apk_app/lib/app/rtc_app.dart`
  - Flutter app 根组件。
- `rtc_apk_app/lib/features/entry/rtc_room_bootstrap.dart`
  - 从 native 传入的 `requestId`/room payload 进入 Flutter RTC 页的桥接层。
- `rtc_apk_app/lib/features/entry/rtc_room_page.dart`
  - PoC 阶段最小 Flutter RTC 页面；第一阶段可先展示房间打开和参数消费结果，再逐步接入现有 `flutter_module` RTC 页面。
- `rtc_apk_app/android/app/src/main/AndroidManifest.xml`
  - `RtcEntryActivity`、`RtcBridgeService`、signature 权限、无桌面入口、启动主题、AIDL service 声明。
- `rtc_apk_app/android/app/src/main/res/values/themes.xml`
  - `RtcEntryActivity` 专属启动主题。
- `rtc_apk_app/android/app/src/main/res/drawable/rtc_launch_background.xml`
  - 原生 Loading/启动背景。
- `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcApplication.kt`
  - 应用级初始化。
- `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcEntryActivity.kt`
  - 宿主显式启动入口，显示 Loading，绑定 Service，复用 FlutterEngine。
- `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcBridgeService.kt`
  - AIDL Service，托管单 `FlutterEngine`、pending request 缓存、TTL、callback。
- `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/FlutterEngineHolder.kt`
  - 单例 FlutterEngine 生命周期和 attach/detach 管理。
- `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/PendingRoomRequestStore.kt`
  - `requestId -> RtcRoomOptions` 缓存、同步写入、消费、TTL 清理。
- `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcBridgeCallbackRegistry.kt`
  - `RemoteCallbackList` 管理和广播。
- `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/IRscRtcBridgeService.aidl`
  - AIDL 服务接口。
- `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/IRscRtcBridgeCallback.aidl`
  - AIDL 回调接口。
- `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/*.aidl`
  - `RtcInitOptions`、`RtcRoomOptions`、`RtcCommandResult`、`RscRtcRoomSnapshot`、`RtcError` 等 parcelable 声明。
- `rtc_apk_app/android/app/src/androidTest/...`
  - Activity/Service/AIDL 竞态、TTL、requestId 安全校验的 `adb + UI` 黑盒验证用例。Android 跨 APK 行为不使用白盒测试作为验收证据。

### New Project: `MyAppForAIDL/`

**Purpose:** 老工具链验证工程，承载宿主 demo app 和 `rtc-aidl` library。

**Files to create/own:**
- `MyAppForAIDL/settings.gradle`
  - 包含 `:app`、`:rtc-aidl`。
- `MyAppForAIDL/build.gradle`
  - 根 Gradle 配置，严格按宿主工具链版本。
- `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/MainActivity.java`
  - 示例宿主页面，触发 `initialize()` / `enterRoom()`，打印回调。
- `MyAppForAIDL/rtc-aidl/build.gradle`
  - library module 配置。
- `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/RscRtcBridge.java`
  - 宿主唯一入口。
- `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/RscRtcBridgeCallback.java`
  - 宿主回调接口。
- `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/internal/RtcServiceConnector.java`
  - bind/unbind、连接状态机、binder death。
- `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/internal/RtcRequestLauncher.java`
  - `requestId` 生成、同步缓存 room request、显式启动 `RtcEntryActivity`。
- `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/internal/RtcParcelableMapper.java`
  - 对外模型到 AIDL Parcelable 的映射。
- `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/model/*.java`
  - `RtcInitOptions`、`RtcRoomOptions`、`RtcCommandResult`、`RscRtcRoomSnapshot`、`RtcError` 等宿主侧模型。
- `MyAppForAIDL/rtc-aidl/src/androidTest/...`
  - 连接状态、service_not_ready、启动失败、callback 分发测试。

### Existing Code to Reference / Reuse
- `flutter_module/lib/**`
  - 现有 RTC/房间/UI 代码来源。PoC 第一步不要求全量迁入，但要识别最小可复用入口。
- `MyApplicationForFlutter/rsc-sdk/**`
  - 仅参考原生承载经验，不直接复用宿主 SDK 角色。

## Execution Constraints

- Phase 1 只做：`initialize`、`enterRoom`、`getServiceState`、`getRoomSnapshot`、`register/unregisterCallback`、`destroy` 的最小闭环。
- `leaveRoom`、`sendMessage`、`setBusinessCaptureMode` 在 AIDL 接口里必须保留完整定义；Phase 1 可以先接 MethodChannel stub，不要求接入完整 RTC 业务实现。
- 先做“假的 active/failed 回调”验证跨进程链路，再逐步接入真实 Flutter RTC 页面。
- `enterRoom()` 必须满足：宿主从前台 `Activity Context` 调用，先显式启动 `RtcEntryActivity`；冷启动路径允许 Intent 携带受控大小的 `RtcRoomOptions`，温启动路径可复用 `requestId + Service 缓存`。
- 不自动重放 `enterRoom()`；冷启动入房允许先拉起 `RtcEntryActivity`，AIDL 命令通道未连接时后续命令返回 `service_not_ready_please_retry`。

## Task 1: 创建 `rtc_apk_app` Flutter app 工程骨架

**Files:**
- Create: `rtc_apk_app/`
- Create: `rtc_apk_app/pubspec.yaml`
- Create: `rtc_apk_app/lib/main.dart`
- Create: `rtc_apk_app/lib/app/rtc_app.dart`
- Create: `rtc_apk_app/android/app/src/main/AndroidManifest.xml`
- Create: `rtc_apk_app/android/app/src/main/res/values/themes.xml`
- Create: `rtc_apk_app/android/app/src/main/res/drawable/rtc_launch_background.xml`

- [x] **Step 1: 生成新的 Flutter app 工程**

Run:
```bash
cd /Users/wangxinran/StudioProjects
flutter create rtc_apk_app
```

Expected: 生成新的 Flutter app 目录，包含 `android/`、`lib/`、`pubspec.yaml`。

- [x] **Step 2: 运行默认工程，确认 Flutter app 基线可用**

Run:
```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
flutter test
```

Expected: 分析和默认测试通过。

补充说明：
- `android/app/build.gradle` 必须显式配置 `testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"`
- 如果不显式配置，设备侧可能默认落到 `android.test.InstrumentationTestRunner`，从而让后续 `connectedDebugAndroidTest` 在真机上失败
- 本次真机验证确认：补齐 runner 后，手工 `am instrument` 与 `./gradlew app:connectedDebugAndroidTest` 均通过

- [x] **Step 3: 修改 Manifest，移除桌面入口并预留 Service/Activity/权限位**

```xml
<manifest ...>
    <permission
        android:name="com.yourcompany.rtc.permission.LAUNCH_RTC"
        android:protectionLevel="signature" />
    <permission
        android:name="com.yourcompany.rtc.permission.BIND_RTC_SERVICE"
        android:protectionLevel="signature" />

    <application ...>
        <activity
            android:name=".RtcEntryActivity"
            android:exported="true"
            android:permission="com.yourcompany.rtc.permission.LAUNCH_RTC"
            android:theme="@style/Theme.RtcEntry.Launch" />

        <service
            android:name=".RtcBridgeService"
            android:exported="true"
            android:permission="com.yourcompany.rtc.permission.BIND_RTC_SERVICE"
            android:foregroundServiceType="camera|microphone|mediaProjection" />
    </application>
</manifest>
```

- [x] **Step 4: 添加 `RtcEntryActivity` 启动主题和 `windowBackground`**

```xml
<style name="Theme.RtcEntry.Launch" parent="Theme.MaterialComponents.DayNight.NoActionBar">
    <item name="android:windowBackground">@drawable/rtc_launch_background</item>
</style>
```

- [x] **Step 5: 再跑一次构建，确认 Manifest/资源无误**

Run:
```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter build apk --debug
```

Expected: APK 构建成功，无 Manifest 合并错误。

## Task 2: 创建 `MyAppForAIDL` 工程和 `rtc-aidl` library 骨架

**Files:**
- Create: `MyAppForAIDL/settings.gradle`
- Create: `MyAppForAIDL/build.gradle`
- Create: `MyAppForAIDL/app/build.gradle`
- Create: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/MainActivity.java`
- Create: `MyAppForAIDL/rtc-aidl/build.gradle`
- Create: `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/RscRtcBridge.java`
- Create: `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/RscRtcBridgeCallback.java`

- [x] **Step 1: 复制/创建新的 Android 工程骨架**

最小方式：以现有 [MyApplicationForFlutter](/Users/wangxinran/StudioProjects/MyApplicationForFlutter) 为参考，建立新的 root 工程，只保留 `app` 和 `rtc-aidl`。

- [x] **Step 2: 将 root / wrapper / gradle 版本锁到宿主工具链**

目标：
- AGP `3.6.3x`
- Gradle `6.2.2x`
- JDK `1.8`
- Kotlin `1.4.10x`（如需要）

- [x] **Step 3: 在 `settings.gradle` 注册模块**

```gradle
include ':app', ':rtc-aidl'
```

- [x] **Step 4: 在 `app` 中依赖 `rtc-aidl` 并做一个最小演示按钮**

```java
findViewById(R.id.btnEnterRoom).setOnClickListener(v -> {
    RscRtcBridge.get().enterRoom(options);
});
```

- [x] **Step 5: 编译 `rtc-aidl` library，确认老工具链下可用**

Run:
```bash
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :rtc-aidl:assembleDebug
./gradlew :app:assembleDebug
```

Expected: library 和 demo app 均能编过。

## Task 3: 定义 AIDL 协议和 Parcelable 数据模型

**Files:**
- Create: `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/IRscRtcBridgeService.aidl`
- Create: `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/IRscRtcBridgeCallback.aidl`
- Create: `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/RtcInitOptions.aidl`
- Create: `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/RtcRoomOptions.aidl`
- Create: `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/RtcLeaveOptions.aidl`
- Create: `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/RtcMessage.aidl`
- Create: `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/RtcCaptureOptions.aidl`
- Create: `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/RtcCaptureResult.aidl`
- Create: `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/RtcCommandResult.aidl`
- Create: `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/RscRtcRoomSnapshot.aidl`
- Create: `rtc_apk_app/android/app/src/main/aidl/com/yc/rtc/bridge/RtcError.aidl`
- Modify: `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/model/*.java`

- [x] **Step 1: 先写出 AIDL 最小接口定义**

```aidl
interface IRscRtcBridgeService {
  RtcCommandResult initialize(in RtcInitOptions options);
  RtcCommandResult cacheEnterRoomRequest(in RtcRoomOptions options);
  RtcCommandResult leaveRoom(in RtcLeaveOptions options);
  RtcCommandResult sendMessage(in RtcMessage message);
  RtcCommandResult setBusinessCaptureMode(in RtcCaptureOptions options);
  RscRtcRoomSnapshot getRoomSnapshot();
  String getServiceState();
  String getSdkVersion();
  String getProtocolVersion();
  Bundle getCapabilities();
  void destroy();
  void registerCallback(IRscRtcBridgeCallback callback);
  void unregisterCallback(IRscRtcBridgeCallback callback);
}
```

`IRscRtcBridgeCallback.aidl` 第一版也要一次性定义完整方法集，至少包括：

```aidl
interface IRscRtcBridgeCallback {
  void onServiceStateChanged(String serviceState);
  void onRoomOpening(String requestId);
  void onRoomSnapshotChanged(in RscRtcRoomSnapshot snapshot);
  void onMessageReceived(in RtcMessage message);
  void onBusinessCaptureResult(in RtcCaptureResult result);
  void onError(in RtcError error);
}
```

- [x] **Step 2: 为宿主和服务端补齐同名 Parcelable**

```java
public class RtcRoomOptions implements Parcelable {
  public String requestId;
  public String route;
  public Bundle arguments;
}
```

- [x] **Step 3: 通过 adb + UI 黑盒路径验证非法 Bundle 类型被拦截**

验证方式：
- 示例宿主增加一个仅调试用非法参数入口，构造包含宿主自定义 `Serializable` 的 `Bundle`
- 通过 adb 启动宿主并点击该入口
- 期望 UI 日志或 callback 返回参数非法错误，且 RTC APK 不崩溃

- [x] **Step 4: 运行黑盒验证确认失败，再实现白名单校验**

Run:
```bash
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :app:connectedDebugAndroidTest
```

Expected: 初次失败，补代码后通过。

## Task 4: 实现 `rtc-aidl` 连接器和 `RscRtcBridge` 主入口

**Files:**
- Modify: `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/RscRtcBridge.java`
- Create: `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/internal/RtcServiceConnector.java`
- Create: `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/internal/RtcRequestLauncher.java`
- Test: `MyAppForAIDL/rtc-aidl/src/test/java/com/yc/rtc/aidl/RscRtcBridgeTest.java`

- [x] **Step 1: 用 adb + UI 黑盒覆盖冷启动三种连接状态**

验证内容：
- `disconnected`：RTC APK 未启动 / 被 `force-stop` 时，真实点击入房仍应先拉起 `RtcEntryActivity`
- `connecting`：正在建立 AIDL 通道时，不重放业务命令
- `connected`：后续 `leaveRoom` / `sendMessage` / `setBusinessCaptureMode` 可走 AIDL 命令通道

- [x] **Step 2: 实现 `RtcServiceConnector` 最小状态机**

状态只保留：
- `disconnected`
- `connecting`
- `connected`

- [x] **Step 3: 在 `RscRtcBridge` 中实现 `initialize()` / `getServiceState()` / `registerCallback()`**

```java
public RtcCommandResult initialize(Context context, RtcInitOptions options) {
    connector.bind(context.getApplicationContext());
    return connector.initialize(options);
}
```

- [x] **Step 4: 在 `enterRoom()` 中使用 Activity-first 冷启动，不要求 binder ready**

```java
RtcCommandResult launchResult = requestLauncher.launch(activityContext, options);
connector.ensureBindAfterActivityLaunched(activityContext.getApplicationContext());
return launchResult;
```

- [x] **Step 5: 运行黑盒验证与编译**

Run:
```bash
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :rtc-aidl:assembleDebug
./gradlew :app:connectedDebugAndroidTest
```

Expected: 通过。

## Task 5: 实现 Service 侧同步缓存、TTL 和 callback 基础设施

**Files:**
- Create: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/PendingRoomRequestStore.kt`
- Create: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcBridgeCallbackRegistry.kt`
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcBridgeService.kt`
- Test: `rtc_apk_app/android/app/src/androidTest/kotlin/com/example/rtc_apk_app/PendingRoomRequestStoreTest.kt`

- [x] **Step 1: 用 adb + UI / logcat 黑盒验证缓存消费和 TTL 清理**

验证内容：
- 正常入房时 `requestId` 被消费后不再重复消费
- 构造页面未消费参数的异常路径，等待 TTL 后 logcat / callback 出现过期错误
- RTC APK 不因过期缓存崩溃

- [x] **Step 2: 实现 `PendingRoomRequestStore.put/consume/expire`**

```kotlin
fun put(requestId: String, options: RtcRoomOptions): Boolean
fun consume(requestId: String): RtcRoomOptions?
```

- [x] **Step 3: 在 `RtcBridgeService` 暴露同步 `cacheEnterRoomRequest()`**

```kotlin
override fun cacheEnterRoomRequest(options: RtcRoomOptions): RtcCommandResult {
  val ok = store.put(options.requestId, options)
  return if (ok) success(options.requestId) else error("cache_failed")
}
```

- [x] **Step 4: TTL 到期时向 callback 广播失败**

```kotlin
callbackRegistry.notifyError(
  RtcError("enter_room_request_expired", "pending request expired")
)
```

- [x] **Step 5: 跑 adb + UI 黑盒验证**

Run:
```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
./gradlew app:connectedDebugAndroidTest
```

Expected: TTL 和消费测试通过。

## Task 6: 实现 `RtcEntryActivity` 和显式启动链路

**Files:**
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcEntryActivity.kt`
- Modify: `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/internal/RtcRequestLauncher.java`
- Test: `MyAppForAIDL/app/src/androidTest/java/com/yc/rtc/myappforaidl/RtcEntryLaunchTest.java`

- [x] **Step 1: 用 adb + UI 黑盒验证冷启动 Activity-first 链路**

验证内容：
- RTC APK `force-stop` 后，宿主点击真实“启动会议”按钮
- 即使首次 `bindService(RtcBridgeService)` 被 ROM 拦截，也必须能通过前台显式 `startActivity(RtcEntryActivity)` 拉起 RTC 页面
- `RtcEntryActivity` 能消费 Intent 内受控大小的 `RtcRoomOptions`

- [x] **Step 2: 在 `RtcRequestLauncher` 中实现 Activity-first 主链路**

```java
String requestId = newRequestId();
Intent intent = buildEntryIntent(requestId, options);
context.startActivity(intent);
```

注意：
- 使用 `Activity Context` 启动时，除非调用方只能提供 `Application Context`，否则不要添加 `FLAG_ACTIVITY_NEW_TASK`
- 该约束用于满足 spec 中“宿主与 RTC 页面尽量保持同一任务栈”的 UX 目标
- Intent payload 必须保持受控大小；不得传图片、二进制、大列表或宿主自定义类

- [x] **Step 3: `RtcEntryActivity` onCreate 展示 Loading，并绑定本地 `RtcBridgeService`**

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
  setTheme(R.style.Theme_RtcEntry_Launch)
  super.onCreate(savedInstanceState)
  bindService(...)
}
```

- [x] **Step 4: `RtcEntryActivity` 用 `requestId` + payload 拉取完整参数，非法则立即结束**

```kotlin
val requestId = intent.getStringExtra("requestId") ?: return finishWithError()
val options = service.consumeRoomRequest(requestId) ?: intentOptions ?: return finishWithError()
```

- [x] **Step 5: 运行启动链路测试**

Run:
```bash
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :app:connectedDebugAndroidTest
```

Expected: 冷启动时可拉起 `RtcEntryActivity` 并消费 Intent payload；温启动缓存路径若启用，非法 `requestId` / payload 直接失败退出。

## Task 7: 实现单 `FlutterEngine` 托管和最小 Flutter 页面 attach

**Files:**
- Create: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/FlutterEngineHolder.kt`
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcBridgeService.kt`
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcEntryActivity.kt`
- Create: `rtc_apk_app/lib/features/entry/rtc_room_bootstrap.dart`
- Create: `rtc_apk_app/lib/features/entry/rtc_room_page.dart`
- Test: `rtc_apk_app/test/features/entry/rtc_room_bootstrap_test.dart`

- [x] **Step 1: 写 Flutter 侧失败测试，验证请求参数能渲染到 PoC 页面**

```dart
testWidgets('renders request id and route from bootstrap payload', (tester) async {
  await tester.pumpWidget(RtcRoomBootstrap(payload: {'requestId': 'r1', 'route': '/room'}));
  expect(find.text('r1'), findsOneWidget);
});
```

- [x] **Step 2: 实现 `FlutterEngineHolder` 的单例获取**

```kotlin
fun getOrCreate(context: Context): FlutterEngine
```

- [x] **Step 3: 在 `RtcBridgeService` 中预热/复用 engine，在 `RtcEntryActivity` attach**

- [x] **Step 4: 实现最小 Flutter 页面，先显示“Room Opening / Active / Failed”占位**

- [x] **Step 5: 运行 Flutter test 和 APK 构建**

Run:
```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter test test/features/entry/rtc_room_bootstrap_test.dart
flutter build apk --debug
```

Expected: Flutter 页能 attach，APK 仍能构建。

## Task 8: 贯通 callback、room snapshot 和崩溃/重连 PoC

**Files:**
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcBridgeService.kt`
- Modify: `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/internal/RtcServiceConnector.java`
- Modify: `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/RscRtcBridge.java`
- Test: `MyAppForAIDL/rtc-aidl/src/androidTest/java/com/yc/rtc/aidl/RtcReconnectTest.java`

- [x] **Step 1: 用 adb 黑盒验证 binder 死亡后状态变成 `disconnected`**

验证内容：
- 启动会议后通过 adb force-stop RTC APK
- 宿主收到 `disconnected` / `service_restarted` 或等价错误 callback
- SDK 不自动重新入房

- [x] **Step 2: 在 `RtcBridgeService` 里返回最小 `RscRtcRoomSnapshot`**

字段必须对齐 spec，至少包括：
- `serviceState`
- `roomState`
- `failureType`
- `failureCode`
- `failureMessage`
- `canRetry`
- `roomPageShowing`
- `disconnectReason`
- `extras`

- [x] **Step 3: 在 `RtcServiceConnector` 中区分连接建立重试与业务自动恢复**

实现约束：
- 收到 `onServiceDisconnected()` / `onBindingDied()` / `RemoteException` 后进入 `disconnected`
- 通过 callback 将 `disconnectReason` / `errorCode` / `errorMessage` 通知宿主
- 冷启动 Activity 已被前台显式拉起后，允许有限绑定重试以建立 callback / 命令通道
- 不自动重放命令
- 不自动重新入房

- [x] **Step 4: 当服务重启且上下文丢失时，返回：**

```java
failureType = "service_restarted"
roomState = "failed"
```

- [x] **Step 5: 跑 Android 仪器测试**

Run:
```bash
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :rtc-aidl:connectedDebugAndroidTest
```

Expected: binder death 后状态变为 `disconnected`，宿主收到断线 callback；SDK 不自动重放入房命令。冷启动 Activity 拉起后的连接建立重试只用于恢复 callback / 命令通道。

## Task 9: 接入现有 `flutter_module` RTC 代码的最小入口

**Files:**
- Reference: `flutter_module/lib/main.dart`
- Reference: `flutter_module/lib/screens/room/**`
- Reference: `flutter_module/lib/features/signaling/**`
- Modify: `rtc_apk_app/lib/features/entry/rtc_room_bootstrap.dart`
- Modify: `rtc_apk_app/pubspec.yaml`

- [x] **Step 1: 识别当前 `flutter_module` 中最小可复用的房间入口**

目标：找出能在新 app 中最小挂载的房间入口 Widget 或路由，而不是一次性迁整套启动逻辑。

- [x] **Step 2: 先写一份迁移清单，明确第一批仅迁哪些 Dart 文件**

至少包含：
- 入口 Widget
- 其直接依赖
- 必需的 DI/配置初始化

- [x] **Step 3: 将最小入口接到 `rtc_room_bootstrap.dart`**

原则：
- 先跑通页面打开和入房参数接收
- 再逐步替换 PoC 占位页

- [x] **Step 4: 运行 Flutter analyze 和最小 UI 测试**

Run:
```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze lib
flutter test
```

Expected: 新 app 中最小 RTC 页面可编译、可渲染。

## Task 10: 端到端 PoC 验证与文档回写

**Files:**
- Modify: `docs/superpowers/specs/2026-04-08-rtc-double-apk-aidl-architecture-design.md`
- Create: `docs/rtc_double_apk_poc_validation.md`

- [x] **Step 1: 运行最小闭环验证**

Run:
```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter build apk --debug

cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :app:assembleDebug
./gradlew :app:connectedDebugAndroidTest
```

Expected:
- 宿主可绑定服务
- 宿主前台可显式拉起 `RtcEntryActivity`
- Flutter 页面可打开
- callback 能回传 opening/active/failed
- 验证前提：`android/app/build.gradle` 已显式配置 `testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"`
- Android 验收必须走 `adb + UI` 黑盒路径，模拟真实用户点击宿主按钮、跨 APK 启动 RTC 页面、RTC 页面挂断或 Back 后自然回到宿主
- Android 跨 APK 启动、Activity/Service 生命周期、浮窗控制、RTC 命令链路必须以 `adb + UI` 黑盒路径作为修复证据
- 2026-04-10 复测：`./gradlew :app:connectedDebugAndroidTest` 在真机 `BZT3-AL00 Android 10` 通过
- 同日手工 adb 黑盒验证发现：首次 `bindService(RtcBridgeService)` 会被华为系统拦截，前台显式 `startActivity(RtcEntryActivity)` 成功；因此 Phase 1 采用 Activity-first 冷启动路径

- [x] **Step 2: 手工验证重点风险**

手工清单：
- 华为/荣耀/联想设备上显式启动 `RtcEntryActivity`
- 冷启动/温启动耗时记录
- binder death 后的失败快照
- Loading 背景是否消除白屏/黑屏
- RTC 页面内挂断 / 系统 Back 是否触发 `leaveRoom()`、callback 和 `RtcEntryActivity.finish()`，并自然回到发起会议的宿主 Activity

- [x] **Step 3: 回写 spec 和验证文档**

记录：
- 实际文件路径
- 实际错误码
- 已验证风险 / 未验证风险
- Phase 2 需要承接的遗留项

## Notes for Execution

- 先写假实现和失败测试，把 AIDL/Activity/Service/FlutterEngine 主链跑通，再逐步替换成真实 RTC 页面。
- 不要在 Phase 1 同时实现完整消息、拍照、FGS、权限细节，那会把 PoC 稀释掉。
- `RtcEntryActivity`、`RtcBridgeService`、`PendingRoomRequestStore` 是第一阶段最需要严格 review 的三个原生点。
- `RtcRoomBootstrap` 是第一阶段最需要严格 review 的 Flutter 入口点。
- 这个 workspace 不是单一 git 仓库。执行时若需要提交，必须按各自工程的 git 边界分别处理，不在本计划中强制要求 commit 步骤。
