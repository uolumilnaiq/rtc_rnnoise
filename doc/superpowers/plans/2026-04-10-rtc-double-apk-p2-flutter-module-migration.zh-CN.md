# RTC 双 APK P2 Flutter Module 迁移实施计划

> **给执行 agent 的要求：** 按任务逐项执行。实现阶段优先使用 `executing-plans`，如用户明确要求并行 agent 再使用 `subagent-driven-development`。步骤使用 checkbox（`- [ ]`）跟踪。Android 跨 APK 验收禁止白盒替代，必须使用 `adb + UI` 黑盒路径。

**目标：** 将 `rtc_apk_app` 从 P1 skeleton/probe 页面接入真实 `flutter_module` RTC 页面，并补齐 AIDL 命令、业务拍照、媒体前台服务和黑盒验收闭环。

**架构：** `rtc_apk_app` 继续通过本地 `path` 依赖复用 `flutter_module`，不复制 Dart 代码。`rtc_apk_app` 原生层负责 AIDL、Activity/Service、FlutterEngine、`xchatkit` MethodChannel 适配、MediaStore 与前台服务；`flutter_module` 负责 RTC 页面、信令、WebRTC、页面内挂断、业务拍照 UI 和媒体生命周期。P2 保持 P1 Activity-first 冷启动主路径，不回退到后台 Service 拉页。

**技术栈：** Flutter app + local `path` package、Dart/Flutter、Android Java/Kotlin、AIDL、MethodChannel `xchatkit`、MediaStore、Android Foreground Service、`adb + UI` 黑盒测试、`MyAppForAIDL` 使用 JDK 8。

---

## 范围

P2 包含：

- `rtc_apk_app` 通过 `path: ../flutter_module` 复用现有 RTC 能力
- 不复制 `flutter_module/lib` 到 `rtc_apk_app/lib`
- `flutter_module` 增加 P2 专用最小入口，不改变原 `main()` standalone 行为
- `rtc_apk_app` 适配既有 `xchatkit` 协议，参考但不整块迁移 `SDLActivityAdapter`
- 入房参数对齐旧 `ConferenceOptions`
- `environment` 默认 `0=production`，`1=debug`
- `proxyIp/proxyPort` 从 `enterRoom()` 业务参数传入，不放到 `initialize()` 主路径
- `sendMessage`
- 合照、单人照业务拍照；`singleWithFrame` 不作为 AIDL mode 支持，只通过合照流程中的二次拍照路径覆盖
- 业务拍照保存到 `Pictures/RscRtc/`
- 原生 `RtcBridgeService` 统一管理 microphone/camera/mediaProjection 前台服务类型与通知
- `adb + UI` 黑盒验收

P2 不包含：

- 复制 `flutter_module/lib` 到 `rtc_apk_app/lib`
- 重写 RTC 信令、WebRTC、房间 UI
- 新增正式 `singleWithFrame` 宿主按钮或 AIDL mode
- 用白盒测试替代跨 APK 黑盒验收

---

## 文件结构

### `flutter_module`

- 修改：`flutter_module/lib/main.dart`
  - 抽出可复用 app 启动函数，保留原 `main()` 行为。
- 新增：`flutter_module/lib/rtc_module_entry.dart`
  - 暴露 `RtcModuleLaunchOptions` 和 `runRtcModuleApp(...)`，供 `rtc_apk_app` 调用。
- 修改：`flutter_module/lib/config/app_config.dart`
  - 对 package asset 路径做最小兼容，支持 `assets/config/...` 和 `packages/flutter_module/assets/config/...`。
- 修改：`flutter_module/lib/features/xchatkit_adapter/...` 或现有 `xchatkit` 入口文件，按实际路径落地。
  - 如缺少 `engineReady`、`navigatorPush`、`requestExit`、`sendMessage`、业务拍照、媒体状态上报等协议，按现有协议最小补齐。
