# Room Lifecycle State Machine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Flutter 房间流程补齐完整生命周期状态机，解耦页面退场和后台清理，并支持按房间策略执行设备前置检测与分类失败重试。

**Architecture:** 保持现有 `RoomStateV2 + RoomBlocV2 + RoomClientEntranceV2` 主结构不变，在 `RoomStateV2` 中新增生命周期、建立阶段和失败模型；`RoomConnectionStatus` 继续保留为传输层状态。`RoomClientEntranceV2` 负责按阶段更新状态并执行 join/reconnect/leave，UI 只监听生命周期状态，不再直接根据传输层断开退场。

**Tech Stack:** Dart, Flutter, flutter_bloc, Equatable, flutter_test

---

## 文件结构

**Create:**
- `flutter_module/lib/features/room/models/room_lifecycle.dart`
- `flutter_module/test/features/room/room_bloc_v2_test.dart`
- `flutter_module/test/features/signaling/room_mode_strategy_device_requirements_test.dart`
- `flutter_module/test/screens/room/room_lifecycle_ui_test.dart`

**Modify:**
- `flutter_module/lib/features/room/models/models.dart`
- `flutter_module/lib/features/room/bloc/room_state_v2.dart`
- `flutter_module/lib/features/room/bloc/room_event_v2.dart`
- `flutter_module/lib/features/room/bloc/room_bloc_v2.dart`
- `flutter_module/lib/features/signaling/room_mode_strategy_v2.dart`
- `flutter_module/lib/features/signaling/strategies_v2/single_agent_room_mode_strategy_v2.dart`
- `flutter_module/lib/features/signaling/strategies_v2/single_pad_room_mode_strategy_v2.dart`
- `flutter_module/lib/features/signaling/strategies_v2/single_llm_room_mode_strategy_v2.dart`
- `flutter_module/lib/features/signaling/strategies_v2/single_robot_room_mode_strategy_v2.dart`
- `flutter_module/lib/features/signaling/strategies_v2/single_robot_llm_room_mode_strategy_v2.dart`
- `flutter_module/lib/features/signaling/strategies_v2/single_robot_agent_room_mode_strategy_v2.dart`
- `flutter_module/lib/features/signaling/strategies_v2/single_voice_room_mode_strategy_v2.dart`
- `flutter_module/lib/features/signaling/strategies_v2/multiple_room_mode_strategy_v2.dart`
- `flutter_module/lib/features/signaling/room_client_entrance_v2.dart`
- `flutter_module/lib/features/xchatkit_adapter/channels/xchat_method_channel.dart`
- `flutter_module/lib/screens/room/room.dart`
- `flutter_module/lib/screens/room/ui/room_app_bar.dart`
- `flutter_module/lib/screens/room/controllers/room_controller.dart`
- `flutter_module/lib/di/service_locator.dart`

**Test:**
- `flutter_module/test/features/room/room_bloc_v2_test.dart`
- `flutter_module/test/features/signaling/room_mode_strategy_device_requirements_test.dart`
- `flutter_module/test/screens/room/room_lifecycle_ui_test.dart`

## 实施约束

- 不引入新的 coordinator
- 不在本轮拆分 `RoomClientEntranceV2` 大文件
- 先以状态机取代 `_closed` / `_isJoining` 的主导语义，再保留它们作为局部幂等保护
- Native `requestExit` 只能触发 Flutter 进入退出流程，不能再直接 `SystemNavigator.pop()`
- 所有新增失败信息同时包含技术码和用户文案

### Task 1: 建立生命周期模型与 Bloc 更新接口

**Files:**
- Create: `flutter_module/lib/features/room/models/room_lifecycle.dart`
- Modify: `flutter_module/lib/features/room/models/models.dart`
- Modify: `flutter_module/lib/features/room/bloc/room_state_v2.dart`
- Modify: `flutter_module/lib/features/room/bloc/room_event_v2.dart`
- Modify: `flutter_module/lib/features/room/bloc/room_bloc_v2.dart`
- Test: `flutter_module/test/features/room/room_bloc_v2_test.dart`

