# MyAppForAIDL 启动 rtc_apk_app 完整流程走读

本文档详细记录从宿主 App (MyAppForAIDL) 点击"开始会议"按钮,到 rtc_apk_app 会议页面显示的完整调用链路。

## 流程概览

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                        MyAppForAIDL (宿主 App)                              │
│  ┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐│
│  │   MainActivity    │───▶│ RtcHostController │───▶│RscRtcBridgeClient │─▶│
│  │ (点击开始会议按钮) │    │ (会议控制)        │    │                  │  │            │
│  └───────────────────┘    └───────────────────┘    └───────────────────┘│
│           │                                                            │
│           ▼                                                            │
│  ┌───────────────────┐    ┌───────────────────┐                       │
│  │ FloatingService   │    │ RscRtcBridge      │◀─────────────────────│
│  │ (浮窗服务)       │    │ (会议状态管理)    │                       │
│  └───────────────────┘    └───────────────────┘                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ 启动 RTC APK (RtcRequestLauncher)
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              rtc_apk_app                                    │
│  ┌───────────────────┐    ┌───────────────────┐                             │
│  │  RtcEntryActivity │───▶│   RtcService      │                             │
│  │ (入口Activity)   │    │   (RTC核心服务)    │                             │
│  └───────────────────┘    └───────────────────┘                             │
└────────────────────────────────────────────────────────────────────���────┘
                                    │
                                    ▼ 绑定 Service → MyApplicationForFlutter
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                    MyApplicationForFlutter (XChatKit SDK)                       │
│  ┌───────────────────┐    ┌───────────────────┐                             │
│  │ FlutterDemoActivity│───▶│ SDLActivityAdapter│                             │
│  │ (Flutter容器)     │    │ (Flutter引擎管理)  │                             │
│  └───────────────────┘    └───────────────────┘                             │
│           │                              │                                      │
│           ▼                              ▼ (ExecuteDartEntrypoint)               │
│  ┌───────────────────┐                                                       │
│  │   Dart main()     │───▶ Flutter Module (flutter_module)                  │
│  └───────────────────┘                                                       │
└─────────────────────────────────────────────────────────────────────────┘
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     MyAppForAIDL (宿主 App)                             │
│  ┌─────────────────────┐    ┌─────────────────────┐                   │
│  │   MainActivity     │───▶│  RscRtcBridge       │                   │
│  │ (点击开始会议按钮) │    │ (会议状态管理)     │                   │
│  └─────────────────────┘    └─────────────────────┘                   │
│           │                         │                                    │
│           ▼                         ▼ (createConferenceIntent)        │
│  ┌─────────────────────┐    ┌─────────────────────┐                   │
│  │ RtcRequestLauncher │───▶│  RtcServiceConnector│                   │
│  │ (启动RTC APK)     │    │ (绑定RTC Service)   │                   │
│  └─────────────────────┘    └─────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼ 启动 RTC APK
┌─────────────────────────────────────────────────────────────────────────────┐
│                     rtc_apk_app (RTC 服务)                             │
│  ┌─────────────────────┐    ┌─────────────────────┐                   │
│  │  RtcEntryActivity │───▶│  RtcService        │                   │
│  │ (入口Activity)   │    │ (RTC核心服务)       │                   │
│  └─────────────────────┘    └─────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼ 绑定 Service
┌─────────────────────────────────────────────────────────────────────────────┐
│                  MyApplicationForFlutter (XChatKit SDK)                  │
│  ┌─────────────────────┐    ┌─────────────────────┐                   │
│  │ FlutterDemoActivity│─���─▶│ SDLActivityAdapter │                   │
│  │ (Flutter容器)     │    │ (Flutter引擎管理)  │                   │
│  └─────────────────────┘    └─────────────────────┘                   │
│           │                         │                                    │
│           ▼                         ▼ (ExecuteDartEntrypoint)           │
│  ┌─────────────────────┐                                               │
│  │   Dart main()       │───▶ Flutter Module (flutter_module)          │
│  └─────────────────────┘                                               │
└─────────────────────────────────────────────────────────────────────┘
```

## 详细流程

### 第一阶段：MyAppForAIDL 启动会议请求

#### 1.1 MainActivity 用户交互

**文件**: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/MainActivity.java`

```java
// 第 224 行
@Override
public void onStartConference() {
    checkPermissionAndStart();
}
```

#### 1.2 权限检查与会议启动

```java
// 第 262-274 行
private void checkPermissionAndStart() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        if (!Settings.canDrawOverlays(this)) {
            // 请求悬浮窗权限
            Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, ...);
            startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION);
        } else {
            startConferenceWithFloating();
        }
    } else {
        startConferenceWithFloating();
    }
}
```

#### 1.3 构建会议参数并启动

