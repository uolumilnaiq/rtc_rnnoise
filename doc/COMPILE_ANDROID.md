# Native Binary Reproduction (Android)

This document is for **maintainers** who need to re-compile or update the pre-compiled `.so` binaries. 

## 📦 Current Distribution Strategy
The `rtc_rnnoise` package follows a **Binary-Only** distribution to keep the package size minimal and installation fast.
*   **Active Binaries**: Located in `android/src/main/jniLibs/`.
*   **Headers**: Located in `src/cpp/third_party/` (headers only, no source logic).

## 🛠️ How to Recompile (Advanced)

If you need to update the binaries, follow these steps to restore the environment:

### 1. Restore Source Code
Since this is a slimmed repository, you must fetch the source code from external sources:
*   **RNNoise (v0.2)**: Clone [xiph/rnnoise](https://github.com/xiph/rnnoise) and copy `.c` files into `src/cpp/third_party/rnnoise/src/`.
*   **SpeexDSP (1.2.1)**: Clone [xiph/speexdsp](https://github.com/xiph/speexdsp) and copy `.c` files into `src/cpp/third_party/speexdsp/libspeexdsp/`.

### 2. Build Commands
Once the source is restored, use the standard NDK workflow:

```bash
NDK_PATH=~/Library/Android/sdk/ndk/27.0.12077973
CMAKE_PATH=~/Library/Android/sdk/cmake/3.22.1/bin/cmake

for ABI in arm64-v8a armeabi-v7a x86_64; do
  mkdir -p android/build_$ABI && cd android/build_$ABI
  $CMAKE_PATH \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_PATH/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=$ABI \
    -DANDROID_PLATFORM=android-24 \
    -DCMAKE_BUILD_TYPE=Release \
    ../src/main/cpp
  make -j4
  cp librtc_rnnoise.so ../src/main/jniLibs/$ABI/
  cd ../..
done
```

## 📜 Source Provenance
| Library | Version | Role |
| :--- | :--- | :--- |
| RNNoise | v0.2 | AI Noise Reduction |
| SpeexDSP | 1.2.1 | Pre-processing |
