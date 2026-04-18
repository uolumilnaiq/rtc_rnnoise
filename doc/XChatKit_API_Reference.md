# XChatKit RTC SDK API 参考文档（Android）

本文档基于以下源码整理（2026-04-03）：
- `MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/XChatKit.java`
- `MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/ConferenceOptions.java`
- `MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/XChatLifecycleObserver.java`

## 1. SDK 概览

`XChatKit` 是 Android 侧统一入口，提供：
- SDK 初始化与 Flutter 引擎预热
- 会议页面启动/停止
- 多监听器事件分发（主线程）
- transport 消息发送
- 业务拍照能力
- 生命周期绑定与资源销毁

## 2. 快速接入

### 2.1 初始化（必须先于 startConference）

```java
XChatKit.init(getApplicationContext(), new XChatKit.OnEnginePrewarmListener() {
    @Override
    public void onEnginePrewarmComplete() {
        // 预热完成
    }

    @Override
    public void onEnginePrewarmFailed(String error) {
        // 预热失败
    }
});
```

约束：
- `startConference(...)` 前必须调用 `init(...)`，否则会抛 `IllegalStateException`。
- `init(...)` 幂等；已初始化时再次调用不会重复初始化。

### 2.2 监听事件

```java
private final XChatKit.XChatEventListener listener = new XChatKit.XChatEventListener() {
    @Override
    public void onMessage(String msgType, String message, String time) {
        // 处理状态/事件
    }

    @Override
    public void onReceiveMessage(String message) {
        // 处理业务消息
    }
};

XChatKit.addEventListener(listener);
```

说明：
- 监听回调由 SDK 切回主线程分发。
- `addEventListener(...)` 会按“监听器类名”去重：同类型重复注册会移除旧实例再添加新实例。

### 2.3 启动会议

```java
ConferenceOptions options = new ConferenceOptions.Builder()
    .setRoute("/room")
    .setFromUser("862175051124177")
    .setBrhName("中国xx银行xx支行")
    .setLanguage("01")
    .setLanguageName("普通话")
    .setUnionId("64000652")
    .clientInfo()
        .setTellerCode("20080612010")
        .setTellerName("某**")
        .setTellerBranch("11009021")
        .setTellerIdNo("510321197****1565X")
        .setIp("172.20.10.7")
        .setLocationFlag("1")
        .setFileId("1312639206AK")
        .setPageIndex(1)
        .setPushSpeechFlag("1")
        .deviceInfo()
            .setImei("862175051124177")
            .setBrand("HUAWEI")
            .setModel("BZT3-AL00")
            .setBoard("BZT3-AL00")
            .setOsVersion("10")
            .setSdk("29")
            .setDisplay("2000x1200")
            .setBrhShtName("北**台区**支行")
            .setDeviceInst("11009021")
            .setDeviceNo("9999130008")
            .setUpdeviceInst("11000013")
            .build()
        .build()
    .build();

XChatKit.startConference(this, options);
```

简化调用：
```java
XChatKit.startConference(this);
```

### 2.4 停止与销毁

```java
XChatKit.stopConference();
```

```java
XChatKit.destroy(); // 全局不再使用 SDK 时调用
```

## 3. 常量定义

### 3.1 环境常量
- `XChatKit.ENV_PROD = 0`
- `XChatKit.ENV_DEBUG = 1`

当前实现默认环境：`ENV_DEBUG`。

### 3.2 事件常量（`onMessage` 的 `msgType`）
- `XChatKit.EVENT_WEBCAM_ENABLED = "EnableWebcamAndUploadDone"`
- `XChatKit.EVENT_WEBCAM_DISABLED = "DisableWebcamAndUploadDone"`
- `XChatKit.EVENT_ENTER_ROOM_DONE = "EnterRoomDone"`
- `XChatKit.EVENT_LEAVE_ROOM_DONE = "LeaveRoomDone"`
- `XChatKit.EVENT_MATCH_AGENT_DONE = "matchAgentSuccess"`
- `XChatKit.EVENT_ROOM_LIFECYCLE_STATE_CHANGED = "RoomLifecycleStateChanged"`

## 4. XChatKit API 一览

### 4.1 环境与初始化

| 方法 | 说明 |
| --- | --- |
| `int getEnvironment()` | 获取当前环境 |
| `void setEnvironment(int env)` | 设置运行环境（需在 `startConference` 前） |
| `String getConfigFileName()` | 返回配置文件名：debug 为 `xchatkit_config_debug.json`，prod 为 `xchatkit_config.json` |
| `void init(Context context)` | 初始化（无预热回调） |
| `void init(Context context, OnEnginePrewarmListener listener)` | 初始化（带预热回调） |
| `void bindLifecycle(LifecycleOwner owner)` | 绑定生命周期，`owner.onDestroy` 时自动 `XChatKit.destroy()` |

### 4.2 会议启动/停止

| 方法 | 说明 |
| --- | --- |
| `Intent createConferenceIntent(Context context, ConferenceOptions options)` | 构建会议页 Intent（不启动） |
| `void startConference(Activity activity)` | 使用默认参数启动 |
| `void startConference(Activity activity, ConferenceOptions options)` | 使用自定义参数启动 |
| `void stopConference()` | 停止会议并退出页面 |

### 4.3 事件与消息

| 方法 | 说明 |
| --- | --- |
| `void addEventListener(XChatEventListener listener)` | 添加事件监听（按类名去重） |
| `void removeEventListener(XChatEventListener listener)` | 移除监听（实例或类名匹配） |
| `void sendMessage(String message)` | 发送 JSON 字符串消息 |

### 4.4 业务拍照