**文件**: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/MainActivity.java`

```java
// 第 184-199 行
private void startConferenceWithFloating() {
    RtcCommandResult result;
    // 1. 根据是否有代理调用不同的 startConference
    if (proxyIp == null || proxyPort == 0) {
        result = rtcHostController.startConference(this);
    } else {
        result = rtcHostController.startConference(this, proxyIp, proxyPort);
    }
    
    // 2. 检查启动结果
    if (!result.isAccepted()) {
        Toast.makeText(this, "启动失败: " + result.getErrorCode(), Toast.LENGTH_SHORT).show();
        return;
    }
    
    // 3. 启动浮窗服务
    startService(new Intent(this, FloatingService.class));
}
```

#### 1.4 RtcHostController 启动会议

**文件**: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/rtc/RtcHostController.java`

```java
// 第 100-123 行 (无代理)
public RtcCommandResult startConference(Context context) {
    appendLog("启动会议 requested");
    
    // 1. 初始化 SDK
    RtcCommandResult initResult = bridgeClient.initialize(
            context,
            new RtcInitOptions(0, null, null, 0, null));  // environment=0
    if (!initResult.isAccepted()) {
        appendLog("启动会议 callback rejected errorCode=" + initResult.getErrorCode());
        return initResult;
    }
    
    // 2. 获取 RoomOptions 并进入房间
    RtcRoomOptions roomOptions = roomOptionsFactory.create();
    RtcCommandResult enterResult = bridgeClient.enterRoom(context, roomOptions);
    
    // 3. 更新状态
    if (enterResult.isAccepted()) {
        conferenceRequested = true;
        conferenceOpened = false;
        // ... 重置其他状态标志
        appendLog("启动会议 callback accepted requestId=" + enterResult.getRequestId());
    }
    return enterResult;
}

// 第 125-149 行 (带代理)
public RtcCommandResult startConference(Context context, String proxyIp, int proxyPort) {
    appendLog("启动会议 requested");
    
    // 1. 初始化 SDK (带代理配置)
    RtcCommandResult initResult = bridgeClient.initialize(
            context,
            new RtcInitOptions(1, null, proxyIp, proxyPort, null));  // environment=1 (debug)
    if (!initResult.isAccepted()) {
        appendLog("启动会议 callback rejected errorCode=" + initResult.getErrorCode());
        return initResult;
    }
    
    // 2. 获取 RoomOptions 并进入房间
    RtcRoomOptions roomOptions = roomOptionsFactory.create();
    RtcCommandResult enterResult = bridgeClient.enterRoom(context, roomOptions);
    
    if (enterResult.isAccepted()) {
        conferenceRequested = true;
        conferenceOpened = false;
        // ... 重置其他状态标志
        appendLog("启动会议 callback accepted requestId=" + enterResult.getRequestId());
    }
    return enterResult;
}
```

#### 1.5 RscRtcBridgeClient 代理调用

**文件**: `MyAppForAIDL/app/src/main/java/com/yc/rtc/myappforaidl/rtc/RscRtcBridgeClient.java`

```java
// 第 21-23 行
@Override
public RtcCommandResult initialize(Context context, RtcInitOptions options) {
    return bridge.initialize(context, options);
}

// 第 30-33 行
@Override
public RtcCommandResult enterRoom(Context context, RtcRoomOptions options) {
    return bridge.enterRoom(context, options);
}
```

### 第二阶段：RscRtcBridge 初始化与状态管理

**文件**: `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/RscRtcBridge.java`

#### 2.1 initialize 初始化 SDK

```java
// 第 117-136 行
public RtcCommandResult initialize(Context context, RtcInitOptions options) {
    if (context == null) {
        RtcCommandResult result = errorResult(null, "context_required");
        notifyConferenceFailed(buildCommandError(...));
        return result;
    }
    latestInitOptions = options;
    Log.i(TAG, "initialize: bind start, currentState=" + connector.getState());
    
    // 1. 绑定 RTC Service
    connector.bind(context.getApplicationContext());
    
    // 2. 检查连接状态
    if (!connector.isConnected()) {
        pendingInitOptions = options;
        Log.i(TAG, "initialize: deferred until connected");
        return new RtcCommandResult(true, null, null, null);
    }
    
    // 3. 已连接，直接调用远程初始化
    Log.i(TAG, "initialize: connected, invoke remote initialize");
    return connector.initialize(options);
}
```

#### 2.2 enterRoom 处理

