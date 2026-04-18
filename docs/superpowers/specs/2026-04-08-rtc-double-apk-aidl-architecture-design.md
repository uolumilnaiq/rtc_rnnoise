# RTC 双 APK + AIDL 架构设计

日期：2026-04-08

## 背景

当前 RTC 能力通过宿主直接集成 Flutter SDK 的方式提供。该方案在宿主工具链受限的环境下存在明显风险：

- 宿主固定为老版本 Android 构建链：`Kotlin 1.4.10x / AGP 3.6.3x / Gradle 6.2.2x / JDK 1.8.0_171`
- 宿主要求离线、本地 AAR 接入
- 宿主工具链不可升级
- 现有 Flutter/WebRTC/插件 Android 产物链对新版本 Kotlin、Java bytecode、Gradle/AGP 依赖较强

继续让宿主直接承载 Flutter/WebRTC 产物，等价于让宿主承担整条现代 Android/Flutter 技术栈的兼容成本。这条路径问题多且耦合深，风险主要集中在：

- Kotlin metadata 不兼容
- Java 17 bytecode 与 JDK 8 宿主不兼容
- Flutter AAR 与插件闭包离线交付复杂
- 运行时资源、混淆、minSdk、前台服务等问题叠加

为降低宿主适配压力，并保留现有 Flutter 房间逻辑与 UI，本设计引入一条新增架构：

- 宿主 APK 继续保持原有工具链和接入方式
- 新增独立 RTC APK，负责 Flutter/WebRTC/页面与房间流程
- 新增宿主侧 `rtc-aidl` library，作为轻量桥接 SDK
- 宿主与 RTC APK 通过 AIDL 通信

本设计只描述新增双 APK 方案，不修改、不废弃现有旧方案。旧方案继续保留并独立演进。

## 目标

- 新增一条不依赖宿主承载 Flutter/WebRTC 产物的接入路径
- 提供一套新的、最小工作量的宿主侧 RTC 调用接口
- 保留当前 Flutter 房间逻辑、页面能力和 RTC 状态机
- 将复杂 UI、媒体、信令、日志、权限申请等职责集中在独立 RTC APK 中
- 通过 AIDL 提供稳定的跨进程能力边界
- 让宿主只关心业务命令和业务回调，不感知 Flutter 内部实现细节
- 为后续 PoC、工程化交付、MDM 联调提供清晰阶段边界

## 非目标

- 本次不废弃现有宿主直接集成 Flutter SDK 的旧方案
- 本次不改造现有旧工程作为新方案前提
- 本次不将 Flutter 房间逻辑改写为 Native 实现
- 本次不引入宿主对 RTC 页面生命周期的细粒度控制
- 本次不设计多会议并发、多窗口 RTC 页面
- 本次不覆盖后台自动拉起 RTC 页面的能力
- 本次不依赖 MDM 具备原子双包安装/卸载能力

## 总体方案

新增两个工程和一个新库：

1. `rtc_apk_app`
- 一个新的 Flutter app 工程
- 独立生成并安装为 RTC APK
- 承担：Flutter UI、WebRTC、房间状态机、AIDL Service、会议 Activity、前台服务、通知、权限申请、FlutterEngine 管理

2. `MyAppForAIDL`
- 一个新的 Android 工程
- 使用宿主相同工具链配置
- 承担：`rtc-aidl` library 的编译验证与示例宿主验证

3. `rtc-aidl`
- 一个新的 Android library
- 面向宿主提供轻量桥接 SDK
- 承担：bind/unbind Service、AIDL 命令转发、回调注册与分发、binder 死亡监听、断线回调、状态查询、版本协商

宿主主入口命名：

- 新宿主入口统一命名为 `RscRtcBridge`
- 不继续沿用 `XChatKit` 命名
- 相关配套命名统一采用：
  - `RscRtcBridge`
  - `RscRtcBridgeCallback`
  - `RscRtcServiceState`
  - `RscRtcRoomSnapshot`
  - `IRscRtcBridgeService`
  - `IRscRtcBridgeCallback`

架构原则：

- `rtc_apk_app` 为 Flutter app 工程，但采用 **native 主导、Flutter 承载业务** 的架构
- Android 原生层负责：`Application`、`Service`、`Activity`、`FlutterEngine`、AIDL、前台服务、通知、权限桥接与系统级生命周期
- Flutter 层负责：房间 UI、RTC 业务逻辑、房间状态机、页面内交互、日志与业务流程
- `rtc_apk_app` 第一阶段优先沿用当前 `flutter_module` 中已有的 RTC/房间/信令/UI 能力
- 第一阶段不要求先抽共享 Flutter 包，不将 `flutter_module` 的内部解耦作为前置条件
- Android 原生侧允许选择性复用当前 `rtc-sdk` 中可迁移的承载能力，以降低新增 RTC APK 的壳层工作量
- 但 `rtc-sdk` 当前“宿主侧 SDK”职责不直接迁入 `rtc_apk_app`，而由新的 `rtc-aidl` 承接

宿主角色收敛为：

- 初始化 SDK
- 进入房间
- 退出房间
- 发送消息
- 启动/停止业务拍照模式
- 监听状态和结果回调

宿主接入约束：

- 宿主从前台 `Activity` 调用 `enterRoom()`
- 宿主传入 `Activity Context`，第一版不以 `Application Context` 作为主路径
- 入房失败以同步错误码返回为主
- RTC APK 未安装、签名权限不匹配、Service 绑定失败、Activity 启动失败等异常通过错误码或 callback 反馈宿主
- 宿主保证 RTC APK 安装状态
- RTC APK 隐藏桌面入口，不提供 `MAIN/LAUNCHER`
- `signature` 权限名按宿主交付环境定制

