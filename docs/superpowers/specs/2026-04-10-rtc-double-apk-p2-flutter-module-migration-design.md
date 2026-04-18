# RTC 双 APK P2 Flutter Module 迁移设计

日期：2026-04-10

## 背景

P1 已完成双 APK + AIDL 的最小 PoC：宿主通过 `rtc-aidl` 的 `RscRtcBridge` 从前台 `Activity` 显式启动 `rtc_apk_app` 的 `RtcEntryActivity`，RTC APK 拉起 Flutter 壳页面，并通过 AIDL 建立后续 callback / 命令通道。

P2 的目标是在 P1 主路径不变的前提下，把 `rtc_apk_app` 从 skeleton/probe 页面推进到真实 RTC 页面能力。当前 `flutter_module` 已具备以下能力：

- RTC 页面内挂断
- 系统 Back 触发离房
- `sendMessage`
- 业务拍照模式
- 权限申请与媒体资源生命周期
- 投屏时启动 Flutter 侧前台服务的既有逻辑

因此 P2 不重写 RTC 业务，而是把 `rtc_apk_app` 接入 `flutter_module` 已有能力，并补齐双 APK 下的 Android 原生适配。

## 目标

- `rtc_apk_app` 通过本地 `path` 依赖复用 `flutter_module`
- `rtc_apk_app` 启动真实 `flutter_module` RTC 页面，不再停留在 P1 skeleton/probe 页面
- 保持 P1 的 Activity-first 冷启动主路径
- 保持宿主只安装并启动 `rtc_apk_app.apk`，设备运行时不需要存在 `flutter_module` 目录
- 对 `flutter_module` 只做最小兼容改造，不影响原 standalone / 旧宿主嵌入模式
- 将 AIDL 命令适配到 `flutter_module` 现有 `xchatkit` MethodChannel 协议
- 补齐麦克风、摄像头、投屏驱动的 Android 前台服务类型与通知
- 业务拍照结果保存到共享图片目录，供宿主或其他同权限 App 访问
- Android 跨 APK 验收继续使用 `adb + UI` 黑盒测试

## 非目标

- 不复制 `flutter_module/lib` 到 `rtc_apk_app/lib`
- 不重写 RTC 房间、信令、WebRTC、业务拍照核心逻辑
- 不把旧 `SDLActivityAdapter` 整个迁入 `rtc_apk_app`
- 不让宿主承载 Flutter/WebRTC 产物
- 不在 P2 处理 P3 的 MDM 交付联调、线上日志导出、安装器能力
- 不以白盒测试作为跨 APK 行为验收依据

## 总体方案

P2 采用本地 `path` 依赖方案：

```yaml
dependencies:
  flutter_module:
    path: ../flutter_module
```

`path` 依赖是构建期源码依赖，不是设备运行时依赖。`flutter build apk` 会把 `flutter_module` 的 Dart、插件和资源编进 `rtc_apk_app.apk`，交付时仍然只有一个 RTC APK。

P2 不采用复制方案。复制 `flutter_module` 会带来两份 RTC 代码分叉、bug 修复需要同步、旧宿主可用但 RTC APK 漏修等维护风险，不符合最小工作量原则。

## 模块边界

### `rtc_apk_app`

负责：

- `RtcEntryActivity`
- `RtcBridgeService`
- AIDL Service
- FlutterEngine 创建与复用
- Activity-first 启动与任务栈
- `xchatkit` MethodChannel 原生端适配
- 前台服务、通知、Android 14 `foregroundServiceType`
- MediaStore 业务拍照文件写入桥接
- AIDL callback 分发

不负责：

- RTC 信令实现
- WebRTC 房间状态机
- Flutter 房间 UI 重写
- 业务拍照 UI 重写

### `flutter_module`

负责：

- RTC 页面 UI
- 房间进入、离开、重试与失败状态
- 页面内挂断
- 系统 Back 后离房
- `sendMessage`
- 业务拍照 UI 与拍照动作
- 媒体能力开关生命周期
- `xchatkit` MethodChannel Flutter 端协议

允许的 P2 最小改造：

- 新增供 `rtc_apk_app` 调用的入口函数
- 资源路径或 package asset 适配
- `doubleApkNativeMode` 下前台服务启动逻辑改为上报媒体状态
- 必要的媒体状态事件埋点
- 必要的离房完成或错误事件回调

