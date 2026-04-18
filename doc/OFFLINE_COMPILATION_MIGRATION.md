# Flutter + Android 离线编译环境迁移手册

> **源机器**: macOS  
> **目标机器**: Windows 10 (完全离线环境)  
> **编译目标**: rsc-sdk (AAR) + 完整 APK

---

## 一、需求确认

| 项目 | 说明 |
|------|------|
| 编译产物 | SDK (AAR) + APK |
| 网络环境 | 完全离线 |
| 磁盘空间 | 充裕 (>100GB) |
| 传输方式 | 外部存储 (硬盘/U盘) |

---

## 二、当前项目 SDK 版本

基于对项目配置文件的分析：

| 组件 | 版本 | 配置位置 |
|------|------|----------|
| **Flutter** | 3.24.5 | `flutter --version` |
| **compileSdk** | 36 | 项目配置（flutter_module/build.sh） |
| **targetSdk** | 36 | 项目配置（flutter_module/build.sh） |
| **minSdk** | 21 | 项目配置（支持 Android 5.0+） |
| **ndkVersion** | Flutter 自动管理 | `flutter.ndkVersion` |
| **Java** | 17 | Gradle 要求 |

```gradle
// flutter_module/.android/Flutter/build.gradle
android {
    compileSdk = flutter.compileSdkVersion  // 35
    ndkVersion = flutter.ndkVersion          // Flutter 自动管理
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
```

---

## 三、在 macOS 上准备工具

### 3.1 下载清单

| 序号 | 软件 | 下载地址 | 预估大小 |
|------|------|----------|----------|
| 1 | JDK 17 (Temurin) | https://adoptium.net/temurin/releases/ | 150MB |
| 2 | Flutter 3.24.5 | https://docs.flutter.dev/release/archive | 1.1GB |
| 3 | Android Command Line Tools | https://developer.android.com/studio#cmdline-tools | 150MB |
| 4 | 7-Zip (Windows) | https://www.7-zip.org/download.html | 1.5MB |
| 5 | Visual Studio Build Tools 2022 | https://visualstudio.microsoft.com/visual-cpp-build-tools/ | ~15GB |

> **VS Build Tools 下载**：访问 https://visualstudio.microsoft.com/visual-cpp-build-tools/，下载 `vs_buildtools.exe`，选择以下工作负载：
> - `Desktop development with C++`
> - `Windows 10 SDK (10.0.22621.0)`

### 3.2 下载脚本

```bash
#!/bin/bash
# download_tools.sh

DOWNLOADS="$HOME/Downloads/windows-migration"
mkdir -p "$DOWNLOADS"

echo "=== 1/4 下载 JDK 17 ==="
curl -L -o "$DOWNLOADS/jdk-17.zip" \
  "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.11%2B9/OpenJDK17U-jdk_x64_windows_hotspot_17.0.11_9.zip"

echo "=== 2/4 下载 Flutter 3.24.5 ==="
curl -L -o "$DOWNLOADS/flutter.zip" \
  "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"

echo "=== 3/4 下载 Android Command Line Tools ==="
curl -L -o "$DOWNLOADS/cmdline-tools.zip" \
  "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"

echo "=== 4/4 下载 7-Zip ==="
curl -L -o "$DOWNLOADS/7z2408-x64.exe" \
  "https://www.7-zip.org/a/7z2408-x64.exe"

echo "=== 下载完成 ==="
ls -lh "$DOWNLOADS"
```

### 3.3 打包 Android SDK

需要导出完整的 Android SDK 供 Windows 使用：