- 修改：`flutter_module/lib/screens/room/room.dart` 或实际房间页面文件，只有在黑盒验证证明 `SystemNavigator.pop()` 不能关闭 `RtcEntryActivity` 时，才补 `finishActivity` 通道。
- 修改：Flutter 前台服务封装所在文件，按实际路径落地。
  - `doubleApkNativeMode` 下不再实际启动/停止 `flutter_foreground_task`，改为向 `rtc_apk_app` 原生层上报媒体状态；standalone 模式保持原逻辑。

### `rtc_apk_app`

- 修改：`rtc_apk_app/pubspec.yaml`
  - 保持 `flutter_module: path: ../flutter_module`，补齐必要依赖/asset 兼容。
- 修改：`rtc_apk_app/lib/main.dart`
  - 调用 `flutter_module` 新入口，不直接调用旧 `main()`。
- 修改：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
  - 将 AIDL 命令转发到 `xchatkit`，消费 `RtcRoomOptions`，管理媒体前台服务。
- 修改：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcEntryActivity.kt`
  - 启动 FlutterEngine 后等待 `xchatkit.engineReady` 再推 `/room` 导航。
- 新增：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcXChatKitBridge.java`
  - 封装 `xchatkit` MethodChannel、pending navigation、Flutter callback 到 AIDL callback 的桥接。
- 新增：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcRoomPayloadBuilder.java`
  - 将 `RtcInitOptions + RtcRoomOptions` 转成旧 `ConferenceOptions` 等价 `/room` JSON。
- 新增：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBusinessPhotoStore.java`
  - 使用 `MediaStore.Images` 写入 `Pictures/RscRtc/`，返回 `content://` URI 和 best-effort file path。
- 新增：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcMediaForegroundController.java`
  - 维护 microphone/camera/mediaProjection active 状态，统一 `startForeground/stopForeground`。
- 修改：`rtc_apk_app/android/app/src/main/AndroidManifest.xml`
  - 补齐 Android 14 前台服务类型和权限声明。

### `MyAppForAIDL`

- 修改：`MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/ControlPanelController.java`
  - 保留/新增按钮：启动会议、发送消息、合照模式、单人照模式、关闭拍照模式、停止会议；如需要，增加环境、proxy、消息输入框。
- 修改：`MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/rtc/RtcHostController.java`
  - 默认入房参数对齐旧 `ConferenceOptions`，`initialize()` 默认 `environment=0`，proxy 从 `enterRoom()` 参数传入。
- 修改：`MyAppForAIDL/app/src/androidTest/java/com/yc/rtc/myappforaidl/MainActivityConferenceBlackboxTest.java`
  - 拆分黑盒用例：启动+停止、启动+发送+停止、启动+合照+二次拍照覆盖 singleWithFrame + 停止、启动+单拍+停止、启动+投屏+停止。

不要修改：

- `MyAppForAIDL/app/src/main/res/.DS_Store`
- 旧 `MyApplicationForFlutter` 运行行为；只能作为只读参考。

---

## Task 1：基线验证与工作区保护

**文件：**

- 只读：所有相关工程

- [x] **Step 1：检查工作区状态**

运行：

```bash
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL status --short
git -C /Users/wangxinran/StudioProjects/rtc_apk_app status --short
git -C /Users/wangxinran/StudioProjects/flutter_module status --short
```

预期：

- 只允许存在用户已说明忽略的 `MyAppForAIDL/app/src/main/res/.DS_Store`。
- 如果发现其他非本任务改动，停止并向用户确认。

- [x] **Step 2：验证 `rtc_apk_app` 基线**

运行：

```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
flutter build apk --debug
```

预期：

- `flutter analyze` 无阻塞错误。
- debug APK 构建成功。

- [x] **Step 3：验证 `MyAppForAIDL` 基线**

运行：

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :rtc-aidl:assembleDebug :app:assembleDebug
```

预期：

- JDK 8 下构建成功。

- [x] **Step 4：如有基线修复，独立提交**

如果没有文件改动，不提交。

---

## Task 2：给 `flutter_module` 增加 P2 入口且不破坏旧 `main()`

**文件：**

- 新增：`flutter_module/lib/rtc_module_entry.dart`
- 修改：`flutter_module/lib/main.dart`
- 修改：`rtc_apk_app/lib/main.dart`
- 可选测试：`flutter_module/test/rtc_module_entry_test.dart`

