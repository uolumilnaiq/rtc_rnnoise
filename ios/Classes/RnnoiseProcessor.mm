#import "RnnoiseProcessor.h"
#import "types.h"
#import "RtcRnnoisePlugin.h"
#import <objc/message.h>
#import <os/log.h>

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
        _enabled = NO; 
        _mixLevel = 1.0f;
    }
    return self;
}

#pragma mark - RtcRnnoiseExternalAudioProcessingDelegate

- (void)audioProcessingInitializeWithSampleRate:(size_t)sampleRateHz channels:(size_t)channels {
    os_log_error(OS_LOG_DEFAULT, "[RNNoiseNative] WebRTC Hook Active: %zu Hz", sampleRateHz);
}

- (void)audioProcessingProcess:(id)audioBuffer {
    if (!_nativeHandle) return;

    @try {
        SEL bandsSel = NSSelectorFromString(@"bands");
        if (![audioBuffer respondsToSelector:bandsSel]) return;

        SEL framesSel = NSSelectorFromString(@"frames");
        SEL channelsSel = NSSelectorFromString(@"channels");

        int numSamples = ((int (*)(id, SEL))objc_msgSend)(audioBuffer, framesSel);
        int numChannels = ((int (*)(id, SEL))objc_msgSend)(audioBuffer, channelsSel);
        float **audioData = ((float ** (*)(id, SEL))objc_msgSend)(audioBuffer, bandsSel);

        if (!audioData || !audioData[0]) return;

        // --- 静音检测日志 ---
        static int zero_count = 0;
        if (audioData[0][0] == 0.0f) {
            if (zero_count++ % 500 == 0) {
                os_log_error(OS_LOG_DEFAULT, "[RNNoiseNative] WARNING: Receiving ALL ZERO audio. Check Mac Microphone Permissions!");
            }
        } else {
            if (zero_count > 0 && zero_count % 100 == 0) {
                os_log_error(OS_LOG_DEFAULT, "[RNNoiseNative] SUCCESS: Audio signal detected (non-zero).");
            }
            zero_count = 0;
        }

        // 无论是否开启降噪，我们都计算 VAD 并回传，以便 UI 验证
        AudioBufferPtr ptr;
        ptr.interleaved_data = nullptr;
        ptr.non_interleaved_data = (void **)audioData;

        // 如果未开启 AI 降噪，我们调用 process 但 mix_level 设为 0 (仅探测 VAD，不修改音频)
        // 如果开启了，则使用用户设置的 _mixLevel
        float currentMix = _enabled ? _mixLevel : 0.0f;

        float vad = rtc_rnnoise_process(_nativeHandle, ptr, numSamples, 48000, numChannels, 
                                       FORMAT_FLOAT32, LAYOUT_NON_INTERLEAVED, currentMix);
        
        static int vad_throttle = 0;
        if (vad_throttle++ % 20 == 0) {
            [RtcRnnoisePlugin sendVadUpdate:vad];
        }
        
    } @catch (NSException *e) {
        os_log_error(OS_LOG_DEFAULT, "[RNNoiseNative] RT Error: %{public}@", e.reason);
    }
}

- (void)audioProcessingRelease {
    os_log_error(OS_LOG_DEFAULT, "[RNNoiseNative] WebRTC Release");
}

- (void)dealloc {
    if (_nativeHandle) {
        rtc_rnnoise_destroy(_nativeHandle);
        _nativeHandle = nullptr;
    }
}

@end
