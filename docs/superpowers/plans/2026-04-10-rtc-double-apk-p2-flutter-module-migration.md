# RTC Double APK P2 Flutter Module Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `rtc_apk_app` 从 P1 skeleton/probe 页面接入真实 `flutter_module` RTC 页面，并补齐 AIDL 命令、业务拍照、媒体前台服务和黑盒验收闭环。

**Architecture:** `rtc_apk_app` 继续通过 `path` 依赖复用 `flutter_module`，不复制 Dart 代码。`rtc_apk_app` 原生层负责 AIDL、Activity/Service、FlutterEngine、`xchatkit` MethodChannel 适配、MediaStore 与前台服务；`flutter_module` 负责 RTC 页面、信令、WebRTC、页面内挂断、业务拍照 UI 和媒体生命周期。P2 保持 P1 Activity-first 冷启动主路径，避免回退到后台 Service 拉页。

**Tech Stack:** Flutter app + local `path` package, Dart/Flutter, Android Java/Kotlin, AIDL, MethodChannel `xchatkit`, MediaStore, Android Foreground Service, adb + UI 黑盒测试, JDK 8 for `MyAppForAIDL`.

---

## Scope

Reference spec:

- `docs/superpowers/specs/2026-04-10-rtc-double-apk-p2-flutter-module-migration-design.md`

P2 includes:

- `rtc_apk_app` 启动真实 `flutter_module` 房间页
- `flutter_module` 新增不影响旧行为的 app 入口
- `rtc_apk_app` 原生侧用 `xchatkit` 协议适配 Flutter
- 入房参数对齐旧 `ConferenceOptions`
- `environment` 默认 `0=production`，`1=debug`
- `proxyIp/proxyPort` 从 `enterRoom()` 业务参数传入
- `sendMessage`
- 合照、单人照业务拍照；`singleWithFrame` 不作为 AIDL mode 支持，只通过合照流程中的二次拍照路径覆盖
- 业务拍照保存到 `Pictures/RscRtc/`
- 原生 `RtcBridgeService` 统一管理 microphone/camera/mediaProjection 前台服务类型与通知
- `adb + UI` 黑盒验收

P2 excludes:

- 复制 `flutter_module/lib` 到 `rtc_apk_app/lib`
- 重写 RTC 信令/WebRTC/房间 UI
- 整体迁入 `SDLActivityAdapter`
- P3 MDM/线上交付联调
- 用白盒测试替代跨 APK 验收

## File Structure

### `flutter_module`

- Modify: `flutter_module/lib/main.dart`
  - 抽出可复用 app 启动函数，保留原 `main()` 行为。
- Create: `flutter_module/lib/rtc_module_entry.dart`
  - 暴露 `RtcModuleLaunchOptions` 和 `runRtcModuleApp(...)`，供 `rtc_apk_app` 调用。
- Modify: `flutter_module/lib/config/app_config.dart`
  - 对 package asset 路径做最小兼容，支持 `assets/config/...` 和 `packages/flutter_module/assets/config/...`。
- Modify: `flutter_module/lib/features/signaling/room_client_entrance_v2.capability.dart`
  - `doubleApkNativeMode` 下不实际启动/停止 `flutter_foreground_task`，改为发送媒体状态事件。
- Modify: `flutter_module/lib/features/signaling/room_client_entrance_v2.dart`
  - 如 `_stopForegroundServiceSafely(...)` 仍会在 `doubleApkNativeMode` 下停止 Flutter 插件服务，做保护。
- Modify: `flutter_module/lib/features/xchatkit_adapter/channels/xchat_event_channel.dart`
  - 必要时增加媒体状态事件 helper。
- Modify: `flutter_module/lib/screens/room/controllers/room_controller.dart`
  - 如业务拍照保存路径仍是私有目录，调整成功回调前的保存/路径传递策略。
- Modify: `flutter_module/lib/features/signaling/room_client_entrance_v2.media.dart` or related photo manager files
  - 将业务拍照结果保存目标改到可共享图片目录的 Flutter/Native 桥接入口。实际文件名以定位结果为准，修改前用 `rg "takePhotoByCaptureFrame|saved to|onPhotoTakeSuccess"` 确认。

### `rtc_apk_app`

- Modify: `rtc_apk_app/pubspec.yaml`
  - 保持 `flutter_module: path: ../flutter_module`，补齐必要依赖/asset 兼容。
- Modify: `rtc_apk_app/lib/main.dart`
  - 调用 `flutter_module` 新入口。
- Keep or remove later: `rtc_apk_app/lib/app/rtc_app.dart`
  - P1 skeleton/probe 入口不再作为正式主路径；可保留作 probe 页面，但不得影响启动真实 RTC。
