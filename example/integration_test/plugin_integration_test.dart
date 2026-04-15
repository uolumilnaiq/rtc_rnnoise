import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rtc_rnnoise/rtc_rnnoise.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('init test', (WidgetTester tester) async {
    // 仅仅测试初始化是否报错
    await RtcRnnoise.init();
    expect(true, true);
  });
}
