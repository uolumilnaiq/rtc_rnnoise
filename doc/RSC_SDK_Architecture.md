# RSC SDK 代码架构文档

## 1. 项目概述

RSC SDK是一个Android平台的实时通信( RTC ) SDK，采用Native + Flutter混合架构。通过Flutter Embedding技术，将Flutter业务模块集成到原生Android应用中。

### 1.1 项目结构

```
MyApplicationForFlutter/
├── app/                    # Android主应用
├── rsc-sdk/               # Native RTC SDK (AAR)
│   └── src/main/java/com/yc/rtc/rsc_sdk/
│       ├── XChatKit.java              # SDK统一入口
│       ├── SDLActivityAdapter.java    # Flutter引擎适配器
│       ├── FlutterDemoActivity.java    # Flutter页面容器
│       ├── ConferenceOptions.java     # 会议配置
│       ├── XChatKitConfig.java        # SDK配置
│       └── PipMethodChannelHandler.java # 画中画处理
│
flutter_module/             # Flutter业务模块
├── lib/
│   ├── features/
│   │   ├── rtc/            # RTC核心模块
│   │   │   ├── client_instance_v2.dart    # RTC客户端
│   │   │   ├── session_instance_v2.dart   # 会话管理
│   │   │   └── connection/                 # 传输层
│   │   ├── signaling/      # 信令模块
│   │   ├── room/           # 房间模块
│   │   ├── producers/      # 媒体生产者
│   │   ├── peers/          # 远端用户
│   │   └── media_devices/  # 媒体设备
│   ├── plugin/             # 核心插件
│   │   ├── transport.dart           # 传输抽象
│   │   ├── handlers/                # SDP处理
│   │   ├── session/                 # 会话管理
│   │   └── state_machine/           # 状态机
│   └── screens/            # 界面模块
```

## 2. 架构设计

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────┐
│                    Android Host App                      │
│  ┌─────────────────────────────────────────────────┐    │
│  │                  XChatKit                        │    │
│  │  (统一入口: init/startConference/stopConference) │    │
│  └──────────────────┬──────────────────────────────┘    │
│                     │                                     │
│  ┌──────────────────▼──────────────────────────────┐    │
│  │           SDLActivityAdapter                     │    │
│  │  - FlutterEngine管理                              │    │
│  │  - MethodChannel通信                             │    │
│  │  - EventChannel事件推送                          │    │
│  │  - 引擎预热(Pre-warm)                            │    │
│  └──────────────────┬──────────────────────────────┘    │
│                     │                                     │
│  ┌──────────────────▼──────────────────────────────┐    │
│  │         FlutterDemoActivity                      │    │
│  │         (FlutterActivity Wrapper)                │    │
│  └──────────────────┬──────────────────────────────┘    │
└─────────────────────┼───────────────────────────────────┘
                      │
        ┌─────────────▼─────────────┐
        │      Flutter Engine       │
        │   ┌───────────────────┐   │
        │   │   MethodChannel   │   │
        │   │   EventChannel   │   │
        │   └─────────┬─────────┘   │
        │             │             │
        │  ┌─────────▼──────────┐  │
        │   │   RTC Client      │  │
        │   │  (client_instance)│  │
        │   └─────────┬──────────┘  │
        │             │              │
        │  ┌─────────▼──────────┐   │
        │   │   Signaling       │   │
        │   │   (room_client)  │   │
        │   └───────────────────┘   │
        └───────────────────────────┘
```

### 2.2 分层架构

```
┌─────────────────────────────────────────┐
│            Presentation Layer            │
│  (Screens, Widgets, UI Components)       │
├─────────────────────────────────────────┤
│            Business Layer                │
│  (BLoC, Room Management, Signaling)     │
├─────────────────────────────────────────┤
│            Core RTC Layer                │
│  (Client, Session, Transport, Handlers)  │
├─────────────────────────────────────────┤
│            Platform Layer               │
│  (MethodChannel, EventChannel, Plugins)  │
└─────────────────────────────────────────┘
```

## 3. Native模块详解

### 3.1 XChatKit (入口类)

**职责**: SDK统一入口，提供简洁的API接口

**核心方法**:

```java
// 初始化 (建议在Application.onCreate中调用)
public static void init(Context context)

// 绑定生命周期 (自动资源管理)
public static void bindLifecycle(LifecycleOwner owner)