- Modify: `rtc_apk_app/android/app/src/main/AndroidManifest.xml`
  - 补齐前台服务权限、通知权限、MediaStore/相机/麦克风相关权限声明。
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/FlutterEngineHolder.kt`
  - 初始路由回到 `/` 或新增入口要求的 route，避免继续用 `/room-bootstrap` 作为正式主路径。
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcEntryActivity.kt`
  - 冷启动时消费 `RtcRoomOptions` 后交给 Service，由 Service 等 `engineReady` 后推 `navigatorPush`。
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcEntryCoordinator.kt`
  - P2 不再只拼 `/room-bootstrap?requestId=...`；改为生成原生侧 payload 或移交给 Java builder。
- Modify: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
  - 保存 init/runtime options，接入 `RtcXChatKitBridge`，处理 AIDL 命令，处理 Flutter callback，管理 FGS。
- Create: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcXChatKitBridge.java`
  - `xchatkit` MethodChannel 原生适配，参考 `SDLActivityAdapter` 协议，不复用旧 Activity/Engine 逻辑。
- Create: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcRoomPayloadBuilder.java`
  - 将 `RtcInitOptions + RtcRoomOptions` 转成 `navigatorPush` 的 `/room` JSON 参数。
- Create: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcMediaForegroundController.java`
  - 维护 microphone/camera/mediaProjection active 状态，统一 `startForeground/stopForeground`。
- Create: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBusinessPhotoStore.java`
  - 如果业务拍照文件保存需要原生 MediaStore，负责写入 `Pictures/RscRtc/`、返回 URI、给宿主授权。

### `MyAppForAIDL`

- Modify: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/ControlPanelController.java`
  - 保留/新增按钮：启动会议、发送消息、合照模式、单人照模式、关闭拍照模式、停止会议；如需要，增加环境、proxy、消息输入框。
- Modify: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/rtc/RtcHostController.java`
  - 默认入房参数对齐旧 `ConferenceOptions`，`initialize()` 默认 `environment=0`，proxy 从 `enterRoom()` 参数传入。
- Modify: `MyAppForAIDL/app/src/androidTest/java/com/yc/rtc/myappforaidl/MainActivityConferenceBlackboxTest.java`
  - 拆分黑盒用例：启动+停止、启动+发送+停止、启动+合照+二次拍照覆盖 singleWithFrame + 停止、启动+单拍+停止、启动+投屏+停止。

Do not touch:

- Existing unrelated `.DS_Store` under `MyAppForAIDL/app/src/main/res/.DS_Store`.
- Old `MyApplicationForFlutter` runtime behavior, except as read-only reference.

---

## Task 1: Baseline Verification And Dirty Worktree Guard

**Files:**
- Read: `docs/superpowers/specs/2026-04-10-rtc-double-apk-p2-flutter-module-migration-design.md`
- Read: `MyAppForAIDL/app/src/main/res/.DS_Store`
- Read: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/rtc/RtcHostController.java`
- Read: `rtc_apk_app/lib/main.dart`
- Read: `flutter_module/lib/main.dart`

- [x] **Step 1: Confirm repo states**

Run:

```bash
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL status --short
git -C /Users/wangxinran/StudioProjects/rtc_apk_app status --short
git -C /Users/wangxinran/StudioProjects/flutter_module status --short 2>/dev/null || true
```

Expected:

- `MyAppForAIDL` may show `?? app/src/main/res/.DS_Store`; ignore it unless user explicitly asks to delete.
- `rtc_apk_app` should be clean before P2 implementation starts.
- `flutter_module` status must be reviewed before edits because P2 will touch it.

- [x] **Step 2: Run baseline Flutter APK verification**

Run:

```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
flutter build apk --debug
```

Expected:

- `flutter analyze` reports no blocking issues.
- debug APK builds.

- [x] **Step 3: Run baseline host/AIDL verification**

Run:

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :rtc-aidl:assembleDebug :app:assembleDebug
```

Expected:

- Build succeeds with JDK 8.

- [x] **Step 4: Commit baseline only if there are intentional setup changes**

Do not commit if no files changed.

---

## Task 2: Add `flutter_module` P2 Entry Without Breaking Old `main()`

**Files:**
- Create: `flutter_module/lib/rtc_module_entry.dart`
- Modify: `flutter_module/lib/main.dart`
- Modify: `rtc_apk_app/lib/main.dart`
- Test: `flutter_module/test/rtc_module_entry_test.dart` if practical

- [x] **Step 1: Add a launch options model**

Create `flutter_module/lib/rtc_module_entry.dart` with a minimal model:

```dart
class RtcModuleLaunchOptions {
  final bool doubleApkNativeMode;
  final String? initialRoute;
  final Map<String, dynamic>? initialArguments;

