#ifndef RTC_RNNOISE_C_API_H
#define RTC_RNNOISE_C_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define RTC_RNNOISE_API __declspec(dllexport)
#else
#define RTC_RNNOISE_API __attribute__((visibility("default")))
#endif

typedef struct RtcRnnoiseContext RtcRnnoiseContext;

/**
 * Create a new RNNoise context.
 * @param sample_rate Input/output sample rate.
 * @param channels Number of channels.
 * @return Context pointer, or NULL on failure.
 */
RTC_RNNOISE_API RtcRnnoiseContext* rtc_rnnoise_create(uint32_t sample_rate, uint32_t channels);

/**
 * Process audio.
 * @param ctx Context pointer.
 * @param input_buffer Input buffer (int16_t interleaved).
 * @param output_buffer Output buffer (int16_t interleaved).
 * @param num_samples_per_channel Number of samples per channel.
 */
RTC_RNNOISE_API void rtc_rnnoise_process(RtcRnnoiseContext* ctx, const int16_t* input_buffer, int16_t* output_buffer, uint32_t num_samples_per_channel);

/**
 * Set dry/wet mix ratio.
 * @param ctx Context pointer.
 * @param mix Ratio from 0.0 (dry) to 1.0 (wet).
 */
RTC_RNNOISE_API void rtc_rnnoise_set_mix(RtcRnnoiseContext* ctx, float mix);

/**
 * Destroy the RNNoise context.
 * @param ctx Context pointer.
 */
RTC_RNNOISE_API void rtc_rnnoise_destroy(RtcRnnoiseContext* ctx);

#ifdef __cplusplus
}
#endif

#endif // RTC_RNNOISE_C_API_H