```bash
#!/bin/bash
# package_android_sdk.sh

ANDROID_SDK_DIR="$HOME/Library/Android/sdk"
OUTPUT_DIR="$HOME/Downloads/windows-migration"

echo "=== 打包 Android SDK (排除不需要的组件) ==="

# 只复制需要的组件
mkdir -p "$OUTPUT_DIR/android-sdk-temp"

# platform-36 (必须)
cp -r "$ANDROID_SDK_DIR/platforms/android-36" "$OUTPUT_DIR/android-sdk-temp/"

# build-tools 36.0.0 (必须)
cp -r "$ANDROID_SDK_DIR/build-tools/36.0.0" "$OUTPUT_DIR/android-sdk-temp/"

# NDK (不需要！Flutter 插件的 .so 是预编译的)
# 如果你确认需要自定义 NDK 编译，才需要复制
# if [ -d "$ANDROID_SDK_DIR/ndk/23.1.7779620" ]; then
#   cp -r "$ANDROID_SDK_DIR/ndk/23.1.7779620" "$OUTPUT_DIR/android-sdk-temp/ndk/"
# fi

# CMake (不需要！Flutter 插件的原生库已预编译)
# if [ -d "$ANDROID_SDK_DIR/cmake" ]; then
#   cp -r "$ANDROID_SDK_DIR/cmake" "$OUTPUT_DIR/android-sdk-temp/"
# fi

# cmdline-tools (用于安装其他组件)
mkdir -p "$OUTPUT_DIR/android-sdk-temp/cmdline-tools"
cp -r "$ANDROID_SDK_DIR/cmdline-tools/latest" "$OUTPUT_DIR/android-sdk-temp/cmdline-tools/"

# platform-tools (adb 等)
if [ -d "$ANDROID_SDK_DIR/platform-tools" ]; then
  cp -r "$ANDROID_SDK_DIR/platform-tools" "$OUTPUT_DIR/android-sdk-temp/"
fi

# licenses (必须！否则会有许可协议警告)
if [ -d "$ANDROID_SDK_DIR/licenses" ]; then
  cp -r "$ANDROID_SDK_DIR/licenses" "$OUTPUT_DIR/android-sdk-temp/"
fi

# 打包
echo "=== 创建 tar.gz ==="
COPYFILE_DISABLE=1 tar -cvzf "$OUTPUT_DIR/android-sdk.tar.gz" -C "$OUTPUT_DIR/android-sdk-temp" .

# 清理临时目录
rm -rf "$OUTPUT_DIR/android-sdk-temp"

echo "=== 打包完成 ==="
ls -lh "$OUTPUT_DIR/android-sdk.tar.gz"
```

---

## 四、源代码准备

### 4.1 项目结构

```
StudioProjects/
├── MyApplicationForFlutter/    # Android 宿主项目 (~200MB)
├── flutter_module/              # Flutter 模块 (~500MB)
└── docs/                        # 文档
```

### 4.2 打包源代码

```bash
cd /Users/wangxinran/StudioProjects

echo "=== 打包 Flutter Module ==="
tar -cvzf flutter_module.tar.gz flutter_module/

echo "=== 打包 Android 项目 ==="
tar -cvzf MyApplicationForFlutter.tar.gz MyApplicationForFlutter/

echo "=== 完成 ==="
ls -lh *.tar.gz
```

### 4.3 导出依赖列表（可选）

```bash
cd flutter_module
flutter pub deps > dependencies.txt
```

### 4.4 打包 Flutter pub 缓存（完全离线需要）

如果目标机器**完全没有网络**，需要预下载 Flutter 依赖：

```bash
#!/bin/bash
# package_pub_cache.sh

OUTPUT_DIR="$HOME/Downloads/windows-migration"

echo "=== 打包 Flutter pub 缓存 ==="

# 复制 pub.dev 缓存
mkdir -p "$OUTPUT_DIR/pub-cache"
cp -r ~/.pub-cache/hosted/pub.dev "$OUTPUT_DIR/pub-cache/" 2>/dev/null || true
cp -r ~/.pub-cache/git "$OUTPUT_DIR/pub-cache/" 2>/dev/null || true

echo "=== 完成 ==="
ls -lh "$OUTPUT_DIR/pub-cache/"
```

在 Windows 上恢复 pub 缓存：

```powershell
# 复制缓存到 Flutter 目录
xcopy /E /I D:\workspace\pub-cache D:\flutter\.pub-cache\

# 预热 Flutter
flutter precache --android
```

### 4.5 预热 Gradle（可选）

```bash
cd MyApplicationForFlutter

# 预热 Gradle 缓存
./gradlew --refresh-dependencies || true

# 复制 Gradle 缓存
cp -r ~/.gradle/caches "$OUTPUT_DIR/gradle-cache/"
```