  const RtcModuleLaunchOptions({
    this.doubleApkNativeMode = false,
    this.initialRoute,
    this.initialArguments,
  });
}
```

Keep this file free of AIDL terms.

- [x] **Step 2: Extract current main boot logic into a reusable function**

Modify `flutter_module/lib/main.dart` so current `main()` delegates to a new function:

```dart
Future<void> main() async {
  await runRtcModuleApp(const RtcModuleLaunchOptions());
}
```

Move the current body of `main()` into `runRtcModuleApp(...)`. Preserve existing standalone behavior when `RtcModuleLaunchOptions()` is default.

- [x] **Step 3: Keep `doubleApkNativeMode` handshake behavior**

Inside `runRtcModuleApp(...)`, keep:

- `WidgetsFlutterBinding.ensureInitialized()`
- `setupServiceLocator()`
- `loggerManager.initializeSync(...)`
- `XChatKitAdapter.init(onNavigatorPush: _handleNativePush)`
- `XChatKitAdapter.handshake()`
- `doubleApkNativeMode` boot placeholder behavior

Do not change route parsing yet.

- [x] **Step 4: Update `rtc_apk_app` main**

Modify `rtc_apk_app/lib/main.dart`:

```dart
import 'package:flutter_module/rtc_module_entry.dart';

Future<void> main() async {
  await runRtcModuleApp(
    const RtcModuleLaunchOptions(doubleApkNativeMode: true),
  );
}
```

- [x] **Step 5: Run analysis**

Run:

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
flutter analyze lib/main.dart lib/rtc_module_entry.dart
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
```

Expected:

- No new analyzer errors.

- [x] **Step 6: Commit**

Commit in the relevant repo(s). If `flutter_module` is a separate repo, commit there separately.

Suggested messages:

```bash
git -C /Users/wangxinran/StudioProjects/flutter_module add lib/main.dart lib/rtc_module_entry.dart
git -C /Users/wangxinran/StudioProjects/flutter_module commit -m "feat: expose rtc module app entry"
git -C /Users/wangxinran/StudioProjects/rtc_apk_app add lib/main.dart
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: run flutter module entry from rtc apk"
```

---

## Task 3: Fix Flutter Asset Loading For Package Dependency Mode

**Files:**
- Modify: `flutter_module/lib/config/app_config.dart`
- Modify: `rtc_apk_app/pubspec.yaml` if required

- [x] **Step 1: Write asset fallback behavior**

Modify `AppConfig.load(...)` so it tries the requested asset path first, then `packages/flutter_module/<assetPath>` when the first load fails and the path starts with `assets/`.

Expected logic:

```dart
final candidates = <String>[
  assetPath,
  if (assetPath.startsWith('assets/'))
    'packages/flutter_module/$assetPath',
];
```

Try each candidate in order; only return defaults after all candidates fail.

- [x] **Step 2: Keep standalone behavior unchanged**

Ensure default standalone paths still work:

- `assets/config/app_config_debug.json`
- `assets/config/app_config.json`

- [x] **Step 3: Run Flutter verification**