- [x] **Step 1：新增启动参数模型**

创建 `flutter_module/lib/rtc_module_entry.dart`：

```dart
class RtcModuleLaunchOptions {
  const RtcModuleLaunchOptions({
    this.doubleApkNativeMode = false,
    this.initialEnvironment = 0,
  });

  final bool doubleApkNativeMode;
  final int initialEnvironment;
}
```

- [x] **Step 2：抽出 `runRtcModuleApp(...)`**

修改 `flutter_module/lib/main.dart`，让当前 `main()` 委托给新函数：

```dart
Future<void> main() async {
  await runRtcModuleApp(const RtcModuleLaunchOptions());
}
```

要求：

- 将现有 `main()` 主体迁移到 `runRtcModuleApp(...)`。
- `RtcModuleLaunchOptions()` 默认参数必须保持旧 standalone 行为。
- 不改变旧 native 嵌入模式的可见行为。
- 双 APK 新逻辑只通过 `options.doubleApkNativeMode` 做最小分支，避免和旧 native 嵌入模式混用。

- [x] **Step 3：让 `rtc_apk_app` 调用新入口**

修改 `rtc_apk_app/lib/main.dart`：

```dart
import 'package:flutter_module/rtc_module_entry.dart';

Future<void> main() async {
  await runRtcModuleApp(
    const RtcModuleLaunchOptions(
      doubleApkNativeMode: true,
      initialEnvironment: 0,
    ),
  );
}
```

- [x] **Step 4：运行 Flutter 验证**

运行：

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
flutter analyze
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
flutter build apk --debug
```

预期：

- 无 analyzer 阻塞错误。
- `rtc_apk_app` debug APK 构建成功。

- [x] **Step 5：提交**

```bash
git -C /Users/wangxinran/StudioProjects/flutter_module add lib/main.dart lib/rtc_module_entry.dart
git -C /Users/wangxinran/StudioProjects/flutter_module commit -m "feat: add rtc module p2 entry"

git -C /Users/wangxinran/StudioProjects/rtc_apk_app add lib/main.dart pubspec.yaml pubspec.lock
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: launch flutter module entry"
```

---

## Task 3：修复 package 依赖模式下的 Flutter asset 加载

**文件：**

- 修改：`flutter_module/lib/config/app_config.dart`
- 按需修改：`rtc_apk_app/pubspec.yaml`

- [x] **Step 1：增加 asset fallback**

修改 `AppConfig.load(...)`，先尝试原路径，再尝试 package 路径：

```dart
final candidates = <String>[
  assetPath,
  if (assetPath.startsWith('assets/'))
    'packages/flutter_module/$assetPath',
];
```

要求：

- 逐个候选路径尝试。
- 只有全部失败后才使用默认配置。

- [x] **Step 2：保持 standalone 行为不变**

确认这些路径仍然可用：

- `assets/config/app_config_debug.json`
- `assets/config/app_config.json`

- [x] **Step 3：运行验证**

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
flutter analyze lib/config/app_config.dart
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
flutter build apk --debug
```

预期：

- 无 analyzer 错误。
- `rtc_apk_app` 可以构建。

- [x] **Step 4：提交**

```bash
git -C /Users/wangxinran/StudioProjects/flutter_module add lib/config/app_config.dart
git -C /Users/wangxinran/StudioProjects/flutter_module commit -m "fix: support package asset config loading"
```

---

## Task 4：从 `RtcInitOptions + RtcRoomOptions` 构造 `/room` payload

**文件：**

