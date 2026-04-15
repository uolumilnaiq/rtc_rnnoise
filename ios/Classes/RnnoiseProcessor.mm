#import "RnnoiseProcessor.h"
#import "types.h"

extern "C" {
    void* rtc_rnnoise_create();
    float rtc_rnnoise_process(void* handle, AudioBufferPtr buffer, int num_samples, 
                              int sample_rate, int num_channels, int format, 
                              int layout, float mix_level);
    void rtc_rnnoise_destroy(void* handle);
}

@implementation RnnoiseProcessor {
    void *_nativeHandle;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _nativeHandle = rtc_rnnoise_create();
        _enabled = YES;
        _mixLevel = 1.0f;
    }
    return self;
}

- (void)processAudioBuffer:(float **)audioData
                numSamples:(int)numSamples
                sampleRate:(int)sampleRate
               numChannels:(int)numChannels {
    if (!_enabled || !_nativeHandle) return;

    AudioBufferPtr ptr;
    ptr.interleaved_data = nullptr;
    ptr.non_interleaved_data = (void **)audioData;

    // iOS WebRTC 通常给的是 Non-interleaved Float32, 归一化数据 [-1, 1]
    float vad = rtc_rnnoise_process(_nativeHandle, ptr, numSamples, sampleRate, numChannels, 
                                   FORMAT_FLOAT32, LAYOUT_NON_INTERLEAVED, _mixLevel);
    
    // --- 数值防御：确保 VAD 在 [0, 1] 之间，防止 NaN 导致的溢出错误 ---
    if (!(vad >= 0.0f)) vad = 0.0f;
    if (vad > 1.0f) vad = 1.0f;
    
    // 每 10 帧回传一次 VAD (约 200ms)
    static int frame_count = 0;
    frame_count++;
    if (frame_count >= 10) {
        // 使用通知方式安全回传到插件
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RNNoiseVadNotification" 
                                                            object:nil 
                                                          userInfo:@{@"vad": @(vad)}];
        frame_count = 0;
    }
}

- (void)releaseResources {
    if (_nativeHandle) {
        rtc_rnnoise_destroy(_nativeHandle);
        _nativeHandle = nullptr;
    }
}

- (void)dealloc {
    [self releaseResources];
}

@end