Run:

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
flutter analyze lib/config/app_config.dart
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
flutter build apk --debug
```

Expected:

- No analyzer errors.
- `rtc_apk_app` can still build.

- [x] **Step 4: Commit**

Suggested message:

```bash
git -C /Users/wangxinran/StudioProjects/flutter_module add lib/config/app_config.dart
git -C /Users/wangxinran/StudioProjects/flutter_module commit -m "fix: support package asset config loading"
```

---

## Task 4: Build Room Payload From `RtcInitOptions + RtcRoomOptions`

**Files:**
- Create: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcRoomPayloadBuilder.java`
- Modify: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
- Modify: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/rtc/RtcHostController.java`

- [x] **Step 1: Define payload builder responsibilities**

Create `RtcRoomPayloadBuilder` with:

```java
final class RtcRoomPayloadBuilder {
    String buildRoomArgumentsJson(
            RtcInitOptions initOptions,
            RtcRoomOptions roomOptions) {
        // returns JSON string for xchatkit.navigatorPush arguments
    }
}
```

Use `org.json.JSONObject`.

- [x] **Step 2: Implement environment mapping**

Rules:

- `environment == 1` -> `_configSource = "debug"`
- all other values, including missing/default -> `_configSource = "production"`
- effective mapping must remain: `environment=0` -> `app_config.json`, `environment=1` -> `app_config_debug.json`

Do not use `configFileName` as the P2 main path.

- [x] **Step 3: Avoid initialize/enterRoom race**

Because cold start may start Activity before remote AIDL `initialize()` flushes, do not rely only on `RtcBridgeService.initialize(...)` for environment.

Implement one of these minimal options:

- Preferred: `RscRtcBridge.enterRoom(...)` includes the latest pending init environment in the Activity launch payload by creating a copied `RtcRoomOptions` with `arguments.environment`.
- Alternative: `RtcRequestLauncher` accepts `RtcInitOptions` and passes it as an additional Intent extra.

Do not require host to pass environment twice.

- [x] **Step 4: Map `RtcRoomOptions` to old ConferenceOptions equivalent**

Root JSON must include:

```json
{
  "_configSource": "production",
  "fromuser": "...",
  "brhName": "...",
  "unionId": "...",
  "deviceId": "...",
  "language": "...",
  "languageName": "...",
  "appid": "",
  "dept": "",
  "channelName": "zypad",
  "init": 0,
  "noAgentLogin": 0,
  "p2p": false,
  "queueHintCount": 0,
  "queueHintInterval": 0,
  "browser": "pad",
  "busitype1": "ZY",
  "visitorSendInst": "99700320000",
  "r_flag": -1,
  "clientInfo": {
    "tellerCode": "...",
    "tellerName": "...",
    "tellerBranch": "...",
    "tellerIdNo": "...",
    "ip": "...",
    "locationFlag": "...",
    "fileId": "...",
    "pageIndex": 1,
    "pushSpeechFlag": "...",
    "outTaskNo": "",
    "deviceInfo": {
      "imei": "...",
      "brand": "...",
      "model": "...",
      "board": "...",
      "osVersion": "...",
      "sdk": "...",
      "display": "...",
      "gps": "",
      "boxflag": "",
      "brhShtName": "...",
      "deviceInst": "...",
      "deviceNo": "...",
      "updeviceInst": "..."
    }
  }
}
```

Also pass `proxyIp/proxyPort` from `RtcRoomOptions.arguments` if present:

```json
{
  "proxyIp": "x.x.x.x",
  "proxyPort": 8080,
  "mediaInfo": {
    "proxyIp": "x.x.x.x",
    "proxyPort": 8080
  }
}
```

- [x] **Step 5: Update MyAppForAIDL default room options**

Modify `RtcHostController.createDefaultRoomOptions()` to match old `MyApplicationForFlutter` demo values:

- `fromuser = "862175051124177"`
- `route = "/room"`
- `brhName = "中国邮政储蓄银行股份有限公司银川市金凤区支行"`
- `language = "01"`
- `languageName = "普通话"`
- `unionId = "64000652"`
- `channelName = "zypad"`
- `browser = "pad"`
- `busitype1 = "ZY"`
- `visitorSendInst = "99700320000"`
- `r_flag = -1`
- client info and device info from old `MainActivity.startConference()`，必须包含 `updeviceInst`

Default `initialize()` should use `new RtcInitOptions(0, null, null, 0, null)`.

Bundle / ClassLoader constraints:

- only put primitive values, `String`, `Bundle`, primitive arrays/lists, and Android framework parcelables into cross-process `Bundle`
- do not put host custom classes or `Serializable` into cross-process `Bundle`
- JSON-encode complex objects before passing them across APK/process boundaries
- keep payload size controlled to avoid `TransactionTooLargeException`

- [x] **Step 6: Add optional demo inputs only if needed**

If blackbox testing requires runtime input, extend `ControlPanelController` with minimal `EditText` fields:

- environment: default `0`
- proxyIp: optional
- proxyPort: optional
- message: default demo JSON

If hardcoded values are sufficient for P2 blackbox, skip this step.

- [x] **Step 7: Run host build**

Run:

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :rtc-aidl:assembleDebug :app:assembleDebug
```

Expected:

- Build succeeds with JDK 8.

- [x] **Step 8: Commit**

Suggested messages:

```bash
git -C /Users/wangxinran/StudioProjects/rtc_apk_app add android/app/src/main/java/com/example/rtc_apk_app/RtcRoomPayloadBuilder.java android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: build room payload for flutter module"
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL add app/src/main/java/com/yc/rtc/myappforaidl/rtc/RtcHostController.java app/src/main/java/com/yc/rtc/myappforaidl/ControlPanelController.java
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL commit -m "feat: align aidl demo room options"
```

---

## Task 5: Replace P1 Probe Channel With `xchatkit` `doubleApkNativeMode` Bridge

**Files:**
- Create: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcXChatKitBridge.java`
- Modify: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/FlutterEngineHolder.kt`
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcEntryActivity.kt`
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcEntryCoordinator.kt`

- [x] **Step 1: Create `RtcXChatKitBridge`**

Implement a focused bridge with:

```java
final class RtcXChatKitBridge {
    static final String CHANNEL_NAME = "xchatkit";

    interface Listener {
        void onEngineReady();
        void onBusinessPhotoTakeSuccess(ArrayList<String> paths);
        void onBusinessPhotoTakeFail(String errorMessage);
        void onReceiveMessage(String message);
        void onEvent(String event, String message, String timestamp);
    }
}
```

