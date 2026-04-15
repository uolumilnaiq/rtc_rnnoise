package com.rtc.rnnoise;

import java.nio.ByteBuffer;
import android.util.Log;
import com.rtc.rnnoise.rtc_rnnoise.RtcRnnoisePlugin;

public class RnnoiseProcessor {
    private long nativeHandle = 0;
    private float mixLevel = 1.0f;
    private boolean enabled = true;
    private int sampleRate = 48000;
    private int numChannels = 1;
    private int processCounter = 0;

    static {
        System.loadLibrary("rtc_rnnoise");
    }

    public RnnoiseProcessor() {
        nativeHandle = nativeCreate();
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public void setMixLevel(float mixLevel) {
        this.mixLevel = mixLevel;
    }

    public void initialize(int sampleRateHz, int numChannels) {
        this.sampleRate = sampleRateHz;
        this.numChannels = numChannels;
    }

    public void reset(int newRate) {
        this.sampleRate = newRate;
    }

    public void process(int numBands, int numFrames, ByteBuffer buffer) {
        if (!enabled || nativeHandle == 0) return;
        
        float vad = nativeProcess(nativeHandle, buffer, numFrames, this.sampleRate, this.numChannels, 1, 0, mixLevel); 

        // 每 20 帧 (约 200ms) 回传一次 VAD 到 UI 层
        processCounter++;
        if (processCounter >= 20) {
            RtcRnnoisePlugin.sendVadUpdate(vad);
            processCounter = 0;
        }
    }

    public void release() {
        if (nativeHandle != 0) {
            nativeDestroy(nativeHandle);
            nativeHandle = 0;
        }
    }

    private native long nativeCreate();
    private native float nativeProcess(long handle, ByteBuffer buffer, int numSamples, 
                                      int sampleRate, int numChannels, int format, 
                                      int layout, float mixLevel);
    private native void nativeDestroy(long handle);
}