- [ ] **Step 1: 写失败测试，固定新的状态字段与流转接口**

```dart
test('RoomBlocV2 can enter establishing phase and failed state', () async {
  final bloc = buildRoomBloc();

  bloc.add(const UpdateLifecycleStateV2(
    lifecycleState: RoomLifecycleState.establishing,
    establishPhase: RoomEstablishPhase.deviceCheck,
  ));

  await expectLater(
    bloc.stream,
    emits(
      predicate<RoomStateV2>((state) =>
          state.lifecycleState == RoomLifecycleState.establishing &&
          state.establishPhase == RoomEstablishPhase.deviceCheck),
    ),
  );
});
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run: `cd flutter_module && flutter test test/features/room/room_bloc_v2_test.dart -r expanded`

Expected: FAIL，提示 `RoomLifecycleState`、`UpdateLifecycleStateV2` 或对应字段不存在。

- [ ] **Step 3: 新增生命周期模型文件并导出**

```dart
enum RoomLifecycleState { establishing, established, leaving, left, failed }

enum RoomEstablishPhase {
  networkCheck,
  dualCenterProbe,
  deviceCheck,
  connecting,
  joining,
  initializingCapabilities,
}

enum RoomFailureType { network, device, system }
```

- [ ] **Step 4: 扩展 `RoomStateV2`**

```dart
final RoomLifecycleState lifecycleState;
final RoomEstablishPhase? establishPhase;
final RoomFailureType? failureType;
final String? failureCode;
final String? failureMessage;
final bool canRetry;
```

- [ ] **Step 5: 给 `RoomBlocV2` 增加状态更新事件**

```dart
class UpdateLifecycleStateV2 extends RoomEventV2 {
  final RoomLifecycleState lifecycleState;
  final RoomEstablishPhase? establishPhase;
  final RoomFailureType? failureType;
  final String? failureCode;
  final String? failureMessage;
  final bool? canRetry;
}
```

- [ ] **Step 6: 运行测试，确认模型与 Bloc 更新通过**

Run: `cd flutter_module && flutter test test/features/room/room_bloc_v2_test.dart -r expanded`

Expected: PASS

- [ ] **Step 7: 提交这一小步**

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
git add lib/features/room/models/room_lifecycle.dart \
  lib/features/room/models/models.dart \
  lib/features/room/bloc/room_state_v2.dart \
  lib/features/room/bloc/room_event_v2.dart \
  lib/features/room/bloc/room_bloc_v2.dart \
  test/features/room/room_bloc_v2_test.dart
git commit -m "feat: add room lifecycle state model"
```

### Task 2: 给房间策略补齐设备前置检测需求

**Files:**
- Modify: `flutter_module/lib/features/signaling/room_mode_strategy_v2.dart`
- Modify: `flutter_module/lib/features/signaling/strategies_v2/single_agent_room_mode_strategy_v2.dart`
- Modify: `flutter_module/lib/features/signaling/strategies_v2/single_pad_room_mode_strategy_v2.dart`
- Modify: `flutter_module/lib/features/signaling/strategies_v2/single_llm_room_mode_strategy_v2.dart`
- Modify: `flutter_module/lib/features/signaling/strategies_v2/single_robot_room_mode_strategy_v2.dart`
- Modify: `flutter_module/lib/features/signaling/strategies_v2/single_robot_llm_room_mode_strategy_v2.dart`
- Modify: `flutter_module/lib/features/signaling/strategies_v2/single_robot_agent_room_mode_strategy_v2.dart`
- Modify: `flutter_module/lib/features/signaling/strategies_v2/single_voice_room_mode_strategy_v2.dart`
- Modify: `flutter_module/lib/features/signaling/strategies_v2/multiple_room_mode_strategy_v2.dart`
- Test: `flutter_module/test/features/signaling/room_mode_strategy_device_requirements_test.dart`

- [ ] **Step 1: 写失败测试，明确策略返回设备要求**

