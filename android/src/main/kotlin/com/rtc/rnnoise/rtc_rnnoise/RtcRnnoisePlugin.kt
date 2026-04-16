package com.rtc.rnnoise.rtc_rnnoise

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import com.rtc.rnnoise.RnnoiseProcessor
import android.os.Handler
import android.os.Looper
import android.util.Log

class RtcRnnoisePlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var methodChannel : MethodChannel
  private lateinit var eventChannel : EventChannel
  
  interface AttachProvider {
    fun onAttach() : Boolean
  }

  companion object {
    var activeProcessor: RnnoiseProcessor? = null
    var eventSink: EventChannel.EventSink? = null
    var attachProvider: AttachProvider? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    @JvmStatic
    fun sendVadUpdate(vad: Float) {
      if (eventSink == null) return
      if (vad.isNaN() || vad < 0.0 || vad > 1.0) return
      mainHandler.post {
        eventSink?.success(vad.toDouble())
      }
    }
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "rtc_rnnoise")
    methodChannel.setMethodCallHandler(this)

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "rtc_rnnoise_events")
    eventChannel.setStreamHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    Log.i("RNNoise-Plugin", "CRITICAL: onMethodCall received -> ${call.method}")
    when (call.method) {
      "init" -> {
        if (activeProcessor == null) {
          activeProcessor = RnnoiseProcessor()
        }
        result.success(null)
      }
      "attach" -> {
        // 核心：由宿主提供的 Provider 执行真正的 attach
        val success = attachProvider?.onAttach() ?: false
        result.success(success)
      }
      "setEnabled" -> {
        val enabled = call.argument<Boolean>("enabled") ?: true
        activeProcessor?.setEnabled(enabled)
        result.success(null)
      }
      "setSuppressionLevel" -> {
        val level = call.argument<Double>("level") ?: 1.0
        activeProcessor?.setMixLevel(level.toFloat())
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
  override fun onCancel(arguments: Any?) { eventSink = null }

  override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }
}