在 Windows 上恢复 Gradle 缓存：

```powershell
xcopy /E /I D:\workspace\gradle-cache C:\Users\%USERNAME%\.gradle\caches\
```

---

## 五、文件传输清单

将以下文件拷贝到外部硬盘：

```
windows-migration/
├── 01-tools/
│   ├── jdk-17.zip                    # 150MB
│   ├── flutter.zip                   # 1.1GB
│   ├── cmdline-tools.zip             # 150MB
│   └── 7z2408-x64.exe                # 1.5MB
├── 02-sdk/
│   └── android-sdk.tar.gz             # ~2GB (精简后)
├── 03-source/
│   ├── flutter_module.tar.gz          # ~500MB
│   ├── MyApplicationForFlutter.tar.gz # ~200MB
│   ├── dependencies.txt               # 依赖列表
│   ├── pub-cache/                      # Flutter pub 缓存 (可选)
│   └── gradle-cache/                   # Gradle 缓存 (可选)
└── 04-vs/
    └── vs_buildtools.exe             # ~15GB (VS Build Tools)
```

---

## 六、Windows 10 安装步骤

### 6.1 解压工具

以管理员身份运行 PowerShell：

```powershell
# 创建工作目录
D:
mkdir D:\workspace
cd D:\workspace

# 1. 安装 7-Zip (双击安装或静默安装)
#.\7z2408-x64.exe /S /D=D:\tools\7zip

# 2. 解压所有文件
7z x jdk-17.zip -oD:\jdk-17 -y
7z x flutter.zip -oD:\flutter -y
7z x android-sdk.tar.gz -oD:\android-sdk -y
7z x flutter_module.tar.gz -oD:\workspace -y
7z x MyApplicationForFlutter.tar.gz -oD:\workspace -y
```

### 6.2 环境变量配置

创建 `setup_environment.bat`：

```batch
@echo off
:: setup_environment.bat

echo === 配置环境变量 ===

:: 设置系统环境变量
setx ANDROID_HOME "D:\android-sdk" /M
setx ANDROID_SDK_ROOT "D:\android-sdk" /M
setx JAVA_HOME "D:\jdk-17" /M
setx FLUTTER_HOME "D:\flutter" /M

:: 添加到 PATH (用户级)
setx PATH "%PATH%;D:\flutter\bin;D:\jdk-17\bin;D:\android-sdk\cmdline-tools\latest\bin;D:\android-sdk\platform-tools" /M

echo === 配置 Gradle 离线模式 ===
:: 创建 gradle.properties 并配置离线模式
echo org.gradle.offline=true > D:\workspace\MyApplicationForFlutter\gradle.properties
echo org.gradle.caching=true >> D:\workspace\MyApplicationForFlutter\gradle.properties

echo === 环境变量配置完成 ===
echo 请重启终端使环境变量生效
pause
```

运行：
```batch
setup_environment.bat
```

### 6.3 安装 Android SDK 组件

```powershell
# 重启 PowerShell 后执行

# 验证环境
java -version
flutter --version

# 预热 Flutter（下载 platform 等）
flutter precache --android

# 列出可用组件
D:\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat --list

# 安装必要的组件
D:\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat --sdk_root=D:\android-sdk ^
    "platforms;android-36" ^
    "build-tools;36.0.0"
```

### 6.4 恢复 pub 缓存（完全离线需要）

```powershell
# 如果有预下载的 pub 缓存
xcopy /E /I D:\workspace\pub-cache D:\flutter\.pub-cache\

# 验证 pub 缓存
flutter pub cache list
```

### 6.4 安装 Visual Studio Build Tools

```powershell
# 运行 VS Build Tools 安装程序
.\vs_buildtools.exe --passive ^
  --add Microsoft.VisualStudio.Workload.VCTools ^
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
  --add Microsoft.VisualStudio.Component.Windows10SDK.22621 ^
  --includeRecommended
```

### 6.5 恢复 Gradle 缓存（可选）

```powershell
# 如果有预下载的 Gradle 缓存
xcopy /E /I D:\workspace\gradle-cache C:\Users\%USERNAME%\.gradle\caches\
```