```java
// 第 138-177 行
public RtcCommandResult enterRoom(Context context, RtcRoomOptions options) {
    if (context == null) {
        // 返回错误结果
        return errorResult(null, "context_required");
    }
    Log.i(TAG, "enterRoom: launch request, state=" + connector.getState());
    
    // 1. 合并最新环境配置
    RtcRoomOptions launchOptions = optionsWithLatestEnvironment(options);
    
    // 2. 通过 RtcRequestLauncher 启动 RTC APK Activity
    RtcCommandResult launchResult = requestLauncher.launch(context, launchOptions);
    if (!launchResult.isAccepted()) {
        notifyConferenceFailed(buildCommandError(...));
        return launchResult;
    }
    
    // 3. 更新会议状态
    conferenceLaunchAccepted = true;
    conferenceOpened = false;
    lastConferenceFailureKey = null;
    
    // 4. 确保命令通道就绪
    connector.ensureCommandChannelAfterActivityLaunch(context.getApplicationContext());
    
    // 5. 更新 roomSnapshot 并通知
    String requestId = launchResult.getRequestId();
    roomSnapshot = new RscRtcRoomSnapshot(
            connector.getState(),
            "opening",  // roomState = opening
            null, null, null,
            false, true,  // isRoomPageShowing = true
            null,
            launchOptions.getArguments());
    notifyRoomOpening(requestId);
    notifyRoomSnapshotChanged();
    
    return launchResult;
}
```

#### 2.3 handleConferenceState 状态处理

```java
// 第 429-458 行
private void handleConferenceState(RscRtcRoomSnapshot snapshot) {
    String roomState = snapshot.getRoomState();
    
    if ("active".equals(roomState)) {
        // 会议活跃状态
        if (!conferenceOpened) {
            conferenceOpened = true;
            conferenceLaunchAccepted = true;
            notifyConferenceOpened();
        }
        return;
    }
    
    if ("failed".equals(roomState)) {
        notifyConferenceFailed(buildSnapshotError(snapshot));
        return;
    }
    
    if ("idle".equals(roomState) && isLeaveRoomDoneSnapshot(snapshot)) {
        // 离开房间完成
        if (conferenceOpened) {
            conferenceOpened = false;
            notifyConferenceClosed();
        } else if (conferenceLaunchAccepted) {
            conferenceLaunchAccepted = false;
            notifyConferenceClosed();
        }
    }
}
```

### 第三阶段：RtcRequestLauncher 启动 RTC APK

**文件**: `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/internal/RtcRequestLauncher.java`

#### 3.1 launch 启动 RTC APK

```java
// 第 40-72 行
public RtcCommandResult launch(Context context, RtcRoomOptions options) {
    String requestId = UUID.randomUUID().toString();
    
    // 构建启动 Intent
    Intent intent = buildEntryIntent(requestId, options);
    intent.setClassName(RTC_PACKAGE, RTC_ENTRY_ACTIVITY);
    // RTC_PACKAGE = "com.example.rtc_apk_app"
    // RTC_ENTRY_ACTIVITY = "com.example.rtc_apk_app.RtcEntryActivity"
    
    // 启动 RTC APK 的 EntryActivity
    activityStarter.startActivity(context, intent);
    
    return new RtcCommandResult(true, requestId, null, null);
}
```

### 第四阶段：rtc_apk_app 接收启动请求

**文件**: `rtc_apk_app/.../RtcEntryActivity.java`

#### 4.1 RtcEntryActivity

```java
// rtc_apk_app 中的入口 Activity
public class RtcEntryActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // 1. 获取启动参数
        RtcRoomOptions options = getIntent().getParcelableExtra(
                RtcRequestLauncher.EXTRA_ROOM_OPTIONS);
        
        // 2. 通过 AIDL 调用 RscRtcBridge
        RtcCommandResult result = rscBridge.enterRoom(context, options);
        
        // 3. 启动 FlutterDemoActivity (通过 XChatKit)
        // 注意：这里会跳转到 MyApplicationForFlutter 中的 FlutterDemoActivity
    }
}
```

### 第五阶段：MyApplicationForFlutter XChatKit SDK

#### 5.1 XChatKit.startConference

**文件**: `MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/XChatKit.java`

```java
// 第 231-257 行
public static void startConference(@NonNull Activity activity, ConferenceOptions options) {
    // 构建 FlutterDemoActivity 的 Intent
    Intent intent = new Intent(activity, FlutterDemoActivity.class);
    intent.putExtra("route", options.getRoute());
    
    // 传递业务参数
    Map<String, Object> args = options.getArguments();
    if (args != null && !args.isEmpty()) {
        Bundle argsBundle = new Bundle();
        argsBundle.putSerializable("arguments", (Serializable) args);
        intent.putExtra("arguments_bundle", argsBundle);
    }
    
    activity.startActivity(intent);
}
```

#### 5.2 FlutterDemoActivity 处理

**文件**: `MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/FlutterDemoActivity.java`

