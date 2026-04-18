# RscRtcBridge SDK API 参考文档（Android）

本文档基于以下源码整理（2026-04-14）：
- `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/RscRtcBridge.java`
- `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/aidl/RscRtcBridgeCallback.java`
- `MyAppForAIDL/rtc-aidl/src/main/java/com/yc/rtc/bridge/*.java`

## 1. SDK 概览

`RscRtcBridge` 是 Android 侧统一入口，提供：
- SDK 初始化与服务连接
- 会议启动/停止（通过 AIDL 与双 APK 架构）
- 多监听器事件分发（主线程回调）
- 消息发送与业务拍照能力
- 房间状态快照查询

### 架构说明

```
┌─────────────────┐     AIDL      ┌─────────────────┐
│  宿主 App       │  ────────────→│  RscRtcBridge  │
│  (MyAppForAIDL) │               │  (rtc-aidl)    │
└─────────────────┘               └────────┬────────┘
                                           │ bindService
                                           ▼
                                   ┌─────────────────┐
                                   │ RtcBridgeService│
                                   │ (rtc_apk_app)    │
                                   └────────┬────────┘
                                            │ MethodChannel
                                            ▼
                                    ┌─────────────────┐
                                    │   Flutter RTC   │
                                    │    Module       │
                                    └─────────────────┘
```

## 2. 快速接入

### 2.1 添加依赖

```gradle
// 在宿主 App 的 build.gradle 中
dependencies {
    implementation project(':rtc-aidl')
}
```

### 2.2 初始化与监听事件

```java
public class MainActivity extends AppCompatActivity {
    private RscRtcBridge bridge;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // 创建 Bridge 实例
        bridge = new RscRtcBridge();
        
        // 注册事件监听
        bridge.registerCallback(new RscRtcBridgeCallback() {
            @Override
            public void onServiceStateChanged(String serviceState) {
                Log.d("RTC", "服务状态: " + serviceState);
                // serviceState: "disconnected" | "connecting" | "connected"
            }

            @Override
            public void onRoomOpening(String requestId) {
                Log.d("RTC", "正在进入房间, requestId=" + requestId);
            }

            @Override
            public void onConferenceOpened() {
                Log.d("RTC", "会议已建立");
            }

            @Override
            public void onConferenceClosed() {
                Log.d("RTC", "会议已关闭");
            }

            @Override
            public void onConferenceFailed(RtcError error) {
                Log.e("RTC", "会议失败: " + error.getErrorCode() 
                        + ", " + error.getErrorMessage());
            }

            @Override
            public void onRoomSnapshotChanged(RscRtcRoomSnapshot snapshot) {
                Log.d("RTC", "房间状态变化: roomState=" 
                        + snapshot.getRoomState());
                // roomState: "idle" | "opening" | "active" | "failed"
            }

            @Override
            public void onMessageReceived(RtcMessage message) {
                Log.d("RTC", "收到消息: " + message.getMessage());
            }

            @Override
            public void onBusinessCaptureResult(RtcCaptureResult result) {
                if (result.isSuccess()) {
                    Log.d("RTC", "拍照成功: " + result.getFilePaths());
                } else {
                    Log.e("RTC", "拍照失败: " + result.getErrorMessage());
                }
            }

            @Override
            public void onError(RtcError error) {
                Log.e("RTC", "错误: " + error.getErrorCode());
            }
        });
    }
}
```

### 2.3 初始化 SDK

```java
// 在进入房间前先初始化
RtcInitOptions initOptions = new RtcInitOptions(
    0,                  // environment: 0=生产环境, 1=测试环境
    "app_config.json", // configFileName: 配置文件名
    null,               // proxyIp: 代理 IP，无则传 null
    0,                  // proxyPort: 代理端口
    null                // extras: 额外参数
);

RtcCommandResult result = bridge.initialize(this, initOptions);
if (!result.isAccepted()) {
    Log.e("RTC", "初始化失败: " + result.getErrorCode());
}
```

### 2.4 启动会议