---

## 七、编译验证

### 7.1 验证环境

```powershell
# 重启 PowerShell 后

# 验证 Java
java -version
# 预期: openjdk version "17.0.11"

# 验证 Flutter
flutter --version
# 预期: Flutter 3.24.5

# 预热 Flutter（下载必要的 artifacts）
flutter precache --android

# 验证 Android SDK
flutter doctor -v
```

### 7.2 编译 Flutter APK

```powershell
cd D:\workspace\flutter_module

# 获取依赖
flutter pub get

# 编译 debug APK
flutter build apk --debug

# 编译 release APK
flutter build apk --release
```

### 7.3 编译 Android SDK

```powershell
cd D:\workspace\MyApplicationForFlutter

# 编译 rsc-sdk (AAR)
.\gradlew.bat :rsc-sdk:assembleRelease

# 编译完整 APK
.\gradlew.bat :app:assembleDebug
```

### 7.4 验证产物

```
flutter_module/build/app/outputs/flutter-apk/app-debug.apk
MyApplicationForFlutter/rsc-sdk/build/outputs/aar/rsc-sdk-release.aar
MyApplicationForFlutter/app/build/outputs/apk/debug/app-debug.apk
```

---

## 八、常见问题

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `JAVA_HOME not found` | JDK 未安装或路径错误 | 检查 `java -version` |
| `Android SDK not found` | ANDROID_HOME 未设置 | 确认 `echo %ANDROID_HOME%` |
| `NDK not found` | NDK 未安装 | 使用 `flutter precache --android` |
| `Flutter pub get failed` | 网络不可用 | 恢复 pub 缓存或首次需联网 |
| `Gradle download failed` | 离线模式未配置 | 配置 `gradle.properties` + 恢复缓存 |
| `VC++ not found` | VS Build Tools 未安装 | 安装 VS C++ 工作负载 |
| `compileSdk not found` | platform 未安装 | `sdkmanager "platforms;android-36"` |
| `Android license unknown` | licenses 文件夹缺失 | 复制 `licenses` 目录 |
| `flutter doctor -v` 警告 | 缺少 platform-tools | 复制 platform-tools 目录 |
| `CMake not found` | CMake 未安装 | `sdkmanager "cmake;3.22.1"` |

---

## 九、完整脚本集合

### A. macOS 下载脚本

```bash
#!/bin/bash
# download_all.sh
set -e

DOWNLOADS="$HOME/Downloads/windows-migration"
mkdir -p "$DOWNLOADS"

echo "=== 下载所有工具 ==="

# JDK 17
curl -L -o "$DOWNLOADS/jdk-17.zip" \
  "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.11%2B9/OpenJDK17U-jdk_x64_windows_hotspot_17.0.11_9.zip"

# Flutter
curl -L -o "$DOWNLOADS/flutter.zip" \
  "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"

# Android cmdline-tools
curl -L -o "$DOWNLOADS/cmdline-tools.zip" \
  "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"

# 7-Zip
curl -L -o "$DOWNLOADS/7z2408-x64.exe" \
  "https://www.7-zip.org/a/7z2408-x64.exe"

echo "=== 完成 ==="
ls -lh "$DOWNLOADS"
```

### B. macOS 打包脚本

```bash
#!/bin/bash
# package_source.sh
set -e

cd /Users/wangxinran/StudioProjects

echo "=== 打包源代码 ==="
tar -cvzf flutter_module.tar.gz flutter_module/
tar -cvzf MyApplicationForFlutter.tar.gz MyApplicationForFlutter/

echo "=== 完成 ==="
ls -lh *.tar.gz
```

### C. Windows 配置脚本

```batch
@echo off
REM setup.bat

echo [1/4] 设置环境变量...
setx ANDROID_HOME "D:\android-sdk" /M
setx ANDROID_SDK_ROOT "D:\android-sdk" /M
setx JAVA_HOME "D:\jdk-17" /M
setx FLUTTER_HOME "D:\flutter" /M

echo [2/4] 添加 PATH...
setx PATH "%PATH%;D:\flutter\bin;D:\jdk-17\bin;D:\android-sdk\cmdline-tools\latest\bin;D:\android-sdk\platform-tools" /M

echo [3/4] 配置 Gradle 离线模式...
echo org.gradle.offline=true >> D:\workspace\MyApplicationForFlutter\gradle.properties
echo org.gradle.caching=true >> D:\workspace\MyApplicationForFlutter\gradle.properties

echo [4/4] 完成
echo 请重启终端
pause
```

