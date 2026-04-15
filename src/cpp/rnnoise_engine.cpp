#include "rnnoise_engine.h"
#include "audio_utils.h"
#include <stdlib.h>
#include <string.h>
#include <algorithm>

namespace rtc_rnnoise {

RnnoiseEngine::RnnoiseEngine() {
    rnnoise_state_ = rnnoise_create(nullptr);
}

RnnoiseEngine::~RnnoiseEngine() {
    if (rnnoise_state_) {
        rnnoise_destroy(rnnoise_state_);
    }
    CleanupResources();
}

void RnnoiseEngine::EnsureResources(int sample_rate, int num_channels) {
    if (current_sample_rate_ == sample_rate && current_num_channels_ == num_channels) {
        return;
    }

    CleanupResources();

    current_sample_rate_ = sample_rate;
    current_num_channels_ = num_channels;

    int err = 0;
    if (sample_rate != 48000) {
        upsampler_ = speex_resampler_init(1, sample_rate, 48000, 3, &err);
        downsampler_ = speex_resampler_init(1, 48000, sample_rate, 3, &err);
    }

    // 预分配缓冲区 (考虑 10ms 最大采样率)
    // 最大 48kHz, 10ms = 480 samples
    size_t max_samples = 480 * 2; // 考虑立体声
    float_in_buffer_ = AllocateAligned<float>(max_samples);
    resampled_48k_buffer_ = AllocateAligned<float>(480);
    processed_48k_buffer_ = AllocateAligned<float>(480);
    delay_line_buffer_ = AllocateAligned<float>(480); 
    final_float_buffer_ = AllocateAligned<float>(max_samples);

    // 延迟线初始化 (清零)
    memset(delay_line_buffer_, 0, sizeof(float) * 480);
}

void RnnoiseEngine::CleanupResources() {
    if (upsampler_) speex_resampler_destroy(upsampler_);
    if (downsampler_) speex_resampler_destroy(downsampler_);
    upsampler_ = nullptr;
    downsampler_ = nullptr;

    if (float_in_buffer_) free(float_in_buffer_);
    if (resampled_48k_buffer_) free(resampled_48k_buffer_);
    if (processed_48k_buffer_) free(processed_48k_buffer_);
    if (delay_line_buffer_) free(delay_line_buffer_);
    if (final_float_buffer_) free(final_float_buffer_);
    
    float_in_buffer_ = nullptr;
    resampled_48k_buffer_ = nullptr;
    processed_48k_buffer_ = nullptr;
    delay_line_buffer_ = nullptr;
    final_float_buffer_ = nullptr;
}

template<typename T>
T* RnnoiseEngine::AllocateAligned(size_t size) {
    void* ptr = nullptr;
#if defined(_WIN32)
    ptr = _aligned_malloc(size * sizeof(T), 32);
#else
    if (posix_memalign(&ptr, 32, size * sizeof(T)) != 0) {
        return nullptr;
    }
#endif
    return static_cast<T*>(ptr);
}

float RnnoiseEngine::Process(AudioBufferPtr buffer, int num_samples, int sample_rate, 
                             int num_channels, AudioFormat format, MemoryLayout layout, 
                             float mix_level) {
    EnsureResources(sample_rate, num_channels);

    float vad_prob = 0.0f;

    // 1. 数据标准化 (Early Float + Scaling x32768)
    if (format == FORMAT_INT16) {
        const int16_t* in_ptr = static_cast<int16_t*>(buffer.interleaved_data);
        for (int i = 0; i < num_samples * num_channels; ++i) {
            float_in_buffer_[i] = static_cast<float>(in_ptr[i]);
        }
    } else {
        // iOS Float 归一化数据 [-1, 1]
        if (layout == LAYOUT_NON_INTERLEAVED) {
            float** in_ptrs = reinterpret_cast<float**>(buffer.non_interleaved_data);
            for (int ch = 0; ch < num_channels; ++ch) {
                for (int i = 0; i < num_samples; ++i) {
                    float_in_buffer_[i * num_channels + ch] = in_ptrs[ch][i] * 32768.0f;
                }
            }
        } else {
            const float* in_ptr = static_cast<float*>(buffer.interleaved_data);
            for (int i = 0; i < num_samples * num_channels; ++i) {
                float_in_buffer_[i] = in_ptr[i] * 32768.0f;
            }
        }
    }

    // 2. 声道适配 (Downmix)
    float* mono_ptr = float_in_buffer_;
    if (num_channels == 2) {
        downmix_stereo_to_mono(float_in_buffer_, final_float_buffer_, num_samples);
        mono_ptr = final_float_buffer_;
    }

    // 3. 采样率适配 (Upsample to 48k)
    float* input_48k = mono_ptr;
    unsigned int in_len = num_samples;
    unsigned int out_len = 480;
    if (sample_rate != 48000 && upsampler_) {
        speex_resampler_process_float(upsampler_, 0, mono_ptr, &in_len, resampled_48k_buffer_, &out_len);
        input_48k = resampled_48k_buffer_;
    }

    // 4. RNNoise 处理 + 相位对齐 (Delay Line)
    // 注意：由于 WebRTC 严格 10ms，input_48k 必定刚好是 480 点
    vad_prob = rnnoise_process_frame(rnnoise_state_, processed_48k_buffer_, input_48k);

    // 干湿混合 (Dry/Wet Mix)
    // 为了相位对齐，干声必须用上一帧的
    for (int i = 0; i < 480; ++i) {
        float dry = delay_line_buffer_[i];
        delay_line_buffer_[i] = input_48k[i]; // 将当前帧存入延迟线供下一帧使用
        processed_48k_buffer_[i] = (dry * (1.0f - mix_level)) + (processed_48k_buffer_[i] * mix_level);
    }

    // 5. 逆向还原 (Downsample & Upmix & Clamping)
    float* out_resampled = processed_48k_buffer_;
    unsigned int res_in_len = 480;
    unsigned int res_out_len = num_samples;
    if (sample_rate != 48000 && downsampler_) {
        speex_resampler_process_float(downsampler_, 0, processed_48k_buffer_, &res_in_len, resampled_48k_buffer_, &res_out_len);
        out_resampled = resampled_48k_buffer_;
    }

    if (num_channels == 2) {
        upmix_mono_to_stereo(out_resampled, final_float_buffer_, num_samples);
        out_resampled = final_float_buffer_;
    }

    // 6. 写回原始内存
    if (format == FORMAT_INT16) {
        int16_t* out_ptr = static_cast<int16_t*>(buffer.interleaved_data);
        for (int i = 0; i < num_samples * num_channels; ++i) {
            out_ptr[i] = clamp_to_int16(out_resampled[i]);
        }
    } else {
        if (layout == LAYOUT_NON_INTERLEAVED) {
            float** out_ptrs = reinterpret_cast<float**>(buffer.non_interleaved_data);
            for (int ch = 0; ch < num_channels; ++ch) {
                for (int i = 0; i < num_samples; ++i) {
                    out_ptrs[ch][i] = out_resampled[i * num_channels + ch] / 32768.0f;
                }
            }
        } else {
            float* out_ptr = static_cast<float*>(buffer.interleaved_data);
            for (int i = 0; i < num_samples * num_channels; ++i) {
                out_ptr[i] = out_resampled[i] / 32768.0f;
            }
        }
    }

    return vad_prob;
}

} // namespace rtc_rnnoise