| 方法 | 说明 |
| --- | --- |
| `void businessPhotoForGroup(String fileName, OnBusinessPhotoTakeListener listener)` | 群组拍照（前置摄像头） |
| `void businessPhotoForSingle(String fileName, boolean toggleCamera, String tipsContent, OnBusinessPhotoTakeListener listener)` | 单人拍照（可切后置） |
| `void closeBusinessPhotoMode()` | 关闭拍照模式 UI（会判断 Flutter 是否仍在处理中） |

### 4.5 资源销毁

| 方法 | 说明 |
| --- | --- |
| `void destroy()` | 销毁 SDK、清空监听器、清理缓存引擎（`xchatkit_engine`） |

## 5. 回调接口

### 5.1 `XChatEventListener`

```java
public interface XChatEventListener {
    void onMessage(String msgType, String message, String time);
    void onReceiveMessage(String message);
}
```

### 5.2 `OnEnginePrewarmListener`

```java
public interface OnEnginePrewarmListener {
    void onEnginePrewarmComplete();
    void onEnginePrewarmFailed(String error);
}
```

### 5.3 `OnBusinessPhotoTakeListener`

```java
public interface OnBusinessPhotoTakeListener {
    void onPhotoTakeSuccess(java.util.List<String> filePaths);
    void onPhotoTakeFail(String errorMessage);
}
```

## 6. 回调实际调用示例

### 示例 A：引擎预热

```java
XChatKit.init(getApplicationContext(), new XChatKit.OnEnginePrewarmListener() {
    @Override
    public void onEnginePrewarmComplete() {
        Log.i("Demo", "engine prewarm complete");
    }

    @Override
    public void onEnginePrewarmFailed(String error) {
        Log.e("Demo", "engine prewarm failed: " + error);
    }
});
```

### 示例 B：房间生命周期与入离会事件

```java
XChatKit.addEventListener(new XChatKit.XChatEventListener() {
    @Override
    public void onMessage(String msgType, String message, String time) {
        if (XChatKit.EVENT_ENTER_ROOM_DONE.equals(msgType)) {
            Log.i("Demo", "enter room done");
            return;
        }
        if (XChatKit.EVENT_LEAVE_ROOM_DONE.equals(msgType)) {
            Log.i("Demo", "leave room done");
            return;
        }
        if (XChatKit.EVENT_ROOM_LIFECYCLE_STATE_CHANGED.equals(msgType)) {
            Log.i("Demo", "lifecycle changed: " + message);
            // message 示例：{"lifecycleState":"established","connectionStatus":"connected",...}
        }
    }

    @Override
    public void onReceiveMessage(String message) {
        Log.i("Demo", "receive message: " + message);
    }
});
```

### 示例 C：业务拍照回调

```java
XChatKit.businessPhotoForSingle(
    "single_photo_001",
    true,
    "请将证件置于框内",
    new XChatKit.OnBusinessPhotoTakeListener() {
        @Override
        public void onPhotoTakeSuccess(java.util.List<String> filePaths) {
            Log.i("Demo", "photo success: " + filePaths);
        }

        @Override
        public void onPhotoTakeFail(String errorMessage) {
            Log.e("Demo", "photo failed: " + errorMessage);
        }
    }
);
```

## 7. ConferenceOptions 说明

### 7.1 顶层 Builder 常用方法

| 方法 | 说明 |
| --- | --- |
| `setRoute(String route)` | Flutter 路由，默认 `/` |
| `setFromUser(String userId)` | 发起方用户 ID（必填，空值抛 `IllegalArgumentException`） |
| `setBrhName(String brhName)` | 行名称 |
| `setUnionId(String unionId)` | 联盟 ID |
| `setDeviceId(String deviceId)` | 顶层设备 ID |
| `setLanguage(String language)` | 语言编码 |
| `setLanguageName(String languageName)` | 语言名称 |
| `addArgument(String key, Object value)` | 添加自定义参数 |
| `clientInfo()` | 进入 `clientInfo` 子构建器 |

### 7.2 `clientInfo()` 字段
- `setIp`
- `setLocationFlag`
- `setFileId`
- `setPageIndex`
- `setPushSpeechFlag`
- `setTellerBranch`
- `setTellerCode`
- `setTellerIdNo`
- `setTellerName`
- `setOutTaskNo`
- `deviceInfo()`

### 7.3 `deviceInfo()` 字段
- `setBoard`
- `setBoxflag`
- `setBrand`
- `setBrhShtName`
- `setDeviceInst`
- `setDeviceNo`（会同步回填顶层 `deviceId`）
- `setDisplay`
- `setGps`
- `setImei`
- `setModel`
- `setOsVersion`
- `setSdk`
- `setUpdeviceInst`

### 7.4 Builder 默认参数

`ConferenceOptions.Builder()` 初始化时默认写入：
- `appid = ""`
- `dept = ""`
- `channelName = "zypad"`
- `deviceId = ""`
- `init = 0`
- `noAgentLogin = 0`
- `p2p = false`
- `queueHintCount = 0`
- `queueHintInterval = 0`
- `browser = "pad"`
- `busitype1 = "ZY"`
- `visitorSendInst = "99700320000"`
- `r_flag = -1`

## 8. 接入注意事项

- 先 `init(...)` 再 `startConference(...)`。
- `setEnvironment(...)` 需在 `startConference(...)` 前调用才生效。
- 若你使用 `bindLifecycle(owner)`，`owner` 销毁时会自动 `destroy()`，请避免与手动 `destroy()` 冲突。
- `createConferenceIntent(...)` 支持不立即启动场景；`options == null` 时会走默认配置。
- `XChatKit` 本身没有直接的 `proxyIp/proxyPort` API；如需代理，请由宿主在启动前配置系统属性并确保 Flutter 侧读取策略一致。