### D. Docker 构建脚本 (ARM)

```bash
#!/bin/bash
# build.sh - 一键构建所有产物
# 在容器内执行，放在 /workspace/build.sh

set -e

PROJECT_ROOT="/workspace"
OUTPUT_DIR="/workspace/output"

echo "=========================================="
echo "  RTC Flutter + Android SDK 一键构建"
echo "=========================================="
echo ""

mkdir -p "$OUTPUT_DIR/repo"

# 1. Flutter APK
echo "[1/4] 构建 Flutter APK (Debug)..."
cd "$PROJECT_ROOT/flutter_module"
flutter build apk --debug
cp build/app/outputs/flutter-apk/app-debug.apk "$OUTPUT_DIR/flutter-debug.apk"

# 2. Flutter AAR
echo "[2/4] 构建 Flutter AAR..."
flutter build aar --debug
flutter build aar --profile
flutter build aar --release

# 3. 统一 Repo
echo "[3/4] 发布 rsc-sdk 到统一 Repo..."
cd "$PROJECT_ROOT/MyApplicationForFlutter"
./gradlew :rsc-sdk:publishReleasePublicationToMavenRepository
cp -r "$PROJECT_ROOT/flutter_module/build/host/outputs/repo/"* "$OUTPUT_DIR/repo/"

# 4. Native APK
echo "[4/4] 构建 Native APK..."
./gradlew :app:assembleDebug
./gradlew :app:assembleRelease
cp app/build/outputs/apk/debug/app-debug.apk "$OUTPUT_DIR/native-debug.apk"
cp app/build/outputs/apk/release/app-release.apk "$OUTPUT_DIR/native-release.apk"

echo ""
echo "构建完成！"
ls -lh "$OUTPUT_DIR/"
```

---

## 十、Docker 构建方案（Linux x64 服务器）

> ⚠️ **注意**：Flutter SDK 仅提供 **Linux x86_64** 版本，不提供 Linux ARM64 版本。
> 因此无法在 ARM 服务器（如 Apple Silicon Mac 的 Docker 镜像）上编译 Flutter AAR。

### 10.1 方案说明

如果你有 **Linux x64** 服务器，可以使用 Docker 进行离线构建。

| 需求 | 说明 |
|------|------|
| 工具链 | JDK + Flutter (x86_64) + Android SDK |
| 服务器架构 | Linux x86_64（不可用 ARM） |
| 一键编译 | 执行一个命令生成所有产物 |

### 10.2 为什么不需要 NDK？

Flutter 插件（如 `flutter_webrtc`、`mic_stream_recorder`）的原生库 (.so 文件) 是**预编译好的**，发布时已包含多架构版本：

```
flutter_webrtc/android/src/main/jniLibs/
├── arm64-v8a/    # ARM64 安卓手机
├── armeabi-v7a/  # 32位 ARM (老手机)
├── x86/         # x86 模拟器
└── x86_64/      # x86_64 模拟器
```

构建 APK 时，Flutter 会自动选择对应架构的 `.so` 文件，**不需要在构建时调用 NDK 编译器**。

### 10.2 架构说明（Linux x64 服务器）

```
本地 Mac (Intel/ARM)
       │
       │ docker build
       ▼
┌─────────────────────────────────────┐
│  Docker Image                       │  ← x86_64 架构
│  ├── Ubuntu 22.04                   │
│  ├── JDK 17                         │
│  ├── Flutter 3.24.5 (Linux x64)     │
│  ├── Android SDK (36)                │
│  ├── 项目代码                       │
│  └── 构建脚本                       │
└─────────────────────────────────────┘
       │
       │ 导出 tar，传输到 x64 服务器
       ▼
┌─────────────────────────────────────┐
│   Linux x64 服务器                   │  ← 一键运行
│   docker run rtc-builder ./build.sh │
└─────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  产物                               │
│  ├── flutter-debug.apk              │
│  ├── native-debug.apk               │
│  ├── native-release.apk            │
│  └── repo/ (统一 Maven)             │
└─────────────────────────────────────┘
```