RTC APK 角色收敛为：

- 页面与 FlutterEngine 生命周期管理
- 房间流程与状态机
- 摄像头/麦克风/投屏与权限申请
- 媒体与 WebRTC
- RTC 页面承载与退场
- 房间失败与重试策略
- 宿主回调事件推送

## 工程结构

### 新增工程

#### 1. `rtc_apk_app`

建议为独立 Flutter app，而不是继续使用现有 module 形态。其价值不在于“新建壳”，而在于它本身成为一个可安装、可运行、可被宿主绑定的完整 Android 应用。

工程定位：

- `rtc_apk_app` 不是从零开始重写 RTC 逻辑
- 第一阶段以当前 `flutter_module` 的 Flutter RTC 代码为主要来源进行迁移/承接
- 第一阶段不要求先抽共享包再开始
- 是否在后续抽取共享层，留到双 APK PoC 跑通后再评估

运行架构：

- 工程形态是 Flutter app
- 运行时采用 native 主导宿主架构
- Native 层负责系统级基础设施
- Flutter 层负责 RTC 业务与页面

工具链基线：

- `rtc_apk_app` 采用最新 stable Flutter SDK 构建
- Android 构建基线优先使用该 Flutter stable 版本通过 `flutter create` 生成的默认 Android 工程配置
- 目标运行平台为 Android 9 / 10 / 11（API 28 / 29 / 30）
- 运行兼容范围允许高于该范围，但第一阶段重点验证 Android 9 / 10 / 11
- `flutter_webrtc` 优先使用当时最新稳定版
- 不额外追求 AGP 9 路线，优先遵循 Flutter 官方当前插件工程兼容建议

实现建议：

- 不手工猜测一套自定义 AGP / Gradle / Kotlin 组合
- 以最新 stable Flutter 生成模板为基础，再叠加 RTC APK 需要的原生组件
- 这样能最大限度减少 Flutter 工具链层面的自定义维护成本

需要具备的 Android app 能力包括：

- 独立 `applicationId`
- `Application`
- 可导出的 `Service`
- 内部会议 `Activity`
- Manifest 中的权限与组件声明
- 前台服务与通知
- FlutterEngine 创建与复用

约束：

- 不配置桌面 `MAIN/LAUNCHER` 入口
- 不允许用户手动启动 RTC APK
- 页面只能由宿主调用能力接口后间接拉起

#### 2. `MyAppForAIDL`

作为新 Android 工程，使用宿主同工具链配置，内含：

- `app`：示例宿主 / 验证宿主
- `rtc-aidl`：真正面向外部宿主交付的 library module

其目的不是替代宿主，而是：

- 验证 `rtc-aidl` 在老工具链环境中的可编译性
- 验证 bind、回调、断线检测、版本协商等链路
- 给后续宿主接入提供稳定参考

#### 3. `rtc-aidl`

面向宿主提供稳定 API，内部通过 AIDL 与 RTC APK 通信。对外主入口为 `RscRtcBridge`，不再保留旧 `XChatKit` 命名，也不要求兼容旧接口面。

职责边界：

- `rtc-aidl` 承接宿主侧 SDK 入口职责
- `RscRtcBridge` 是宿主唯一主入口
- `rtc_apk_app` 不再承接“给宿主提供 SDK”的角色
- 因此允许复用当前 `rtc-sdk` 的原生承载能力，但不直接复用其作为宿主 SDK 的整体角色

## 对外 API 设计原则

### 接口收敛原则

宿主侧 API 不以现有 `rtc-sdk / XChatKit` 为兼容目标，而以双 APK 新架构下的最小能力闭环为目标。

规则：

- 第一版不保留旧接口包袱
- `RscRtcBridge` 只暴露最小闭环所需方法
- 宿主不直接持有 AIDL 接口对象
- 宿主不感知 Flutter route、页面 attach、FlutterEngine 等内部概念
- 宿主不直接感知旧 `ConferenceOptions / XChatKit` 模型

推荐第一版宿主接口面：

- `initialize(...)`
- `enterRoom(...)`
- `leaveRoom(...)`
- `sendMessage(...)`
- `setBusinessCaptureMode(...)`
- `destroy()`
- `getServiceState()`
- `getRoomSnapshot()`
- `getProtocolVersion()`
- `registerCallback(...)`
- `unregisterCallback(...)`

### 能力边界

宿主只调用业务能力接口，例如：

- 初始化
- 进入房间
- 退出房间
- 发送消息
- 启动业务拍照模式
- 停止业务拍照模式
- 注册回调
- 获取服务状态 / 房间状态

RTC APK 不向宿主暴露内部房间状态机实现细节，只返回业务上可理解的状态和值。

## AIDL 数据模型

### 总体策略

AIDL 第一版统一采用：

- `Parcelable + Bundle`

原因：

- 工作量最小
- 便于快速建立双 APK PoC
- 便于后续扩展字段
- 仍然足以承载当前 RTC 业务需要

### 核心对象

建议定义：

1. `RtcInitOptions`
- `int environment`
- `String configFileName`
- `String proxyIp`
- `int proxyPort`
- `Bundle extras`

2. `RtcRoomOptions`
- `String route`
- `String fromUser`
- `String unionId`
- `String brhName`
- `String deviceId`
- `String language`
- `String languageName`
- `Bundle arguments`
- `Bundle clientInfo`
- `Bundle deviceInfo`

3. `RtcLeaveOptions`
- `String reason`
- `Bundle extras`

4. `RtcMessage`
- `String message`
- `String messageType`
- `String requestId`
- `Bundle extras`

5. `RtcCaptureOptions`
- `String mode`
- `String fileName`
- `boolean toggleCamera`
- `String tipsContent`
- `Bundle extras`