Methods:

- `attach(FlutterEngine engine)`
- `detach()`
- `navigatorPush(String route, String argumentsJson)`
- `requestExit()`
- `sendMessage(String message)`
- `businessPhotoForGroup(String fileName, boolean isCustomerOnLeft)`
- `businessPhotoForSingle(String fileName, boolean toggleCamera, String tipsContent)`
- `closeBusinessPhotoMode()`

- [x] **Step 2: Implement engineReady and pending navigation**

Match `SDLActivityAdapter` timing:

- Before `engineReady`, cache one pending navigation request.
- On `engineReady`, flush pending `/room` navigation.
- After engine ready, `navigatorPush` invokes immediately.

- [x] **Step 3: Update FlutterEngine initial route**

Modify `FlutterEngineHolder.getOrCreate(...)` so P2 engine starts the `flutter_module` app normally.

Use `/` as initial route unless the new `runRtcModuleApp(...)` requires another route.

Do not use `/room-bootstrap` as P2 formal path.

- [x] **Step 4: Update RtcEntryActivity local service flow**

Keep:

- consume requestId
- finish on missing request/options
- show loading while service/engine prepares
- attach cached FlutterEngine fragment

Change:

- after consuming options, call service API that prepares engine and queues `/room` navigation through `RtcXChatKitBridge`
- do not rely on Flutter navigation channel initial route for `/room` payload

- [x] **Step 5: Wire AIDL commands through `RtcXChatKitBridge`**

In `RtcBridgeService`:

- `leaveRoom(...)` -> `xchatkit.requestExit`
- `sendMessage(RtcMessage)` -> `xchatkit.sendMessage(message.message)`
- `setBusinessCaptureMode(group)` -> `xchatkit.businessPhotoForGroup`
- `setBusinessCaptureMode(single)` -> `xchatkit.businessPhotoForSingle`
- do not support `setBusinessCaptureMode(singleWithFrame)` as a formal AIDL mode in P2
- cover `singleWithFrame` only through the existing Flutter business-photo flow triggered after group capture, as specified by blackbox testing
- `setBusinessCaptureMode(close|disabled)` -> `xchatkit.closeBusinessPhotoMode`

- [x] **Step 6: Map Flutter callbacks to AIDL callbacks**

In `RtcBridgeService` listener:

- `onBusinessPhotoTakeSuccess(paths)` -> `RtcCaptureResult(success=true, filePaths=paths, fileUris=...)`
- `onBusinessPhotoTakeFail(error)` -> `RtcCaptureResult(success=false, errorMessage=error)`
- `onReceiveMessage(message)` -> `RtcMessage(message, "receive", null, null)`
- `onEvent("EnterRoomDone", ...)` -> update snapshot to active
- `onEvent("LeaveRoomDone", ...)` -> update snapshot to idle/page hidden
- `onEvent("RoomLifecycleStateChanged", ...)` -> log and optionally update failure fields

- [x] **Step 7: Run compile verification**

Run:

```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
flutter build apk --debug
```

Expected:

- No compile errors.
- APK builds.

- [x] **Step 8: Commit**

Suggested message:

```bash
git -C /Users/wangxinran/StudioProjects/rtc_apk_app add android/app/src/main/java/com/example/rtc_apk_app android/app/src/main/kotlin/com/example/rtc_apk_app lib/main.dart
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: bridge aidl commands to xchatkit"
```

---

## Task 6: Implement Business Photo Shared Storage

**Files:**
- Create or modify: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBusinessPhotoStore.java`
- Modify: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
- Modify: `flutter_module/lib/screens/room/controllers/room_controller.dart`
- Modify: `flutter_module/lib/features/signaling/room_client_entrance_v2.media.dart` or actual photo save file found by `rg`

- [x] **Step 1: Locate current photo save implementation**

Run:

```bash
rg -n "takePhotoByCaptureFrame|saved to|onPhotoTakeSuccess|capturedImage|writeAsBytes|File\\(" /Users/wangxinran/StudioProjects/flutter_module/lib
```

Expected:

- Identify the exact file where photo bytes are saved and success paths are returned.

- [x] **Step 2: Choose minimal save owner**

Use this decision:

- If Flutter already has the image bytes and can use a plugin-supported shared media save path safely, adapt Flutter save path.
- If Flutter only returns private file paths today, prefer a Native MediaStore write helper invoked through `xchatkit` so RTC APK owns public URI generation.

Do not make宿主 write the photo file.

- [x] **Step 3: Implement `Pictures/RscRtc/` output**

For Android 10+:

- Use `MediaStore.Images.Media.EXTERNAL_CONTENT_URI`
- Use `DISPLAY_NAME`
- Use `RELATIVE_PATH = "Pictures/RscRtc/"`
- Use `IS_PENDING` during write if applicable
- Return `content://` URI

