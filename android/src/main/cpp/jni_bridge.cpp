#include <jni.h>
#include <android/log.h>
#include <string.h>
#include <atomic>
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

static std::atomic<int> debug_counter{0};

extern "C"
JNIEXPORT jlong JNICALL
Java_com_rtc_rnnoise_RnnoiseProcessor_nativeCreate(JNIEnv *env, jobject thiz) {
    LOGD("Native engine created");
    return (jlong)rtc_rnnoise_create();
}

extern "C"
JNIEXPORT jfloat JNICALL
Java_com_rtc_rnnoise_RnnoiseProcessor_nativeProcess(JNIEnv *env, jobject thiz,
                                                   jlong handle, jobject buffer,
                                                   jint numSamples, jint sampleRate,
                                                   jint numChannels, jint format,
                                                   jint layout, jfloat mixLevel) {
    if (!handle || !buffer) return 0.0f;

    void* audio_data = env->GetDirectBufferAddress(buffer);
    jlong capacity = env->GetDirectBufferCapacity(buffer);
    if (!audio_data) return 0.0f;

    AudioBufferPtr ptr;
    ptr.interleaved_data = audio_data;
    ptr.non_interleaved_data = nullptr;

    // format=0 → INT16, format=1 → FLOAT32
    // 若调用方传入 format=-1，则自动检测（兼容旧调用）
    int actual_format = (format >= 0) ? format : ((capacity >= numSamples * numChannels * 4) ? 1 : 0);

    float vad = rtc_rnnoise_process((void*)handle, ptr, numSamples, sampleRate, numChannels,
                                   actual_format, layout, mixLevel);

    if (!(vad >= 0.0f)) vad = 0.0f;
    if (vad > 1.0f) vad = 1.0f;

    debug_counter++;
    if (debug_counter >= 100) {
        LOGD("RNNoise_Status: VAD=%.2f, Level=%.2f, Format=%s",
             vad, mixLevel, (actual_format == 1 ? "Float32" : "Int16"));
        debug_counter = 0;
    }
    return vad;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_rtc_rnnoise_RnnoiseProcessor_nativeDestroy(JNIEnv *env, jobject thiz, jlong handle) {
    if (handle) {
        LOGD("Native engine destroyed");
        rtc_rnnoise_destroy((void*)handle);
    }
}
