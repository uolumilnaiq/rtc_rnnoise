# RTC 双 APK + AIDL 方案设计

更新时间：2026-04-08

## 1. 目标与背景

当前宿主工具链固定为老版本 Android 构建链：
- Kotlin `1.4.10x`
- AGP `3.6.3x`
- Gradle `6.2.2x`
- JDK `1.8.0_171`
- 完全离线、本地 AAR 接入

在该前提下，继续让宿主直接承载 Flutter/WebRTC/插件 Android 产物，存在高耦合、高试错成本的问题。为降低宿主适配压力，改为双 APK 架构：
- 宿主 APK：继续保持现有老工具链
- RTC APK：独立安装，承载 Flutter/WebRTC/房间逻辑/UI
- 两者通过 AIDL 通信

目标：
1. 保持宿主对外接入 API 尽量不变
2. 让宿主不再直接承受 Flutter/WebRTC/Kotlin/Java 高版本产物的编译压力
3. 保留当前 Flutter 房间逻辑和 UI 能力
4. 让 RTC 能独立演进，宿主通过轻量桥接 SDK 调用

## 2. 总体架构

### 2.1 工程拆分

建议拆成三个工程或模块：

1. `rtc_apk_app`
- 一个新的 Flutter app 工程
- 独立生成并安装为 RTC APK
- 内含：
  - Flutter UI
  - WebRTC
  - 房间状态机
  - AIDL Service
  - 会议 Activity
  - 前台服务/通知
  - FlutterEngine 管理

2. `MyAppForAIDL`
- 一个新的 Android 工程
- 使用宿主相同的老工具链配置
- 其中包含：
  - `rtc-aidl` library module
  - `app` demo/验证宿主

3. `rtc-aidl`
- 一个新的 Android library
- 面向宿主提供轻量 SDK
- 仅负责：
  - bind/unbind Service
  - AIDL 请求转发
  - 回调注册与转发
  - binder 断线重连
  - 状态查询
  - 版本协商

### 2.2 运行角色

1. 宿主 App
- 只调用简化业务接口
- 不感知 Flutter 内部实现
- 不感知房间内部状态机细节

2. `rtc-aidl`
- 宿主侧桥接层
- 对外尽量保持现有 `XChatKit` 风格 API
- 内部转成 AIDL 调用

3. RTC APK
- 真正的服务端
- 负责 UI、房间流程、媒体能力、页面控制、日志等

## 3. 对外 API 设计原则

### 3.1 外部接口保持现有语义

结论：
- `rtc-aidl` 对宿主暴露的接口保持与当前 `rtc-sdk / XChatKit` 尽量一致
- 宿主不直接接触 AIDL、Parcelable、ServiceConnection

宿主调用语义保持为业务能力接口，例如：
1. 初始化
2. 进入房间
3. 退出房间
4. 发送消息
5. 启动业务拍照模式
6. 停止业务拍照模式
7. 注册监听器
8. 获取状态

### 3.2 AIDL 内部数据模型

为了兼容当前 `ConferenceOptions` 和历史接入方式，AIDL 内部统一采用：
- `Parcelable + Bundle`

原则：
1. 对外接口不变
2. `rtc-aidl` 内部映射成 AIDL 专用 `Parcelable`
3. RTC APK 服务端再把 `Parcelable` 转成 Flutter payload

推荐对象：
1. `RoomOptionsParcelable`
- `String route`
- `Bundle arguments`

2. `LeaveOptionsParcelable`
- `Bundle arguments`

3. `MessageParcelable`
- `String message`
- `Bundle arguments`

4. `CaptureOptionsParcelable`
- `String mode`
- `Bundle arguments`

5. `CommandResultParcelable`
- `boolean accepted`
- `String requestId`
- `String errorCode`
- `String errorMessage`

6. `RoomStateParcelable`
- `String roomState`
- `String failureType`
- `String failureCode`
- `String failureMessage`
- `boolean canRetry`
- `Bundle extras`