For Android 9 and below:

- Use public `Pictures/RscRtc/` path with the existing storage permission strategy.
- Return best-effort file path and URI if available.

- [x] **Step 4: Grant URI read permission to host**

When `RtcCaptureResult` contains a URI:

- call `grantUriPermission(hostPackageName, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)`
- `hostPackageName` can be carried via init extras or room arguments if needed
- if host package is unknown in demo, use `com.yc.rtc.myappforaidl` only for demo and document that production must pass the host package

- [x] **Step 5: Map result back to AIDL**

Ensure callback includes:

- `success`
- `fileUris`
- `filePaths` as best effort
- `errorCode`
- `errorMessage`
- `extras.relativePath = "Pictures/RscRtc/"`

- [x] **Step 6: Run verification**

Run:

```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
flutter build apk --debug
```

Expected:

- Build succeeds.

- [x] **Step 7: Commit**

Suggested message:

```bash
git -C /Users/wangxinran/StudioProjects/rtc_apk_app add android/app/src/main/java/com/example/rtc_apk_app/RtcBusinessPhotoStore.java android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: save business photos to shared pictures"
```

If Flutter files changed, commit in `flutter_module` separately:

```bash
git -C /Users/wangxinran/StudioProjects/flutter_module add <changed-flutter-files>
git -C /Users/wangxinran/StudioProjects/flutter_module commit -m "feat: support shared business photo output"
```

---

## Task 7: Move Native-Mode Foreground Service Ownership To `RtcBridgeService`

**Files:**
- Create: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcMediaForegroundController.java`
- Modify: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
- Modify: `rtc_apk_app/android/app/src/main/AndroidManifest.xml`
- Modify: `flutter_module/lib/features/signaling/room_client_entrance_v2.capability.dart`
- Modify: `flutter_module/lib/features/signaling/room_client_entrance_v2.dart`
- Modify: `flutter_module/lib/features/xchatkit_adapter/channels/xchat_event_channel.dart` if helper is needed

- [x] **Step 1: Update manifest permissions**

In `rtc_apk_app/android/app/src/main/AndroidManifest.xml`, ensure relevant declarations exist:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Keep service declaration:

```xml
android:foregroundServiceType="camera|microphone|mediaProjection"
```

Android官方约束：Android 14 起需要声明对应 foreground service type 和权限；camera/microphone 需要运行时权限已授予；mediaProjection 需要先完成屏幕捕获授权。

- [x] **Step 2: Implement foreground controller**

Create `RtcMediaForegroundController` with:

```java
final class RtcMediaForegroundController {
    void update(boolean microphoneActive, boolean cameraActive, boolean mediaProjectionActive) {}
    void stop() {}
}
```

Responsibilities:

- create notification channel
- build ongoing notification
- compute service type mask on API 29+
- call `ServiceCompat.startForeground(...)` if androidx core is available, otherwise use API-gated `startForeground(...)`
- call `stopForeground(...)` when all flags false

- [x] **Step 3: Wire Flutter media state events**

In `RtcXChatKitBridge.onEvent(...)`, parse:

```json
{
  "microphoneActive": true,
  "cameraActive": true,
  "mediaProjectionActive": false
}
```

When `event == "mediaStateChanged"`, call foreground controller.

- [x] **Step 4: Add Flutter `doubleApkNativeMode` event emission**

In `room_client_entrance_v2.capability.dart`, after successful events:

- `EnableMicAndUploadDone` -> `mediaStateChanged(microphoneActive=true)`
- `DisableMicAndUploadDone` -> `mediaStateChanged(microphoneActive=false)`
- `EnableWebcamAndUploadDone` -> `mediaStateChanged(cameraActive=true)`
- `DisableWebcamAndUploadDone` -> `mediaStateChanged(cameraActive=false)`
- `EnableDisplayAndUploadDone` -> `mediaStateChanged(mediaProjectionActive=true)`
- `DisableDisplayAndUploadDone` -> `mediaStateChanged(mediaProjectionActive=false)`

Use `XChatKitAdapter.doubleApkNativeMode` or an equivalent wrapper around the existing native handshake state to avoid changing standalone behavior.

- [x] **Step 5: Disable Flutter foreground task only in `doubleApkNativeMode`**

In existing Flutter foreground service start/stop points:

- if `XChatKitAdapter.doubleApkNativeMode`, send/update `mediaStateChanged` and return
- if not `XChatKitAdapter.doubleApkNativeMode`, keep current `FlutterForegroundTask.startService/restartService/stopService`

Do not remove standalone foreground task support.

- [x] **Step 6: Run verification**

Run:

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
flutter analyze lib/features/signaling/room_client_entrance_v2.capability.dart lib/features/signaling/room_client_entrance_v2.dart
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
flutter build apk --debug
```

