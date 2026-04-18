import 'package:flutter_test/flutter_test.dart';
import 'package:rtc_rnnoise/rtc_rnnoise.dart';
import 'package:rtc_rnnoise/rtc_rnnoise_platform_interface.dart';
import 'package:rtc_rnnoise/rtc_rnnoise_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockRtcRnnoisePlatform
    with MockPlatformInterfaceMixin
    implements RtcRnnoisePlatform {

  @override
  Future<void> init() => Future.value();

  @override
  Future<void> setEnabled(bool enabled) => Future.value();

  @override
  Future<void> setSuppressionLevel(double level) => Future.value();
}

void main() {
  final RtcRnnoisePlatform initialPlatform = RtcRnnoisePlatform.instance;

  test('$MethodChannelRtcRnnoise is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRtcRnnoise>());
  });
}
