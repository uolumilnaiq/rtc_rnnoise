# Platform Support Status & Technical Limitations

## Android
*   **Status**: ✅ **Stable**
*   **Verification**: Tested on physical devices (Lenovo TB X616M, etc.)
*   **Implementation**: Native JNI Injection into `AudioProcessingAdapter`.
*   **Performance**: Excellent, full Neon optimization enabled.

## iOS
*   **Status**: ⚠️ **Experimental / Not Fully Supported**
*   **Technical Diagnosis**:
    *   The core RNNoise C++ engine and XCFramework are fully compatible with M3 (arm64) and physical devices.
    *   **Simulator Limitation**: The WebRTC iOS SDK (iphonesimulator) does not trigger the `ExternalAudioProcessingDelegate` callback for capture streams. This is a known limitation of the virtual audio driver in the simulator environment.
    *   **Physical Device**: Logic is implemented via Runtime Reflection, but has not been verified on physical hardware due to a lack of test devices.
*   **Recommendation**: Use for Android production. iOS requires physical device verification before production use.

## Technical Details (iOS Hook)
The iOS implementation uses Objective-C Runtime reflection to hook into `FlutterWebRTCPlugin` to avoid hard dependencies on WebRTC headers. 
Target Hook Point: `FlutterWebRTCPlugin.sharedSingleton.audioManager.capturePostProcessingAdapter`
