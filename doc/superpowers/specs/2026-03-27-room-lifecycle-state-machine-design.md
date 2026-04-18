# 房间生命周期状态机设计

日期：2026-03-27

## 背景

当前 Flutter 房间页只有一套 `RoomConnectionStatus`，主要描述传输层连接状态：

- `disconnected`
- `connecting`
- `connected`
- `reconnecting`
- `failed`

这套状态不足以表达完整的房间生命周期，导致几个问题混在一起：

- 建立中和已建立没有明确边界
- 主动离会、异常断开、重连失败都容易被压缩成 `disconnected`
- UI 退场时机和后台清理时机耦合
- Native 退出请求和 Flutter 自身退出链路没有统一约束
- `_closed`、`_isJoining` 这类局部锁承担了本应由状态机承担的职责

本设计的目标是补齐房间生命周期状态机，但保持现有 `RoomStateV2 + RoomBlocV2 + RoomClientEntranceV2` 主结构不变，避免一次性引入新的 coordinator。

## 目标

- 在 `RoomStateV2` 中建立完整生命周期状态
- 保留 `RoomConnectionStatus` 作为传输层状态，不再直接驱动页面退场
- 让 UI 在 `leaving` 时快速退场
- 让后台 teardown 在页面退场后继续执行，并最终收口到 `left`
- 将失败区分为网络失败、设备失败、系统失败
- 让建立阶段失败支持从头重试
- 让已建立后的连接失败只走重连
- 让设备检测内容由房间策略决定
- 让 Native 只发请求，不再直接关闭页面

## 非目标

- 本次不引入独立 `RoomLifecycleCoordinator`
- 本次不重构 `RoomClientEntranceV2` 的大文件拆分
- 本次不引入新的 Native 会话代际协议
- 本次不重新设计房间 UI 布局

## 总体方案

在现有 `RoomStateV2` 中新增一套业务生命周期字段，形成两层状态：

1. 生命周期状态
2. 传输层连接状态

其中：

- 生命周期状态决定页面行为、业务允许操作、退出链路
- 连接状态只用于描述 WebSocket/连接层健康度和重连过程

## 状态模型

### 生命周期状态

新增 `RoomLifecycleState`：

- `establishing`
- `established`
- `leaving`
- `left`
- `failed`

语义如下：

- `establishing`
  表示正在建立房间，尚未达到“可正常使用”的标准。

- `established`
  表示房间已建立完成，允许正常使用房间能力。

- `leaving`
  表示用户或系统已经决定离开房间，页面可以立即退场，后台继续清理资源。

- `left`
  表示后台清理流程已经结束。这里的“结束”是流程收口，不要求每一步都成功。

- `failed`
  表示当前建立或连接恢复失败，需要根据失败类型决定重试或退出。

### 建立阶段

新增 `RoomEstablishPhase`：

- `networkCheck`
- `dualCenterProbe`
- `deviceCheck`
- `connecting`
- `joining`
- `initializingCapabilities`

语义如下：

- `networkCheck`
  网络可达性、TURN/UDP 等建立前网络检测。

- `dualCenterProbe`
  双中心探测与中心选择。

- `deviceCheck`
  按房间策略执行设备前置检测。

- `connecting`
  建立 WebSocket 或底层连接。

- `joining`
  创建房间、加入房间、建立会话。

- `initializingCapabilities`
  初始化房间默认能力。

说明：

- `establishPhase` 只在 `lifecycleState == establishing` 时有意义
- 一旦进入 `established / leaving / left / failed`，`establishPhase` 应清空

### 失败模型

新增 `RoomFailureType`：

- `network`
- `device`
- `system`

新增失败字段：

- `failureType`
- `failureCode`
- `failureMessage`
- `canRetry`

语义如下：

- `failureCode`
  技术错误码，供内部逻辑和日志使用，例如 `rearCameraMissing`、`turnUnavailable`。

- `failureMessage`
  面向用户的展示文案。