- 新增：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcRoomPayloadBuilder.java`
- 修改：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
- 修改：`MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/rtc/RtcHostController.java`

- [x] **Step 1：定义 payload builder 职责**

创建：

```java
final class RtcRoomPayloadBuilder {
    String buildRoomArgumentsJson(
            RtcInitOptions initOptions,
            RtcRoomOptions roomOptions) {
        // 返回 xchatkit.navigatorPush 的 /room arguments JSON
    }
}
```

要求使用 `org.json.JSONObject`。

- [x] **Step 2：实现环境映射**

规则：

- `environment == 1` -> `_configSource = "debug"`
- 其他值，包括缺省/0 -> `_configSource = "production"`
- 有效映射必须保持：`environment=0` -> `app_config.json`，`environment=1` -> `app_config_debug.json`
- `configFileName` 不作为 P2 主路径使用

- [x] **Step 3：规避 initialize/enterRoom 竞态**

原因：冷启动时 Activity 可能先于远端 AIDL `initialize()` 参数落地。

最小实现选择其一：

- 推荐：`RscRtcBridge.enterRoom(...)` 将最新 init environment 合并到 Activity launch payload，例如复制一份 `RtcRoomOptions` 并写入 `arguments.environment`。
- 可选：`RtcRequestLauncher` 接收 `RtcInitOptions` 并作为额外 Intent extra 传递。

要求：宿主不需要重复传 `environment`。

- [x] **Step 4：映射旧 `ConferenceOptions` 等价字段**

Root JSON 必须包含：

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

如 `RtcRoomOptions.arguments` 中存在 `proxyIp/proxyPort`，同时写入根层和 `mediaInfo`：

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

- [x] **Step 5：更新 MyAppForAIDL 默认入房参数**

修改 `RtcHostController.createDefaultRoomOptions()`，对齐旧 `MyApplicationForFlutter` demo 值：

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
- `clientInfo/deviceInfo` 参考旧 `MainActivity.startConference()`，必须包含 `updeviceInst`

默认 `initialize()` 使用：

```java
new RtcInitOptions(0, null, null, 0, null)
```

Bundle / ClassLoader 约束：

- 跨进程 `Bundle` 只放基础类型、`String`、`Bundle`、基础数组/列表、Android framework parcelable
- 禁止放宿主自定义类或 `Serializable`
- 复杂对象跨 APK/跨进程前必须 JSON 化
- 控制体积，避免 `TransactionTooLargeException`

- [x] **Step 6：如黑盒需要，再增加 demo 输入框**

可选字段：

- environment：默认 `0`
- proxyIp：可选
- proxyPort：可选
- message：默认 demo JSON

如果硬编码值足够 P2 黑盒验收，则跳过。

- [x] **Step 7：运行 host 构建**

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :rtc-aidl:assembleDebug :app:assembleDebug
```

- [x] **Step 8：运行 Flutter APK 构建**

```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter build apk --debug
```

- [x] **Step 9：提交**

```bash
git -C /Users/wangxinran/StudioProjects/rtc_apk_app add android/app/src/main/java/com/example/rtc_apk_app/RtcRoomPayloadBuilder.java android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: build rtc room payload"

git -C /Users/wangxinran/StudioProjects/MyAppForAIDL add app/src/main/java/com/yc/rtc/myappforaidl/rtc/RtcHostController.java
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL commit -m "test: align aidl demo room options"
```

---

## Task 5：用 `xchatkit` `doubleApkNativeMode` Bridge 替换 P1 probe 通道

**文件：**

- 新增：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcXChatKitBridge.java`
- 修改：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
- 修改：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcEntryActivity.kt`

- [x] **Step 1：实现 MethodChannel 封装**

创建 `RtcXChatKitBridge`，Channel 名称必须是：

```text
xchatkit
```

需要支持：

- `engineReady`
- `navigatorPush(String route, String argumentsJson)`
- `requestExit`
- `sendMessage(String message)`
- `businessPhotoForGroup(...)`
- `businessPhotoForSingle(...)`
- `closeBusinessPhotoMode`

参考：

```text
MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/SDLActivityAdapter.java
```

只参考协议和时序，不迁移旧 Activity/Engine 管理。

- [x] **Step 2：实现 engineReady 和 pending navigation**

要求：

- `engineReady` 前缓存一个 pending navigation request。
- `engineReady` 后 flush `/room` navigation。
- 如果已有新请求覆盖旧请求，以最新请求为准。
- 记录关键日志，方便黑盒定位。