```java
// 第 49-58 行
@Override
protected void onCreate(Bundle savedInstanceState) {
    // 1. 确保引擎已初始化
    SDLActivityAdapter.InitXChatKit(this, false);
    
    super.onCreate(savedInstanceState);
    
    // 2. 解析 Intent 参数
    handleIntent(getIntent());
}

// 第 81-150 行
private void handleIntent(Intent intent) {
    String route = intent.getStringExtra("route");  // "/room"
    
    // 1. 处理 userData (从 arguments 解析)
    // 2. 执行数据初始化 (合并 assets 配置)
    initXchatData();
    
    // 3. 执行跳转 (通知 Flutter)
    pendingRoute = route;
    pendingArguments = SDLActivityAdapter.getCachedXChatData();
    tryPerformNavigation("handleIntent");
}

// 第 171-232 行
private void initXchatData() {
    // 1. 构建 mediaInfo 对象 (从 assets 配置读取)
    // 2. 构建 userData 对象
    // 3. 构建最终嵌套 JSON
    //    {
    //      "mediaInfo": {...},
    //      "userData": {...}
    //    }
    SDLActivityAdapter.CacheXChatData(finalPayload);
}

// 第 152-169 行
private void tryPerformNavigation(String source) {
    // 通过 SDLActivityAdapter 执行 Flutter 导航
    SDLActivityAdapter.PerformNavigation(route, payload);
}
```

#### 5.3 SDLActivityAdapter 导航处理

**文件**: `MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/SDLActivityAdapter.java`

```java
// 第 351-379 行
public static void PerformNavigation(String route, String arguments) {
    // 检查引擎是否就绪
    if (isEngineReady) {
        // 执行 Flutter 导航
        performFlutterNavigation(route, arguments);
    } else {
        // 缓存导航请求，等引擎就绪后执行
        pendingNavigation = new HashMap<>();
        pendingNavigation.put("route", route);
        pendingNavigation.put("arguments", arguments);
    }
}

private static void performFlutterNavigation(String route, String arguments) {
    // 通过 MethodChannel 调用 Flutter
    Map<String, Object> params = new HashMap<>();
    params.put("route", route);
    params.put("arguments", arguments);
    methodChannel.invokeMethod("navigatorPush", params);
}
```

### 第六阶段：Flutter Module 接收导航请求

#### 6.1 XChatMethodChannel 处理 navigatorPush

**文件**: `flutter_module/lib/features/xchatkit_adapter/channels/xchat_method_channel.dart`

```dart
// 第 41-68 行
case 'navigatorPush':
    final args = call.arguments;
    String route = args['route'] as String? ?? '/';
    Map<String, dynamic>? routeArgs;
    
    // 解析 arguments JSON
    if (args['arguments'] is String) {
        routeArgs = jsonDecode(args['arguments']) as Map<String, dynamic>;
    }
    
    // 调用 main.dart 的 _handleNativePush
    _onNavigatorPush!(route, routeArgs);
    return null;
```

#### 6.2 main.dart 导航处理

**文件**: `flutter_module/lib/main.dart`

```dart
// 第 54-67 行
void _handleNativePush(String route, Map<String, dynamic>? arguments) {
    loggerManager.info('main', 'Native push: $route');
    if (navigatorKey.currentState != null) {
        _pushNamedFromNative(route, arguments);
        return;
    }
    
    // 缓存导航请求
    _pendingNavigation = _PendingNavigation(route, arguments);
    loggerManager.warning('main', 'Navigation not ready, cache route: $route');
    _schedulePendingNavigationFlush();
}

// 第 107-129 行
void _pushNamedFromNative(String route, Map<String, dynamic>? arguments) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = navigatorKey.currentState;
        if (nav == null) {
            // 重新缓存
            _pendingNavigation = _PendingNavigation(route, arguments);
            _schedulePendingNavigationFlush();
            return;
        }
        
        // 执行页面跳转
        if (route == Welcome.RoutePath) {
            nav.pushNamedAndRemoveUntil(route, (route) => false, 
                    arguments: arguments);
        } else {
            nav.pushNamed(route, arguments: arguments);
        }
    });
}
```

### 第七阶段：Room 页面构建与房间连接

#### 7.1 Room 页面路由生成

**文件**: `flutter_module/lib/main.dart`

```dart
// 第 393-437 行
onGenerateRoute: (settings) {
    if (settings.name == Room.RoutePath) {
        // 创建 RoomBlocContainerV2 和 RoomBlocV2
        final providers = getRoomModules(settings: settings, 
                config: effectiveConfig);
        
        return PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MultiBlocProvider(
                    providers: providers,
                    child: Builder(
                        builder: (context) {
                            // Native 模式下初始化后台任务
                            if (widget.isNativeMode) {
                                _ensureNativeRuntimeInitAfterRoomLaunch();
                            }
                            
                            // 获取 RoomClientEntranceV2 单例并加入房间
                            return RepositoryProvider<RoomClientEntranceV2>.value(
                                value: sl<RoomClientEntranceV2>()..join(),
                                child: const Room(),
                            );
                        },
                    ),
                ),
        );
    }
}
```

#### 7.2 RoomClientEntranceV2.join() 房间加入流程

**文件**: `flutter_module/lib/features/signaling/room_client_entrance_v2.dart`