7. `ErrorParcelable`
- `String errorCode`
- `String errorMessage`
- `String failureType`
- `Bundle extras`

### 3.3 参数兼容原则

`ConferenceOptions` 当前真实结构来自：
- 顶层 `route`
- 顶层 `arguments`
- `arguments.clientInfo`
- `arguments.clientInfo.deviceInfo`

第一版策略：
- 严格对齐现有参数模型
- 不做强收敛
- 通过 `Bundle` 保持兼容

约束：
- 跨进程只允许基础可稳定序列化类型：
  - `String`
  - `int`
  - `long`
  - `boolean`
  - `double`
  - `Bundle`
  - `ArrayList<String>`
  - 可选 `byte[]`
- 不允许任意 `Object/Serializable` 无限制下传
- `rtc-aidl` 在映射时需要做参数合法性归一化

## 4. AIDL 接口分层

AIDL 按三层接口设计：
1. 命令接口
2. 状态查询接口
3. 回调接口

### 4.1 命令接口

建议第一版保留：
1. `initialize(InitOptionsParcelable options)`
2. `enterRoom(RoomOptionsParcelable options)`
3. `leaveRoom(LeaveOptionsParcelable options)`
4. `sendMessage(MessageParcelable message)`
5. `startBusinessCaptureMode(CaptureOptionsParcelable options)`
6. `stopBusinessCaptureMode(CaptureOptionsParcelable options)`
7. `dismissRoom()`
8. `ping()`

规则：
- 命令返回只表示“请求是否被受理”
- 真正结果通过 callback 返回

### 4.2 状态查询接口

建议保留：
1. `getServiceState()`
2. `getRoomState()`
3. `getCurrentRoomSnapshot()`
4. `isRoomPageShowing()`
5. `getSdkVersion()`
6. `getProtocolVersion()`
7. `getCapabilities()`

理由：
- 宿主重连后需要补状态
- callback 丢失时需要主动拉取
- 双 APK 场景不能只依赖 push 事件

### 4.3 回调接口

建议通过 `IRtcServiceCallback` 暴露：
1. `onRtcServiceConnected()`
2. `onRtcServiceDisconnected()`
3. `onRtcServiceReconnecting(int attempt)`
4. `onRtcServiceUnavailable(String errorCode, String message)`
5. `onRoomOpening(String requestId)`
6. `onEnterRoomSuccess(RoomResultParcelable result)`
7. `onEnterRoomFailed(ErrorParcelable error)`
8. `onRoomStateChanged(RoomStateParcelable state)`
9. `onMessageReceived(MessageParcelable message)`
10. `onBusinessCaptureStateChanged(CaptureStateParcelable state)`
11. `onLeaveRoomCompleted()`
12. `onError(ErrorParcelable error)`

实现建议：
- 使用 `RemoteCallbackList` 管理 callback

## 5. RTC APK 内部设计

### 5.1 FlutterEngine 管理

结论：
- 由 RTC APK 的 `Service` 持有唯一 `FlutterEngine`
- `Activity` 仅负责附着显示，不持有核心状态

理由：
1. AIDL 入口先到 `Service`
2. `enterRoom()` 先打到 `Service`
3. 单 Engine 更利于状态一致性
4. 避免双 Engine 带来的状态同步和内存复杂度

### 5.2 组件职责

1. `RtcBridgeService`
- 持有单例 `FlutterEngine`
- 管 AIDL 请求入口
- 管 Flutter 桥接
- 管宿主回调列表
- 管 binder 重连后的状态补齐
- 管会议页是否已打开
- 管命令幂等

2. `RoomActivity`
- 复用 `RtcBridgeService` 中的 `FlutterEngine`
- 承载 Flutter 页面
- 页面退出时通知 Service
- 不持有核心房间状态

3. Flutter 业务层
- 房间状态机
- 信令
- 媒体能力
- 页面逻辑
- 日志
- 失败与重试策略

### 5.3 权限归属

推荐方案：
- RTC APK 自己申请并持有运行所需权限