```java
// 构建房间参数
Bundle arguments = new Bundle();
arguments.putString("appid", "your_app_id");
arguments.putString("channelName", "zypad");
arguments.putInt("init", 0);

Bundle clientInfo = new Bundle();
clientInfo.putString("tellerCode", "20080612010");
clientInfo.putString("tellerName", "张三");
clientInfo.putString("tellerBranch", "11009021");
clientInfo.putString("ip", "172.20.10.7");

Bundle deviceInfo = new Bundle();
deviceInfo.putString("imei", "862175051124177");
deviceInfo.putString("brand", "HUAWEI");
deviceInfo.putString("model", "BZT3-AL00");

RtcRoomOptions options = new RtcRoomOptions(
    "/room",                    // route: Flutter 路由
    "862175051124177",          // fromUser: 用户 ID
    "64000652",                 // unionId: 联盟 ID
    "中国xx银行xx支行",         // brhName: 行名称
    "862175051124177",          // deviceId: 设备 ID
    "01",                       // language: 语言编码
    "普通话",                   // languageName: 语言名称
    arguments,                  // arguments: 业务参数
    clientInfo,                 // clientInfo: 柜员信息
    deviceInfo                  // deviceInfo: 设备信息
);

// 启动会议（从主 Activity 上下文调用）
RtcCommandResult result = bridge.enterRoom(this, options);
if (result.isAccepted()) {
    Log.d("RTC", "会议启动成功, requestId=" + result.getRequestId());
} else {
    Log.e("RTC", "会议启动失败: " + result.getErrorCode());
}
```

简化调用（使用默认参数）：
```java
RtcRoomOptions options = new RtcRoomOptions(
    "/room", "862175051124177", null, null, null, null, null, null, null, null
);
bridge.enterRoom(this, options);
```

### 2.5 停止会议

```java
RtcLeaveOptions leaveOptions = new RtcLeaveOptions("user_exit", null);
RtcCommandResult result = bridge.leaveRoom(leaveOptions);
if (result.isAccepted()) {
    Log.d("RTC", "离房请求已发送");
}
```

### 2.6 销毁

```java
@Override
protected void onDestroy() {
    if (bridge != null) {
        bridge.unregisterCallback(callback);
        bridge.destroy();
    }
    super.onDestroy();
}
```

## 3. API 一览

### 3.1 初始化与连接

| 方法 | 说明 |
| --- | --- |
| `RtcCommandResult initialize(Context context, RtcInitOptions options)` | 初始化 SDK，建立与 RTC APK 的 AIDL 连接 |
| `String getServiceState()` | 获取服务连接状态：`disconnected` / `connecting` / `connected` |
| `String getSdkVersion()` | 获取 SDK 版本号 |
| `String getProtocolVersion()` | 获取协议版本号 |
| `Bundle getCapabilities()` | 获取 RTC APK 支持的能力（如 supportsBusinessCapture） |

### 3.2 会议控制

| 方法 | 说明 |
| --- | --- |
| `RtcCommandResult enterRoom(Context context, RtcRoomOptions options)` | 启动会议，会拉起 RTC APK 的 `RtcEntryActivity` |
| `RtcCommandResult leaveRoom(RtcLeaveOptions options)` | 停止当前会议 |
| `RscRtcRoomSnapshot getRoomSnapshot()` | 获取当前房间状态快照 |

### 3.3 消息与业务

| 方法 | 说明 |
| --- | --- |
| `RtcCommandResult sendMessage(RtcMessage message)` | 发送业务消息到房间 |
| `RtcCommandResult setBusinessCaptureMode(RtcCaptureOptions options)` | 发起业务拍照（团体照/单人照） |

### 3.4 监听器管理

| 方法 | 说明 |
| --- | --- |
| `void registerCallback(RscRtcBridgeCallback callback)` | 注册事件监听器 |
| `void unregisterCallback(RscRtcBridgeCallback callback)` | 移除事件监听器 |
| `void destroy()` | 销毁 Bridge，断开 AIDL 连接 |

## 4. 回调接口

### 4.1 `RscRtcBridgeCallback`

```java
public interface RscRtcBridgeCallback {
    // 服务连接状态变化
    void onServiceStateChanged(String serviceState);
    
    // 正在进入房间（房间正在开启）
    void onRoomOpening(String requestId);
    
    // 会议已成功建立
    void onConferenceOpened();
    
    // 会议已关闭（正常离开）
    void onConferenceClosed();
    
    // 会议失败
    void onConferenceFailed(RtcError error);
    
    // 房间快照变化（包含详细状态）
    void onRoomSnapshotChanged(RscRtcRoomSnapshot snapshot);
    
    // 收到业务消息
    void onMessageReceived(RtcMessage message);
    
    // 业务拍照结果
    void onBusinessCaptureResult(RtcCaptureResult result);
    
    // 通用错误
    void onError(RtcError error);
}
```

## 5. 数据模型

### 5.1 `RtcInitOptions` - 初始化参数

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `environment` | int | 环境：0=生产，1=测试 |
| `configFileName` | String | 配置文件名 |
| `proxyIp` | String | 代理服务器 IP（可选） |
| `proxyPort` | int | 代理服务器端口 |
| `extras` | Bundle | 额外参数 |