// 启动会议
public static void startConference(Activity activity)
public static void startConference(Activity activity, ConferenceOptions options)

// 停止会议
public static void stopConference()

// 事件监听
public static void addEventListener(XChatEventListener listener)
public static void removeEventListener(XChatEventListener listener)

// 拍照
public static byte[] takePhoto(String peerId)

// 销毁
public static void destroy()
```

**设计模式**: 静态工厂 + 观察者模式

### 3.2 SDLActivityAdapter (Flutter引擎适配器)

**职责**: 管理Flutter引擎生命周期，负责Native与Flutter的通信

**核心功能**:

1. **FlutterEngine管理**
   - 引擎创建与缓存 (`FlutterEngineCache`)
   - 引擎预热 (Pre-warm)
   - 资源释放

2. **通道管理**
   - `MethodChannel`: 方法调用 (Native ↔ Flutter)
   - `EventChannel`: 事件推送 (Native ← Flutter)

3. **性能优化**
   - `FlutterUiDisplayListener`: 首帧渲染监听
   - 引擎就绪状态管理 (`isEngineReady`)
   - 挂起导航请求队列 (`pendingNavigation`)

**关键代码结构**:

```java
// 通道定义
private static final String METHOD_CHANNEL_NAME = "xchatkit";
private static final String EVENT_CHANNEL_NAME = "xchatkit";
private static final String FLUTTER_ENGINE_ID = "xchatkit_engine";

// MethodChannel处理
private static void handleMethodCall(MethodCall call, Result result) {
    switch (call.method) {
        case "engineReady":    // Flutter引擎就绪
        case "getUserData":   // 获取用户数据
        case "onEvent":       // 事件回调
        case "onPhotoCaptured": // 拍照完成
        // ...
    }
}
```

### 3.3 ConferenceOptions (会议配置)

**职责**: 封装会议参数，支持链式配置

```java
ConferenceOptions options = new ConferenceOptions.Builder()
    .setRoute("/call")
    .addArgument("roomId", "12345")
    .addArgument("peerId", "user_001")
    .build();

XChatKit.startConference(activity, options);
```

### 3.4 FlutterDemoActivity (Flutter容器)

**职责**: FlutterActivity包装器，启动Flutter页面

**特点**:
- 支持PIP (画中画)
- 生命周期透传
- 主题适配

## 4. Flutter模块详解

### 4.1 RTC Client (client_instance_v2.dart)

**职责**: RTC核心客户端，管理整个通话流程

**核心类**:

```dart
class ClientInstance {
  // 连接管理
  Future<void> connect(ClientSettings settings);
  Future<void> disconnect();
  
  // 房间管理
  Future<void> joinRoom(RoomSetting roomSetting);
  Future<void> leaveRoom();
  
  // 媒体控制
  void muteMicphone(bool mute);
  void muteCamera(bool mute);
  void switchCamera();
  
  // 屏幕共享
  Future<void> startSharing();
  Future<void> stopSharing();
}
```

**ROOM_MODE枚举** (支持9种房间模式):
- `SINGLE`: 单人模式
- `SINGLE_PAD`: 单Pad模式
- `SINGLE_ROBOT`: 单机器人模式
- `SINGLE_ROBOT_LLM`: 单机器人+LLM模式
- `SINGLE_AGENT`: 单智能体模式
- `SINGLE_LLM`: 单LLM模式
- `SINGLE_VOICE`: 语音模式
- `SINGLE_ROBOT_AGENT`: 机器人+智能体模式
- `MULTIPLE`: 多人模式

### 4.2 Signaling模块 (signaling/)

**职责**: 信令处理，会话控制

**核心组件**:

```
signaling/
├── room_client_entrance_v2.dart    # 信令入口
├── strategies_v2/                   # 房间模式策略
│   ├── single_agent_room_mode_strategy_v2.dart
│   ├── single_llm_room_mode_strategy_v2.dart
│   └── multiple_room_mode_strategy_v2.dart
└── v2/
    ├── room_orchestrator.dart      # 房间协调器
    ├── handlers/                    # 事件处理器
    │   ├── connection_event_handler.dart
    │   ├── producer_event_handler.dart
    │   └── peer_event_handler.dart
    └── managers/
        ├── connection_manager.dart
        ├── media_manager.dart
        └── capability_manager.dart
