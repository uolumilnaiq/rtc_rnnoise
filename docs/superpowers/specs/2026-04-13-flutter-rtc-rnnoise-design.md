# 方案设计文档：Flutter WebRTC 高性能 RNNoise 降噪库 (flutter_rtc_rnnoise) - v3.1 (最终工程标准版)

## 1. 项目背景与目标
为 Flutter WebRTC 提供工业级的 AI 降噪插件，基于 RNNoise 原生 C 内核，追求极致性能与稳定性。

### 核心设计原则 (v3.1)
*   **10ms 帧直通 (Direct 10ms Flow)**：利用 WebRTC 严格的 10ms 步进，通过重采样自然对齐 480 采样点，移除 RingBuffer 以消除延迟。
*   **SIMD 内存安全**：所有内部浮点缓存强制执行 32-byte 对齐，确保 ARM NEON 指令集运行安全。
*   **类型安全接口**：使用 `AudioBufferPtr` 结构体明确区分 Android (Interleaved) 与 iOS (Non-interleaved) 的内存物理布局。
*   **数值稳定性**：在写回整型内存前执行硬裁剪 (Clamping)，消除由于滤波器过冲导致的爆音。
*   **AI 增强感知**：同步输出 RNNoise 内置的人声检测 (VAD) 概率。

## 2. 系统架构

### 2.1 核心数据流 (极致优化版)
```text
[ WebRTC Audio Thread ]
       |
[ Glue Code (Java/OC) ] -> 封装为 AudioBufferPtr
       |
[ C++ Process (v3.1) ]
    1. Early Float & Scaling (*32768.0f)
    2. Resampling (10ms in -> 10ms out @ 48k = 480 samples)
    3. RNNoise Process (Outputs: Denoised Audio + VAD Prob)
    4. Delay Line Alignment (Phase Alignment)
    5. Dry/Wet Mix
    6. Down-sampling
    7. Clamping (-32768 to 32767) -> Write Back
```

## 3. 关键工程实现

### 3.1 内存布局适配器
```cpp
typedef struct {
    void* interleaved_data;      // Android: int16_t* (Interleaved)
    void** non_interleaved_data; // iOS: float** (Non-interleaved pointers)
} AudioBufferPtr;
```

### 3.2 内存对齐分配
所有引擎内部 Buffer 必须通过对齐分配器创建：
*   Android: `posix_memalign` (32 bytes)
*   iOS: `aligned_alloc` 或 `posix_memalign` (32 bytes)

### 3.3 溢出保护 (Clamping)
在最终写回 `int16_t` 之前：
```cpp
float sample = processed_data[i];
sample = std::max(-32768.0f, std::min(32767.0f, sample));
output_ptr[i] = static_cast<int16_t>(sample);
```

## 4. 接口定义

### 4.1 C++ 核心接口
```cpp
enum AudioFormat { FORMAT_INT16, FORMAT_FLOAT32 };
enum MemoryLayout { LAYOUT_INTERLEAVED, LAYOUT_NON_INTERLEAVED };

extern "C" {
    typedef struct RnnoiseContext RnnoiseContext;
    RnnoiseContext* rtc_rnnoise_create();
    
    // 返回值 float 为 VAD 概率 (0.0 ~ 1.0)
    float rtc_rnnoise_process(
        RnnoiseContext* ctx, 
        AudioBufferPtr buffer, 
        int num_samples, 
        int sample_rate, 
        int num_channels, 
        AudioFormat format, 
        MemoryLayout layout, 
        float mix_level
    );
    
    void rtc_rnnoise_destroy(RnnoiseContext* ctx);
}
```

## 5. 性能与集成规范
*   **延迟控制**：总算法引入延迟（含重采样与相位补偿）应固定在 10ms 左右，单帧处理耗时 < 1.2ms (iPhone 12 / SD888)。
*   **挂载策略**：
    *   **Android**: `capturePostProcessing`
    *   **iOS**: `RTCAudioCustomProcessingDelegate`
*   **约束条件**：必须在 WebRTC 层显式禁用 `googNoiseSuppression`。

## 6. 验证方案
*   **VAD 准确性测试**：验证在极高背景噪声下，返回的 VAD 概率是否能准确识别通话者的人声。
*   **压力测试**：在 P2P 通话中持续运行 24 小时，观察是否存在内存对齐导致的偶现 Crash。
