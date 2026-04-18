package com.rtc.rnnoise.rtc_rnnoise_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.rtc.rnnoise.RnnoiseProcessor
import com.rtc.rnnoise.rtc_rnnoise.RtcRnnoisePlugin
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.audio.AudioProcessingAdapter
import java.nio.ByteBuffer
import android.util.Log

class MainActivity: FlutterActivity() {
    private var rnnoiseProcessor: RnnoiseProcessor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 1. 初始化处理器
        val processor = RnnoiseProcessor()
        rnnoiseProcessor = processor
        RtcRnnoisePlugin.activeProcessor = processor
        
        // 2. 实现挂载协议：当 Dart 调用 attach 时，这里的代码将被执行
        RtcRnnoisePlugin.attachProvider = object : RtcRnnoisePlugin.AttachProvider {
            override fun onAttach(): Boolean {
                try {
                    val plugin = FlutterWebRTCPlugin.sharedSingleton
                    val controller = plugin?.audioProcessingController
                    if (controller != null) {
                        val webrtcProcessor = object : AudioProcessingAdapter.ExternalAudioFrameProcessing {
                            override fun initialize(rate: Int, channels: Int) {
                                processor.initialize(rate, channels)
                            }
                            override fun reset(rate: Int) {
                                processor.reset(rate)
                            }
                            override fun process(bands: Int, frames: Int, buffer: ByteBuffer) {
                                processor.process(bands, frames, buffer)
                            }
                        }
                        controller.capturePostProcessing.addProcessor(webrtcProcessor)
                        Log.d("RNNoise", "SUCCESS: RNNoise attached via Dart Command (Scheme D)!")
                        return true
                    }
                } catch (e: Exception) {
                    Log.e("RNNoise", "Attach Error: ${e.message}")
                }
                return false
            }
        }
    }

    override fun onDestroy() {
        RtcRnnoisePlugin.activeProcessor = null
        RtcRnnoisePlugin.attachProvider = null
        rnnoiseProcessor?.release()
        super.onDestroy()
    }
}
