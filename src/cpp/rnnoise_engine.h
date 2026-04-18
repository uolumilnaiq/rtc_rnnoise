#ifndef RTC_RNNOISE_ENGINE_H
#define RTC_RNNOISE_ENGINE_H

#include <memory>
#include <atomic>
#include <vector>
#include "types.h"
#include "rnnoise.h"
#include "third_party/speexdsp/include/speex/speex_resampler.h"

namespace rtc_rnnoise {

class RnnoiseEngine {
public:
    RnnoiseEngine();
    ~RnnoiseEngine();

    /**
     * @brief 处理音频帧
     * @return VAD 概率 (0.0 ~ 1.0)
     */
    float Process(AudioBufferPtr buffer, int num_samples, int sample_rate, 
                  int num_channels, AudioFormat format, MemoryLayout layout, 
                  float mix_level);

private:
    // 初始化资源
    void EnsureResources(int sample_rate, int num_channels);
    void CleanupResources();

    // 内存对齐分配辅助
    template<typename T>
    T* AllocateAligned(size_t size);

private:
    DenoiseState* rnnoise_state_ = nullptr;
    SpeexResamplerState* upsampler_ = nullptr;
    SpeexResamplerState* downsampler_ = nullptr;

    // 内部缓冲区 (32 字节对齐)
    float* float_in_buffer_ = nullptr;      // 输入浮点缓存
    float* resampled_48k_buffer_ = nullptr; // 48kHz 重采样缓存
    float* processed_48k_buffer_ = nullptr; // 降噪后的 48kHz 缓存
    float* delay_line_buffer_ = nullptr;    // 延迟线缓存，用于相位对齐
    float* final_float_buffer_ = nullptr;   // 最终输出浮点缓存

    int current_sample_rate_ = 0;
    int current_num_channels_ = 0;
    
    // 延迟长度 (RNNoise 内部有 480 点的重叠，这里需要根据算法延迟对齐)
    // 根据 RNNoise 源码，处理是在 480 点 (10ms) 上进行的，存在大约 1 帧的相位偏移
    static const int kRnnoiseDelay = 480; 
};

} // namespace rtc_rnnoise

#endif // RTC_RNNOISE_ENGINE_H
