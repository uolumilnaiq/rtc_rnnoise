# RTC-SDK 启动 Flutter Module 流程详解

本文档详细说明 Android RTC-SDK 启动 Flutter Module 的完整流程，包括 Method Channel 交互、数据流转，以及首次启动延迟的原因分析。

---

## 1. 整体架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Android 端 (RTC-SDK)                            │
├─────────────────────────────────────────────────────────────────────────┤
│  XChatKit.java           - SDK 入口，提供 init/startConference        │
│  SDLActivityAdapter.java  - Flutter 引擎管理、MethodChannel 设置        │
│  FlutterDemoActivity.java - Flutter 承载页面，解析启动参数              │
│  MainActivity.java        - 宿主 Activity，初始化 SDK                    │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ MethodChannel ("xchatkit")
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        Flutter 端                                       │
├─────────────────────────────────────────────────────────────────────────┤
│  main.dart               - Flutter 入口，初始化 XChatKitAdapter          │
│  XChatMethodChannel.dart - MethodChannel 处理器                         │
│  XChatKitAdapter.dart    - 适配层核心，管理回调                        │
│  RoomClientEntranceV2    - 房间客户端，处理业务逻辑                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 启动流程时序图

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         首次启动时序                                    │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  MainActivity.onCreate()                                                │
│       │                                                                  │
│       ▼                                                                  │
│  XChatKit.init(context)                                                 │
│       │                                                                  │
│       ├── 1. 创建 FlutterEngine                                         │
│       ├── 2. 缓存到 FlutterEngineCache                                  │
│       ├── 3. 执行 Dart Entrypoint (后台执行)                           │
│       ├── 4. setupMethodChannel()                                        │
│       └── 5. setupEventChannel()                                        │
│                                                                          │
│  [Flutter 后台初始化中...]                                              │
│                                                                          │
│  用户点击"启动会议"                                                      │
│       │                                                                  │
│       ▼                                                                  │
│  XChatKit.startConference(activity, options)                            │
│       │                                                                  │
│       ├── 1. 创建 Intent(FlutterDemoActivity)                          │
│       ├── 2. 传递 route 参数                                            │
│       └── 3. 传递 arguments (ConferenceOptions)                         │
│                                                                          │
│  FlutterDemoActivity.onCreate()                                          │
│       │                                                                  │
│       ├── 1. SDLActivityAdapter.InitXChatKit(this, false)              │
│       │     (FlutterEngine 已缓存，直接使用)                             │
│       ├── 2. handleIntent() 解析参数                                    │
│       │                                                                  │
│       ├── 3. initXchatData() 构建配置                                   │
│       │     ├── 从 assets 加载配置文件                                  │
│       │     ├── 合并 userData                                          │
│       │     └── 缓存到 SDLAdapter                                        │
│       │                                                                  │
│       └── 4. PerformNavigation(route, data) 导航到 Flutter              │
│                                                                          │
│  [Flutter 端]                                                           │
│                                                                          │
│  main.dart 入口                                                         │
│       │                                                                  │
│       ├── 1. XChatKitAdapter.init()                                    │
│       │     └── 注册 navigatorPush 回调                                │
│       │                                                                  │
│       ├── 2. runApp() 启动 Flutter                                      │
│       │                                                                  │
│       ├── 3. XChatKitAdapter.handshake()                               │
│       │     └── notifyEngineReady() 通知 Android 引擎已就绪            │
│       │                                                                  │
│       └── 4. 收到 navigatorPush 回调                                     │
│             ├── navigatorKey.currentState.pushNamed(route)             │
│             └── RoomClientEntranceV2.join()                          │
│                                                                          │
│  [进入房间流程]                                                          │
│                                                                          │
│  RoomClientEntranceV2.join()                                           │
│       │                                                                  │
│       ├── 1. 双中心探测 (可选)                                          │
│       ├── 2. UDP 连通性检测                                             │
│       ├── 3. 创建 WebSocket 连接                                        │
│       ├── 4. 创建/加入房间                                              │
│       └── 5. 建立 WebRTC 会话                                          │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Method Channel 交互

### 3.1 Channel 名称

统一使用 `"xchatkit"` 作为 MethodChannel 名称。

### 3.2 双向交互

```
┌─────────────────────┐                         ┌─────────────────────┐
│      Android         │                         │      Flutter         │
├─────────────────────┤                         ├─────────────────────┤
│                     │                         │                     │
│  MethodChannel      │◄─────────────────────►│  MethodChannel      │
│  ("xchatkit")       │   invokeMethod()       │  ("xchatkit")       │
│                     │                         │                     │
│                     │                         │                     │
│  EventChannel       │◄──────────────────────►│  EventChannel      │
│  ("xchatkit")       │   sendEvent()         │  ("xchatkit")       │
│                     │                         │                     │
└─────────────────────┘                         └─────────────────────┘
```

### 3.3 Flutter -> Android 方法调用

| 方法名 | 方向 | 说明 |
|--------|------|------|
| `engineReady` | Flutter → Android | Flutter 引擎就绪通知 |
| `navigatorPush` | Android → Flutter | 页面导航 |
| `requestExit` | Android → Flutter | 退出请求 |

### 3.4 Android -> Flutter 方法调用

| 方法名 | 方向 | 说明 |
|--------|------|------|
| `onEvent` | Android → Flutter | 事件推送 |
| `onReceiveMessage` | Android → Flutter | 消息接收 |
| `takePhoto` | Android → Flutter | 拍照请求 |
| `sendMessage` | Android → Flutter | 发送消息 |

---

## 4. 关键数据内容

### 4.1 启动参数 (ConferenceOptions)