```dart
test('single_agent strategy requires camera and microphone checks', () {
  final strategy = SingleAgentRoomModeStrategyV2(FakeEntrance());

  expect(strategy.deviceCheckRequirements.requireMicrophone, isTrue);
  expect(strategy.deviceCheckRequirements.requireAnyCamera, isTrue);
});
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run: `cd flutter_module && flutter test test/features/signaling/room_mode_strategy_device_requirements_test.dart -r expanded`

Expected: FAIL，提示 `deviceCheckRequirements` 不存在。

- [ ] **Step 3: 在策略接口中增加设备检测要求模型**

```dart
class DeviceCheckRequirements {
  final bool requireMicrophone;
  final bool requireAnyCamera;
  final bool requireFrontCamera;
  final bool requireRearCamera;
  final bool requirePositiveVolume;
}
```

- [ ] **Step 4: 为各策略填充最小必要规则**

```dart
@override
DeviceCheckRequirements get deviceCheckRequirements =>
    const DeviceCheckRequirements(
      requireMicrophone: true,
      requireAnyCamera: true,
      requirePositiveVolume: true,
    );
```

- [ ] **Step 5: 运行测试，确认策略规则稳定**

Run: `cd flutter_module && flutter test test/features/signaling/room_mode_strategy_device_requirements_test.dart -r expanded`

Expected: PASS

- [ ] **Step 6: 提交这一小步**

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
git add lib/features/signaling/room_mode_strategy_v2.dart \
  lib/features/signaling/strategies_v2/*.dart \
  test/features/signaling/room_mode_strategy_device_requirements_test.dart
git commit -m "feat: add strategy driven device check requirements"
```

### Task 3: 重写建立阶段状态流转与失败分类

**Files:**
- Modify: `flutter_module/lib/features/signaling/room_client_entrance_v2.dart`
- Test: `flutter_module/test/features/room/room_bloc_v2_test.dart`

- [ ] **Step 1: 先补状态迁移辅助测试，锁定建立阶段顺序**

```dart
test('join updates lifecycle phases before room becomes established', () async {
  // 用假依赖驱动 join 的阶段更新
  // 断言至少出现 networkCheck -> connecting -> joining -> established
});
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run: `cd flutter_module && flutter test test/features/room/room_bloc_v2_test.dart -r expanded`

Expected: FAIL，当前 join 只更新 `connectionStatus`，没有生命周期阶段。

- [ ] **Step 3: 在 `join()` 中按阶段更新生命周期**

```dart
_updateLifecycle(
  RoomLifecycleState.establishing,
  phase: RoomEstablishPhase.networkCheck,
);
```

- [ ] **Step 4: 实现设备前置检测并映射失败结果**

```dart
_failEstablish(
  type: RoomFailureType.device,
  code: 'rearCameraMissing',
  message: '未检测到后置摄像头',
  canRetry: false,
);
```

- [ ] **Step 5: 将网络、双中心、连接异常统一映射为 `failed(network)`**

```dart
_failEstablish(
  type: RoomFailureType.network,
  code: 'turnUnavailable',
  message: '网络检测失败，请检查网络后重试',
  canRetry: true,
);
```

- [ ] **Step 6: 建立成功时切到 `established` 并清空失败信息**

```dart
_updateLifecycle(RoomLifecycleState.established);
```

- [ ] **Step 7: 运行相关测试**

Run: `cd flutter_module && flutter test test/features/room/room_bloc_v2_test.dart -r expanded`

Expected: PASS

- [ ] **Step 8: 提交这一小步**

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
git add lib/features/signaling/room_client_entrance_v2.dart \
  test/features/room/room_bloc_v2_test.dart
git commit -m "feat: add lifecycle phases to room join flow"
```

### Task 4: 重写已建立后重连失败、主动离会和 Native 退出请求语义

**Files:**
- Modify: `flutter_module/lib/features/signaling/room_client_entrance_v2.dart`
- Modify: `flutter_module/lib/features/xchatkit_adapter/channels/xchat_method_channel.dart`
- Modify: `flutter_module/lib/di/service_locator.dart`

- [ ] **Step 1: 写失败测试或补日志断言，锁定 `leaving -> left` 与重连失败语义**

