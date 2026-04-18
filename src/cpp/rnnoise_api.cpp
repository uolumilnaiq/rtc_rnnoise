#include "rnnoise_engine.h"
#include "types.h"

using namespace rtc_rnnoise;

extern "C" {

/**
 * @brief 创建降噪引擎实例
 */
void* rtc_rnnoise_create() {
    return new RnnoiseEngine();
}

/**
 * @brief 处理音频帧
 * @return VAD 概率
 */
float rtc_rnnoise_process(void* handle, AudioBufferPtr buffer, int num_samples, 
                          int sample_rate, int num_channels, int format, 
                          int layout, float mix_level) {
    if (!handle) return 0.0f;
    RnnoiseEngine* engine = static_cast<RnnoiseEngine*>(handle);
    return engine->Process(buffer, num_samples, sample_rate, num_channels, 
                          static_cast<AudioFormat>(format), 
                          static_cast<MemoryLayout>(layout), mix_level);
}

/**
 * @brief 销毁引擎实例
 */
void rtc_rnnoise_destroy(void* handle) {
    if (handle) {
        delete static_cast<RnnoiseEngine*>(handle);
    }
}

} // extern "C"