6. `RtcCaptureResult`
- `boolean success`
- `ArrayList<String> fileUris`
- `ArrayList<String> filePaths`
- `String errorCode`
- `String errorMessage`
- `Bundle extras`

7. `RtcCommandResult`
- `boolean accepted`
- `String requestId`
- `String errorCode`
- `String errorMessage`

8. `RscRtcRoomSnapshot`
- `String serviceState`
- `String roomState`
- `String failureType`
- `String failureCode`
- `String failureMessage`
- `boolean canRetry`
- `boolean roomPageShowing`
- `String disconnectReason`
- `Bundle extras`

9. `RtcError`
- `String errorCode`
- `String errorMessage`
- `String failureType`
- `Bundle extras`

说明：

- 第一版不要求兼容旧 `ConferenceOptions`
- 但仍允许通过 `Bundle` 保留少量扩展字段
- `RtcRoomOptions` 直接服务双 APK 新架构，而不是服务旧接口迁移

### Bundle 类型边界

跨进程 `Bundle` 必须严格限制类型。复杂对象不允许直接跨进程传递。

硬规则：

- 严禁传递宿主自定义类
- 严禁传递宿主自定义枚举
- 严禁传递宿主自定义 `Serializable`
- 严禁传递宿主自定义 `Parcelable`
- 复杂对象一律转为：
  - JSON String
  - 或拆成基础字段 / 嵌套 `Bundle`

第一版允许值类型：

- `String`
- `int`
- `long`
- `boolean`
- `double`
- `Bundle`
- `ArrayList<String>`
- 可选 `byte[]`

需要在 `rtc-aidl` 中增加参数归一化与白名单校验层。

## AIDL 接口分层

AIDL 分三层：

1. 命令接口
2. 状态查询接口
3. 回调接口

### 命令接口

建议第一版保留：

- `initialize(RtcInitOptions options)`
- `enterRoom(RtcRoomOptions options)`
- `leaveRoom(RtcLeaveOptions options)`
- `sendMessage(RtcMessage message)`
- `setBusinessCaptureMode(RtcCaptureOptions options)`
- `destroy()`

规则：

- 命令返回只表示“请求是否已被受理”
- 真正业务结果通过 callback 返回
- 每次命令分配 `requestId`，便于串联日志与回调

### 状态查询接口

建议保留：

- `getServiceState()`
- `getRoomSnapshot()`
- `getSdkVersion()`
- `getProtocolVersion()`
- `getCapabilities()`

理由：

- 宿主重新初始化或重新绑定后需要补状态
- callback 丢失时需要主动查询
- 双 APK 场景不能只依赖 push 事件

### 回调接口

建议通过 `IRscRtcBridgeCallback` 暴露：

- `onServiceStateChanged(String serviceState)`
- `onRoomOpening(String requestId)`
- `onRoomSnapshotChanged(RscRtcRoomSnapshot snapshot)`
- `onMessageReceived(RtcMessage message)`
- `onBusinessCaptureResult(RtcCaptureResult result)`
- `onError(RtcError error)`

实现建议：

- 使用 `RemoteCallbackList` 管理 callback

## RTC APK 内部设计

### 单 FlutterEngine 模式

结论：

- 由 RTC APK 的 `Service` 持有唯一 `FlutterEngine`
- 会议 `Activity` 仅负责 attach 和显示
- Activity 不持有房间核心状态

理由：

- AIDL 入口先到 `Service`
- `enterRoom()` 先打到 `Service`
- 单 Engine 更利于状态一致性
- 避免双 Engine 带来的状态同步、初始化竞争和额外内存成本

### 组件职责

#### `RtcBridgeService`

负责：

- 持有单例 `FlutterEngine`
- 提供 AIDL 请求入口
- 与 Flutter 桥接
- 管宿主回调列表
- 管 binder 重新绑定后的状态补齐
- 管房间命令受理和状态同步
- 管命令幂等
- 管协议版本与能力查询
- 管 native 层与 Flutter 层之间的桥接入口

#### `RoomActivity`

负责：

- 复用 `RtcBridgeService` 中的 `FlutterEngine`
- 承载 Flutter 页面
- 页面退出时通知 `Service`
- 不持有核心房间状态

#### `RtcEntryActivity`

负责：

- 作为 RTC APK 对宿主暴露的唯一页面入口
- 由宿主前台通过 `rtc-aidl` 间接显式 `startActivity()` 启动
- 绑定 `RtcBridgeService`
- 确保 `FlutterEngine` 已就绪
- 将 `RtcRoomOptions` 交给 Flutter 页面或房间入口逻辑
- 在无法进入房间时回传错误并结束页面
- 承载原生 Loading 闪屏页，直到 Flutter UI 可挂载
- RTC 页面内挂断和系统 Back 统一等同于 `leaveRoom()`
- `leaveRoom()` 完成或失败后通过 callback 通知宿主
- 正常退出时只 `finish()` 自己，不主动 `startActivity()` 拉起宿主页面

Loading 体验要求：

- `RtcEntryActivity` 必须配置专属启动主题
- 通过 `android:windowBackground` 提供稳定的启动图或纯色背景
- 要求系统在跨 APK 启动页面的最初帧即可显示该背景

目的：

- 降低跨进程启动时的黑屏/白屏感知
- 保证从宿主切换到 RTC 页面时视觉过渡平滑

### 任务栈与返回栈

第一版目标是让 RTC 页面在用户感知上仍然表现为“宿主流程中的一个页面”，而不是独立 App 卡片。

约束：

- `RtcEntryActivity` 不设置独立 `taskAffinity`
- 不使用 `singleInstance`
- 宿主从前台 `Activity` 启动 RTC 页面时，不额外添加 `FLAG_ACTIVITY_NEW_TASK`
- 默认让 `RtcEntryActivity` 进入当前调用链路所在 task

