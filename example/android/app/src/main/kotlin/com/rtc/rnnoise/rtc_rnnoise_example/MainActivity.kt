package com.rtc.rnnoise.rtc_rnnoise_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.rtc.rnnoise.RnnoiseProcessor
import com.rtc.rnnoise.rtc_rnnoise.RtcRnnoisePlugin
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.audio.AudioProcessingAdapter
import java.nio.ByteBuffer
import android.util.Log
import android.os.Handler
import android.os.Looper

class MainActivity: FlutterActivity() {
    private var rnnoiseProcessor: RnnoiseProcessor? = null
    private val handler = Handler(Looper.getMainLooper())
    private var injectionCount = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val processor = RnnoiseProcessor()
        rnnoiseProcessor = processor
        RtcRnnoisePlugin.activeProcessor = processor
        
        startInjectionAttempts(processor)
    }

    private fun startInjectionAttempts(processor: RnnoiseProcessor) {
        val runnable = object : Runnable {
            override fun run() {
                try {
                    val plugin = FlutterWebRTCPlugin.sharedSingleton
                    // 关键修正：通过 plugin.audioProcessingController 获取 (注意它可能是一个 getter)
                    val controller = plugin?.audioProcessingController
                    
                    if (controller != null) {
                        val webrtcProcessor = object : AudioProcessingAdapter.ExternalAudioFrameProcessing {
                            override fun initialize(sampleRateHz: Int, numChannels: Int) {
                                processor.initialize(sampleRateHz, numChannels)
                            }
                            override fun reset(newRate: Int) {
                                processor.reset(newRate)
                            }
                            override fun process(numBands: Int, numFrames: Int, buffer: ByteBuffer) {
                                processor.process(numBands, numFrames, buffer)
                            }
                        }
                        controller.capturePostProcessing.addProcessor(webrtcProcessor)
                        Log.d("RNNoise", "SUCCESS: AI Denoise Injected via correct path!")
                        return 
                    }
                } catch (e: Exception) {
                    Log.e("RNNoise", "Injection error: ${e.message}")
                }

                injectionCount++
                if (injectionCount < 30) { 
                    Log.d("RNNoise", "WebRTC not ready yet, retrying... ($injectionCount)")
                    handler.postDelayed(this, 1000)
                }
            }
        }
        handler.post(runnable)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        RtcRnnoisePlugin.activeProcessor = null
        rnnoiseProcessor?.release()
        super.onDestroy()
    }
}
