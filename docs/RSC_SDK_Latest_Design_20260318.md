# RSC SDK 最新设计文档（代码快照版）

更新时间：2026-03-18  
生成方式：基于 `repomix` 打包结果 + 核心源码抽样校验

## 1. 输入快照与产物

1. Android 打包产物：`docs/repomix_android_20260318.md`
2. Flutter 打包产物：`docs/repomix_flutter_module_20260318.md`

快照指标：

| 模块 | 文件数 | Token 数 | 主要入口 |
|---|---:|---:|---|
| `MyApplicationForFlutter` | 50 | 43,290 | `XChatKit`, `SDLActivityAdapter`, `FlutterDemoActivity` |
| `flutter_module` | 357 | 701,084 | `main.dart`, `RoomClientEntranceV2`, `ClientInstanceV2` |

## 2. 系统总体设计

本项目是一个 Android Native + Flutter Module 的混合 RTC SDK：

1. Android `rsc-sdk` 提供稳定对外 API（初始化、入会、退会、事件监听、拍照）。
2. Flutter `flutter_module` 承载 RTC 核心业务（房间、媒体、信令、策略、状态管理）。
3. Native 与 Flutter 通过统一 `MethodChannel("xchatkit")` 和 `EventChannel("xchatkit")` 进行桥接。

架构分层如下：

1. 宿主接入层：`XChatKit`
2. 引擎与桥接层：`SDLActivityAdapter` + `FlutterDemoActivity` + `xchat_method_channel.dart`
3. 业务编排层：`RoomClientEntranceV2` + 策略工厂
4. 通信与会话层：`ClientInstanceV2` + `StandardWebSocketSession` + `SessionInstanceV2`
5. 媒体与协议层：`plugin/*`（transport/protocol/handlers/pipeline/state_machine）

## 3. Android 侧设计

核心职责：

1. `XChatKit`：统一 SDK API，管理初始化、环境切换、会议启动与事件分发。
2. `SDLActivityAdapter`：管理 FlutterEngine 生命周期、预热、导航、Method/Event 通道回调。
3. `FlutterDemoActivity`：承载 Flutter 页面，解析 `ConferenceOptions`，合并配置并触发路由导航。
4. `ConferenceOptions`：Builder 模式封装启动参数，支持 `clientInfo` 嵌套结构。

关键设计点：

1. 引擎预热：`XChatKit.init()` -> `SDLActivityAdapter.PrewarmFlutterEngine(...)`。
2. 延迟执行 Dart：在 `FlutterDemoActivity.configureFlutterEngine()` 中执行 `ExecuteDartEntrypoint()`。
3. 导航门控：`PerformNavigation()` 优先判断 Dart 是否执行，其次判断 `engineReady`。
4. 线程安全：主线程分发回调、`CopyOnWriteArrayList` 管理监听器、`WeakReference<Activity>` 防泄漏。

## 4. Flutter 侧设计

核心职责：

1. `main.dart`：初始化适配层、BLoC 容器与路由；启动后执行 Native 握手。
2. `XChatKitAdapter`：管理 Native 模式识别、退出回调、拍照回调、业务拍照模式回调。
3. `XChatMethodChannel`：处理 Native 下发的 `navigatorPush/requestExit/takePhoto/sendMessage` 等方法。
4. `RoomClientEntranceV2`：房间编排主入口，负责 join/leave、能力启停、资源清理。
5. `ClientInstanceV2`：WebSocket 会话、request/notify、房间信令、MGW 匹配能力。

设计特征：

1. 房间模式策略化：`RoomModeStrategyFactoryV2` 根据 `roomMode` 选择能力策略。
2. 能力统一编排：`enableCapability/disableCapability` 管理麦克风、摄像头、投屏、机器人、语音等。
3. 状态驱动：通过 `RoomBlocV2`、`MeBloc`、`PeersBloc`、`ProducersBloc` 协同 UI 与业务状态。
4. 双中心 + ICE 检测：入会前执行中心探测与 TURN/UDP 可达性筛选。

