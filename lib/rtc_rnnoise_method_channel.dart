import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rtc_rnnoise_platform_interface.dart';

class MethodChannelRtcRnnoise extends RtcRnnoisePlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('rtc_rnnoise');

  @override
  Future<void> init() async {
    await methodChannel.invokeMethod<void>('init');
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    await methodChannel.invokeMethod<void>('setEnabled', {'enabled': enabled});
  }

  @override
  Future<void> setSuppressionLevel(double level) async {
    await methodChannel.invokeMethod<void>('setSuppressionLevel', {'level': level});
  }
}
