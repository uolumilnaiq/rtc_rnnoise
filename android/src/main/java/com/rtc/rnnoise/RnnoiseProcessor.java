package com.rtc.rnnoise;

import java.nio.ByteBuffer;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;
import android.util.Log;
import com.rtc.rnnoise.rtc_rnnoise.RtcRnnoisePlugin;

public class RnnoiseProcessor {
    // AtomicLong 保证 nativeHandle 的可见性和 release() 的 CAS 原子性，
    // 防止音频线程 use-after-free（processPcmBuffer 与主线程 release() 并发）。
    private final AtomicLong nativeHandle = new AtomicLong(0);
    private final AtomicBoolean enabled = new AtomicBoolean(true);
    private volatile float mixLevel = 1.0f;
    private volatile int sampleRate = 48000;
    private volatile int numChannels = 1;
    private int processCounter = 0;  // 仅音频线程访问，无需 volatile

    static {
        System.loadLibrary("rtc_rnnoise");
    }

    public RnnoiseProcessor() {
        nativeHandle.set(nativeCreate());
    }

    public void setEnabled(boolean en) {
        enabled.set(en);
    }

    public void setMixLevel(float level) {
        this.mixLevel = level;
    }

    public void initialize(int sampleRateHz, int channels) {
        this.sampleRate = sampleRateHz;
        this.numChannels = channels;
        Log.d("RNNoiseAndroid", "initialize: sampleRateHz=" + sampleRateHz + " channels=" + channels);
    }

    public void reset(int newRate) {
        this.sampleRate = newRate;
        Log.d("RNNoiseAndroid", "reset: newRate=" + newRate);
    }

    @Deprecated
    public void process(int numBands, int numFrames, ByteBuffer buffer) {
        // ExternalAudioFrameProcessing 传入 QMF 子带数据，直接处理会产生相位混叠。已弃用。
    }

    /**
     * 处理完整宽带 PCM int16 数据（来自 AudioBufferCallback，位于 QMF 之前）。
     * buffer 为 DirectByteBuffer，数据会被原地修改。
     */
    public float processPcmBuffer(ByteBuffer buffer, int sampleRate, int numChannels, int numFrames) {
        if (!enabled.get()) return 0f;
        long handle = nativeHandle.get();
        if (handle == 0) return 0f;

        float vad = nativeProcess(handle, buffer, numFrames, sampleRate, numChannels, 0, 0, mixLevel);
        if (Float.isNaN(vad) || Float.isInfinite(vad) || vad < 0f || vad > 1f) vad = 0f;
        processCounter++;
        if (processCounter >= 20) {
            RtcRnnoisePlugin.sendVadUpdate(vad);
            Log.d("RNNoiseAndroid", "AudioBufCB vad=" + vad + " sr=" + sampleRate + " frames=" + numFrames);
            processCounter = 0;
        }
        return vad;
    }

    public void release() {
        // CAS 将 handle 置 0，确保 nativeDestroy 只被调用一次，
        // 且不会与 processPcmBuffer 中 nativeHandle.get() 产生 use-after-free。
        long handle = nativeHandle.getAndSet(0);
        if (handle != 0) {
            nativeDestroy(handle);
        }
    }

    private native long nativeCreate();
    private native float nativeProcess(long handle, ByteBuffer buffer, int numSamples,
                                      int sampleRate, int numChannels, int format,
                                      int layout, float mixLevel);
    private native void nativeDestroy(long handle);
}
