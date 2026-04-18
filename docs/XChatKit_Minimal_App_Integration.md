# XChatKit 最小化接入指南（App 侧）

本文档只关注三件事：
- App 如何引入 `rtc-sdk`
- App 如何引入 Flutter AAR（`flutter_debug/profile/release`）
- `rtc-sdk` 内置 `AndroidManifest.xml` 包含哪些内容，以及 App 侧最小配置

源码基线（2026-04-03）：
- `MyApplicationForFlutter/rsc-sdk/build.gradle`
- `MyApplicationForFlutter/rsc-sdk/src/main/AndroidManifest.xml`
- `MyApplicationForFlutter/rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/XChatKit.java`

---

## 1. 依赖坐标

| 组件 | groupId | artifactId | version |
| --- | --- | --- | --- |
| RTC SDK | `com.yc.rtc` | `rtc-sdk` | `1.0.0` |
| Flutter Debug AAR | `com.yc.rtc.flutter_module` | `flutter_debug` | `1.0` |
| Flutter Profile AAR | `com.yc.rtc.flutter_module` | `flutter_profile` | `1.0` |
| Flutter Release AAR | `com.yc.rtc.flutter_module` | `flutter_release` | `1.0` |

说明：
- Gradle 模块名是 `rsc-sdk`，但发布到 Maven 的 artifact 是 `rtc-sdk`。
- `rtc-sdk` 内部对 Flutter AAR 是 `compileOnly`，所以 App 必须显式引入三套 Flutter 变体依赖。

---

## 2. App 侧最小 Gradle 配置

### 2.1 `settings.gradle`

```groovy
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // 指向你本地/私服的 AAR Maven 仓库
        maven { url "file:///absolute/path/to/repo" }
    }
}
```

### 2.2 `app/build.gradle`

```groovy
android {
    compileSdk 35

    defaultConfig {
        minSdk 29
        targetSdk 35
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

dependencies {
    // Flutter AAR（必须）
    debugImplementation 'com.yc.rtc.flutter_module:flutter_debug:1.0'
    profileImplementation 'com.yc.rtc.flutter_module:flutter_profile:1.0'
    releaseImplementation 'com.yc.rtc.flutter_module:flutter_release:1.0'

    // RTC SDK
    implementation 'com.yc.rtc:rtc-sdk:1.0.0'
}
```

---

## 3. rtc-sdk 内置 Manifest 内容（当前版本）

`rtc-sdk` AAR 中包含以下声明，默认会通过 Manifest Merge 合并到宿主：

### 3.1 权限

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

### 3.2 组件

```xml
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
```

---

## 4. App 侧最小运行时配置

### 4.1 调用顺序（必须）

```java
XChatKit.init(getApplicationContext());
// ...
XChatKit.startConference(activity, options);
```

注意：`startConference` 前未调用 `init` 会抛 `IllegalStateException`。

### 4.2 动态权限（建议在入会前确认）

- `CAMERA`
- `RECORD_AUDIO`

> 以上权限即使已在 Manifest 合并，也仍需按 Android 运行时权限流程申请。

---