禁止的 P2 改造：

- 改变原 `main()` 的 standalone 行为
- 大规模重构房间状态机
- 把双 APK AIDL 细节侵入 RTC 核心逻辑

## Flutter 入口策略

`flutter_module` 保留现有 `main()`，新增一个给 `rtc_apk_app` 使用的最小入口函数，例如：

```dart
Future<void> runRtcModuleApp(RtcModuleLaunchOptions options)
```

要求：

- 原 `main()` 的 standalone / 旧 native 嵌入行为保持不变
- `rtc_apk_app/lib/main.dart` 调用新增入口，不直接调用旧 `main()`
- 双 APK 特有的启动参数、环境、bridge hook 通过 `RtcModuleLaunchOptions` 传入，并使用 `doubleApkNativeMode` 命名区分旧 native 嵌入模式
- 如果新增入口复用现有 `main()` 内部逻辑，必须保证默认参数与旧行为一致

## `doubleApkNativeMode` Bridge 适配

P2 在 `rtc_apk_app` 内新增或重构一个原生桥，例如 `RtcXChatKitBridge`。

Channel 名称使用既有协议：

```text
xchatkit
```

该桥参考 `MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/SDLActivityAdapter.java` 的协议和时序，但不整块复用旧类。

复用协议：

- Flutter -> Native: `engineReady`
- Native -> Flutter: `navigatorPush`
- Native -> Flutter: `requestExit`
- Native -> Flutter: `sendMessage`
- Native -> Flutter: `businessPhotoForGroup`
- Native -> Flutter: `businessPhotoForSingle`
- Native -> Flutter: `closeBusinessPhotoMode`
- Flutter -> Native: `onBusinessPhotoTakeSuccess`
- Flutter -> Native: `onBusinessPhotoTakeFail`
- Flutter -> Native: `onReceiveMessage`
- Flutter -> Native: `onEvent`

不复用旧职责：

- 不复用 `StartFlutterActivity`
- 不复用旧 `FlutterActivity.withCachedEngine(...)` 启动逻辑
- 不复用旧宿主 `CallEventListener` 静态监听模型
- 不复用旧宿主 Activity 引用管理
- 不把旧 `SDLActivityAdapter` 直接搬进 `rtc_apk_app`

P1 的 `com.yc.rtc.bridge/channel` 只作为 PoC/探针遗留，不作为 P2 正式主路径。P2 正式主路径收敛到 `xchatkit`，因为 `flutter_module` 已经支持该协议。

## 入房参数与环境

### 当前缺口

P1 的 `RtcRoomOptions` 已具备 `route/fromUser/unionId/brhName/deviceId/language/languageName/arguments/clientInfo/deviceInfo` 字段，结构上可以承载旧 `ConferenceOptions` 的大部分数据。

但 P1 demo 当前只传了精简参数，没有完整复刻旧 `MyApplicationForFlutter` 的 `startConference()` 参数。P1 的 `rtc_apk_app` 也还没有把 `RtcRoomOptions` 转成 `flutter_module` 所需的 `/room` route arguments。

### P2 要求

`MyAppForAIDL` demo 入房参数必须参考旧 `MyApplicationForFlutter/app/src/main/java/com/example/myapplicationforflutter/MainActivity.java` 的 `startConference()` 调用，传入足够业务数据。

必须支持的顶层参数：

- `appid`
- `dept`
- `channelName`
- `deviceId`
- `init`
- `noAgentLogin`
- `p2p`
- `queueHintCount`
- `queueHintInterval`
- `browser`
- `busitype1`
- `visitorSendInst`
- `r_flag`
- `fromuser`
- `brhName`
- `language`
- `languageName`
- `unionId`

必须支持的 `clientInfo` 参数：

- `tellerCode`
- `tellerName`
- `tellerBranch`
- `tellerIdNo`
- `ip`
- `locationFlag`
- `fileId`
- `pageIndex`
- `pushSpeechFlag`
- `outTaskNo`

必须支持的 `clientInfo.deviceInfo` 参数：