包括：
1. 摄像头权限
2. 麦克风权限
3. 屏幕共享 / `MediaProjection` 相关授权

原因：
1. Android 权限归属于 `applicationId`
2. 真正使用媒体能力的是 RTC APK，而不是宿主 APK
3. 将权限申请留在 RTC APK，可以减少宿主与 RTC 之间的耦合

第一版建议：
- 宿主不处理任何 RTC 媒体权限弹框
- 进入会议页后由 RTC APK 自己完成权限校验与申请

### 5.4 FlutterEngine 生命周期释放

推荐增加空闲释放策略，避免 RTC APK 长期作为高内存后台进程驻留。

建议策略：
1. `leaveRoom()` 成功后
2. 若当前没有宿主 Binder 连接
3. 且持续空闲超过一段时间（建议 `3` 分钟）
4. 则主动：
   - `destroy FlutterEngine`
   - `stopSelf()` 结束 `RtcBridgeService`

说明：
1. 冷启动重建 `FlutterEngine` 的代价通常可接受
2. 该策略可显著降低后台内存占用
3. 可减少系统因内存压力杀死 RTC APK 的概率

## 6. enterRoom 时序设计

### 6.1 正常时序

1. 宿主调用 `enterRoom(options)`
2. `rtc-aidl` 确保服务已绑定
3. RTC APK `Service` 收到请求
4. 参数校验、状态校验、缓存本次参数
5. 返回 `CommandResult.accepted=true`
6. Service 判断会议页是否已存在
7. 若不存在则自动 `startActivity(RoomActivity)`
8. 回调宿主：`onRoomOpening`
9. `RoomActivity` attach 到同一个 `FlutterEngine`
10. Flutter 收到入房 payload，开始真实入房流程
11. 持续回调状态变化
12. 成功时回调 `onEnterRoomSuccess`

### 6.2 宿主可见状态

建议暴露：
1. `accepted`
2. `opening`
3. `establishing`
4. `established`
5. `failed`
6. `leaving`
7. `left`

### 6.3 失败分类

建议保留：
1. `service_unavailable`
2. `request_rejected`
3. `activity_launch_failed`
4. `engine_not_ready`
5. `room_establish_failed`
6. `service_died`

### 6.4 幂等规则

1. 状态为 `opening / establishing / established` 时：
- 再次 `enterRoom()` 不重复执行
- 返回 `already_in_progress_or_active`

2. 状态为 `failed / left` 时：
- 允许重新 `enterRoom()`

3. 状态为 `leaving` 时：
- 拒绝新的 `enterRoom()`
- 返回 `leaving_in_progress`

### 6.5 后台启动限制

第一版约束：
- `enterRoom()` 默认要求宿主当前在前台
- 宿主在后台时，不自动拉起页面
- 直接返回后台限制相关错误

补充要求：
1. RTC APK 不能假设自己总能从后台 `startActivity()`
2. 若采用“宿主调用 `enterRoom()` 后由 RTC APK 自动拉页”的方案：
   - 宿主必须处于前台/可见
   - 宿主在 `bindService()` 时应传递 `Context.BIND_ALLOW_ACTIVITY_STARTS`
   - RTC APK 仍需处理页面拉起失败分支

## 7. rtc-aidl 重连状态机

### 7.1 连接状态

建议仅保留：
1. `uninitialized`
2. `binding`
3. `connected`
4. `reconnecting`
5. `unavailable`

### 7.2 重连触发条件

1. `onServiceDisconnected()`
2. `onBindingDied()`
3. `IBinder.DeathRecipient`
4. AIDL 调用 `RemoteException`
5. 调用时发现 binder 已失效

### 7.3 重连策略

建议：指数退避 + 上限封顶
- `1s`
- `2s`
- `5s`
- `10s`
- 后续固定 `15s`

约束：
1. 单飞重连
2. 宿主前台优先重连

### 7.4 重连成功后的行为