```

### 4.3 Transport层 (connection/)

**职责**: 网络传输抽象

**实现类**:

```dart
// 传输接口
abstract class TransportInterface {
  Future<void> connect();
  Future<void> disconnect();
  void send(data);
  Stream<dynamic> get onMessage;
}

// Native传输 (通过MethodChannel)
class NativeTransport implements TransportInterface

// WebSocket传输
class WebTransport implements TransportInterface
```

### 4.4 核心Plugin (plugin/)

#### 4.4.1 Transport (transport.dart)

```dart
class Transport {
  // ICE连接管理
  void iceRestart();
  void updateIceCandidates();
  
  // 连接状态
  ConnectionState connectionState;
}
```

#### 4.4.2 Handlers (handlers/)

**SDP处理**: 支持Plan B和Unified Plan两种SDP格式

```dart
// Plan B (传统格式)
class PlanBHandler

// Unified Plan (现代格式)
class UnifiedPlanHandler
```

#### 4.4.3 State Machine (state_machine/)

```dart
// 智能体状态机
class MatchAgentStateMachine {
  MatchAgentState currentState;
  
  void transitionTo(MatchAgentState newState);
}
```

### 4.5 房间模块 (features/room/)

**职责**: 房间状态管理，UI控制

```dart
class RoomBloc {
  // 状态: connected, connecting, disconnected, reconnecting
  // 事件: join, leave, reconnect
}
```

## 5. 通信机制

### 5.1 MethodChannel (双向方法调用)

```
Native → Flutter:
  - navigatorPush: 页面跳转
  - setCallEventListener: 设置事件监听
  - takePhoto: 拍照请求
  - requestExit: 请求退出

Flutter → Native:
  - engineReady: 引擎就绪通知
  - getUserData: 获取用户数据
  - onEvent: 事件上报
  - onPhotoCaptured: 拍照完成回调
```

### 5.2 EventChannel (事件推送)

```
Native ← Flutter:
  - 连接状态变化
  - 媒体状态变化
  - 房间事件
```

### 5.3 数据流程

```dart
// 入会流程
1. XChatKit.startConference() 
   ↓
2. FlutterDemoActivity启动
   ↓
3. Flutter引擎初始化
   ↓
4. RoomClient.connect(mgwUrl)
   ↓
5. Signaling建立WebSocket连接
   ↓
6. Transport建立ICE连接
   ↓
7. Producers/Consumers创建
   ↓
8. 媒体流传输
```

## 6. 关键设计模式

### 6.1 单例模式
- `XChatKit`: SDK全局入口
- `SDLActivityAdapter`: Flutter引擎管理

### 6.2 观察者模式
- `XChatEventListener`: 事件监听
- `EnhancedEventEmitter`: Flutter事件发射器

### 6.3 建造者模式
- `ConferenceOptions`: 会议配置构建

### 6.4 策略模式
- `RoomModeStrategy`: 房间模式策略

### 6.5 状态机模式
- `MatchAgentStateMachine`: 状态转换管理

## 7. 性能优化

### 7.1 Flutter引擎预热
- 在Application.onCreate中调用`XChatKit.init()`
- 提前创建FlutterEngine并缓存

### 7.2 弱引用防止内存泄漏
```java
private static WeakReference<Activity> currentActivityRef;
```

### 7.3 线程安全
- 主线程UI操作通过Handler分发
- 监听器线程安全: `CopyOnWriteArrayList`

### 7.4 性能埋点
```java
FlutterUiDisplayListener uiListener = new FlutterUiDisplayListener() {
    void onFlutterUiDisplayed() {
        // 首帧渲染时间统计
    }
};
```

## 8. 集成方式

### 8.1 AAR集成 (推荐)
```
宿主App
    ├── xchat-sdk-release.aar  (Native SDK)
    └── flutter_module-release.aar (Flutter业务)
```

### 8.2 依赖关系
```
宿主App
    ↓ implementation
xchat-sdk (Native)
    ↓ (FlutterEngine)
flutter_module (Flutter)
```

## 9. 扩展能力

### 9.1 房间模式扩展
新增策略类实现`RoomModeStrategy`接口即可支持新模式

### 9.2 传输层扩展
实现`TransportInterface`接口支持新的传输协议

### 9.3 SDP处理扩展
新增Handler实现对应的SDP处理逻辑

---

**文档版本**: 1.0  
**最后更新**: 2026-03-09
