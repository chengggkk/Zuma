package com.example.mopro_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import uniffi.mopro.semaphoreProve
import uniffi.mopro.semaphoreVerify
import uniffi.mopro.ProofResult

import io.flutter.plugin.common.StandardMethodCodec
/** MoproFlutterPlugin */
class MoproFlutterPlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "mopro_flutter",
            StandardMethodCodec.INSTANCE
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "generateProof") {
            val zkeyPath = call.argument<String>("zkeyPath") ?: return result.error(
                "ARGUMENT_ERROR",
                "Missing zkeyPath",
                null
            )

            val inputs =
                call.argument<String>("inputs") ?: return result.error(
                    "ARGUMENT_ERROR",
                    "Missing inputs",
                    null
                )

            val res = generateCircomProof(zkeyPath, inputs, ProofLib.ARKWORKS)
            val proof: ProofCalldata = toEthereumProof(res.proof)
            val convertedInputs: List<String> = toEthereumInputs(res.inputs)

            val proofList = listOf(
                mapOf(
                    "x" to proof.a.x,
                    "y" to proof.a.y
                ), mapOf(
                    "x" to proof.b.x,
                    "y" to proof.b.y
                ), mapOf(
                    "x" to proof.c.x,
                    "y" to proof.c.y
                )
            )

            // Return the proof and inputs as a map supported by the StandardMethodCodec
            val resMap = mapOf(
                "proof" to proofList,
                "inputs" to convertedInputs
            )

            result.success(
                resMap
            )
        } else if (call.method == "semaphoreProve") {
            val idSecret = call.argument<String>("idSecret") ?: return result.error(
                "ARGUMENT_ERROR",
                "Missing idSecret",
                null
            )
            val leaves = call.argument<List<String>>("leaves") ?: return result.error(
                "ARGUMENT_ERROR",
                "Missing leaves",
                null
            )
            val signal = call.argument<String>("signal") ?: return result.error(
                "ARGUMENT_ERROR",
                "Missing signal",
                null
            )
            val externalNullifier = call.argument<String>("externalNullifier") ?: return result.error(
                "ARGUMENT_ERROR",
                "Missing externalNullifier",
                null
            )

            val proofResult = semaphoreProve(idSecret, leaves, signal, externalNullifier)
            val proof = proofResult.proof
            val inputs = proofResult.inputs

            val resMap = mapOf(
                "proof" to proof,
                "inputs" to inputs
            )

            result.success(resMap)
        } else if (call.method == "semaphoreVerify") {
            val proof = call.argument<String>("proof") ?: return result.error(
                "ARGUMENT_ERROR",
                "Missing proof",
                null
            )
            val inputs = call.argument<String>("inputs") ?: return result.error(
                "ARGUMENT_ERROR",
                "Missing inputs",
                null
            )

            val proofResult = ProofResult(proof, inputs)
            val valid = semaphoreVerify(proofResult)
            result.success(valid)
        } else if (call.method == "getIdCommitment") {
            val idSecret = call.argument<String>("idSecret") ?: return result.error(
                "ARGUMENT_ERROR",
                "Missing idSecret",
                null
            )
            val commitment = getIdCommitment(idSecret)
            result.success(commitment)
        } else {
            result.notImplemented()
        }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
