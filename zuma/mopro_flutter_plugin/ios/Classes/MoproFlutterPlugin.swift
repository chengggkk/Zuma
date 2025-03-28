import Flutter
import UIKit
import moproFFI

public class MoproFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "mopro_flutter", binaryMessenger: registrar.messenger())
    let instance = MoproFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    // case "generateProof":
    //     guard let args = call.arguments as? [String: Any],
    //           let zkeyPath = args["zkeyPath"] as? String,
    //           let inputs = args["inputs"] as? String
    //     else {
    //         result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing arguments", details: nil))
    //         return
    //     }

    //     do {
    //         // Call the function from mopro.swift
    //         let proofResult = try generateCircomProof(zkeyPath: zkeyPath, circuitInputs: inputs, proofLib: ProofLib.arkworks)
    //         let proof = toEthereumProof(proof: proofResult.proof)
    //         let convertedInputs = toEthereumInputs(inputs: proofResult.inputs)

    //         let proofList: [[String: Any]] = [
    //             ["x": proof.a.x, "y": proof.a.y],
    //             ["x": proof.b.x, "y": proof.b.y],
    //             ["x": proof.c.x, "y": proof.c.y]
    //         ]

    //         let resMap: [String: Any] = [
    //             "proof": proofList,
    //             "inputs": convertedInputs
    //         ]

    //         // Return the proof and inputs as a map supported by the StandardMethodCodec
    //         result(resMap)
    //     } catch {
    //         result(FlutterError(code: "PROOF_GENERATION_ERROR", message: "Failed to generate proof", details: error.localizedDescription))
    //     }

    // default:
    //     result(FlutterMethodNotImplemented)
    // }
    case "semaphoreProve":
      guard let args = call.arguments as? [String: Any],
        let idSecret = args["idSecret"] as? String,
        let leaves = args["leaves"] as? [String],
        let signal = args["signal"] as? String,
        let externalNullifier = args["externalNullifier"] as? String
      else {
        result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing arguments", details: nil))
        return
      }

      do {
        // Call the function from mopro.swift
        let proofResult = try semaphoreProve(
          idSecret: idSecret, leaves: leaves, signal: signal, externalNullifier: externalNullifier)

        let resMap: [String: Any] = [
          "proof": proofResult.proof,
          "inputs": proofResult.inputs,
        ]

        // Return the proof and inputs as a map supported by the StandardMethodCodec
        result(resMap)
      } catch {
        result(
          FlutterError(
            code: "PROOF_GENERATION_ERROR", message: "Failed to generate proof",
            details: error.localizedDescription))
      }

    case "semaphoreVerify":
      guard let args = call.arguments as? [String: Any],
        let proof = args["proof"] as? String,
        let inputs = args["inputs"] as? String
      else {
        result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing arguments", details: nil))
        return
      }

      do {
        // Call the function from mopro.swift
        let proofResult = ProofResult(inputs: inputs, proof: proof)
        let valid = try semaphoreVerify(proof: proofResult)
        result(valid)
      } catch {
        result(
          FlutterError(
            code: "PROOF_VERIFICATION_ERROR", message: "Failed to verify proof",
            details: error.localizedDescription))
      }

    case "getIdCommitment":
      guard let args = call.arguments as? [String: Any],
        let idSecret = args["idSecret"] as? String
      else {
        result(FlutterError(code: "ARGUMENT_ERROR", message: "Missing arguments", details: nil))
        return
      }

      do {
        // Call the function from mopro.swift
        let commitment = try getIdCommitment(idSecret: idSecret)
        result(commitment)
      } catch {
        result(
          FlutterError(
            code: "COMMITMENT_GENERATION_ERROR", message: "Failed to generate commitment",
            details: error.localizedDescription))
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