Expected:

- Analyzer clean.
- APK builds.

- [x] **Step 7: Commit**

Suggested messages:

```bash
git -C /Users/wangxinran/StudioProjects/rtc_apk_app add android/app/src/main/AndroidManifest.xml android/app/src/main/java/com/example/rtc_apk_app/RtcMediaForegroundController.java android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: manage media foreground service natively"
git -C /Users/wangxinran/StudioProjects/flutter_module add lib/features/signaling/room_client_entrance_v2.capability.dart lib/features/signaling/room_client_entrance_v2.dart lib/features/xchatkit_adapter/channels/xchat_event_channel.dart
git -C /Users/wangxinran/StudioProjects/flutter_module commit -m "feat: emit native media foreground state"
```

---

## Task 8: Complete Leave / Back / Finish Callback Loop

**Files:**
- Modify: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
- Modify: `rtc_apk_app/android/app/src/main/kotlin/com/example/rtc_apk_app/RtcEntryActivity.kt`
- Modify: `flutter_module/lib/screens/room/room.dart` only if blackbox proves `SystemNavigator.pop()` does not finish `RtcEntryActivity`
- Modify: `flutter_module/lib/features/signaling/room_client_entrance_v2.dart` only if leave callback event is missing

- [x] **Step 1: Use current Flutter leave path first**

Keep current behavior:

- page hangup -> `RoomClientEntranceV2.leave()`
- `doubleApkNativeMode` leaving -> `SystemNavigator.pop()`
- Activity finishes naturally

Do not add a new `finishActivity` channel unless blackbox testing proves it is needed.

- [x] **Step 2: Update snapshot on Flutter leave event**

In `RtcBridgeService` bridge callback:

- `LeaveRoomDone` -> `roomState=idle`, `roomPageShowing=false`
- `ConnectionErrorOccur` or failed lifecycle -> `roomState=failed`, fill failure fields if parseable

- [x] **Step 3: Handle Activity destroy**

In `RtcEntryActivity.onDestroy()`:

- notify Service that page is no longer showing if service still bound
- do not start host Activity
- unbind local Service safely

- [x] **Step 4: Run blackbox smoke**

Install both APKs, then run existing blackbox instrumentation:

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :app:connectedDebugAndroidTest
```

Expected:

- Startup + stop test passes or reveals exact missing finish/callback behavior.

- [x] **Step 5: Commit**

Suggested message:

```bash
git -C /Users/wangxinran/StudioProjects/rtc_apk_app add android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java android/app/src/main/kotlin/com/example/rtc_apk_app/RtcEntryActivity.kt
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: complete rtc page exit callbacks"
```

---

## Task 9: Expand `MyAppForAIDL` Blackbox UI Controls

**Files:**
- Modify: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/ControlPanelController.java`
- Modify: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/rtc/RtcHostController.java`
- Modify: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/MainActivity.java`
- Modify: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/FloatingService.java`

- [x] **Step 1: Keep existing buttons stable**

Ensure these IDs remain:

- `R.id.btnStartConference`
- `R.id.btnSendMessage`
- `R.id.btnBusinessPhotoForGroup`
- `R.id.btnBusinessPhotoForSingle`
- `R.id.btnCloseBusinessPhoto`
- `R.id.btnStopConference`
- `R.id.tvLog`
- `R.id.tvBusinessPhotoPath`

- [x] **Step 2: Add missing controls only if absent**

Add minimal buttons if needed:

- optional environment/proxy/message input fields if hardcoded demo values are insufficient

Do not add a dedicated `singleWithFrame` host button for P2 unless the spec changes. P2 covers it through RTC page second photo action after group mode.

Default environment must be `0`.

- [x] **Step 3: Add explicit logging for blackbox assertions**

Log these strings through `RtcHostLogManager`:

- `进入会议请求已发送`
- `发送消息:`
- `进入群拍模式:`
- `进入单拍模式:`
- `业务拍照回调:`
- `业务拍照路径:`
- `请求关闭会议`
- `房间状态:`
- `Service状态:`

- [x] **Step 4: Run JDK 8 compile**

Run:

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :app:assembleDebug :app:assembleDebugAndroidTest
```

Expected:

- Build succeeds.

- [x] **Step 5: Commit**

Suggested message:

```bash
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL add app/src/main/java/com/yc/rtc/myappforaidl
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL commit -m "feat: add p2 aidl blackbox controls"
```

---

## Task 10: Implement Split Blackbox Test Cases

**Files:**
- Modify: `MyAppForAIDL/app/src/androidTest/java/com/yc/rtc/myappforaidl/MainActivityConferenceBlackboxTest.java`
- Optionally create: `MyAppForAIDL/app/src/androidTest/java/com/yc/rtc/myappforaidl/UiAutomatorActions.java`