```dart
test('reconnect failure after established becomes failed network and stays retryable', () {
  // 断言 lifecycleState == failed 且 canRetry == true
});
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run: `cd flutter_module && flutter test test/features/room/room_bloc_v2_test.dart -r expanded`

Expected: FAIL，当前重连失败直接走 `disconnected`。

- [ ] **Step 3: 将主动离会改为 `leaving` 先行**

```dart
_updateLifecycle(RoomLifecycleState.leaving);
```

- [ ] **Step 4: 将 teardown 收口改为 `left`，并采用 best-effort + timeout 语义**

```dart
await _runCleanupStepWithTimeout(...);
_updateLifecycle(RoomLifecycleState.left);
```

- [ ] **Step 5: 将已建立后的 `reconnectFailed` 改为 `failed(network, canRetry=true)`**

```dart
_failAfterEstablished(
  type: RoomFailureType.network,
  code: 'reconnectFailed',
  message: '重连失败，请重试或退出',
);
```

- [ ] **Step 6: 修改 Native `requestExit`，只发请求不直接 `SystemNavigator.pop()`**

```dart
case 'requestExit':
  await XChatKitAdapter.onExitRequest?.call();
  return null;
```

- [ ] **Step 7: 移除页面 `dispose()` 对完整 `leave()` 的兜底依赖**

```dart
// cleanupRoomDependencies 不再从 Room.dispose() 触发业务 leave
```

- [ ] **Step 8: 运行分析和核心测试**

Run: `cd flutter_module && flutter analyze lib/features/signaling/room_client_entrance_v2.dart lib/features/xchatkit_adapter/channels/xchat_method_channel.dart lib/di/service_locator.dart`

Expected: 无新增 error

- [ ] **Step 9: 提交这一小步**

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
git add lib/features/signaling/room_client_entrance_v2.dart \
  lib/features/xchatkit_adapter/channels/xchat_method_channel.dart \
  lib/di/service_locator.dart
git commit -m "feat: align leave and native exit with lifecycle state"
```

### Task 5: 更新房间 UI 的退场和失败交互

**Files:**
- Modify: `flutter_module/lib/screens/room/room.dart`
- Modify: `flutter_module/lib/screens/room/ui/room_app_bar.dart`
- Modify: `flutter_module/lib/screens/room/controllers/room_controller.dart`
- Test: `flutter_module/test/screens/room/room_lifecycle_ui_test.dart`

- [ ] **Step 1: 写失败测试，固定 UI 只在 `leaving` 时退场**

```dart
testWidgets('room exits only when lifecycle enters leaving', (tester) async {
  // 推入 Room，更新 lifecycleState 到 failed，不应 pop
  // 更新到 leaving，应触发 pop
});
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run: `cd flutter_module && flutter test test/screens/room/room_lifecycle_ui_test.dart -r expanded`

Expected: FAIL，当前 UI 监听的是 `connectionStatus == disconnected`。

- [ ] **Step 3: 将页面监听改为 `lifecycleState == leaving`**

```dart
listenWhen: (prev, curr) =>
    prev.lifecycleState != curr.lifecycleState &&
    curr.lifecycleState == RoomLifecycleState.leaving
```

- [ ] **Step 4: 在房间页展示失败分支 UI**

```dart
if (state.lifecycleState == RoomLifecycleState.failed) {
  return RoomFailureActions(
    failureType: state.failureType,
    failureMessage: state.failureMessage,
    canRetry: state.canRetry,
  );
}
```

- [ ] **Step 5: 更新 AppBar 文案，让传输层状态和生命周期状态并存显示**

```dart
final lifecycleText = _getLifecycleText(roomState.lifecycleState);
```

- [ ] **Step 6: 确保 `RoomController.dispose()` 只做 UI 回调解绑，不触发业务退出**

```dart
sl<RoomClientEntranceV2>().onLog = null;
```

- [ ] **Step 7: 运行 UI 测试**

Run: `cd flutter_module && flutter test test/screens/room/room_lifecycle_ui_test.dart -r expanded`

Expected: PASS

- [ ] **Step 8: 提交这一小步**

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
git add lib/screens/room/room.dart \
  lib/screens/room/ui/room_app_bar.dart \
  lib/screens/room/controllers/room_controller.dart \
  test/screens/room/room_lifecycle_ui_test.dart
git commit -m "feat: update room ui for lifecycle driven exit and failure actions"
```

