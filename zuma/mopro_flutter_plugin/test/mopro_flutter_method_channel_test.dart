import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mopro_flutter/mopro_flutter_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelMoproFlutter platform = MethodChannelMoproFlutter();
  const MethodChannel channel = MethodChannel('mopro_flutter');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    var leaves = ["3", "12117908060695761916205289021945666294466648454297996401752691981878568491412", "3", "4", "5"];
    expect(await platform.semaphoreProve("idSecret", leaves, "signal", "externalNullifier"), '42');
  });
}
