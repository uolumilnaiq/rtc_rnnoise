#ifndef RTC_RNNOISE_AUDIO_UTILS_H
#define RTC_RNNOISE_AUDIO_UTILS_H

#include <stdint.h>
#include <algorithm>
#include <cmath>

namespace rtc_rnnoise {

/**
 * @brief 限幅处理 (Clamping)，防止 int16_t 溢出
 */
static inline int16_t clamp_to_int16(float sample) {
    if (sample > 32767.0f) return 32767;
    if (sample < -32768.0f) return -32768;
    return static_cast<int16_t>(sample);
}

/**
 * @brief 立体声下混为单声道 (L + R) / 2
 */
static inline void downmix_stereo_to_mono(const float* stereo, float* mono, int num_samples) {
    for (int i = 0; i < num_samples; ++i) {
        mono[i] = (stereo[i * 2] + stereo[i * 2 + 1]) * 0.5f;
    }
}

/**
 * @brief 单声道上混为立体声 (复制 L 到 R)
 */
static inline void upmix_mono_to_stereo(const float* mono, float* stereo, int num_samples) {
    for (int i = 0; i < num_samples; ++i) {
        stereo[i * 2] = mono[i];
        stereo[i * 2 + 1] = mono[i];
    }
}

} // namespace rtc_rnnoise

#endif // RTC_RNNOISE_AUDIO_UTILS_H