目的：

- 避免在系统最近任务列表中分裂成两个卡片
- 用户按 Home 后再点宿主图标时，尽量回到当前会议页
- 返回栈保持“宿主页面 -> RTC 页面 -> finish RTC 页面后自然返回宿主”的直觉体验

补充说明：

- 若宿主只能从 `Application Context` 发起启动，则必须使用 `FLAG_ACTIVITY_NEW_TASK`
- 该情况不作为第一版推荐主路径
- 因宿主已确认从前台 `Activity Context` 调用，正式 SDK 不应主动使用 `CLEAR_TOP / REORDER_TO_FRONT / SINGLE_INSTANCE` 等方式拉宿主 Activity
- RTC APK 退出后依赖 `RtcEntryActivity.finish()` 自然露出发起会议的宿主 Activity
- 宿主如需额外页面跳转，应在收到 callback 后自行处理
- demo 浮窗中用于验证的“主动拉回 `MainActivity`”逻辑只属于示例宿主，不进入 `rtc-aidl` 正式能力

#### Flutter 业务层

继续负责：

- 房间状态机
- 信令
- 媒体能力
- 页面逻辑
- 日志
- 失败与重试策略
- 这些能力第一阶段优先来源于当前 `flutter_module` 现有实现

### Android 原生复用策略

为降低第一阶段工作量，允许在 `rtc_apk_app` 中选择性吸收当前 `rtc-sdk` 中可复用的原生承载能力。

优先考虑可复用的内容：

- `FlutterDemoActivity` 中可复用的页面承载逻辑
- `SDLActivityAdapter` 中与 FlutterEngine / Activity 管理相关的逻辑
- 业务拍照 Native 桥接能力
- 原生到 Flutter 的事件转发经验与实现

不建议直接复用为核心边界的内容：

- 当前 `rtc-sdk` 作为宿主 SDK 的整体入口角色
- 宿主直接拉起 Flutter 页面的旧链路
- 宿主与 Flutter 直接 MethodChannel 通信的旧嵌入假设

原则：

- 可以复用原生壳能力
- 不复用旧架构边界
- 新架构下宿主 SDK 职责统一由 `rtc-aidl` 承接

### 权限归属

推荐方案：

- RTC APK 自己申请并持有所有 RTC 媒体相关权限

包括：

- 摄像头权限
- 麦克风权限
- `MediaProjection` 屏幕共享授权

原因：

- Android 权限归属于 `applicationId`
- 真正使用媒体能力的是 RTC APK
- 可以减少宿主与 RTC 之间的权限耦合

第一版约束：

- 宿主不处理任何 RTC 媒体权限弹框
- RTC APK 在进入会议页后自行做权限检查与授权引导

### 业务拍照文件归属

第一版建议：

- RTC APK 负责创建并写入拍照结果文件
- 文件保存到共享媒体目录
- 推荐目录：
  - `DCIM/YourApp/`
  - 或 `Pictures/YourApp/`
- 推荐通过 `MediaStore` 写入，而不是直接操作裸路径

宿主侧约束：

- 宿主默认只读取拍照结果
- 不承担拍照文件的修改或删除职责
- 回调结果优先消费 `contentUri`

返回策略：

- `RtcCaptureResult.fileUris` 为主
- `RtcCaptureResult.filePaths` 为辅
- 若同时提供二者，应以 `contentUri` 作为稳定主值

原因：

- Android 9 / 10 / 11 对共享媒体目录访问模型不同
- `MediaStore + contentUri` 比直接裸路径更稳
- 更适合双 APK 之间共享媒体结果

### FlutterEngine 生命周期释放

推荐增加空闲释放策略：

1. `leaveRoom()` 成功后
2. 若没有宿主 Binder 连接
3. 且持续空闲超过防抖时间（建议 3 分钟）
4. 则主动：
- `destroy FlutterEngine`
- `stopSelf()` 结束 `RtcBridgeService`

目的：

- 降低后台内存占用
- 避免 RTC APK 长期驻留成为高内存后台进程
- 降低被系统因内存压力猎杀的概率

## enterRoom 时序设计

### 正常时序

1. 宿主调用 `enterRoom(options)`
2. `rtc-aidl` 做本地参数校验和前台条件校验
3. `rtc-aidl` 生成本次 `requestId`
4. `rtc-aidl` 使用宿主传入的前台 `Activity Context` 显式 `startActivity(RtcEntryActivity)`
5. `Intent` 中携带：
  - `requestId`
  - 受控大小的完整 `RtcRoomOptions` 或其 JSON 等价结构
6. `RtcEntryActivity.onCreate()` 展示原生 Loading 页面
7. `RtcEntryActivity` 绑定本地 `RtcBridgeService`
8. `RtcEntryActivity` 将 `requestId + RtcRoomOptions` 交给本进程 `RtcBridgeService` 消费
9. `RtcBridgeService` 确保 `FlutterEngine` 已创建或复用
10. `RtcEntryActivity` attach 到同一 `FlutterEngine`
11. Flutter 收到入房 payload，开始真实入房流程
12. 宿主侧继续建立或恢复 AIDL 连接，用于后续 callback 与命令通道
13. 持续回调状态变化
14. 成功时回调 `onRoomSnapshotChanged(roomState=active)`

补充说明：

