# Native Binary Reproduction (iOS)

This document describes how the `rtc_rnnoise.xcframework` was created. Regular users do not need to perform these steps.

## 📦 Current Distribution Strategy
The iOS implementation uses a pre-compiled **XCFramework** to support both physical devices and M3 Simulators seamlessly.
*   **Active Binary**: `ios/libs/rtc_rnnoise.xcframework`.
*   **Headers**: `src/cpp/third_party/` (minimal headers for linkage).

## 🛠️ How to Rebuild the XCFramework

To update the binary, you must first **restore the C source files** from the official repositories into the `src/cpp/third_party/` directory tree.

### 1. Build for Device (iphoneos arm64)
```bash
mkdir -p ios/build_iphoneos && cd ios/build_iphoneos
cmake -G Xcode -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_SYSROOT=iphoneos -DLIB_TYPE=STATIC ../../android/src/main/cpp
xcodebuild -project rtc_rnnoise.xcodeproj -target rtc_rnnoise -configuration Release -sdk iphoneos build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
cd ../..
```

### 2. Build for M3 Simulator (iphonesimulator arm64)
```bash
SIM_SYSROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
mkdir -p ios/build_sim_m3 && cd ios/build_sim_m3
# (Run clang compilation commands as defined in the maintainer's build script)
# ...
libtool -static -o librtc_rnnoise_sim.a *.o
cd ../..
```

### 3. Package as XCFramework
```bash
rm -rf ios/libs/rtc_rnnoise.xcframework
xcodebuild -create-xcframework \
  -library ios/build_iphoneos/Release-iphoneos/librtc_rnnoise.a \
  -library ios/build_sim_m3/librtc_rnnoise_sim.a \
  -output ios/libs/rtc_rnnoise.xcframework
```

## 🎯 Design Goal
The repository is optimized for **Flutter Pub Developers**. They receive the binary and headers, ensuring "Plug & Play" functionality without requiring a C++ toolchain or source management.
