#ifndef RTC_RNNOISE_TYPES_H
#define RTC_RNNOISE_TYPES_H

#include <stdint.h>

/**
 * @brief 音频数据格式
 */
enum AudioFormat {
    FORMAT_INT16 = 0,
    FORMAT_FLOAT32 = 1
};

/**
 * @brief 内存布局
 */
enum MemoryLayout {
    LAYOUT_INTERLEAVED = 0,      // 交错格式 (Android: L R L R)
    LAYOUT_NON_INTERLEAVED = 1   // 非交错格式 (iOS: L L..., R R...)
};

/**
 * @brief 音频缓冲区指针结构体
 * 兼容 Android (连续内存) 和 iOS (指针数组)
 */
typedef struct {
    void* interleaved_data;      // Android: int16_t* (Interleaved)
    void** non_interleaved_data; // iOS: float** (Non-interleaved pointers)
} AudioBufferPtr;

#endif // RTC_RNNOISE_TYPES_H