- [x] **Step 1: Use UIAutomator/adb-style interactions only**

Do not call SDK internals directly.

Allowed:

- launch app
- find button by text/resource ID
- click
- wait for text/log output
- press Back
- inspect current package/window

Not allowed as final proof:

- directly instantiate `RscRtcBridge`
- directly call `RtcBridgeService`
- mock AIDL service

- [x] **Step 2: Add startup + stop case**

Test:

- click 启动会议
- wait real Flutter page / RTC package visible
- click 停止会议
- assert logs contain leave/callback result

- [x] **Step 3: Add startup + send + stop case**

Test:

- click 启动会议
- wait room ready or log marker
- click 发送消息
- assert logs/logcat contain send message marker
- click 停止会议

- [x] **Step 4: Add group capture case**

Test:

- click 启动会议
- wait room ready
- click 合照模式
- click RTC page photo button by coordinates or accessible text
- wait business photo callback
- assert path contains `Pictures/RscRtc/` or URI starts with `content://`
- click 停止会议

- [x] **Step 5: Add group second-photo singleWithFrame coverage**

Test:

- click 启动会议
- click 合照模式
- click RTC page photo button by coordinates or accessible text
- wait first business photo callback; if the expected current behavior is failure before second capture, assert/log that failure explicitly
- click RTC page photo button again to cover the existing Flutter `singleWithFrame` path
- wait callback
- assert path/URI
- click 停止会议

- [x] **Step 6: Add single capture case**

Test:

- click 启动会议
- click 单人照模式
- click RTC page photo button
- wait callback
- assert path/URI
- click 停止会议

- [x] **Step 7: Add display trigger case**

Test:

- click 启动会议
- wait room ready
- tap RTC page once to trigger display/presentation behavior
- assert logcat or host log contains display/mediaProjection active marker
- click 停止会议

- [x] **Step 8: Run connected tests**

Run:

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :app:connectedDebugAndroidTest
```

Expected:

- All blackbox tests pass on connected device.

- [x] **Step 9: Commit**

Suggested message:

```bash
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL add app/src/androidTest/java/com/yc/rtc/myappforaidl
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL commit -m "test: cover p2 rtc double apk blackbox flows"
```

---

## Task 11: Final Cross-Project Verification

**Files:**
- No source edits expected

- [x] **Step 1: Verify Flutter module**

Run:

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
flutter analyze lib
flutter test
```

Expected:

- Analyzer has no new blocking errors.
- Tests pass or failures are documented as pre-existing.

- [x] **Step 2: Verify RTC APK**

Run:

```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
flutter build apk --debug
```

Expected:

- Analyzer clean.
- APK builds.

- [x] **Step 3: Verify host/AIDL with JDK 8**

Run:

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :rtc-aidl:assembleDebug :app:assembleDebug :app:assembleDebugAndroidTest
```

Expected:

- Build succeeds under JDK 8.

- [x] **Step 4: Run blackbox connected tests**

Run:

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :app:connectedDebugAndroidTest
```

Expected:

- All P2 blackbox cases pass on connected device.

- [x] **Step 5: Capture log evidence**

Collect:

```bash
adb logcat -d -v threadtime > /tmp/rtc_p2_blackbox_logcat.txt
```

Confirm log evidence includes:

- room enter success
- mic/camera/display media state
- message send
- group capture result
- group second-photo `singleWithFrame` result
- single capture result
- leave callback

- [x] **Step 6: Final commits**

Commit any remaining intentionally changed files by repo:

```bash
git -C /Users/wangxinran/StudioProjects/flutter_module status --short
git -C /Users/wangxinran/StudioProjects/rtc_apk_app status --short
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL status --short
```

Do not commit ignored `.DS_Store` unless user explicitly asks.

---

## Notes For Implementers

- Keep P2 small. If a change starts rewriting RTC logic, stop and re-scope.
- Treat the local path dependency as an explicit build risk: if `flutter_module` fails analysis/build, fix the shared source or dependency constraint instead of copying Dart code into `rtc_apk_app`.
- Prefer adapting `rtc_apk_app` to existing `flutter_module` protocol over changing Flutter internals.
- Do not rely on `initialize()` arriving before Activity cold start navigation. Carry or merge environment into the Activity-first launch path.
- Keep `proxyIp/proxyPort` in `enterRoom()` payload, not `initialize()`主路径。
- Use `xchatkit` as the formal P2 MethodChannel path.
- Treat `com.yc.rtc.bridge/channel` as P1 probe/stub only.
- Android official docs require foreground service type declarations and type-specific permissions for Android 14 when targeting API 34; camera/microphone also require runtime permissions before starting corresponding foreground service types, and mediaProjection requires screen capture consent before creating that type.