```java
// Android 端构建
ConferenceOptions options = new ConferenceOptions.Builder()
    .setRoute("/room")                              // Flutter 路由
    .addArgument("fromuser", "user123")            // 用户ID
    .addArgument("brhName", "BranchName")          // 机构名称
    .addArgument("roomId", "room001")              // 房间ID
    .build();
```

### 4.2 传递给 Flutter 的数据 (XChatData)

```json
{
  "mediaInfo": {
    "mediaEntranceUrl": "wss://xxx/media-entrance/websocket",
    "mgwUrl": "wss://xxx/mgw",
    "roomMode": "single_pad",
    "roomId": "room001",
    "peerId": "user123",
    "aCenter": "20.198.100.91:18090",
    "bCenter": "20.198.100.92:18090",
    "probe": "/probe",
    "iceServers": [...]
  },
  "userData": {
    "fromuser": "user123",
    "brhName": "BranchName",
    "unionId": "xxx",
    "deviceId": "device001",
    "language": "zh_CN"
  }
}
```

### 4.3 数据来源

| 数据来源 | 说明 |
|----------|------|
| assets/config/*.json | 配置文件，包含 mediaInfo、iceServers |
| ConferenceOptions | 启动时传入，包含 userData 字段 |
| XChatKit.setUserData() | 预先缓存的用户数据 |

---

## 5. 关键函数说明

### 5.1 Android 端

| 文件 | 函数 | 作用 |
|------|------|------|
| XChatKit.java | `init(Context)` | 初始化 SDK，创建 FlutterEngine |
| XChatKit.java | `startConference(Activity, ConferenceOptions)` | 启动会议，跳转 Flutter 页面 |
| SDLActivityAdapter.java | `InitXChatKit(Context)` | 创建/获取 FlutterEngine，缓存 |
| SDLActivityAdapter.java | `PerformNavigation(route, data)` | 通知 Flutter 导航 |
| FlutterDemoActivity.java | `handleIntent()` | 解析 Intent 参数 |
| FlutterDemoActivity.java | `initXchatData()` | 构建并缓存配置数据 |

### 5.2 Flutter 端

| 文件 | 函数 | 作用 |
|------|------|------|
| main.dart | `main()` | Flutter 入口，初始化适配层 |
| XChatMethodChannel.dart | `setup()` | 设置 MethodChannel 处理器 |
| XChatMethodChannel.dart | `notifyEngineReady()` | 通知 Android 引擎就绪 |
| XChatKitAdapter.dart | `init()` | 初始化适配层，注册回调 |
| XChatKitAdapter.dart | `handshake()` | 握手，检测是否 Native 模式 |
| RoomClientEntranceV2.java | `join()` | 加入房间 |

---

## 6. 为什么第一次启动需要等待 3-5 秒？

### 6.1 原因分析

**首次启动 Flutter 需要做大量冷启动工作：**

1. **Flutter 引擎初始化** (~500ms-1s)
   - 加载 Flutter 运行时
   - 初始化 Dart VM
   - 创建 Isolate

2. **插件初始化** (~500ms-1s)
   - 所有 Flutter 插件的初始化逻辑
   - 包括 WebRTC、Camera、Audio 等

3. **Dart 代码 JIT/AOT 编译** (~1s)
   - 首次执行 Dart 代码需要编译
   - 特别是业务逻辑复杂的代码

4. **首次 UI 渲染** (~500ms-1s)
   - 构建 Widget 树
   - 布局和绘制

5. **资源加载** (~500ms-1s)
   - 字体加载
   - 图片资源
   - 配置文件解析

### 6.2 性能优化措施 (代码中已实现)

```java
// SDLActivityAdapter.java
// 1. 预热：在 Application 阶段就初始化 FlutterEngine
public static void init(@NonNull Context context) {
    // 创建 FlutterEngine 并缓存
    flutterEngine = new FlutterEngine(applicationContext);
    FlutterEngineCache.getInstance().put(FLUTTER_ENGINE_ID, flutterEngine);
    
    // 立即执行 Dart 入口点（后台执行）
    flutterEngine.getDartExecutor().executeDartEntrypoint(...);
}
```

```java
// 2. 性能埋点：监控首次渲染时间
private static long sStartTime = 0;
private final FlutterUiDisplayListener uiListener = new FlutterUiDisplayListener() {
    @Override
    public void onFlutterUiDisplayed() {
        long endTime = System.currentTimeMillis();
        Log.i(TAG, "[Perf] First Frame Rendered at: " + endTime);
        Log.i(TAG, "[Perf] Total Launch Time: " + (endTime - sStartTime) + " ms");
    }
};
```

### 6.3 后续启动

由于 FlutterEngine 被缓存，后续启动会快很多：

- **第二次启动**: ~1-2 秒 (Engine 已就绪)
- **后续启动**: ~500ms-1 秒 (只需渲染 UI)

### 6.4 进一步优化建议

1. **使用预编译的 AOT 代码** - 减少 JIT 编译时间
2. **减少首次加载的 Widget** - 使用懒加载
3. **优化插件初始化** - 延迟初始化非必要插件
4. **使用 Splitter A/B** - 减少首次包体积

---

## 7. 关闭流程

```
用户点击"停止会议"
       │
       ▼
XChatKit.stopConference()
       │
       ▼
MethodChannel: requestExit
       │
       ▼
Flutter: XChatMethodChannel._handleMethodCall('requestExit')
       │
       ├── 执行 XChatKitAdapter.onExitRequest 回调
       │     └── RoomClientEntranceV2.leave()
       │           ├── 清理业务能力 (disableRobot, disableMatchAgent...)
       │           ├── 清理媒体资源 (摄像头、麦克风、投屏)
       │           ├── 清理 WebSocket 连接
       │           └── 清理 WebRTC 会话
       │
       └── SystemNavigator.pop() 返回 Android
```