### 10.3 Dockerfile

```dockerfile
# Dockerfile
FROM ubuntu:22.04

LABEL maintainer="your-email@example.com"
LABEL description="RTC Flutter + Android SDK 构建环境 - x86_64"

# ===== 1. 安装基础工具 =====
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    curl \
    git \
    openjdk-17-jdk \
    && rm -rf /var/lib/apt/lists/*

# ===== 2. Android SDK =====
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk

RUN wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip && \
    mkdir -p $ANDROID_HOME/cmdline-tools && \
    unzip -q /tmp/cmdline-tools.zip -d $ANDROID_HOME/cmdline-tools && \
    mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

RUN yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --sdk_root=$ANDROID_HOME \
    "platforms;android-35" \
    "build-tools;35.0.0"

# 注意：不需要 NDK 和 CMake！
# Flutter 插件的原生库 (.so) 是预编译的，构建时会自动选择对应架构

# ===== 3. Flutter =====
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=$PATH:$FLUTTER_HOME/bin

RUN wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.38.5-stable.zip -O /tmp/flutter.zip && \
    unzip -q /tmp/flutter.zip -d /opt/flutter && \
    rm /tmp/flutter.zip

RUN flutter precache --android

# ===== 4. 项目文件 =====
WORKDIR /workspace

# 复制 flutter_module（排除 build、.git、IDE 等）
COPY flutter_module/lib/ ./flutter_module/lib/
COPY flutter_module/assets/ ./flutter_module/assets/
COPY flutter_module/pubspec.yaml ./flutter_module/pubspec.yaml
COPY flutter_module/pubspec.lock ./flutter_module/pubspec.lock
COPY flutter_module/.metadata ./flutter_module/.metadata
COPY flutter_module/analysis_options.yaml ./flutter_module/analysis_options.yaml
COPY flutter_module/.flutter-plugins ./flutter_module/.flutter-plugins
COPY flutter_module/.flutter-plugins-dependencies ./flutter_module/.flutter-plugins-dependencies

# 复制 MyApplicationForFlutter（排除 build、.gradle、logs 等）
COPY MyApplicationForFlutter/app/ ./MyApplicationForFlutter/app/
COPY MyApplicationForFlutter/rsc-sdk/ ./MyApplicationForFlutter/rsc-sdk/
COPY MyApplicationForFlutter/lib/ ./MyApplicationForFlutter/lib/
COPY MyApplicationForFlutter/build.gradle ./MyApplicationForFlutter/build.gradle
COPY MyApplicationForFlutter/settings.gradle ./MyApplicationForFlutter/settings.gradle
COPY MyApplicationForFlutter/gradle.properties ./MyApplicationForFlutter/gradle.properties
COPY MyApplicationForFlutter/gradlew ./MyApplicationForFlutter/gradlew
COPY MyApplicationForFlutter/gradlew.bat ./MyApplicationForFlutter/gradlew.bat
COPY MyApplicationForFlutter/gradle/ ./MyApplicationForFlutter/gradle/
COPY MyApplicationForFlutter/local.properties ./MyApplicationForFlutter/local.properties

# 设置项目路径
ENV PROJECT_ROOT=/workspace

# ===== 5. Gradle 离线配置 =====
RUN echo "org.gradle.offline=true" >> $PROJECT_ROOT/MyApplicationForFlutter/gradle.properties && \
    echo "org.gradle.caching=true" >> $PROJECT_ROOT/MyApplicationForFlutter/gradle.properties

# ===== 5.1 下载 Flutter 依赖 =====
RUN cd $PROJECT_ROOT/flutter_module && flutter pub get

# ===== 5.2 下载 Gradle/Android 依赖 =====
RUN cd $PROJECT_ROOT/MyApplicationForFlutter && \
    chmod +x gradlew && \
    ./gradlew dependencies --offline || ./gradlew dependencies

# ===== 6. 一键构建脚本 =====
COPY build.sh /workspace/build.sh
RUN chmod +x /workspace/build.sh

WORKDIR /workspace
CMD ["/workspace/build.sh"]
```

