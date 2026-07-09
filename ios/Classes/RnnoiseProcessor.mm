#import "RnnoiseProcessor.h"
#import "types.h"
#import "RtcRnnoisePlugin.h"
#import <objc/message.h>

extern "C" {
    void* rtc_rnnoise_create();
    float rtc_rnnoise_process(void* handle, AudioBufferPtr buffer, int num_samples,
                              int sample_rate, int num_channels, int format,
                              int layout, float mix_level);
    void rtc_rnnoise_destroy(void* handle);
}

@implementation RnnoiseProcessor {
    void *_nativeHandle;
    int   _sampleRate;
    int   _vadThrottle;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _nativeHandle = rtc_rnnoise_create();
        _enabled  = YES;
        _mixLevel = 0.75f;
        _sampleRate = 48000;
    }
    return self;
}

#pragma mark - ExternalAudioProcessingDelegate (flutter_webrtc)

- (void)audioProcessingInitializeWithSampleRate:(size_t)sampleRateHz channels:(size_t)channels {
    _sampleRate = (int)sampleRateHz;
    NSLog(@"[RNNoise-iOS] initialize: sampleRate=%zu channels=%zu", sampleRateHz, channels);
}

- (void)audioProcessingProcess:(id)audioBuffer {
    if (!_nativeHandle || !_enabled) return;

    static dispatch_once_t onceToken;
    static SEL rawBufSel, framesSel, channelsSel;
    dispatch_once(&onceToken, ^{
        rawBufSel   = NSSelectorFromString(@"rawBufferForChannel:");
        framesSel   = NSSelectorFromString(@"frames");
        channelsSel = NSSelectorFromString(@"channels");
    });

    size_t numFrames   = ((size_t(*)(id,SEL))objc_msgSend)(audioBuffer, framesSel);
    size_t numChannels = ((size_t(*)(id,SEL))objc_msgSend)(audioBuffer, channelsSel);
    if (numFrames == 0 || numChannels == 0 || numChannels > 8) return;

    float *channelPtrs[8];
    for (size_t ch = 0; ch < numChannels; ch++) {
        channelPtrs[ch] = ((float*(*)(id,SEL,size_t))objc_msgSend)(audioBuffer, rawBufSel, ch);
        if (!channelPtrs[ch]) return;
    }

    // WebRTC AudioBuffer 内部是 Q15 浮点（[-32768, 32767]），RNNoise 期望 [-1, 1]。
    const float Q15_TO_F = 1.0f / 32768.0f;
    const float F_TO_Q15 = 32768.0f;
    for (size_t ch = 0; ch < numChannels; ch++) {
        for (size_t i = 0; i < numFrames; i++) channelPtrs[ch][i] *= Q15_TO_F;
    }

    AudioBufferPtr ptr;
    ptr.interleaved_data     = nullptr;
    ptr.non_interleaved_data = (void **)channelPtrs;
    float vad = rtc_rnnoise_process(_nativeHandle, ptr,
                                    (int)numFrames, _sampleRate,
                                    (int)numChannels, FORMAT_FLOAT32,
                                    LAYOUT_NON_INTERLEAVED, _mixLevel);

    for (size_t ch = 0; ch < numChannels; ch++) {
        for (size_t i = 0; i < numFrames; i++) {
            float s = channelPtrs[ch][i] * F_TO_Q15;
            channelPtrs[ch][i] = s < -32768.0f ? -32768.0f : (s > 32767.0f ? 32767.0f : s);
        }
    }

    if (++_vadThrottle >= 20) {
        _vadThrottle = 0;
        [RtcRnnoisePlugin sendVadUpdate:vad];
    }
}

- (void)audioProcessingRelease {
    NSLog(@"[RNNoise-iOS] audioProcessingRelease");
    [self releaseResources];
}

#pragma mark - Resources

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