- [x] **Step 3：更新 FlutterEngine initial route**

规则：

- initial route 使用 `/`，除非新 `runRtcModuleApp(...)` 明确要求其他 route。
- 不再把 `/room-bootstrap` 作为正式主路径。
- 不依赖 Flutter navigation channel initial route 承载 `/room` payload。

- [x] **Step 4：接入 `RtcBridgeService.enterRoom`**

消费 options 后：

- 调用 service API 准备 engine。
- 通过 `RtcXChatKitBridge` queue `/room` navigation。
- 不依赖 Flutter initial route 承载 `/room` payload。

- [x] **Step 5：通过 `RtcXChatKitBridge` 转发 AIDL 命令**

在 `RtcBridgeService` 中映射：

- `leaveRoom(...)` -> `xchatkit.requestExit`
- `sendMessage(RtcMessage)` -> `xchatkit.sendMessage(message.message)`
- `setBusinessCaptureMode(group)` -> `xchatkit.businessPhotoForGroup`
- `setBusinessCaptureMode(single)` -> `xchatkit.businessPhotoForSingle`
- 不支持 `setBusinessCaptureMode(singleWithFrame)` 作为 P2 正式 AIDL mode
- `singleWithFrame` 只通过现有 Flutter 合照后的二次拍照流程覆盖
- `setBusinessCaptureMode(close|disabled)` -> `xchatkit.closeBusinessPhotoMode`

- [x] **Step 6：映射 Flutter callback 到 AIDL callback**

需要处理：

- 房间进入成功/失败
- 页面退出/离房完成
- sendMessage 到达或失败
- 业务拍照成功/失败
- 媒体状态变化：microphone/camera/display active

- [x] **Step 7：运行构建**

```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter build apk --debug
```

- [x] **Step 8：提交**

```bash
git -C /Users/wangxinran/StudioProjects/rtc_apk_app add android/app/src/main/java/com/example/rtc_apk_app/RtcXChatKitBridge.java android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java android/app/src/main/java/com/example/rtc_apk_app/RtcEntryActivity.kt
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: bridge aidl commands to xchatkit"
```

---

## Task 6：业务拍照保存到共享图片路径

**文件：**

- 新增：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBusinessPhotoStore.java`
- 修改：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
- 按需修改：`flutter_module` 业务拍照结果路径生成处，按实际路径落地

- [x] **Step 1：实现 `Pictures/RscRtc/` 输出策略**

使用 `MediaStore.Images` 写入：

- `Pictures/RscRtc/`
- 主要返回 `content://` URI
- `filePaths` best-effort 返回真实路径，拿不到时不阻塞主流程

- [x] **Step 2：给宿主授予 URI 读权限**

如果知道宿主包名：

```java
grantUriPermission(hostPackageName, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
```

- [x] **Step 3：对齐 callback 数据模型**

Flutter 成功：

- `onBusinessPhotoTakeSuccess(List<String>)`

AIDL 返回：

- `RtcCaptureResult(success=true, uri=contentUri, filePaths=...)`

Flutter 失败：

- `onBusinessPhotoTakeFail(String)`

AIDL 返回：

- `RtcCaptureResult(success=false, errorMessage=...)`

- [x] **Step 4：记录黑盒日志**

日志必须包含：

- capture mode
- content URI
- file path if available
- error message if failed

- [x] **Step 5：构建验证**

```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter build apk --debug
```

- [x] **Step 6：提交**

```bash
git -C /Users/wangxinran/StudioProjects/rtc_apk_app add android/app/src/main/java/com/example/rtc_apk_app/RtcBusinessPhotoStore.java android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: store business photos in shared pictures"
```

---

## Task 7：`doubleApkNativeMode` 下由 `RtcBridgeService` 接管前台服务

**文件：**