### Task 6: 补齐重试入口与回归验证

**Files:**
- Modify: `flutter_module/lib/features/signaling/room_client_entrance_v2.dart`
- Modify: `flutter_module/lib/screens/room/room.dart`
- Test: `flutter_module/test/features/room/room_bloc_v2_test.dart`
- Test: `flutter_module/test/screens/room/room_lifecycle_ui_test.dart`

- [ ] **Step 1: 写失败测试，锁定两类重试行为**

```dart
test('retry from establishing failure restarts join from beginning', () {});
test('retry from established network failure only triggers reconnect', () {});
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run: `cd flutter_module && flutter test test/features/room/room_bloc_v2_test.dart test/screens/room/room_lifecycle_ui_test.dart -r expanded`

Expected: FAIL，当前没有统一 retry 入口。

- [ ] **Step 3: 为 `RoomClientEntranceV2` 增加统一 `retry()` 入口**

```dart
Future<void> retry() async {
  if (_lastStableLifecycleState == RoomLifecycleState.established) {
    await _retryReconnectOnly();
    return;
  }
  await join();
}
```

- [ ] **Step 4: 在失败 UI 上接入“继续重试”与“退出”动作**

```dart
onRetry: state.canRetry ? () => sl<RoomClientEntranceV2>().retry() : null,
onExit: () => sl<RoomClientEntranceV2>().leave(),
```

- [ ] **Step 5: 运行目标测试**

Run: `cd flutter_module && flutter test test/features/room/room_bloc_v2_test.dart test/features/signaling/room_mode_strategy_device_requirements_test.dart test/screens/room/room_lifecycle_ui_test.dart -r expanded`

Expected: PASS

- [ ] **Step 6: 运行分析**

Run: `cd flutter_module && flutter analyze lib/features/room/ lib/features/signaling/ lib/screens/room/`

Expected: 无新增 error；若有 warning，记录为既有问题或本次新增问题并处理。

- [ ] **Step 7: 手工验证关键场景**

Run:

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
flutter test test/features/room/room_bloc_v2_test.dart -r expanded
flutter test test/features/signaling/room_mode_strategy_device_requirements_test.dart -r expanded
flutter test test/screens/room/room_lifecycle_ui_test.dart -r expanded
flutter analyze lib/features/room/ lib/features/signaling/ lib/screens/room/
```

Expected:

- 建立中失败进入 `failed`
- 已建立后重连失败进入 `failed(network, canRetry=true)`
- `leaving` 时页面立即退场
- `left` 只在后台 teardown 收口后出现

- [ ] **Step 8: 提交这一小步**

```bash
cd /Users/wangxinran/StudioProjects/flutter_module
git add lib/features/signaling/room_client_entrance_v2.dart \
  lib/screens/room/room.dart \
  test/features/room/room_bloc_v2_test.dart \
  test/screens/room/room_lifecycle_ui_test.dart
git commit -m "feat: add lifecycle aware retry flow"
```

## 完成定义

完成本计划后，应满足以下结果：

- 房间页不再通过 `RoomConnectionStatus.disconnected` 自动退场
- `RoomStateV2` 能完整表达建立、已建立、离开中、已离会、失败
- 设备检测前置条件完全由房间策略决定
- 网络失败和设备失败的交互不同
- 已建立后的失败只重连，不重跑完整建立流程
- Native `requestExit` 不再直接强退页面
- teardown 以 `left` 收口，不新增 `leaveFailed`

## 执行提示

- 实施时优先按任务顺序推进，不要跨任务混改
- 每完成一个 Task 就先跑对应测试和分析，再提交
- 如果 `RoomClientEntranceV2` 的测试难以直接写，先抽出最薄的一层状态辅助方法，再对辅助方法做单测，不要跳过测试