- `imei`
- `brand`
- `model`
- `board`
- `osVersion`
- `sdk`
- `display`
- `gps`
- `boxflag`
- `brhShtName`
- `deviceInst`
- `deviceNo`
- `updeviceInst`

约束：

- `Bundle` 仅允许基础类型、`String`、`Bundle`、基础数组/列表
- 禁止跨进程传宿主自定义类或 `Serializable`
- 复杂对象必须 JSON 化
- 参数体积必须受控，避免 `TransactionTooLargeException`

### 环境选择

宿主只通过 `RtcInitOptions.environment` 指定环境。

语义：

- `0 = production/release`
- `1 = debug/test`
- 未传或非法值默认按 `0 = production/release`

映射：

- `environment=0` -> `_configSource=production` -> `app_config.json`
- `environment=1` -> `_configSource=debug` -> `app_config_debug.json`

`RtcInitOptions.configFileName` 不作为 P2 主路径使用。字段可保留作兼容字段，但 P2 实现应优先按 `environment` 计算配置文件。

### 代理参数

`proxyIp/proxyPort` 属于本次入房上下文，不放在 `initialize()` 主路径。

P2 要求：

- 宿主在 `enterRoom()` 的 `RtcRoomOptions.arguments` 或等价业务参数里传入 `proxyIp/proxyPort`
- `rtc_apk_app` 合并 `/room` 参数时写入 `mediaInfo.proxyIp/proxyPort`
- 为兼容 `flutter_module` 现有解析，也可在根层保留 `proxyIp/proxyPort`
- 把 `System.setProperty("http.proxyHost")` 作为备用，如果传空，则默认使用；它最多作为原生网络兼容补充

### 入房 payload 合并

`rtc_apk_app` 在真正推 `/room` 前执行等价于旧 `FlutterDemoActivity.initXchatData()` 的合并逻辑：

1. 根据 `environment` 选择配置
2. 从配置构造 `mediaInfo`
3. 从 `RtcRoomOptions` 构造 `userData`
4. 合并 `clientInfo` 和 `deviceInfo`
5. `mediaInfo.peerId` 优先使用 `userData.fromuser`
6. 注入 `proxyIp/proxyPort`
7. 注入 `_configSource`
8. 通过 `xchatkit.navigatorPush(route="/room", arguments=json)` 推给 `flutter_module`

## 页面退出闭环

退出来源：

- 宿主通过 AIDL 调 `leaveRoom()`
- RTC 页面内挂断按钮
- 系统 Back

行为：

- AIDL `leaveRoom()` 转成 `xchatkit.requestExit`
- Flutter 页面内挂断沿用现有 `Leave` 按钮与 `RoomClientEntranceV2.leave()`
- 系统 Back 沿用现有 `doubleApkNativeMode` 下的离房逻辑
- 离房后 Flutter 当前可继续使用 `SystemNavigator.pop()` 关闭承载 Activity
- `RtcEntryActivity` 不主动拉起宿主 `MainActivity`
- 页面关闭后由 Android 任务栈自然回到发起会议的宿主 Activity
- `RtcBridgeService` 回调宿主 `onRoomSnapshotChanged(roomState=idle, roomPageShowing=false)` 或错误事件

最小工作量策略：

- 先接受现有 `SystemNavigator.pop()` 作为正式退出动作
- 只有黑盒验证发现 ROM 行为异常时，再补 Flutter -> Native 的 `finishActivity` MethodChannel

## 消息

`sendMessage` 不改 Flutter 业务签名。

映射：

- AIDL `sendMessage(RtcMessage)` -> `xchatkit.sendMessage(message.message)`
- `messageType/requestId/extras` 在 P2 先用于日志和 AIDL 结果关联
- Flutter `onReceiveMessage(String)` -> AIDL `onMessageReceived(RtcMessage)`

默认：

- Flutter 收到消息时，`messageType` 可填 `receive`
- 若没有 requestId，则为空或由原生生成

## 业务拍照

`setBusinessCaptureMode(RtcCaptureOptions)` 转成现有 Flutter 业务拍照协议。

映射：

- `mode=group` -> `businessPhotoForGroup(fileName, isCustomerOnLeft)`
- `mode=single` -> `businessPhotoForSingle(fileName, toggleCamera, tipsContent)`
- 不支持`mode=singleWithFrame`
- `mode=close` 或 `mode=disabled` -> `closeBusinessPhotoMode`

