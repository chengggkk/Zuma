import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mopro_flutter/mopro_types.dart';

import 'mopro_flutter_platform_interface.dart';

/// An implementation of [MoproFlutterPlatform] that uses method channels.
class MethodChannelMoproFlutter extends MoproFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('mopro_flutter');

  // @override
  // Future<GenerateProofResult?> generateProof(
  //     String zkeyPath, String inputs) async {
  //   final proofResult = await methodChannel
  //       .invokeMethod<Map<Object?, Object?>>('generateProof', {
  //     'zkeyPath': zkeyPath,
  //     'inputs': inputs,
  //   });

  //   if (proofResult == null) {
  //     return null;
  //   }

  //   var generateProofResult = GenerateProofResult.fromMap(proofResult);

  //   return generateProofResult;
  // }

  @override
  Future<SemaphoreProveResult?> semaphoreProve(String idSecret,
      List<String> leaves, String signal, String externalNullifier) async {
    final proofResult = await methodChannel
        .invokeMethod<Map<Object?, Object?>>('semaphoreProve', {
      'idSecret': idSecret,
      'leaves': leaves,
      'signal': signal,
      'externalNullifier': externalNullifier,
    });

    if (proofResult == null) {
      return null;
    }

    var semaphoreProveResult = SemaphoreProveResult.fromMap(proofResult);

    return semaphoreProveResult;
  }

  @override
  Future<bool?> semaphoreVerify(String proof, String inputs) async {
    final valid = await methodChannel.invokeMethod<bool>('semaphoreVerify', {
      'proof': proof,
      'inputs': inputs,
    });

    return valid;
  }

  @override
  Future<String?> getIdCommitment(String idSecret) async {
    final commitment = await methodChannel
        .invokeMethod<String>('getIdCommitment', {'idSecret': idSecret});
    return commitment;
  }
}