```dart
// 第 542-878 行
Future<void> join() async {
    if (_closed || _isJoining || isConnected || isJoined) {
        return;
    }
    _isJoining = true;
    
    try {
        // 1. UDP 连通性检测
        _setEstablishPhase(RoomEstablishPhase.networkCheck);
        
        // 2. 双中心探测
        _setEstablishPhase(RoomEstablishPhase.dualCenterProbe);
        final probeResult = await CenterProbeService.probe(...);
        
        // 3. 设备检查
        _setEstablishPhase(RoomEstablishPhase.deviceCheck);
        final deviceCheckFailure = await _resolveDeviceCheckFailureIfNeeded();
        
        // 4. WebSocket 连接
        _setEstablishPhase(RoomEstablishPhase.connecting);
        _webSocket = await _createClientInstance(clientSettings, ...);
        
        // 5. 创建房间和 WebRTC 会话
        await _webSocket?.createRoom(roomId, ...);
        await _createSession();
        
        // 6. 初始化能力
        await _initializeCapabilitiesForCurrentState();
        
        // 7. 标记为已建立
        _markEstablished();
        
        // 8. 发送 EnterRoomDone 事件到 Android
        safeEmit('EnterRoomDone', {...});
    }
}
```

#### 7.3 safeEmit 事件发送 (Native 模式)

```dart
// 第 382-415 行
@override
void safeEmit(String event, [Map<String, dynamic>? args]) {
    // 检查是否通过 XChatKit 启动 (Native 模式)
    if (XChatKitAdapter.isNativeMode) {
        String message = jsonEncode(args);
        
        // 通过 XChatEventChannel 发送到 Android
        XChatEventChannel.sendEvent(event, message);
    }
}
```

#### 7.4 XChatEventChannel 事件发送

**文件**: `flutter_module/lib/features/xchatkit_adapter/channels/xchat_event_channel.dart`

```dart
// 第 24-41 行
static Future<void> sendEvent(String event, String message) async {
    // 添加到队列
    _eventQueue.add({
        'event': event,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // 处理队列
    _processEventQueue();
}

// 通过 MethodChannel 'onEvent' 调用到 Android
await _methodChannel.invokeMethod('onEvent', {
    'event': event,
    'message': message,
    'timestamp': event['timestamp']
});
```

### 第八阶段：Android 接收事件回调

#### 8.1 SDLActivityAdapter 处理 onEvent

**文件**: `MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/SDLActivityAdapter.java`

```java
// 第 325-330 行
case "onEvent":
    Map<String, Object> args = (Map<String, Object>) call.arguments;
    onEvent((String) args.get("event"), 
            (String) args.get("message"), 
            String.valueOf(args.getOrDefault("timestamp", 0L)));
    result.success(null);
    break;
```

#### 8.2 onEvent 事件分发

```java
// 第 405-415 行
public static void onEvent(String event, String message, String time) {
    if (callEventListener != null) {
        callEventListener.onMessage(event, message, time);
    }
}
```

#### 8.3 XChatKit 事件监听

**文件**: `MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/XChatKit.java`

```java
// 第 349-373 行
private static void ensureAdapterListener() {
    SDLActivityAdapter.SetCallEventListener(new CallEventListener() {
        @Override
        public void onMessage(String msgtype, String message, String time) {
            // 分发到所有注册的监听器
            for (XChatEventListener l : listeners) {
                mainHandler.post(() -> l.onMessage(msgtype, message, time));
            }
        }
    });
}
```

## 关键节点时序图

```
时间线          MyAppForAIDL                    rtc_apk_app           MyApplicationForFlutter        Flutter Module
   │                                                                          
   ├───点击"开始会议"──▶                                                                 
   │                  RscRtcBridge.enterRoom()                                  
   │                         │                                                    
   ├───launch()───────▶ RtcRequestLauncher.buildEntryIntent()                    
   │                         │                                                    
   │                    startActivity(RtcEntryActivity)                        
   │                         │                                                    
   ├───onCreate()─────▶ RtcEntryActivity.onCreate()                          
   │                         │                                                    
   │                    rscBridge.enterRoom() (AIDL)                         
   │                         │                                                    
   │                    startActivity(FlutterDemoActivity)                  
   │                         │                                                    
   ├───onCreate()─────▶ FlutterDemoActivity.onCreate()                       
   │                         │                                                    
   │                    handleIntent()                                        
   │                         │                                                    
   │                    SDLActivityAdapter.PerformNavigation()                   
   │                         │                                                    
   │                    methodChannel.invokeMethod("navigatorPush")              
   │                         ├───────────────────────────────▶ XChatMethodChannel._handleMethodCall()
   │                         │                                        │          
   │                         │                              _handleNativePush("/room", args)
   │                         │                                        │          
   │                         │                       _pushNamedFromNative("/room", arguments)
   │                         │                                        │          
   │                         │                       Navigator.pushNamed("/room")
   │                         │                                        │          
   │                         │                              RoomPage.build()                       
   │                         │                                        │          
   │                         │                       RoomClientEntranceV2.join()         
   │                         │                                        │          
   │                         │                       WebSocket.connect()              
   │                         │                                        │          
   │                         │                       socket.on("connected")              
   │                         │                                        │          
   │                         │                       _handleConnectedRebuildFlow()    
   │                         │                                        │          
   │                         │                       _markEstablished()              
   │                         │                                        │          
   │                         │                       safeEmit("EnterRoomDone", {...})          
   │                         │                                        │          
   │                         │                       XChatEventChannel.sendEvent()          
   │                         │                                        │          
   │                         │                 methodChannel.invokeMethod("onEvent")
   │◀──────────────────────────────────────────────────────────────────┤          
   │                  SDLActivityAdapter.onEvent()                       │          
   │                         │                                                    
   │                    XChatKit.onMessage("EnterRoomDone", ...)           
   │                         │                                                    
   │                    MainActivity.onMessage(...)                       
   │                         │                                                    
   │                  显示"会议建立成功" UI ✅                         
   ���                                                                          
```