结果：

- Flutter `onBusinessPhotoTakeSuccess(List<String>)` -> `RtcCaptureResult(success=true, filePaths=...)`
- Flutter `onBusinessPhotoTakeFail(String)` -> `RtcCaptureResult(success=false, errorMessage=...)`

### 文件保存路径

业务拍照结果默认保存到共享图片目录：

```text
Pictures/RscRtc/
```

实现要求：

- RTC APK 负责创建并写入业务拍照结果
- Android 10+ 默认通过 `MediaStore.Images` 写入共享媒体库
- 使用`filePaths` 仅作为宿主读取的主协议依赖
- 不依赖 `DATA` 裸文件路径作为主协议
- AIDL 回调优先返回 `content://` URI
- RTC APK 对宿主包名授予该 URI 读权限
- 若宿主要批量读取图库，宿主自行按 Android 版本申请读取权限

读取权限提示：

- Android 13+：宿主批量读取图库需要 `READ_MEDIA_IMAGES`
- Android 12 及以下：宿主批量读取图库需要 `READ_EXTERNAL_STORAGE`
- 对单次回调 URI，优先使用 `grantUriPermission` 降低宿主权限要求

## 前台服务与通知

P2 由 `rtc_apk_app` 原生 `RtcBridgeService` 统一承担媒体前台服务，不以 Flutter 插件作为 `doubleApkNativeMode` 主路径。

模式区分：

- standalone 模式：`flutter_module` 继续使用现有 `flutter_foreground_task`
- `doubleApkNativeMode`：Flutter 不实际启动/停止 `flutter_foreground_task`，只上报媒体状态事件

原因：

- Android 14 的 `foregroundServiceType` 是原生系统策略
- 麦克风、摄像头、投屏需要统一计算类型集合
- 避免 Flutter 插件和原生 Service 同时启动前台服务，导致通知重复、类型不一致、停止时序不一致

P2 需要在 Flutter 媒体能力启停处增加最小事件埋点：

```json
{
  "event": "mediaStateChanged",
  "message": {
    "microphoneActive": true,
    "cameraActive": true,
    "mediaProjectionActive": false
  }
}
```

`RtcBridgeService` 维护：

- `microphoneActive`
- `cameraActive`
- `mediaProjectionActive`

类型计算：

- 只有麦克风：`microphone`
- 只有摄像头：`camera`
- 麦克风 + 摄像头：`microphone|camera`
- 投屏开启后追加 `mediaProjection`
- 三类均为 false 时停止前台服务

兼容策略：

- P2 先保证 Android 9/10/11 可运行
- Android 14 的 manifest 和代码路径补齐
- Android 14 真机验证可作为后续增强验证项

## 测试与验收

Android 跨 APK 验收必须走 `adb + UI` 黑盒路径。

P2 黑盒验收流程保持简化，统一使用 `MyAppForAIDL` UI 和 `adb` 模拟真实点击。

入房参数与发送消息参数优先参考 `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/ControlPanelController.java` 中现有按钮和日志面板设计。

完整用例：

- 通过 `adb` 模拟点击 `MyAppForAIDL` 的启动会议按钮
- 等待进入真实 `flutter_module` RTC 页面，而不是 P1 skeleton/probe 页面
- 等待 pad 策略房间进入完成
- 通过宿主日志面板或 logcat 确认麦克风、摄像头、匹配已经启动
- 投屏需要额外通过 `adb` 点击一次 RTC 页面屏幕，触发后再通过日志确认投屏启动
- 通过 `adb` 模拟点击宿主 UI 的发送消息按钮
- 通过日志确认 AIDL `sendMessage` 到达 Flutter 现有 `sendMessage`
- 通过 `adb` 模拟点击宿主 UI 的合照模式按钮
- 在 RTC 页面通过 `adb` 模拟点击屏幕拍照按钮
- 等待拍照结果回调（预期失败），再次在 RTC 页面通过 `adb` 模拟点击拍照按钮，覆盖 `singleWithFrame` 场景，通过日志确认返回的拍照路径符合 `Pictures/RscRtc/` 与 `content://` URI 要求
- 通过 `adb` 模拟点击宿主 UI 的单人照模式按钮
- 在 RTC 页面通过 `adb` 模拟点击屏幕拍照按钮
- 等待拍照结果回调，通过日志确认返回的拍照路径符合要求
- 通过 `adb` 模拟点击宿主 UI 的停止会议按钮
- 通过日志确认离房 callback，并确认页面自然回到发起会议的宿主 Activity