- 新增：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcMediaForegroundController.java`
- 修改：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
- 修改：`rtc_apk_app/android/app/src/main/AndroidManifest.xml`
- 修改：Flutter 前台服务封装所在文件，按实际路径落地

- [x] **Step 1：补 Manifest 权限与类型**

按目标 SDK 和兼容性声明：

- `android.permission.FOREGROUND_SERVICE`
- Android 14/API 34 需要的类型权限：
  - `android.permission.FOREGROUND_SERVICE_CAMERA`
  - `android.permission.FOREGROUND_SERVICE_MICROPHONE`
  - `android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION`
- service 类型：
  - `camera`
  - `microphone`
  - `mediaProjection`

- [x] **Step 2：实现 `RtcMediaForegroundController`**

职责：

- 跟踪 `microphoneActive`
- 跟踪 `cameraActive`
- 跟踪 `displayActive/mediaProjectionActive`
- 根据 active 类型合成前台服务类型 bitmask
- 可用时调用 `ServiceCompat.startForeground(...)`，否则做 API gated `startForeground(...)`
- 所有 flag 为 false 时调用 `stopForeground(...)`
- Android 14 前提：camera/microphone runtime permission 已获取后才能启动对应 type；mediaProjection 必须在屏幕采集授权之后才能创建对应 type

- [x] **Step 3：Flutter `doubleApkNativeMode` 下不直接控制 `flutter_foreground_task`**

修改 Flutter 前台服务封装：

- `doubleApkNativeMode`：只上报 media state 到 `xchatkit`
- standalone mode：保持现有 `FlutterForegroundTask.startService/restartService/stopService`

- [x] **Step 4：接入 `RtcBridgeService`**

当 Flutter 上报：

- mic active -> 更新 microphone type
- camera active -> 更新 camera type
- display/projection active -> 更新 mediaProjection type
- stop -> 清理对应 type

- [x] **Step 5：构建验证**

```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter build apk --debug
```

- [x] **Step 6：提交**

```bash
git -C /Users/wangxinran/StudioProjects/rtc_apk_app add android/app/src/main/AndroidManifest.xml android/app/src/main/java/com/example/rtc_apk_app/RtcMediaForegroundController.java android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: manage rtc media foreground service"
```

---

## Task 8：完成 leave / back / finish callback 闭环

**文件：**

- 修改：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java`
- 修改：`rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcXChatKitBridge.java`
- 只在必要时修改：`flutter_module/lib/screens/room/room.dart` 或实际房间页面文件

- [x] **Step 1：AIDL leaveRoom 转发**

`leaveRoom()` 调用：

- `xchatkit.requestExit`
- Flutter 执行现有 leave 流程
- Flutter leave 完成后 callback 到 native
- native 回调宿主

- [x] **Step 2：RTC 页面挂断按钮闭环**

要求：

- RTC 页面内部挂断按钮使用现有 Flutter leave 能力。
- 离房完成后通知 native。
- native 回调宿主。
- Activity 自然 finish，回到发起会议的宿主 Activity。

- [x] **Step 3：系统 Back 等价 leaveRoom**

要求：

- 用户按系统 Back 退出 RTC 页面时，等同 `leaveRoom()`。
- 不由宿主强拉回页面。
- 只通过 callback 告知宿主状态。

- [x] **Step 4：只在黑盒证明需要时新增 `finishActivity`**

默认不新增 `finishActivity` channel。

如果黑盒证明 `SystemNavigator.pop()` 不能关闭 `RtcEntryActivity`，再新增 Flutter -> Native：

```text
xchatkit.finishActivity
```

- [x] **Step 5：运行黑盒 smoke**

