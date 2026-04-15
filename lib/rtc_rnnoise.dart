import 'package:flutter/services.dart';

class RtcRnnoise {
  static const MethodChannel _methodChannel = MethodChannel('rtc_rnnoise');
  static const EventChannel _eventChannel = EventChannel('rtc_rnnoise_events');

  static Future<void> init() async {
    await _methodChannel.invokeMethod('init');
  }

  static Future<void> setEnabled(bool enabled) async {
    await _methodChannel.invokeMethod('setEnabled', {'enabled': enabled});
  }

  static Future<void> setSuppressionLevel(double level) async {
    await _methodChannel.invokeMethod('setSuppressionLevel', {'level': level});
  }

  /// 监听实时 VAD 概率流 (0.0 ~ 1.0)
  static Stream<double> get vadStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event as double);
  }
}