### 5.2 `RtcRoomOptions` - 房间参数

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `route` | String | Flutter 路由，默认 `/room` |
| `fromUser` | String | 发起方用户 ID（必填） |
| `unionId` | String | 联盟 ID |
| `brhName` | String | 行名称 |
| `deviceId` | String | 设备 ID |
| `language` | String | 语言编码 |
| `languageName` | String | 语言名称 |
| `arguments` | Bundle | 业务参数（appid, channelName, dept 等） |
| `clientInfo` | Bundle | 柜员信息（tellerCode, tellerName, tellerBranch 等） |
| `deviceInfo` | Bundle | 设备信息（imei, brand, model 等） |

**arguments 常用字段**：
| 字段 | 说明 |
| --- | --- |
| `appid` | 应用 ID |
| `dept` | 部门 |
| `channelName` | 渠道名称，默认 `zypad` |
| `init` | 初始化参数 |
| `noAgentLogin` | 是否免登录 |
| `p2p` | 是否 P2P 模式 |
| `browser` | 浏览器类型，默认 `pad` |
| `busitype1` | 业务类型，默认 `ZY` |
| `visitorSendInst` | 访客发送指令 |
| `r_flag` | 标志位 |
| `environment` | 环境（会自动从 RtcInitOptions 注入） |
| `proxyIp` | 代理 IP |
| `proxyPort` | 代理端口 |

**clientInfo 字段**：
- `tellerCode` - 柜员工号
- `tellerName` - 柜员姓名
- `tellerBranch` - 柜员网点
- `tellerIdNo` - 柜员身份证号
- `ip` - IP 地址
- `locationFlag` - 定位标志
- `fileId` - 文件 ID
- `pageIndex` - 页面索引
- `pushSpeechFlag` - 语音推送标志
- `outTaskNo` - 外出任务号

**deviceInfo 字段**：
- `imei` - 设备 IMEI
- `brand` - 品牌
- `model` - 型号
- `board` - 主板
- `osVersion` - 系统版本
- `sdk` - SDK 版本
- `display` - 屏幕分辨率
- `gps` - GPS 坐标
- `boxflag` - 盒子标志
- `brhShtName` - 网点简称
- `deviceInst` - 设备实例
- `deviceNo` - 设备编号
- `updeviceInst` - 上级设备实例

### 5.3 `RscRtcRoomSnapshot` - 房间快照

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `serviceState` | String | 服务状态：`disconnected` / `connecting` / `connected` |
| `roomState` | String | 房间状态：`idle` / `opening` / `active` / `failed` |
| `failureType` | String | 失败类型（如 `network`） |
| `failureCode` | String | 失败代码 |
| `failureMessage` | String | 失败消息 |
| `canRetry` | boolean | 是否可重试 |
| `roomPageShowing` | boolean | 房间页面是否正在显示 |
| `disconnectReason` | String | 断开原因 |
| `extras` | Bundle | 额外数据 |

**房间状态流转**：
```
idle → opening → active (会议成功)
                ↘ failed (会议失败)
active → idle (正常离开)
```

### 5.4 `RtcError` - 错误信息

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `errorCode` | String | 错误代码 |
| `errorMessage` | String | 错误消息 |
| `failureType` | String | 失败类型 |
| `extras` | Bundle | 额外数据 |

### 5.5 `RtcCommandResult` - 命令结果

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `accepted` | boolean | 命令是否被接受 |
| `requestId` | String | 请求 ID |
| `errorCode` | String | 错误代码（若 accepted=false） |
| `errorMessage` | String | 错误消息 |

### 5.6 `RtcCaptureOptions` - 拍照参数

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `mode` | String | 拍照模式：`group` / `single` / `singleWithFrame` / `close` / `disabled` |
| `fileName` | String | 文件名（不含扩展名） |
| `toggleCamera` | boolean | 是否切换到后置摄像头 |
| `tipsContent` | String | 提示内容 |
| `extras` | Bundle | 额外参数 |

### 5.7 `RtcMessage` - 消息

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `message` | String | 消息内容 |
| `messageType` | String | 消息类型 |
| `requestId` | String | 请求 ID |
| `extras` | Bundle | 额外参数 |

## 6. 回调示例

### 示例 A：完整会议流程监听