## 核心参数传递路径

```
ConferenceOptions (MainActivity)
         │
         ▼
    RtcRoomOptions
         │
         ▼
    Intent (EXTRA_ROOM_OPTIONS)
         │
         ▼
    RtcEntryActivity
         │
         ▼
    XChatKit.startConference()
         │
         ▼
    FlutterDemoActivity.handleIntent()
         │
         ├─── route ──────────────────▶ "/room" 路由
         │
         ▼
    SDLActivityAdapter.CacheXChatData()
         │
         ▼
    pendingArguments (JSON payload)
         │
         ▼
    Flutter: navigatorPush arguments
         │
         ▼
    main.dart _handleNativePush()
         │
         ▼
    RoomRoute /room 页面构建
```

## 关键数据 Payload 结构

```json
{
  "mediaInfo": {
    "mediaEntranceUrl": "wss://center.example.com/media-entrance/websocket",
    "mgwUrl": "wss://center.example.com/mgw",
    "picUrl": "https://center.example.com/pic",
    "logUrl": "/log",
    "roomMode": "video",
    "roomId": "xxx",
    "peerType": "1",
    "aCenter": "center-a.example.com",
    "bCenter": "center-b.example.com",
    "probe": "/probe",
    "iceServers": [...],
    "proxyIp": "172.20.10.7",
    "proxyPort": "8888",
    "peerId": "862175051124177"
  },
  "userData": {
    "fromuser": "862175051124177",
    "brhName": "中国邮政储蓄银行股份有限公司银川市金凤区支行",
    "unionId": "64000652",
    "clientInfo": {
      "tellerCode": "20080612010",
      "tellerName": "小甜甜",
      "tellerBranch": "11009021"
    },
    "deviceInfo": {
      "imei": "862175051124177",
      "brand": "HUAWEI",
      "model": "BZT3-AL00"
    }
  }
}
```

## 事件类型列表

| 事件名 | 方向 | 说明 |
|-------|------|------|
| `EnterRoomDone` | Flutter → Android | 房间建立成功 |
| `LeaveRoomDone` | Flutter → Android | 离开房间完成 |
| `RoomLifecycleStateChanged` | Flutter → Android | 房间生命周期状态变化 |
| `EnableWebcamAndUploadDone` | Flutter → Android | 摄像头开启并上传完成 |
| `DisableWebcamAndUploadDone` | Flutter → Android | 摄像头关闭 |
| `ConnectionErrorOccur` | Flutter → Android | 连接错误 |
| `PROBE_CENTER_FAILED` | Flutter → Android | 双中心探测失败 |
| `DEVICE_CHECK_FAILED` | Flutter → Android | 设备检查失败 |

## AIDL 与 Flutter 通信完整流程

### 通信架构总览

```
┌────────────────────────────────────────────────────────────────────────┐
│                        通信层次架构                                     │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 1: AIDL 通信层                                                   │
│ ┌──────────────┐         ┌──────────────┐                             │
│ │ MyAppForAIDL │◀───────▶│   rtc-aidl   │                             │
│ │(RscRtcBridge)│  AIDL   │(RscRtcBridge)│                             │
│ └──────────────┘         └──────────────┘                             │
│        │                          │                                      │
│        │                   AIDL │                                      │
│        ▼                          ▼                                      │
│ ┌──────────────┐         ┌──────────────┐                              │
│ │RtcServiceConn│◀───────▶│  rtc_apk_app │                              │
│ │   ector      │  AIDL   │(RtcBridgeSvc)│                              │
│ └──────────────┘         └──────────────┘                              │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 2: MethodChannel 通信层                                          │
│ ┌──────────────┐         ┌──────────────┐                              │
│ │flutter_module│◀───────▶│  rtc_apk_app  │                             │
│ │(XChatMethodCh)│MethodCh │(RtcXChatKitBr)│                             │
│ └──────────────┘         └──────────────┘                              │
│        │                          │                                      │
│        │                   MethodChannel │                               │
│        ▼                          ▼                                      │
│ ┌──────────────┐         ┌──────────────┐                              │
│ │XChatEventCh  │────────▶│RtcXChatKitBr │                              │
│ │(Flutter→Andr)│MethodCh│ (onEvent)    │                              │
│ └──────────────┘         └──────────────┘                              │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 3: 事件回调层                                                   │
│ ┌──────────────┐         ┌──────────────┐                             │
│ │Flutter业务层 │         │ MyAppForAIDL  │                             │
│ │RoomClientEntV2│───────▶│(RscRtcBridgeCb)│                            │
│ └──────────────┘         └──────────────┘                             │
└────────────────────────────────────────────────────────────────────────┘
```