- 早期设计要求“先通过 AIDL 同步缓存参数，再启动 `RtcEntryActivity`”。
- 2026-04-10 在 `BZT3-AL00 / Android 10 / 华为 ROM` 真机黑盒验证中观察到：当 RTC APK 处于未启动或被 `force-stop` 后，宿主首次 `bindService(RtcBridgeService)` 会被系统拦截，日志为 `Service starting has been prevented by iaware or trustsbase`。
- 同一设备上，宿主前台显式 `startActivity(RtcEntryActivity)` 可以可靠拉起 RTC APK。
- 因此 Phase 1 主路径调整为“先前台显式拉起 Activity，并通过受控 Intent payload 完成冷启动入房参数传递；AIDL 连接用于后续 callback 与命令通道”。
- 若后续要支持超大参数，再评估 `ContentProvider`、共享文件或 Activity 启动后反向等待 AIDL 缓存的方案；Phase 1 不为超大参数引入额外复杂度。

### 退出房间时序

正式主路径：

1. 用户在 RTC APK 内点击挂断，或按系统 Back
2. `RtcEntryActivity` / Flutter 房间页统一触发 `leaveRoom()`
3. `RtcBridgeService` 执行离房与资源释放
4. `RtcBridgeService` 通过 callback 通知宿主离房结果或失败原因
5. `RtcEntryActivity.finish()`
6. Android 任务栈自然回到发起会议的宿主 Activity

约束：

- `leaveRoom()` 失败时仍需 callback 宿主，错误码由宿主决定是否提示或重试
- `RtcEntryActivity` 不主动 `startActivity()` 拉宿主 `MainActivity`
- `rtc-aidl` 不要求宿主提供 `returnIntent` 或 `returnActivityClassName`
- 宿主需要额外业务跳转时，在收到离房 callback 后自行处理
- `idle` 可以出现在初始化阶段，因此不能仅凭 `roomState=idle` 推断“需要回宿主”；页面退出以 RTC 页面内显式挂断 / Back / Activity finish 为准

### 参数传递策略

第一版采用 Activity-first 混合模式：

- 冷启动主路径：`Intent` 传 `requestId + RtcRoomOptions`，用于可靠启动 RTC APK 并让本进程 Service 消费
- 温启动优化路径：若 AIDL Service 已连接，可先写入 `RtcBridgeService` 的 pending request 缓存，再让 `Intent` 只带 `requestId`
- 两条路径最终都必须在 `RtcBridgeService` 内生成同一份入房 payload，供 FlutterEngine 消费

原因：

- `Intent` / Binder 事务大小受系统限制
- 复杂 `Bundle` 或大对象通过 `Intent` 直接传递，存在 `TransactionTooLargeException` 风险，因此 `RtcRoomOptions` 必须保持受控大小
- 在华为等 ROM 的冷启动场景中，先 AIDL bind 再拉页不可靠；先 Activity 可确保 RTC APK 进入前台启动路径
- 将完整 `RtcRoomOptions` 最终收敛到 `Service` 中，更利于参数校验、幂等控制和日志串联

推荐做法：

- `Intent` 主键使用 `requestId`
- `Intent` payload 只允许 Android framework 自带类型、`Parcelable RtcRoomOptions` 或 JSON String
- `RtcBridgeService` 维护短生命周期的 pending room request 缓存，作为温启动优化和幂等校验工具
- `RtcEntryActivity` 启动后优先按 `requestId` 消费 Service 缓存；若缓存不存在，则使用 Intent 内受控 payload，并立刻写入 / 交给本进程 Service
- 参数消费完成后及时清理缓存，避免长期堆积

硬约束：

- 不允许为满足“先缓存”而阻塞或破坏前台显式 `startActivity` 主路径
- `RtcRoomOptions` 必须保持小体积，严禁把图片、二进制文件、大列表等放进 Intent
- `Bundle` 中严禁传递任何非 Android framework 自带类；复杂业务对象必须转为 JSON String
- `requestId` 缺失、payload 缺失或 payload 校验失败时，`RtcEntryActivity` 必须结束并回调错误
- 若温启动缓存路径可用，缓存写入必须是同步调用，并且失败时不能继续走“requestId only”的启动方式

原因：

- Binder 调用和 Activity 启动属于不同系统调度通道
- 冷启动时先 AIDL 缓存可能被 ROM 阻断；Phase 1 优先保证前台 Activity 启动真实可靠
- `requestId + Intent payload` 能避免 Activity 先启动但拿不到参数
- 温启动缓存路径保留为后续降低 Intent payload 风险的优化路径

### Pending Request TTL

`RtcBridgeService` 需要为 pending request 缓存增加 TTL 兜底机制。

规则：

- 每个 `requestId` 写入缓存时立即创建 TTL 计时器
- 第一版建议 TTL 为 10 秒
- 若 `RtcEntryActivity` 在 TTL 内成功消费参数，则立即清理缓存并取消计时器
- 若 TTL 到期仍未消费，则 `RtcBridgeService` 主动清理该条缓存
- 清理后通过 callback 或错误结果返回：
  - `failureType=request_timeout`
  - `errorCode=enter_room_request_expired`

目的：

- 防止用户快速返回、页面异常退出或系统卡顿导致 pending request 长期滞留
- 降低内存泄漏和脏状态累积风险

### Service 就绪前置条件

`enterRoom()` 进入“写缓存 + 启动页面”阶段前，必须已有可用 binder。

第一版策略：

- `rtc-aidl` 在 `enterRoom()` 前先检查连接状态
- 仅在 `RtcBridgeService` 处于 `connected` 时，继续执行同步缓存和页面启动
- 若仍处于 `connecting / disconnected`，则直接返回明确错误：
  - `errorCode=service_not_ready_please_retry`

约束：

- 第一版不自动挂起 `enterRoom()` 到 pending command 队列
- 第一版不将“服务断线处理”和“业务命令重试队列”耦合

### 宿主可见状态

按最小工作量原则，宿主只暴露四个粗粒度房间状态：

- `idle`
- `opening`
- `active`
- `failed`

语义：