```java
bridge.registerCallback(new RscRtcBridgeCallback() {
    @Override
    public void onServiceStateChanged(String serviceState) {
        // "disconnected" → "connecting" → "connected"
        runOnUiThread(() -> {
            statusText.setText("服务状态: " + serviceState);
        });
    }

    @Override
    public void onRoomOpening(String requestId) {
        runOnUiThread(() -> {
            statusText.setText("正在进入房间...");
            btnStart.setEnabled(false);
        });
    }

    @Override
    public void onConferenceOpened() {
        runOnUiThread(() -> {
            statusText.setText("会议进行中");
            btnStart.setText("会议运行中");
            btnStart.setEnabled(false);
            btnStop.setEnabled(true);
        });
    }

    @Override
    public void onConferenceClosed() {
        runOnUiThread(() -> {
            statusText.setText("会议已结束");
            btnStart.setText("启动会议");
            btnStart.setEnabled(true);
            btnStop.setEnabled(false);
        });
    }

    @Override
    public void onConferenceFailed(RtcError error) {
        runOnUiThread(() -> {
            statusText.setText("会议失败: " + error.getErrorMessage());
            btnStart.setText("启动会议");
            btnStart.setEnabled(true);
            btnStop.setEnabled(false);
            Toast.makeText(MainActivity.this, 
                "会议失败: " + error.getErrorMessage(), 
                Toast.LENGTH_LONG).show();
        });
    }

    @Override
    public void onRoomSnapshotChanged(RscRtcRoomSnapshot snapshot) {
        Log.d("RTC", "roomState=" + snapshot.getRoomState() 
                + ", roomPageShowing=" + snapshot.isRoomPageShowing());
    }

    @Override
    public void onMessageReceived(RtcMessage message) {
        Log.d("RTC", "收到消息: " + message.getMessage());
    }

    @Override
    public void onBusinessCaptureResult(RtcCaptureResult result) {
        if (result.isSuccess()) {
            Log.d("RTC", "拍照成功，文件: " + result.getFilePaths());
            // result.getFileUris() - 文件 URI 列表
            // result.getFilePaths() - 文件路径列表
        } else {
            Log.e("RTC", "拍照失败: " + result.getErrorMessage());
        }
    }

    @Override
    public void onError(RtcError error) {
        Log.e("RTC", "错误: " + error.getErrorCode() 
                + " - " + error.getErrorMessage());
    }
});
```

### 示例 B：业务拍照

```java
// 团体照
RtcCaptureOptions groupOptions = new RtcCaptureOptions(
    "group",              // mode
    "group_photo_001",   // fileName
    false,               // toggleCamera
    null,                 // tipsContent
    null                  // extras
);
bridge.setBusinessCaptureMode(groupOptions);

// 单人照
RtcCaptureOptions singleOptions = new RtcCaptureOptions(
    "single",             // mode
    "single_photo_001",  // fileName
    true,                 // toggleCamera: 切换后置摄像头
    "请将证件置于框内",   // tipsContent
    null                  // extras
);
bridge.setBusinessCaptureMode(singleOptions);

// 关闭拍照模式
RtcCaptureOptions closeOptions = new RtcCaptureOptions(
    "close", null, false, null, null
);
bridge.setBusinessCaptureMode(closeOptions);
```

### 示例 C：发送消息

```java
Bundle extras = new Bundle();
extras.putString("customKey", "customValue");

RtcMessage message = new RtcMessage(
    "Hello from host",    // message
    "text",              // messageType
    null,                // requestId (可选)
    extras                // extras
);

RtcCommandResult result = bridge.sendMessage(message);
if (result.isAccepted()) {
    Log.d("RTC", "消息已发送");
} else {
    Log.e("RTC", "消息发送失败: " + result.getErrorCode());
}
```

## 7. 错误码参考

| 错误码 | 说明 |
| --- | --- |
| `context_required` | Context 参数为空 |
| `service_not_ready_please_retry` | AIDL 服务未就绪，需重试 |
| `initialize_invalid_context` | 初始化时 Context 无效 |
| `enter_room_invalid_context` | 入房时 Context 无效 |
| `enter_room_launch_failed` | 启动 Activity 失败 |
| `leave_room_service_not_ready` | 离房时服务未就绪 |
| `leave_room_failed` | 离房失败 |
| `cache_failed` | 缓存请求失败 |
| `enter_room_request_expired` | 请求已过期 |
| `flutter_not_ready` | Flutter 引擎未就绪 |
| `singleWithFrame` | 不支持的拍照模式 |

## 8. 接入注意事项

- **必须先调用 `initialize()`**：在调用 `enterRoom()` 前必须先调用 `initialize()` 建立 AIDL 连接
- **Context 要求**：`initialize()` 和 `enterRoom()` 必须使用前台 Activity Context，不能使用 Application Context
- **回调线程**：所有回调均在主线程（UI 线程）执行，可直接更新 UI
- **生命周期管理**：在 Activity/Fragment 的 `onDestroy()` 中调用 `destroy()` 断开连接
- **权限要求**：确保 `AndroidManifest.xml` 中声明了启动 RTC APK Activity 的权限
- **双 APK 架构**：本 SDK 采用双 APK 架构，`enterRoom()` 会通过显式 Intent 拉起 `rtc_apk_app` 的 `RtcEntryActivity`