安装两个 APK 后运行既有黑盒 instrumentation：

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :app:connectedDebugAndroidTest
```

预期：

- 启动会议后停止会议能自然回到宿主 Activity。
- 没有 `service_not_ready_please_retry` 首点失败。
- 没有 `beginBroadcast() called while already in a broadcast`。

- [x] **Step 6：提交**

```bash
git -C /Users/wangxinran/StudioProjects/rtc_apk_app add android/app/src/main/java/com/example/rtc_apk_app/RtcBridgeService.java android/app/src/main/java/com/example/rtc_apk_app/RtcXChatKitBridge.java
git -C /Users/wangxinran/StudioProjects/rtc_apk_app commit -m "feat: complete rtc leave callback loop"
```

---

## Task 9：扩展 `MyAppForAIDL` 黑盒 UI 控件

**文件：**

- 修改：`MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/ControlPanelController.java`
- 修改：`MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/MainActivity.java`
- 修改：`MyAppForAIDL/app/src/main/res/layout/activity_main.xml` 或当前实际 layout
- 修改：`MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/rtc/RtcHostController.java`

- [x] **Step 1：确认 UI 控件 ID**

确保保留/新增这些 ID：

- `R.id.btnStartConference`
- `R.id.btnSendMessage`
- `R.id.btnBusinessPhotoForGroup`
- `R.id.btnBusinessPhotoForSingle`
- `R.id.btnCloseBusinessPhoto`
- `R.id.btnStopConference`
- `R.id.tvLog`
- `R.id.tvBusinessPhotoPath`

- [x] **Step 2：只补必要控件**

按需增加：

- environment/proxy/message 输入框，如果硬编码 demo 值不够用

不要新增专门的 `singleWithFrame` 宿主按钮，除非 spec 后续变更。P2 通过合照模式后 RTC 页面二次拍照覆盖 `singleWithFrame`。

默认 environment 必须为 `0`。

- [x] **Step 3：增加黑盒断言日志**

UI 日志至少包含：

- `启动会议 requested`
- `会议进入成功` 或对应 callback
- `发送消息 requested`
- `发送消息 callback`
- `合照模式 requested`
- `单人照模式 requested`
- `业务拍照 result uri=... path=...`
- `停止会议 requested`
- `离房 callback`

- [x] **Step 4：构建验证**

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :app:assembleDebug :app:assembleDebugAndroidTest
```

- [x] **Step 5：提交**

```bash
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL add app/src/main/java/com/yc/rtc/myappforaidl/ControlPanelController.java app/src/main/java/com/yc/rtc/myappforaidl/MainActivity.java app/src/main/res/layout/activity_main.xml app/src/main/java/com/yc/rtc/myappforaidl/rtc/RtcHostController.java
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL commit -m "feat: add p2 aidl blackbox controls"
```

---

## Task 10：实现拆分黑盒用例

**文件：**

- 修改：`MyAppForAIDL/app/src/androidTest/java/com/yc/rtc/myappforaidl/MainActivityConferenceBlackboxTest.java`
- 按需修改：`MyAppForAIDL/app/src/androidTest/java/com/yc/rtc/myappforaidl/...` helper 文件

约束：

- 不写白盒验证作为最终证明。
- 只通过 `adb + UI` 点击模拟真实用户路径。
- 允许用 logcat/UI 文本做断言。
- 允许按坐标点击 RTC 页面拍照按钮；坐标必须集中成常量，方便后续按设备调整。

- [x] **Step 1：增加通用工具**

需要工具能力：

- 启动 `MyAppForAIDL`
- 点击宿主 UI 按钮
- 等待日志文本出现
- 使用 `adb shell input tap x y` 点击 RTC 页面
- 拉取 logcat 并过滤关键 tag
- 每个用例结束时尽力停止会议并回到宿主

- [x] **Step 2：启动+停止用例**

流程：

- 点击启动会议
- 等待房间 ready 或明确日志 marker
- 点击停止会议
- 等待 leave callback
- 确认回到宿主 Activity

- [x] **Step 3：启动+发送+停止用例**

流程：

- 点击启动会议
- 等待房间 ready 或日志 marker
- 点击发送消息
- 断言日志/logcat 包含 send message marker
- 点击停止会议

- [x] **Step 4：合照用例**

流程：

- 点击启动会议
- 等待房间 ready
- 点击合照模式
- 用坐标或可访问文本点击 RTC 页面拍照按钮
- 等待业务拍照 callback
- 断言路径包含 `Pictures/RscRtc/` 或 URI 以 `content://` 开头
- 点击停止会议

- [x] **Step 5：合照二次拍照覆盖 `singleWithFrame`**

流程：