### 10.3 构建镜像

```bash
# 在 ARM Mac 上构建
docker build -t rtc-builder:latest .

# 验证架构
docker inspect rtc-builder:latest --format '{{.Architecture}}'
# 预期输出: arm64
```

### 10.4 一键构建脚本 (build.sh)

```bash
#!/bin/bash
# build.sh - 一键构建所有产物
# 在容器内执行，放在 /workspace/build.sh

set -e

PROJECT_ROOT="/workspace"
OUTPUT_DIR="/workspace/output"

echo "=========================================="
echo "  RTC Flutter + Android SDK 一键构建"
echo "=========================================="
echo ""

# 创建输出目录
mkdir -p "$OUTPUT_DIR/repo"

# ===== 1. Flutter APK =====
echo "[1/4] 构建 Flutter APK (Debug)..."
cd "$PROJECT_ROOT/flutter_module"
flutter build apk --debug
cp build/app/outputs/flutter-apk/app-debug.apk "$OUTPUT_DIR/flutter-debug.apk"
echo "      -> $OUTPUT_DIR/flutter-debug.apk"

# ===== 2. Flutter AAR =====
echo "[2/4] 构建 Flutter AAR (Debug/Profile/Release)..."
flutter build aar --debug
flutter build aar --profile
flutter build aar --release
echo "      -> AAR 构建完成"

# ===== 3. 统一 Repo (Flutter AAR + rsc-sdk) =====
echo "[3/4] 发布 rsc-sdk 到统一 Repo..."
cd "$PROJECT_ROOT/MyApplicationForFlutter"
./gradlew :rsc-sdk:publishReleasePublicationToMavenRepository

# 复制 Flutter AAR 到 Repo
cp -r "$PROJECT_ROOT/flutter_module/build/host/outputs/repo/"* "$OUTPUT_DIR/repo/"
echo "      -> 统一 Repo 已生成"

# ===== 4. Native APK =====
echo "[4/4] 构建 Native APK..."
./gradlew :app:assembleDebug
./gradlew :app:assembleRelease

cp app/build/outputs/apk/debug/app-debug.apk "$OUTPUT_DIR/native-debug.apk"
cp app/build/outputs/apk/release/app-release.apk "$OUTPUT_DIR/native-release.apk"
echo "      -> $OUTPUT_DIR/native-debug.apk"
echo "      -> $OUTPUT_DIR/native-release.apk"

# ===== 完成 =====
echo ""
echo "=========================================="
echo "  构建完成！"
echo "=========================================="
echo ""
echo "产物清单:"
ls -lh "$OUTPUT_DIR/"
echo ""
echo "Maven Repo:"
ls -lh "$OUTPUT_DIR/repo/com/yc/rtc/" 2>/dev/null || echo "  (repo 目录结构见下方)"
find "$OUTPUT_DIR/repo" -type f -name "*.aar" | head -5
echo ""
echo "=========================================="
```

### 10.4 使用方法

```bash
# 1. 在本地构建镜像（x86_64）
docker build -t rtc-builder:latest .

# 验证架构
docker inspect rtc-builder:latest --format '{{.Architecture}}'
# 输出: amd64 (x86_64)

# 2. 导出为 tar 包
docker save -o rtc-builder.tar rtc-builder:latest

# 3. 传输到 Linux x64 服务器
# 方式 A: 文件拷贝
scp rtc-builder.tar user@x64-server:/path/

# 方式 B: 推送到 registry
docker push your-registry/rtc-builder:latest

# 4. 在 x64 服务器上加载并运行
docker load -i rtc-builder.tar
docker run -it --rm \
    -v /path/to/flutter_module:/workspace/flutter_module \
    -v /path/to/MyApplicationForFlutter:/workspace/MyApplicationForFlutter \
    -v /path/to/output:/workspace/output \
    rtc-builder:latest
```

### 10.6 产物结构