- `canRetry`
  由当前失败类型和失败所处阶段共同决定。

## 状态流转

### 正常建立

- `establishing(networkCheck)`
- `establishing(dualCenterProbe)`
- `establishing(deviceCheck)`
- `establishing(connecting)`
- `establishing(joining)`
- `establishing(initializingCapabilities)`
- `established`

### 建立阶段失败

- `establishing(*)`
- `failed`

规则：

- 建立阶段任何失败都进入 `failed`
- 用户点击“继续重试”时，从头执行整个建立流程

### 主动离会

- `established`
- `leaving`
- `left`

规则：

- 进入 `leaving` 时 UI 立即退场
- 后台 teardown 继续执行
- teardown 完成后进入 `left`

### 已建立后的连接异常

- `established`
- 连接状态进入 `reconnecting`
- 若恢复成功，仍回到 `established`
- 若恢复失败，进入 `failed(network, canRetry=true)`

规则：

- 已建立后失败不重跑完整 `establishing`
- 用户点击“继续重试”时，只执行重连路径

## 与现有 `RoomConnectionStatus` 的关系

现有 `RoomConnectionStatus` 保留，继续表达传输层状态：

- `connecting`
- `connected`
- `reconnecting`
- `disconnected`
- `failed`

约束如下：

- UI 页面退场不再直接监听 `RoomConnectionStatus.disconnected`
- 页面退场改为监听 `RoomLifecycleState.leaving`
- `RoomConnectionStatus` 仅用于：
  - 显示连接层状态
  - 控制重连中 UI 文案
  - 记录日志和诊断

## 设备检测设计

设备检测分两类：

1. 建立阶段前置设备检测
2. 房间内设备检测面板

### 建立阶段前置设备检测

这是状态机的一部分，位于 `establishing(deviceCheck)`。

检测内容不写死在公共层，而由房间策略提供。策略需要输出当前房间的设备前置要求，例如：

- 是否必须存在摄像头
- 是否必须同时存在前后摄像头
- 是否必须存在麦克风
- 是否要求当前音量不为 0

若检测失败：

- 进入 `failed(device, canRetry=false)`
- 写入 `failureCode` 和 `failureMessage`
- UI 展示详细错误并提供退出按钮

### 房间内设备检测面板

现有设备检测面板继续保留，作为房内辅助诊断工具，不与前置设备检测冲突。

## 失败交互

### 网络失败

适用场景：

- 网络检测失败
- 双中心探测失败
- 建立连接失败
- 已建立后重连失败

UI 规则：

- 展示失败信息
- 展示“继续重试”按钮
- 展示“退出”按钮

重试规则：

- 若失败前属于 `establishing`，从头跑完整建立流程
- 若失败前属于 `established`，只执行重连，不重跑网络检测和设备检测

### 设备失败

适用场景：

- 缺少所需摄像头
- 缺少麦克风
- 音量不满足要求
- 其他策略定义的设备前置条件不满足

UI 规则：

- 展示详细报错
- 仅展示“退出”按钮

### 系统失败

适用场景：

- 未归类异常
- 内部状态异常
- 无法恢复的清理失败或初始化异常

UI 规则：

- 默认展示失败信息和退出按钮
- 是否允许重试由具体错误码决定

## 退出链路

退出链路采用“两阶段退出”：

1. 前台快速退场
2. 后台受控清理

### 前台阶段

进入 `leaving` 时：

- 不再接受新的用户操作
- 不再接受新的房间能力启停
- 页面立即退场
- UI 相关回调提前解绑

### 后台阶段

后台继续执行 teardown：

- 停止业务能力
- 停止本地媒体
- 清理 peers
- 发送离房信令
- 关闭 RTC / WS
- 注销依赖

### `left` 的定义

`left` 表示后台清理流程已经结束，不要求每个清理步骤都成功，只要求流程已经收口。

实现约束：

- 每个 teardown 步骤应尽量带超时
- 个别步骤失败只记录日志，不引入新的 `leaveFailed` 终态
- teardown 结束后统一进入 `left`