### AIDL 接口定义

#### IRscRtcBridgeService.aidl

**文件**: `MyAppForAIDL/rtc-aidl/src/main/aidl/com/yc/rtc/bridge/IRscRtcBridgeService.aidl`

```aidl
interface IRscRtcBridgeService {
    RtcCommandResult initialize(in RtcInitOptions options);
    RtcCommandResult cacheEnterRoomRequest(in RtcRoomOptions options);
    RtcCommandResult leaveRoom(in RtcLeaveOptions options);
    RtcCommandResult sendMessage(in RtcMessage message);
    RtcCommandResult setBusinessCaptureMode(in RtcCaptureOptions options);
    RscRtcRoomSnapshot getRoomSnapshot();
    String getServiceState();
    String getSdkVersion();
    String getProtocolVersion();
    Bundle getCapabilities();
    void destroy();
    void registerCallback(IRscRtcBridgeCallback callback);
    void unregisterCallback(IRscRtcBridgeCallback callback);
}
```

#### IRscRtcBridgeCallback.aidl

**文件**: `MyAppForAIDL/rtc-aidl/src/main/aidl/com/yc/rtc/bridge/IRscRtcBridgeCallback.aidl`

```aidl
interface IRscRtcBridgeCallback {
    void onServiceStateChanged(String serviceState);
    void onRoomOpening(String requestId);
    void onRoomSnapshotChanged(in RscRtcRoomSnapshot snapshot);
    void onMessageReceived(in RtcMessage message);
    void onBusinessCaptureResult(in RtcCaptureResult result);
    void onError(in RtcError error);
    void onConferenceOpened();
    void onConferenceClosed();
    void onConferenceFailed(in RtcError error);
}
```

### AIDL 通信流程

#### 1. 初始化流程

```
RtcHostController.startConference()
    ↓
bridgeClient.initialize(context, RtcInitOptions)
    ↓
RscRtcBridge.initialize(context, options)
    ↓
RtcServiceConnector.bind(context)
    ↓ 绑定 rtc_apk_app 的 RtcBridgeService
RtcBridgeService.onBind()
    ↓
IRscRtcBridgeService.Stub.initialize()
    ↓
RtcBridgeService.initialize() 返回成功
    ↓
AIDL 返回 RtcCommandResult(true)
```

#### 2. 进入房间流程

```
RtcHostController.startConference()
    ↓
bridgeClient.enterRoom(context, roomOptions)
    ↓
RscRtcBridge.enterRoom(context, options)
    ↓
RtcRequestLauncher.launch() → startActivity(RtcEntryActivity)
    ↓
cacheEnterRoomRequest() 缓存请求到 PendingRoomRequestStore
    ↓
返回 RtcCommandResult(true, requestId)
    ↓
onRoomOpening() 通知 MyAppForAIDL
```

### MethodChannel 通信

#### Flutter → Android: XChatMethodChannel

**文件**: `flutter_module/lib/features/xchatkit_adapter/channels/xchat_method_channel.dart`

```dart
static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
        case 'navigatorPush':
            // route: "/room", arguments: JSON字符串
            _onNavigatorPush!(route, routeArgs);
            return null;

        case 'setNativeMode':
            XChatKitAdapter.forceNativeMode();
            return null;

        case 'requestExit':
            await XChatKitAdapter.onExitRequest!();
            return null;

        case 'businessPhotoForGroup':
            XChatKitAdapter.onBusinessPhotoForGroup!(...);
            return null;

        case 'businessPhotoForSingle':
            XChatKitAdapter.onBusinessPhotoForSingle!(...);
            return null;

        case 'closeBusinessPhotoMode':
            return null;

        case 'sendMessage':
            await entrance.sendMessage(message);
            return null;
    }
}
```

#### Android → Flutter: RtcXChatKitBridge

**文件**: `rtc_apk_app/android/app/src/main/java/com/example/rtc_apk_app/RtcXChatKitBridge.java`

