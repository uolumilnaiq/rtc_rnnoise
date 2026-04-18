#include <jni.h>
#include <android/log.h>
#include <string.h>
#include "types.h"

#define TAG "RNNoise-Native"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, TAG, __VA_ARGS__)

extern "C" {
    void* rtc_rnnoise_create();
    float rtc_rnnoise_process(void* handle, AudioBufferPtr buffer, int num_samples, 
                              int sample_rate, int num_channels, int format, 
                              int layout, float mix_level);
    void rtc_rnnoise_destroy(void* handle);
}

static int debug_counter = 0;

extern "C"
JNIEXPORT jlong JNICALL
Java_com_rtc_rnnoise_RnnoiseProcessor_nativeCreate(JNIEnv *env, jobject thiz) {
    LOGD("Native engine created");
    return (jlong)rtc_rnnoise_create();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_rtc_rnnoise_RnnoiseProcessor_nativeProcess(JNIEnv *env, jobject thiz, 
                                                   jlong handle, jobject buffer, 
                                                   jint numSamples, jint sampleRate, 
                                                   jint numChannels, jint format, 
                                                   jint layout, jfloat mixLevel) {
    if (!handle || !buffer) return;

    void* audio_data = env->GetDirectBufferAddress(buffer);
    jlong capacity = env->GetDirectBufferCapacity(buffer);
    if (!audio_data) return;

    AudioBufferPtr ptr;
    ptr.interleaved_data = audio_data;
    ptr.non_interleaved_data = nullptr;

    // 格式识别：480 samples * 1 channel * 4 bytes = 1920
    int actual_format = (capacity >= numSamples * numChannels * 4) ? 1 : 0;

    // 调用 C++ 处理并获取 VAD 概率
    float vad = rtc_rnnoise_process((void*)handle, ptr, numSamples, sampleRate, numChannels, 
                                   actual_format, layout, mixLevel);

    // --- 数值防御：确保 VAD 在 [0, 1] 之间，防止 NaN 导致的溢出错误 ---
    if (!(vad >= 0.0f)) vad = 0.0f; // 处理 NaN 和 负值
    if (vad > 1.0f) vad = 1.0f;

    // 每 100 帧 (约 1 秒) 打印一次 VAD 指标
    debug_counter++;
    if (debug_counter >= 100) {
        LOGD("RNNoise_Status: VAD=%.2f, Level=%.2f, Format=%s", 
             vad, mixLevel, (actual_format == 1 ? "Float32" : "Int16"));
        debug_counter = 0;
    }
}

extern "C"
JNIEXPORT void JNICALL
Java_com_rtc_rnnoise_RnnoiseProcessor_nativeDestroy(JNIEnv *env, jobject thiz, jlong handle) {
    if (handle) {
        LOGD("Native engine destroyed");
        rtc_rnnoise_destroy((void*)handle);
    }
}