只做：
1. 重新拿 binder
2. 重新注册 callback
3. 主动拉取状态：
- `getServiceState()`
- `getRoomState()`
- `getCurrentRoomSnapshot()`
4. 重新同步状态给宿主

明确不做：
- 自动重放命令
- 自动重建房间命令
- 自动重发业务消息

### 7.5 RTC APK 崩溃后的恢复语义

1. 若重连后还能读到有效房间状态：
- 继续同步当前状态给宿主

2. 若重连后房间上下文已丢失：
- 回调宿主明确的失败/离开状态
- 建议附带 `failureType=service_restarted`

## 8. AIDL 安全与参数边界

### 8.1 Service 访问安全

RTC APK 若暴露可被宿主绑定的 `AIDL Service`，必须增加访问控制，避免被第三方恶意应用直接调用。

建议措施：
1. 定义一个 `signature` 级别权限，例如：
   - `com.yourcompany.rtc.permission.BIND_RTC_SERVICE`
2. 在 RTC APK `AndroidManifest.xml` 中声明该权限
3. 在 `<service>` 上加：
   - `android:permission="com.yourcompany.rtc.permission.BIND_RTC_SERVICE"`
4. 宿主侧声明 `uses-permission`
5. 服务端再补一层调用方 UID / 包名校验，作为第二道防线

### 8.2 Bundle 类型白名单

跨进程 `Bundle` 传输必须严格限制类型，避免 `ClassLoader` / 反序列化问题导致 RTC APK 崩溃。

硬规则：
1. 严禁在 `Bundle` 中放宿主自定义类
2. 严禁放自定义枚举
3. 严禁放自定义 `Serializable`
4. 严禁放自定义 `Parcelable`
5. 复杂对象一律转成：
   - `String(JSON)`
   - 或拆成基础字段 / 嵌套 `Bundle`

第一版允许的值类型：
1. `String`
2. `int`
3. `long`
4. `boolean`
5. `double`
6. `Bundle`
7. `ArrayList<String>`
8. 可选 `byte[]`

原因：
- `Bundle` 在跨进程读取时会触发对象反序列化
- 一旦涉及宿主自定义类，RTC APK 侧可能因缺少 `ClassLoader` 而出现崩溃风险

## 9. 版本协商策略

采用三层版本模型：
1. APK 版本
2. `protocolVersion`
3. `capabilities`

### 8.1 服务端必须提供

1. `getProtocolVersion()`
2. `getSdkVersion()`
3. `getCapabilities()`

### 8.2 兼容规则

1. 主协议版本不一致：
- 直接不兼容
- 返回 `protocol_version_mismatch`

2. 次版本不一致：
- 允许连接
- 通过 capability 判断功能是否支持

3. 字段演进规则：
- 只能新增可选字段
- 不删除旧字段
- 不改变旧字段语义

### 8.3 建议 capability

第一版建议保留：
1. `supportsBusinessCapture`
2. `supportsProxyConfig`
3. `supportsRoomStateQuery`
4. `supportsMessageSend`

## 10. 安装、卸载与 MDM 依赖

### 9.1 安装

双 APK 方案下，安装能力强依赖 MDM/安装器能力。

推荐确认项：
1. 是否支持双 APK 一次任务下发
2. 是否支持多包原子安装
3. 若不支持原子安装，是否支持顺序安装和失败回滚
4. 安装后宿主是否可直接 bind RTC APK Service

结论：
- RTC APK 安装完成后，宿主即可 `bindService()`
- 不需要先手动打开 RTC APK

当前已知 MDM 能力边界：
1. MDM 目前不具备足够强的双包原子安装/卸载能力
2. 当前阶段按以下模式设计：
   - 我方提供宿主 APK 与 RTC APK
   - MDM / 设备侧提供安装白名单能力
   - 允许用户安装
3. RTC APK 不要求桌面显示入口
4. RTC APK 不允许用户手动运行

