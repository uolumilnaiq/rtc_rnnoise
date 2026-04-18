import 'package:flutter/services.dart';

class RtcRnnoise {
  static const MethodChannel _methodChannel = MethodChannel('rtc_rnnoise');
  static const EventChannel _eventChannel = EventChannel('rtc_rnnoise_events');

  static Future<void> init() async {
    await _methodChannel.invokeMethod('init');
  }

  /// 核心：将降噪处理器挂载到 WebRTC 音频管道
  /// 请在 getUserMedia 或 createPeerConnection 之后调用
  static Future<bool> attach() async {
    final bool? success = await _methodChannel.invokeMethod<bool>('attach');
    return success ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    await _methodChannel.invokeMethod('setEnabled', {'enabled': enabled});
  }

  static Future<void> setSuppressionLevel(double level) async {
    await _methodChannel.invokeMethod('setSuppressionLevel', {'level': level});
  }

  static Stream<double> get vadStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event as double);
  }
}