用例可以按稳定性拆分：

- 启动会议 + 停止会议
- 启动会议 + 发送消息 + 停止会议
- 启动会议 + 合照模式拍照 + `singleWithFrame` 拍照 + 停止会议
- 启动会议 + 单人照模式拍照 + 停止会议
- 启动会议 + 投屏触发 + 停止会议

P2 验收确认点：

- `rtc_apk_app` 通过 `path` 依赖启动真实 `flutter_module` 房间页
- 入房 route arguments 包含旧 `ConferenceOptions` 等价业务参数
- `environment=0` 选择 production 配置
- `environment=1` 选择 debug 配置
- `proxyIp/proxyPort` 从 `enterRoom()` 参数进入 Flutter room modules
- pad 策略房间自动触发麦克风、摄像头、投屏与匹配流程
- 宿主 AIDL `sendMessage` 能到达 Flutter 现有 `sendMessage`，并能通过日志确认
- 宿主 AIDL 合照模式能打开 Flutter 现有业务拍照 UI，并能通过日志或回调确认
- 宿主 AIDL 单人照模式能打开 Flutter 现有业务拍照 UI，并能通过日志或回调确认
- 业务拍照结果保存到 `Pictures/RscRtc/`
- 业务拍照结果通过 AIDL 返回 `content://` URI
- 麦克风、摄像头、投屏启停会驱动 `RtcBridgeService` 原生前台服务类型与通知
- `doubleApkNativeMode` 下 Flutter 不实际启动 `flutter_foreground_task`
- 页面内挂断后触发 `leave()`，宿主收到 callback，并自然回到发起 Activity
- 系统 Back 与页面挂断行为一致

辅助测试：

- Dart/Flutter 单测可用于 Flutter adapter 逻辑
- Java/Kotlin 单测可用于参数 mapper
- 这些白盒测试不能替代跨 APK 黑盒验收

## 风险与处理

### `path` 依赖导致构建受 `flutter_module` 影响

处理：

- P2 先接受该风险，符合最小工作量
- 通过 `flutter build apk --debug` 和后续 release 构建验证插件闭包
- 后续交付若需要固定版本，再评估 git submodule/subtree 或 vendor 快照

### asset 路径变化

处理：

- 优先保持 `flutter_module` 内部资源声明
- 必要时在 `rtc_apk_app` 中显式声明 package asset
- Flutter 代码中需要区分 package asset 时做最小适配

### 前台服务双实现冲突

处理：

- standalone 模式保留 Flutter 插件前台服务
- `doubleApkNativeMode` 只上报媒体状态，不启动 Flutter 插件前台服务
- `RtcBridgeService` 统一 `startForeground/stopForeground`

### 旧 `SDLActivityAdapter` 职责污染

处理：

- 只复用协议与时序
- 不整类迁移
- 双 APK 原生生命周期仍由 `RtcEntryActivity/RtcBridgeService/FlutterEngineHolder` 管理

### 入房参数体积与 ClassLoader

处理：

- `Bundle` 只传基础类型和 framework 类型
- 复杂对象 JSON 化
- 参数大小受控
- 禁止 `Serializable` 和宿主自定义类跨进程传递

## 结论

P2 采用 `path` 依赖复用 `flutter_module`，不复制代码。`rtc_apk_app` 负责双 APK 原生壳层和系统能力，`flutter_module` 继续负责 RTC 业务。原生桥接层参考 `SDLActivityAdapter` 的 `xchatkit` 协议，但不整块复用旧类。入房参数按旧 `ConferenceOptions` 语义补齐，环境由 `RtcInitOptions.environment` 控制，代理随 `enterRoom()` 业务参数传递。前台服务由 `RtcBridgeService` 在 `doubleApkNativeMode` 下统一管理，业务拍照结果写入 `Pictures/RscRtc/` 并通过 URI 回调宿主。