```
output/
├── flutter-debug.apk        # Flutter 独立 APK (可直接安装测试)
├── native-debug.apk         # Native + Flutter 组合 APK (Debug)
├── native-release.apk        # Native + Flutter 组合 APK (Release)
└── repo/                     # 统一的 Maven Repo
    └── com/
        └── yc/
            └── rtc/
                ├── flutter_module/
                │   ├── flutter_debug/1.0/flutter_debug-1.0.aar
                │   ├── flutter_profile/1.0/flutter_profile-1.0.aar
                │   └── flutter_release/1.0/flutter_release-1.0.aar
                └── rtc-sdk/
                    └── 1.0.0/rtc-sdk-1.0.0.aar
```

### 10.5 产物结构

```
output/
├── flutter-debug.apk        # Flutter 独立 APK
├── native-debug.apk         # Native + Flutter 组合 APK (Debug)
├── native-release.apk        # Native + Flutter 组合 APK (Release)
└── repo/                     # 统一的 Maven Repo
    └── com/
        └── yc/
            └── rtc/
                ├── flutter_module/
                │   ├── flutter_debug/1.0/
                │   ├── flutter_profile/1.0/
                │   └── flutter_release/1.0/
                └── rtc-sdk/
                    └── 1.0.0/
```

### 10.7 使用说明

```bash
# 启动容器（会自动执行 build.sh）
docker run -it --rm \
    -v $(pwd)/output:/workspace/output \
    rtc-builder:latest

# 或者只进入交互式终端
docker run -it --rm \
    -v $(pwd)/output:/workspace/output \
    rtc-builder:latest \
    bash

# 在容器内手动构建
cd /workspace
./build.sh
```

### A. macOS 下载脚本

```bash
#!/bin/bash
# download_all.sh
set -e

DOWNLOADS="$HOME/Downloads/windows-migration"
mkdir -p "$DOWNLOADS"

echo "=== 下载所有工具 ==="

# JDK 17
curl -L -o "$DOWNLOADS/jdk-17.zip" \
  "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.11%2B9/OpenJDK17U-jdk_x64_windows_hotspot_17.0.11_9.zip"

# Flutter
curl -L -o "$DOWNLOADS/flutter.zip" \
  "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"

# Android cmdline-tools
curl -L -o "$DOWNLOADS/cmdline-tools.zip" \
  "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"

# 7-Zip
curl -L -o "$DOWNLOADS/7z2408-x64.exe" \
  "https://www.7-zip.org/a/7z2408-x64.exe"

echo "=== 完成 ==="
ls -lh "$DOWNLOADS"
```

### B. macOS 打包脚本

```bash
#!/bin/bash
# package_source.sh
set -e

cd /Users/wangxinran/StudioProjects

echo "=== 打包源代码 ==="
tar -cvzf flutter_module.tar.gz flutter_module/
tar -cvzf MyApplicationForFlutter.tar.gz MyApplicationForFlutter/

echo "=== 完成 ==="
ls -lh *.tar.gz
```

### C. Windows 配置脚本

```batch
@echo off
REM setup.bat

echo [1/4] 设置环境变量...
setx ANDROID_HOME "D:\android-sdk" /M
setx ANDROID_SDK_ROOT "D:\android-sdk" /M
setx JAVA_HOME "D:\jdk-17" /M
setx FLUTTER_HOME "D:\flutter" /M

echo [2/4] 添加 PATH...
setx PATH "%PATH%;D:\flutter\bin;D:\jdk-17\bin;D:\android-sdk\cmdline-tools\latest\bin;D:\android-sdk\platform-tools" /M

echo [3/4] 配置 Gradle 离线模式...
echo org.gradle.offline=true >> D:\workspace\gradle.properties

echo [4/4] 完成
echo 请重启终端
pause
```

---

**文档版本**: 1.8  
**最后更新**: 2026-04-08  
**更新内容**:
- 移除 ARM Docker 方案（Flutter SDK 不支持 Linux ARM64）
- 明确只能在 Linux x64 服务器上使用 Docker 构建
- 更新架构说明为 x86_64
- Flutter 版本 3.24.5，compileSdk 36，minSdk 21
