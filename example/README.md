# rtc_rnnoise example

A minimal Flutter app demonstrating real-time AI noise reduction via the `rtc_rnnoise` plugin.

## What it does

- Opens a microphone stream with WebRTC (`getUserMedia`)
- Injects RNNoise into the audio capture pipeline (pre-QMF wideband PCM on Android, `capturePostProcessingAdapter` on iOS)
- Displays real-time VAD (Voice Activity Detection) probability
- Provides a slider to adjust suppression level (0.0 – 1.0)

## Running

```bash
flutter pub get
flutter run
```

Android requires a physical device or an x86_64 emulator. iOS requires a physical device (WebRTC audio is not supported on Simulator).

## Key file

`lib/main.dart` — full example showing `RtcRnnoise.init()`, `attach()`, `setEnabled()`, `setSuppressionLevel()`, and `vadStream` usage.