- `idle`
  表示未入房、已离房或当前无活动房间。

- `opening`
  表示从宿主发起 `enterRoom()` 到房间真正可用之前的整个过程。

- `active`
  表示房间已建立完成，可正常使用。

- `failed`
  表示当前房间流程失败，需要由宿主决定重试、退出或提示用户。

约束：

- `accepted / establishing / leaving / left` 不作为宿主一级状态暴露
- 若宿主确实需要更细阶段，只通过 `extras` 或错误码补充，不再新增一级状态

### 失败分类

建议保留：

- `service_unavailable`
- `request_rejected`
- `activity_launch_failed`
- `engine_not_ready`
- `room_establish_failed`
- `service_died`

### 幂等规则

- 状态为 `opening / active` 时，再次 `enterRoom()` 不重复执行
- 状态为 `failed / idle` 时，允许重新 `enterRoom()`
- 离会中的内部过程不作为宿主一级状态暴露，最终收口为 `idle`

## 页面启动限制

第一版约束：

- `enterRoom()` 默认要求宿主当前在前台
- 宿主在后台时，不启动 RTC 页面
- 直接返回后台限制相关错误

补充要求：

- 第一版主路径不采用“RTC Service 从后台自动 `startActivity()`”
- 第一版主路径采用“`rtc-aidl` 使用宿主前台 `Activity Context` 显式启动 `RtcEntryActivity`”
- `RtcBridgeService` 只负责命令受理、状态同步、`FlutterEngine` 托管，不承担主路径拉页职责
- 如未来需要评估 `Service -> startActivity()` 例外路径：
  - 宿主必须处于前台/可见
  - 宿主在 `bindService()` 时应传递 `Context.BIND_ALLOW_ACTIVITY_STARTS`
  - 仍需接受 OEM ROM 差异风险，不作为第一版主路径

## Activity 导出与安全

### `RtcEntryActivity` 安全

由于 `RtcEntryActivity` 需要被宿主跨 APK 显式启动，因此必须 `android:exported=\"true\"`。

同时必须加访问控制：

- 定义 `signature` 级别权限，例如：
  - `com.yourcompany.rtc.permission.LAUNCH_RTC`
- 在 `RtcEntryActivity` 上配置：
  - `android:permission=\"com.yourcompany.rtc.permission.LAUNCH_RTC\"`
- 宿主声明 `uses-permission`

目的：

- 防止其他第三方应用直接通过 `Intent` 拉起 RTC 页面
- 将可启动 RTC 页面这一能力限制在同签名宿主范围内

建议：

- `RtcEntryActivity` 启动后仍校验 `requestId` 是否有效
- 对无效、过期或未预注册的 `requestId`，直接报错并结束页面
- 不把“仅靠导出权限”作为唯一安全边界

## rtc-aidl 断线处理

### 连接状态

按最小工作量原则，AIDL 连接状态只保留：

- `disconnected`
- `connecting`
- `connected`

语义：

- `disconnected`
  表示当前服务不可用，包括未连接、连接失败、版本不匹配、RTC APK 缺失等所有不可调用状态。

- `connecting`
  表示首次绑定过程。

- `connected`
  表示当前可正常发送命令和接收回调。

约束：

- `binding / reconnecting / unavailable` 不再单独作为一级状态
- 这些差异通过 `disconnectReason`、`errorCode`、`errorMessage` 表达

### 断线触发条件

第一版不做 SDK 内部自动重新入房或命令重放。以下事件统一视为断线或服务不可用，需要 callback 宿主：

- `onServiceDisconnected()`
- `onBindingDied()`
- `IBinder.DeathRecipient`
- AIDL 调用 `RemoteException`
- 调用时发现 binder 已失效

### 断线处理策略

第一版策略：

- `rtc-aidl` 不自动重新入房
- `rtc-aidl` 不自动重放命令
- 断线后立即更新为 `disconnected`
- 通过 callback 将 `disconnectReason / errorCode / errorMessage` 通知宿主
- 宿主如需恢复会议，必须在前台 Activity 中重新调用 `initialize()` / `enterRoom()`
- 若调用时 Service 未 ready，直接返回 `service_not_ready_please_retry`

连接建立补充：

- 冷启动时允许 `rtc-aidl` 在 `RtcEntryActivity` 已被前台显式拉起后，执行有限的 AIDL 绑定重试，用于建立 callback / 命令通道
- 该重试只用于“建立连接通道”，不得自动重放 `enterRoom()`、`leaveRoom()`、`sendMessage()` 等业务命令
- 一旦业务命令已经返回失败，是否再次发起由宿主决定

若后续确认需要 SDK 内部自动重连，可作为阶段 2 增量能力评估，候选策略为：

- 指数退避 + 上限封顶：`1s / 2s / 5s / 10s / 15s`
- 任一时刻只允许一个重新绑定任务
- 只重新绑定 binder 与 callback，不自动重放业务命令

### 重新绑定成功后的行为

若由宿主重新触发初始化并连接成功，只做：

- 重新拿 binder
- 重新注册 callback
- 主动拉取状态：
  - `getServiceState()`
  - `getRoomSnapshot()`
- 重新同步状态给宿主

明确不做：

- 自动重放命令
- 自动重建房间
- 自动重发业务消息

### RTC APK 崩溃后的恢复语义

- RTC APK 进程崩溃后，内存态房间上下文默认视为丢失
- 第一版不尝试保留 live WebRTC 会话
- 第一版只允许保留最小恢复快照，例如最近一次 `RtcRoomOptions`、错误状态和最近房间标识
- 检测到 binder 断线或服务死亡后统一回调宿主：
  - `roomState=failed`
  - `failureType=service_restarted`
- 由宿主决定是否重新发起 `enterRoom()`