- 点击启动会议
- 点击合照模式
- 用坐标或可访问文本点击 RTC 页面拍照按钮
- 等待第一次业务拍照 callback；如果当前预期是二次拍照前失败，必须显式断言/记录该失败
- 再次点击 RTC 页面拍照按钮，覆盖现有 Flutter `singleWithFrame` 路径
- 等待 callback
- 断言 path/URI
- 点击停止会议

- [x] **Step 6：单人照用例**

流程：

- 点击启动会议
- 点击单人照模式
- 点击 RTC 页面拍照按钮
- 等待 callback
- 断言 path/URI
- 点击停止会议

- [x] **Step 7：投屏触发用例**

流程：

- 点击启动会议
- 等待 mic/camera 日志
- 点击 RTC 页面触发 display/projection
- 断言日志出现 display/mediaProjection active
- 点击停止会议

- [x] **Step 8：运行黑盒测试**

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :app:connectedDebugAndroidTest
```

预期：

- 所有 P2 黑盒用例在连接设备上通过。

- [x] **Step 9：提交**

```bash
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL add app/src/androidTest/java/com/yc/rtc/myappforaidl/MainActivityConferenceBlackboxTest.java
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL commit -m "test: cover p2 rtc double apk blackbox flows"
```

---

## Task 11：最终跨工程验证

**文件：**

- 所有已修改文件

- [x] **Step 1：Flutter module 静态检查**

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
flutter analyze
```

预期：无阻塞 analyzer 错误。

- [x] **Step 2：rtc_apk_app 构建**

```bash
cd /Users/wangxinran/StudioProjects/rtc_apk_app
flutter analyze
flutter build apk --debug
```

预期：debug APK 构建成功。

- [x] **Step 3：MyAppForAIDL 构建**

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :rtc-aidl:assembleDebug :app:assembleDebug :app:assembleDebugAndroidTest
```

预期：JDK 8 下构建成功。

- [x] **Step 4：安装并运行黑盒 connected 测试**

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd /Users/wangxinran/StudioProjects/MyAppForAIDL
./gradlew :app:connectedDebugAndroidTest
```

预期：所有 P2 黑盒用例通过。

- [x] **Step 5：收集 logcat 证据**

```bash
adb logcat -d -v threadtime > /tmp/rtc_p2_blackbox_logcat.txt
```

确认日志包含：

- 房间进入成功
- mic/camera/display 媒体状态
- 消息发送
- 合照结果
- 合照二次拍照 `singleWithFrame` 结果
- 单人照结果
- 离房 callback

- [x] **Step 6：最终提交**

分别在三个 repo 内检查：

```bash
git -C /Users/wangxinran/StudioProjects/flutter_module status --short
git -C /Users/wangxinran/StudioProjects/rtc_apk_app status --short
git -C /Users/wangxinran/StudioProjects/MyAppForAIDL status --short
```

只提交本任务相关文件。不要提交用户已忽略的 `.DS_Store`。

---

## 执行注意事项

- P2 保持最小工作量。如果改动开始重写 RTC 逻辑，停止并重新收敛范围。
- 将本地 path dependency 视为显式构建风险：如果 `flutter_module` 分析/构建失败，修共享源码或依赖约束，不要复制 Dart 代码到 `rtc_apk_app`。
- 优先让 `rtc_apk_app` 适配现有 `flutter_module` 协议，不让 Flutter 核心理解 AIDL 细节。
- 不依赖 `initialize()` 一定早于 Activity 冷启动导航到达。必须把 environment 携带或合并进 Activity-first 启动路径。
- `proxyIp/proxyPort` 保持在 `enterRoom()` payload，不放到 `initialize()` 主路径。
- `xchatkit` 是 P2 正式 MethodChannel 路径。
- `com.yc.rtc.bridge/channel` 只视为 P1 probe/stub。
- Android 14 target API 34 时，前台服务需要声明类型和对应类型权限；camera/microphone 需要 runtime permission 后才能启动对应前台服务类型，mediaProjection 需要屏幕采集授权后才能创建对应类型。
- Android 相关验收禁止只写白盒测试；最终必须使用 `adb + UI` 黑盒用例证明跨 APK 启动、命令、拍照、投屏和退出链路。
