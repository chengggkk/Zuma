import 'package:flutter_test/flutter_test.dart';
import 'package:mopro_flutter/mopro_flutter.dart';
import 'package:mopro_flutter/mopro_flutter_platform_interface.dart';
import 'package:mopro_flutter/mopro_flutter_method_channel.dart';
import 'package:mopro_flutter/mopro_types.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMoproFlutterPlatform
    with MockPlatformInterfaceMixin
    implements MoproFlutterPlatform {
  // @override
  // Future<GenerateProofResult?> generateProof(
  //         String zkeyPath, String inputs) =>
  //     Future.value(GenerateProofResult(
  //       ProofCalldata(
  //         G1Point("1", "2"),
  //         G2Point(["1", "2"], ["3", "4"]),
  //         G1Point("3", "4"),
  //       ),
  //       ["3", "5"],
  //     ));
  @override
  Future<SemaphoreProveResult?> semaphoreProve(String idSecret,
      List<String> leaves, String signal, String externalNullifier) {
    return Future.value(SemaphoreProveResult("proof", "inputs"));
  }
}

void main() {
  final MoproFlutterPlatform initialPlatform = MoproFlutterPlatform.instance;

  test('$MethodChannelMoproFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMoproFlutter>());
  });

  test('getPlatformVersion', () async {
    MoproFlutter moproFlutterPlugin = MoproFlutter();
    MockMoproFlutterPlatform fakePlatform = MockMoproFlutterPlatform();
    MoproFlutterPlatform.instance = fakePlatform;

    var leaves = [
      "3",
      "12117908060695761916205289021945666294466648454297996401752691981878568491412",
      "3",
      "4",
      "5"
    ];
    
    var result = await moproFlutterPlugin.semaphoreProve(
        "idSecret", leaves, "signal", "externalNullifier");
    print(result?.proof);
    print(result?.inputs);
  });
}
