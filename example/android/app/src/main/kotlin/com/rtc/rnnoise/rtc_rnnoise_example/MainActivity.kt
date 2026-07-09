package com.rtc.rnnoise.rtc_rnnoise_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.rtc.rnnoise.RnnoiseProcessor
import com.rtc.rnnoise.rtc_rnnoise.RtcRnnoisePlugin
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import org.webrtc.audio.JavaAudioDeviceModule
import java.lang.reflect.Field
import java.nio.ByteBuffer
import android.util.Log

class MainActivity : FlutterActivity() {
    private var rnnoiseProcessor: RnnoiseProcessor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val processor = RnnoiseProcessor()
        rnnoiseProcessor = processor
        RtcRnnoisePlugin.activeProcessor = processor

        RtcRnnoisePlugin.attachProvider = object : RtcRnnoisePlugin.AttachProvider {
            override fun onAttach(): Boolean {
                return injectAudioBufferCallback(processor)
            }
        }
    }

    private fun injectAudioBufferCallback(processor: RnnoiseProcessor): Boolean {
        try {
            val plugin = FlutterWebRTCPlugin.sharedSingleton
                ?: return logFail("sharedSingleton is null")

            // 反射获取 private MethodCallHandlerImpl
            val mhField = plugin.javaClass.getDeclaredField("methodCallHandler")
            mhField.isAccessible = true
            val methodHandler = mhField.get(plugin)
                ?: return logFail("methodCallHandler is null")

            // 反射获取 private JavaAudioDeviceModule
            val admField = methodHandler.javaClass.getDeclaredField("audioDeviceModule")
            admField.isAccessible = true
            val adm = admField.get(methodHandler)
                ?: return logFail("audioDeviceModule is null")

            // public final WebRtcAudioRecord audioInput
            val audioInput = adm.javaClass.getField("audioInput").get(adm)
                ?: return logFail("audioInput is null")

            // 反射修改 private final AudioBufferCallback audioBufferCallback
            val cbField = audioInput.javaClass.getDeclaredField("audioBufferCallback")
            cbField.isAccessible = true

            // bytesRead = byteBuffer.capacity()；int16 = 2 bytes/sample
            val callback = JavaAudioDeviceModule.AudioBufferCallback { buffer, _, channelCount, sampleRate, bytesRead, captureTimestampNs ->
                val safeChannels = channelCount.coerceAtLeast(1)
                val numFrames = bytesRead / (2 * safeChannels)
                processor.processPcmBuffer(buffer, sampleRate, safeChannels, numFrames)
                captureTimestampNs
            }

            setFinalField(cbField, audioInput, callback)

            Log.d("RNNoise", "AudioBufferCallback injected (pre-QMF wideband PCM)")
            return true
        } catch (e: Exception) {
            Log.e("RNNoise", "inject failed: ${e.javaClass.simpleName}: ${e.message}")
            return false
        }
    }

    /**
     * 设置 private final 字段。
     * 先用 Field.set()，若被拒绝（IllegalAccessException / InaccessibleObjectException）
     * 则降级用 sun.misc.Unsafe 绕过。任何路径失败都会向上抛出。
     */
    private fun setFinalField(field: Field, target: Any, value: Any?) {
        try {
            field.set(target, value)
            return
        } catch (_: IllegalAccessException) {
            // 继续尝试 Unsafe
        } catch (e: RuntimeException) {
            // Android 12+ InaccessibleObjectException extends RuntimeException
            if (e.javaClass.name != "java.lang.reflect.InaccessibleObjectException") throw e
            // 继续尝试 Unsafe
        }

        // Unsafe 路径：不受 non-SDK 接口限制
        try {
            val unsafeClass = Class.forName("sun.misc.Unsafe")
            val unsafeField = unsafeClass.getDeclaredField("theUnsafe")
            unsafeField.isAccessible = true
            val unsafe = unsafeField.get(null)
            val offsetMethod = unsafeClass.getMethod("objectFieldOffset", Field::class.java)
            val offset = offsetMethod.invoke(unsafe, field) as Long
            val putMethod = unsafeClass.getMethod("putObject", Any::class.java, Long::class.javaPrimitiveType, Any::class.java)
            putMethod.invoke(unsafe, target, offset, value)
        } catch (e: Exception) {
            throw RuntimeException("setFinalField via Unsafe failed for ${field.name}", e)
        }
    }

    private fun logFail(msg: String): Boolean {
        Log.e("RNNoise", "inject failed: $msg")
        return false
    }

    override fun onDestroy() {
        RtcRnnoisePlugin.activeProcessor = null
        RtcRnnoisePlugin.attachProvider = null
        rnnoiseProcessor?.release()
        super.onDestroy()
    }
}