## 5. 启动与入会主链路

1. 宿主在 `Application` 或首屏调用 `XChatKit.init(context)` 完成引擎预热。
2. 宿主调用 `XChatKit.startConference(activity, options)` 拉起 `FlutterDemoActivity`。
3. `FlutterDemoActivity` 解析 route/arguments，提取 userData，合并 assets 配置为 `XChatData`。
4. `SDLActivityAdapter.PerformNavigation(route, xchatData)` 下发 `navigatorPush` 给 Flutter。
5. Flutter `main()` 初始化后执行 `XChatKitAdapter.handshake()`，向 Native 回传 `engineReady`。
6. Room 页面创建时触发 `RoomClientEntranceV2.join()`：
7. 执行双中心探测与 ICE 可达性检测。
8. 创建 `ClientInstanceV2` 并建立 WebSocket。
9. 创建/加入房间并创建 `SessionInstanceV2`，按策略启用初始能力。

## 6. 通信与协议设计

Native ↔ Flutter 方法通道（`xchatkit`）：

1. Native -> Flutter：`navigatorPush`, `requestExit`, `takePhoto`, `sendMessage`, 业务拍照相关方法。
2. Flutter -> Native：`engineReady`, `onEvent`, `onReceiveMessage`, `onPhotoCaptured` 等回调。

WebSocket 通信主链路：

1. `RoomClientEntranceV2` 调用 `ClientInstanceV2`。
2. `ClientInstanceV2` 使用 `StandardWebSocketSession` 发起 `request/notify`。
3. `StandardProtocolCodec` 负责编码与解析，`MessagePipeline` 负责分发。
4. `SessionInstanceV2` 管理 WebRTC 传输与生产/消费者。

## 7. 资源回收与退出设计

`RoomClientEntranceV2.leave()` 的清理顺序是显式分阶段的：

1. 停止匹配定时器和全局回调。
2. 清理策略资源。
3. 业务能力去使能（robot/matchAgent/voiceNavigator/voiceCaller）。
4. 硬件媒体资源关闭（投屏/摄像头/麦克风）。
5. 清理 peers、发送离房信令。
6. 清理订阅/缓存并关闭 RTC 实例。
7. 更新连接状态为 `disconnected` 并发出 `LeaveRoomDone`。

Native 退出会议链路：

1. `XChatKit.stopConference()` -> `SDLActivityAdapter.StopConference()`
2. Native 调用 Flutter `requestExit`
3. Flutter 执行 `onExitRequest` 清理并 `SystemNavigator.pop()`

## 8. 关键扩展点

1. 新房间模式：新增 `strategies_v2/*_room_mode_strategy_v2.dart` 并在工厂注册。
2. 新能力类型：在 `RoomCapability`、`RoomClientEntranceV2` 能力分发中扩展启停逻辑。
3. 新协议类型：在 `plugin/protocol` 扩展 codec 并接入 `codec_factory.dart`。
4. 新 Native API：在 `XChatKit` 对外暴露后，经 `SDLActivityAdapter` 映射到 MethodChannel。

## 9. 当前实现特征与注意项

1. `ClientInstanceV2` 为单例工厂，运行时不允许变更配置对象。
2. `XChatKit` 当前默认环境为 `ENV_DEBUG`，发布前需确认环境切换策略。
3. Flutter 模块规模较大，文档与调试材料也被 repomix 打包，后续如需精简上下文建议增加 `--include` 范围。
4. 当前架构已形成“Native 稳定壳 + Flutter 快速迭代核心”的分层，适合持续演进业务能力。

## 10. 复现命令

```bash
cd /Users/wangxinran/StudioProjects
repomix MyApplicationForFlutter --style markdown --parsable-style --output docs/repomix_android_20260318.md
repomix flutter_module --style markdown --parsable-style --output docs/repomix_flutter_module_20260318.md
```
