# XChatKit SDK 部署集成指南

## 概述

XChatKit 由两部分构成：
- Flutter 模块 AAR（`flutter_debug/profile/release`）
- Android SDK AAR（源码模块名 `rsc-sdk`，Maven 发布产物名 `rtc-sdk`）

对应源码：
- `MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/XChatKit.java`
- `MyApplicationForFlutter/rsc-sdk/build.gradle`
- `MyApplicationForFlutter/rsc-sdk/src/main/AndroidManifest.xml`

---

## 1. 依赖关系与坐标

### 1.1 Maven 坐标

| 组件 | groupId | artifactId | 版本 |
| --- | --- | --- | --- |
| Flutter Debug | `com.yc.rtc.flutter_module` | `flutter_debug` | `1.0` |
| Flutter Profile | `com.yc.rtc.flutter_module` | `flutter_profile` | `1.0` |
| Flutter Release | `com.yc.rtc.flutter_module` | `flutter_release` | `1.0` |
| XChatKit SDK | `com.yc.rtc` | `rtc-sdk` | `1.0.0` |

说明：
- Gradle 模块目录名是 `rsc-sdk`。
- 发布到 Maven 的产物名是 `rtc-sdk`（见 `rsc-sdk/build.gradle` 的 `artifactId`）。

### 1.2 关键点

- `rtc-sdk` 对 Flutter AAR 使用的是 `compileOnly`，因此宿主必须显式依赖 `flutter_debug/profile/release`。
- `XChatKit.startConference(...)` 前必须先 `XChatKit.init(...)`。

---

## 2. 构建发布步骤

### 2.1 构建 Flutter AAR

```bash
cd flutter_module

flutter build aar --debug
flutter build aar --profile
flutter build aar --release
```

Flutter AAR 本地仓库路径：
- `flutter_module/build/host/outputs/repo/`

### 2.2 发布 SDK AAR（rtc-sdk）

```bash
cd MyApplicationForFlutter

./gradlew :rsc-sdk:publishReleasePublicationToMavenRepository
# 如需 debug 变体，也可执行
./gradlew :rsc-sdk:publishDebugPublicationToMavenRepository
```

默认发布仓库路径（由 `rsc-sdk/build.gradle` 指定）：
- `../../flutter_module/build/host/outputs/repo`

---

## 3. 宿主项目配置

### 3.1 settings.gradle 配置仓库

```groovy
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // 指向本地 repo
        maven { url "file:///absolute/path/to/flutter_module/build/host/outputs/repo" }
    }
}
```

### 3.2 app/build.gradle 依赖

```groovy
android {
    compileSdk 35

    defaultConfig {
        minSdk 29
        targetSdk 35
    }

    // 当前 SDK 示例工程使用 Java 8
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

dependencies {
    // 宿主必须显式引入对应构建变体的 Flutter AAR
    debugImplementation 'com.yc.rtc.flutter_module:flutter_debug:1.0'
    profileImplementation 'com.yc.rtc.flutter_module:flutter_profile:1.0'
    releaseImplementation 'com.yc.rtc.flutter_module:flutter_release:1.0'

    // 引入 SDK（Maven 方式）
    implementation 'com.yc.rtc:rtc-sdk:1.0.0'

    // 若是同仓库联调，也可直接依赖模块
    // implementation project(':rsc-sdk')
}
```

---

## 4. AndroidManifest 要点

根据 `rsc-sdk/src/main/AndroidManifest.xml`，宿主需确保以下配置可用。

### 4.1 权限（至少）

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

### 4.2 Activity/Service

```xml
<application>
    <activity
        android:name="com.yc.rtc.rsc_sdk.FlutterDemoActivity"
        android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
        android:hardwareAccelerated="true"
        android:windowSoftInputMode="adjustResize"
        android:exported="false"
        android:theme="@style/Theme.AppCompat.Light.NoActionBar"
        android:supportsPictureInPicture="true"
        android:resizeableActivity="true"
        android:launchMode="singleTop" />

    <service
        android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
        android:foregroundServiceType="mediaProjection"
        android:stopWithTask="true"
        tools:ignore="MissingClass" />
</application>
```

---

## 5. 运行时接入顺序（推荐）

### 5.1 初始化（可在 Application 或首屏）

```java
XChatKit.init(getApplicationContext(), new XChatKit.OnEnginePrewarmListener() {
    @Override
    public void onEnginePrewarmComplete() {
        // 可记录预热耗时
    }

    @Override
    public void onEnginePrewarmFailed(String error) {
        // 可降级处理
    }
});
```

### 5.2 注册监听

```java
XChatKit.addEventListener(new XChatKit.XChatEventListener() {
    @Override
    public void onMessage(String msgType, String message, String time) {
        // 例如 EnterRoomDone / LeaveRoomDone / RoomLifecycleStateChanged
    }

    @Override
    public void onReceiveMessage(String message) {
        // 业务消息
    }
});
```

### 5.3 启动与停止会议

```java
ConferenceOptions options = new ConferenceOptions.Builder()
    .setRoute("/room")
    .setFromUser("your_user_id")
    .build();

XChatKit.startConference(this, options);

// ...
XChatKit.stopConference();
```

### 5.4 生命周期管理

二选一：
- 手动管理：业务时机调用 `XChatKit.destroy()`。
- 自动管理：`XChatKit.bindLifecycle(lifecycleOwner)`，在 `onDestroy` 自动执行 `destroy()`。

---

## 6. 常见问题

### Q1: `IllegalStateException: XChatKit.init() must be called before startConference()`

原因：未先初始化。

解决：确保 `XChatKit.init(...)` 早于任何 `startConference(...)` 调用。

### Q2: 运行时报 `MissingPluginException` 或页面空白

原因：宿主没有按变体引入 Flutter AAR（`flutter_debug/profile/release`）。

解决：在宿主 `dependencies` 中显式配置三套变体依赖。

### Q3: Maven 依赖写成了 `rsc-sdk`

原因：模块名与发布名混淆。

解决：Maven 坐标使用 `com.yc.rtc:rtc-sdk:1.0.0`，不是 `rsc-sdk`。

### Q4: 监听重复触发

说明：`addEventListener` 按监听器“类名”去重；若存在多处注册同类监听器，会替换旧实例。

建议：统一在单一入口注册，并在 `onDestroy` 对应移除。
