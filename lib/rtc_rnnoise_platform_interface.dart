import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'rtc_rnnoise_method_channel.dart';

abstract class RtcRnnoisePlatform extends PlatformInterface {
  RtcRnnoisePlatform() : super(token: _token);

  static final Object _token = Object();

  static RtcRnnoisePlatform _instance = MethodChannelRtcRnnoise();

  static RtcRnnoisePlatform get instance => _instance;

  static set instance(RtcRnnoisePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> init() {
    throw UnimplementedError('init() has not been implemented.');
  }

  Future<void> setEnabled(bool enabled) {
    throw UnimplementedError('setEnabled() has not been implemented.');
  }

  Future<void> setSuppressionLevel(double level) {
    throw UnimplementedError('setSuppressionLevel() has not been implemented.');
  }
}