```java
private boolean handleFlutterCallbackInternal(String method, Object arguments) {
    if ("engineReady".equals(method)) {
        engineReady = true;
        flushPendingNavigation();
        return true;
    }

    if ("onBusinessPhotoTakeSuccess".equals(method)) {
        listener.onBusinessCaptureResult(new RtcCaptureResult(...));
        return true;
    }

    if ("onBusinessPhotoTakeFail".equals(method)) {
        listener.onBusinessCaptureResult(new RtcCaptureResult(...));
        return true;
    }

    if ("onEvent".equals(method)) {
        String eventName = stringValue(event.get("event"));

        if ("mediaStateChanged".equals(eventName)) {
            listener.onMediaStateChanged(...);
            return true;
        }

        if ("EnterRoomDone".equals(eventName) || "RetryConnectionDone".equals(eventName)) {
            listener.onEnterRoomDone(...);
            return true;
        }

        if ("LeaveRoomDone".equals(eventName)) {
            listener.onLeaveRoomDone(...);
            return true;
        }

        if ("ConnectionErrorOccur".equals(eventName)) {
            listener.onConnectionError(...);
            return true;
        }

        return true;
    }

    return false;
}
```

### Flutter → Android 事件发送

**文件**: `flutter_module/lib/features/xchatkit_adapter/channels/xchat_event_channel.dart`

```dart
static Future<void> sendEvent(String event, String message) async {
    _eventQueue.add({
        'event': event,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    if (_isProcessing) return;
    _processEventQueue();
}

static Future<void> _processEventQueue() async {
    _isProcessing = true;
    try {
        while (_eventQueue.isNotEmpty) {
            Map<String, dynamic> event = _eventQueue.removeFirst();
            await _methodChannel.invokeMethod('onEvent', {
                'event': event['event'],
                'message': event['message'],
                'timestamp': event['timestamp']
            });
        }
    } finally {
        _isProcessing = false;
    }
}
```

### 事件类型完整列表

| 事件名 | 方向 | 说明 |
|--------|------|------|
| `EnterRoomDone` | Flutter → Android | 房间建立成功 |
| `RetryConnectionDone` | Flutter → Android | 重连成功 |
| `LeaveRoomDone` | Flutter → Android | 离开房间完成 |
| `ConnectionErrorOccur` | Flutter → Android | 连接错误 |
| `RoomLifecycleStateChanged` | Flutter → Android | 房间状态变化 |
| `EnableWebcamAndUploadDone` | Flutter → Android | 摄像头开启完成 |
| `DisableWebcamAndUploadDone` | Flutter → Android | 摄像头关闭完成 |
| `mediaStateChanged` | Flutter → Android | 媒体状态变化 |
| `PROBE_CENTER_FAILED` | Flutter → Android | 双中心探测失败 |
| `DEVICE_CHECK_FAILED` | Flutter → Android | 设备检查失败 |

### MethodChannel 方法列表

| 方法名 | 方向 | 说明 |
|--------|------|------|
| `engineReady` | Flutter → Android | Flutter 引擎就绪 |
| `navigatorPush` | Android → Flutter | 推送路由 |
| `setNativeMode` | Android → Flutter | 强制 Native 模式 |
| `requestExit` | Android → Flutter | 请求退出 |
| `businessPhotoForGroup` | Android → Flutter | 团体照模式 |
| `businessPhotoForSingle` | Android → Flutter | 单人照模式 |
| `closeBusinessPhotoMode` | Android → Flutter | 关闭业务拍照 |
| `sendMessage` | Android → Flutter | 发送消息 |
| `onEvent` | Flutter → Android | 发送 RTC 事件 |
| `onBusinessPhotoTakeSuccess` | Flutter → Android | 拍照成功 |
| `onBusinessPhotoTakeFail` | Flutter → Android | 拍照失败 |
| `onReceiveMessage` | Flutter → Android | 收到消息 |

### 错误码参考

| 错误码 | 说明 |
|--------|------|
| `context_required` | Context 为空 |
| `service_not_ready_please_retry` | Service 未就绪 |
| `room_options_required` | RoomOptions 为空 |
| `activity_launch_failed` | Activity 启动失败 |
| `cache_failed` | 缓存请求失败 |
| `flutter_not_ready` | Flutter 未就绪 |
| `unsupported_capture_mode` | 不支持的拍照模式 |
| `enter_room_request_expired` | 请求超时 |
| `media_store_save_failed` | 媒体存储失败 |

## 常见问题排查

### 会议卡住 ("运行中" 但 roomState=idle)

1. **Flutter UI 线程阻塞**: 检查 Choreographer 是否有大量 frame skipped
2. **导航路由未重放**: 检查 `_flushPendingNavigation` 是否成功执行
3. **浮窗状态问题**: 检查 `conferenceOpened` 和 `conferenceLaunchAccepted` 状态

### 事件未送达 Android

1. 检查 `XChatEventChannel.sendEvent()` 是否成功
2. 检查 Android 端 `callEventListener` 是否注册
3. 检查 `MissingPluginException`