### Service / Activity 存活语义

- `RtcEntryActivity` 在前台时，RTC APK 进程属于前台进程，系统通常不会单独清理同进程内的 `RtcBridgeService`
- 若出现 Activity 仍在但 Service 已停止，优先视为 RTC APK 内部生命周期设计问题，而不是系统正常清理
- `RtcEntryActivity` 必须本地 bind `RtcBridgeService`
- 页面存在或房间 `active` 时，`RtcBridgeService` 不允许因 `onUnbind()` 立即 `stopSelf()`
- RTC 页面退后台但音视频/投屏仍 active 时，`RtcBridgeService` 必须按媒体能力启动前台服务，避免后台媒体能力被系统限制
- 若系统杀死整个 RTC APK 进程，Activity、Service、FlutterEngine 和内存态房间上下文均视为丢失；宿主通过断线/失败 callback 感知

### disconnectReason

为了避免扩展过多连接状态，连接失败原因统一通过 `disconnectReason` 表达。第一版建议保留：

- `not_installed`
- `bind_failed`
- `binder_died`
- `protocol_mismatch`
- `service_restarted`

## AIDL 安全边界

### Service 安全

RTC APK 暴露的 AIDL Service 必须加访问控制，避免被第三方应用 bind。

建议：

1. 定义 `signature` 级别权限，例如：
- `com.yourcompany.rtc.permission.BIND_RTC_SERVICE`

2. 在 RTC APK manifest 中声明该权限

3. 在 `<service>` 上配置：
- `android:permission="com.yourcompany.rtc.permission.BIND_RTC_SERVICE"`

4. 宿主声明 `uses-permission`

5. 服务端再补一层调用方 UID / 包名校验

## 版本协商策略

采用三层版本模型：

1. APK 版本
2. `protocolVersion`
3. `capabilities`

### 服务端必须提供

- `getProtocolVersion()`
- `getSdkVersion()`
- `getCapabilities()`

### 兼容规则

- 主协议版本不一致：直接不兼容，返回 `protocol_version_mismatch`
- 次版本不一致：允许连接，通过 capability 决定功能可用性
- 字段演进规则：
  - 只能新增可选字段
  - 不删除旧字段
  - 不改变旧字段语义

### 建议能力项

第一版建议：

- `supportsBusinessCapture`
- `supportsProxyConfig`
- `supportsRoomStateQuery`
- `supportsMessageSend`

## 安装、卸载与 MDM 依赖

### 当前前提

当前已知 MDM 能力边界：

- MDM 目前没有足够能力做双包原子安装/卸载
- 当前阶段按“我方提供 APK + 白名单 + 用户安装”方式落地
- RTC APK 不显示桌面入口
- RTC APK 不允许用户手动运行
- MDM 可阻止 RTC APK 被用户单独卸载

### 安装约束

需要满足：

- RTC APK 安装完成后，宿主即可 `bindService()`
- 不需要先手动打开 RTC APK
- 页面只能由宿主能力调用后间接拉起

当前不再依赖 MDM 能力：

- 不要求双 APK 同任务下发
- 不要求原子安装失败回滚

当前仍需确认：

- 安装完成后的白名单和可绑定性策略是否满足目标设备要求

### 卸载约束

平台限制：

- Android 不提供多包原子卸载

宿主还需要具备：

- RTC APK 缺失检测
- 缺失时返回 `service_not_installed / unavailable`

## Android 14 前台服务要求

若 RTC APK 在退到后台后仍需保持媒体能力，则必须及时进入前台服务。

建议：

- 前台服务由媒体能力启停直接驱动
- `RtcBridgeService` 调用 `startForeground(...)`
- manifest 中预声明会用到的 `foregroundServiceType`

类型策略：

1. 启动麦克风时：
- 若前台服务未启动，则启动并使用 `microphone`
- 若已启动，则更新类型，确保包含 `microphone`

2. 启动摄像头时：
- 若前台服务未启动，则启动并使用 `camera`
- 若已启动，则更新类型，确保包含 `camera`

3. 启动投屏时：
- 若前台服务未启动，则启动并使用 `mediaProjection`
- 若已启动，则更新类型，确保包含 `mediaProjection`

4. 停止某个媒体能力时：
- 重新计算当前仍在使用的媒体集合
- 再次调用 `startForeground(...)` 更新类型
- 若 `microphone / camera / mediaProjection` 均已停止，则停止前台服务

manifest 预声明建议至少覆盖：

- `camera`
- `microphone`
- `mediaProjection`

实现约束：

- 前台服务是否启动不由房间 `active` 状态直接决定，而由媒体能力是否启用决定
- `mediaProjection` 仅在真正开始投屏后才加入当前前台服务类型
- 若调用 `startForeground(...)` 时包含多个类型，则运行时必须满足这些类型对应的平台前提和权限要求

## 分阶段实施

### 阶段 1：最小 PoC

目标：验证双 APK 最小闭环是否成立。

范围：

- `rtc_apk_app` 可独立安装
- `rtc-aidl` 可在老工具链下编译并接入示例宿主
- 宿主可 `bindService`
- 宿主调用 `enterRoom()`
- 宿主通过 `rtc-aidl` 显式拉起 RTC APK 的 `RtcEntryActivity`
- RTC APK 通过 callback 回传：
  - 服务连接
  - 房间打开
  - 入房成功/失败
- RTC APK 崩溃或 binder 断线后宿主可检测并收到失败回调

### 阶段 2：工程化补齐

范围：

- `sendMessage / leaveRoom / 拍照模式` 完整接通
- 协议版本与能力协商
- Bundle 白名单和参数 sanitization
- 权限申请与异常链路补齐
- 前台服务与通知完善
- 空闲销毁 `FlutterEngine`
- 若宿主确认需要，再评估 SDK 内部 binder 自动重连