## Native 退出协作

Native 侧不再直接关闭页面，只负责发送退出请求。

新的协作边界：

- Native: 发出 `requestExit`
- Flutter: 根据当前状态进入 `leaving`
- Flutter: 页面退场并在后台执行 teardown
- Flutter: teardown 结束后更新为 `left`

约束：

- Native 不再绕过 Flutter 状态机直接 `SystemNavigator.pop()`
- 重复 `requestExit` 在 `leaving / left` 状态下应被忽略

## 操作门禁

原有 `_closed`、`_isJoining` 只做局部防重入，不再作为主导生命周期的机制。

以状态机为准，约束如下：

- `establishing` 时拒绝再次 `join`
- `established` 时允许正常房间操作
- `leaving` 时拒绝新的能力开关和再次 `leave`
- `left` 时忽略房间内操作
- `failed` 时仅允许：
  - 重试
  - 退出

## 与现有代码的对应关系

### `RoomStateV2`

新增字段：

- `lifecycleState`
- `establishPhase`
- `failureType`
- `failureCode`
- `failureMessage`
- `canRetry`

### `RoomBlocV2`

新增事件或更新方式，用于：

- 更新生命周期状态
- 更新建立阶段
- 写入失败信息
- 清理失败信息

### `RoomClientEntranceV2`

职责调整：

- `join()` 在每个阶段前更新 `establishPhase`
- 建立成功后写入 `established`
- 主动退出时先写入 `leaving`
- teardown 结束后写入 `left`
- 已建立后的重连失败写入 `failed(network)`
- 失败重试根据失败前状态决定“全量重建”或“仅重连”

### `Room`

页面行为调整：

- 不再监听 `connectionStatus == disconnected` 后立即退出
- 改为监听 `lifecycleState == leaving` 后立即退场
- `failed` 时展示对应失败 UI

### `service_locator`

职责调整：

- 不再依赖页面 `dispose()` 触发完整业务 `leave()`
- cleanup 由状态机驱动的后台 teardown 统一负责

### `XChatMethodChannel`

职责调整：

- `requestExit` 只发退出请求
- 不直接强制关闭页面

## 测试重点

需要覆盖的关键场景：

1. 正常入房
- 生命周期从 `establishing` 进入 `established`

2. 双中心探测失败
- 进入 `failed(network)`
- 可点击重试并从头重跑

3. 设备检测失败
- 进入 `failed(device)`
- 展示详细错误
- 仅允许退出

4. 已建立后 WS 断开并自动重连成功
- 生命周期保持 `established`
- 连接状态经历 `reconnecting -> connected`

5. 已建立后 WS 重连失败
- 进入 `failed(network, canRetry=true)`
- 点击重试只走重连路径

6. 主动离会
- 立即进入 `leaving`
- 页面立即退场
- 后台 teardown 结束进入 `left`

7. Native 重复 requestExit
- 在 `leaving / left` 状态下被忽略

8. teardown 单步失败或超时
- 流程仍最终进入 `left`

## 风险与后续

### 本次已接受的风险

- `RoomClientEntranceV2` 仍然较大，状态逻辑仍集中在大类中
- 旧异步回调串话问题本次不靠会话代际机制彻底解决

### 后续可演进方向

- 如状态机稳定后仍存在旧回调污染问题，可引入 `roomSessionId`
- 如生命周期逻辑继续增长，可进一步演进到独立 coordinator
- 可将 teardown 和 establish 阶段进一步下沉成专门组件，缩小 `RoomClientEntranceV2`

## 结论

本方案在不引入新 coordinator 的前提下，为现有房间系统补齐了完整生命周期状态机，并明确了：

- 生命周期状态和连接状态的分层
- 建立阶段与失败分类
- 快速退场与后台 teardown 的边界
- Native 与 Flutter 的退出职责边界
- 基于房间策略的设备检测规则

这是当前代码基线下风险和收益最平衡的方案。