因此 RTC APK 建议：
1. 不配置桌面 Launcher 入口（不声明 `MAIN/LAUNCHER` Activity）
2. 仅保留内部会议 Activity 与对宿主可绑定的 Service
3. 页面只能由宿主调用能力接口后间接拉起
4. 需要安装后即可通过宿主 `bindService()` 使用

### 10.2 卸载

平台限制：
- Android 不提供多包原子卸载

因此需要与 MDM 确认：
1. 是否支持按套件顺序卸载两个包
2. 是否支持禁止 RTC APK 被单独卸载

推荐策略：
- 安装尽量原子
- 卸载使用 MDM 顺序清理
- 通过策略降低用户单独卸载 RTC APK 的概率

## 11. 前台服务与 Android 14 要求

若 RTC APK 在退到后台后仍需保持媒体能力（摄像头、麦克风、投屏），则必须及时进入前台服务。

建议：
1. 入房成功后立即进入前台服务，统一降低后台被系统中断的风险
2. `RtcBridgeService` 需要调用 `startForeground(...)`
3. Manifest 中声明正确的 `foregroundServiceType`

至少需要根据实际能力覆盖：
1. `camera`
2. `microphone`
3. `mediaProjection`

说明：
1. Android 14+ 对前台服务类型与权限约束更严格
2. 若缺少对应类型声明，后台媒体采集链路可能被系统中断
3. 实际声明组合需与最终启用的媒体能力保持一致

## 12. 第一版落地范围

第一版只做最小闭环：
1. 宿主通过 `rtc-aidl` 初始化并绑定 RTC APK
2. 宿主调用 `enterRoom()`
3. RTC APK 自动拉起会议页
4. Flutter 完成入房流程
5. 宿主可收到：
- 服务连接事件
- 房间打开事件
- 入房成功/失败事件
- 房间状态变化事件
6. 宿主可调用：
- `leaveRoom()`
- `sendMessage()`
- `startBusinessCaptureMode()`
- `stopBusinessCaptureMode()`
7. 支持 binder 断线后重连和状态补齐

第一版暂不扩展：
- 自动命令重放
- 后台启动页面
- 复杂多窗口/多会议页并发
- 高阶能力协商

## 13. 风险与待确认项

### 11.1 高风险项

1. MDM 是否支持双 APK 一次下发
2. MDM 是否支持顺序卸载和禁止单独卸载 RTC APK
3. RTC APK 页面自动拉起是否受设备策略限制
4. FlutterEngine 冷启动耗时是否可接受
5. RTC APK 崩溃后房间上下文是否能保留

### 11.2 待确认项

1. MDM 的安装能力边界
2. MDM 的卸载能力边界
3. 宿主前台检测方式由谁提供
4. `XChatKit` 现有监听事件与新 callback 的映射关系
5. 业务拍照模式在双 APK 模式下的权限归属

## 14. 结论

双 APK + AIDL 方案的核心结论如下：

1. 宿主只保留轻量业务接口调用，不直接承载 Flutter/WebRTC 复杂技术栈
2. `rtc-aidl` 作为宿主侧桥接 SDK，保持现有 `XChatKit` 风格接口语义
3. RTC APK 由新的 Flutter app 工程承载，内部自治页面、房间逻辑、媒体能力和状态机
4. RTC APK 的 `Service` 持有唯一 `FlutterEngine`，会议 `Activity` 只负责显示
5. `enterRoom()` 采用自动拉页模式，但默认要求宿主在前台调用
6. AIDL 数据模型第一版统一采用 `Parcelable + Bundle`，优先兼容当前 `ConferenceOptions`
7. binder 断线后由 `rtc-aidl` 负责重连和状态补齐，不自动重放命令
8. RTC APK 必须通过 `signature` 级别权限保护 AIDL Service，并对 Bundle 传输类型做白名单限制
9. 双 APK 的安装/卸载流程必须与 MDM 能力配合设计；当前阶段按“白名单 + 用户安装 + 无桌面入口 + 宿主间接拉起”方式设计
10. 若 RTC APK 需在后台保持媒体能力，则必须及时进入带正确 `foregroundServiceType` 的前台服务