### 阶段 3：交付与联调

范围：

- MDM 安装流程联调
- 顺序卸载流程联调
- 签名权限与安全策略联调
- 宿主错误码和异常提示完善
- 版本升级/兼容性联调

## 测试与验证

第一阶段至少覆盖：

- 宿主未安装 RTC APK 时的错误回调
- RTC APK 已安装但未启动时的 bind 与进入房间
- `enterRoom()` 前台显式拉起 `RtcEntryActivity` 成功链路
- `RtcEntryActivity` 与 `RtcBridgeService` 双轨初始化无竞态
- `requestId + Service 缓存` 参数获取成功链路
- pending request TTL 到期清理链路
- `service_not_ready_please_retry` 返回链路
- `enterRoom()` 在宿主后台时的失败分支
- RTC APK 崩溃后的 binder 断线回调
- 协议版本不匹配时的拒绝逻辑
- 参数 Bundle 中非法类型的拦截逻辑
- 退出房间后的空闲回收策略
- RTC 页面内挂断后 `RtcEntryActivity.finish()` 自然回到发起会议的宿主 Activity
- 系统 Back 与页面挂断一致，均触发 `leaveRoom()` 与 callback
- 示例宿主浮窗只作为查看 / demo 工具，不作为正式交互入口

补充的真机验证结论：

- `android/app/build.gradle` 中的 `testInstrumentationRunner` 必须显式配置为 `androidx.test.runner.AndroidJUnitRunner`
- 第一次 `./gradlew app:connectedDebugAndroidTest` 失败的根因，是未显式配置 runner，导致设备侧默认按 `android.test.InstrumentationTestRunner` 启动
- 修复 runner 配置后，手工 `am instrument` 和 `./gradlew app:connectedDebugAndroidTest` 都已通过
- 近期黑盒验证发现：原 `MainActivityConferenceBlackboxTest` 通过主动拉回宿主再点击停止按钮，未覆盖“RTC 页面上通过浮窗关闭后是否回宿主”的真实路径
- demo 中曾使用 `CLEAR_TOP | SINGLE_TOP` 修复浮窗主动拉回示例宿主的问题；该逻辑只属于示例宿主验证，不作为正式 SDK 返回路径
- 正式 SDK 返回路径改为 RTC 页面挂断 / Back 后 `finish()` 自己，并通过 callback 通知宿主
- targetSdk 22 示例宿主在真机冷安装后可能出现系统兼容提示弹窗，黑盒脚本需要处理该系统弹窗后再查找业务按钮
- 2026-04-10 复测 `./gradlew :app:connectedDebugAndroidTest` 通过；同日手工 adb 黑盒验证显示首次 AIDL bind 被华为系统拦截，但随后前台显式 `startActivity(RtcEntryActivity)` 成功，RTC 页面可见

## 风险与待确认项

### 高风险项

- `rtc-aidl` 使用宿主前台 `Activity Context` 显式启动 `RtcEntryActivity` 在华为 / 荣耀 ROM 上是否受应用启动管理、后台保护或电池策略影响；联想 ROM 需真机验证
- `FlutterEngine` 在空闲回收策略下的冷启动 / 温启动耗时是否满足业务体验
- RTC APK 崩溃后，采用“最小快照 + 失败返回”语义是否满足业务恢复要求

### 待确认项

- 宿主错误码枚举与返回策略

### 重点测试项

- `RtcEntryActivity` 与 `RtcBridgeService` 的并行初始化是否被 Activity-first payload、TTL 和 AIDL 连接建立重试约束完全收敛
- 跨 APK 冷启动时，原生 Loading 页是否足以消除黑屏/白屏感知

### 后续平台扩展验证项

- 若后续设备范围扩展到 Android 14+，前台服务与后台媒体能力需单独实机验证

## 结论

新增双 APK + AIDL 方案的核心结论如下：

- 旧方案继续保留，新方案并行新增
- 通过新增 `rtc_apk_app` 与 `rtc-aidl`，把 Flutter/WebRTC 的承载从宿主移出
- 宿主通过新的 `RscRtcBridge` 使用轻量业务接口与业务回调
- RTC APK 通过 `Service` 持有单 `FlutterEngine`，统一管理房间和页面生命周期
- `enterRoom()` 采用 `rtc-aidl` 使用宿主前台 `Activity Context` 显式启动 RTC 入口 Activity 的主路径，避免将主链路建立在后台 Service 拉页例外路径上
- 宿主从前台 `Activity Context` 发起调用；正式链路中 RTC 页面退出依赖 `RtcEntryActivity.finish()` 自然回到发起会议的宿主 Activity
- RTC 页面内挂断和系统 Back 统一等同于 `leaveRoom()`，并通过 callback 通知宿主结果
- `rtc-aidl` 第一版不自动重放命令、不自动重新入房；冷启动 Activity 已被前台显式拉起后，允许有限 AIDL 绑定重试建立 callback / 命令通道
- 入房参数采用 Activity-first 混合模式：冷启动路径由 `Intent` 携带受控大小的 `requestId + RtcRoomOptions`，温启动路径可退化为 `requestId + RtcBridgeService` 缓存
- `RtcBridgeService` 对 pending request 采用 TTL 清理；温启动缓存路径必须同步写入，避免 AIDL/Intent 竞态和缓存泄漏
- AIDL 第一版统一采用最小工作量的数据模型，不要求兼容旧接口
- 安全上必须增加 `signature` 权限保护和 Bundle 类型白名单
- 双 APK 的安装/卸载流程依赖 MDM 能力，但当前阶段可以按“白名单 + 用户安装 + 无桌面入口”约束推进
