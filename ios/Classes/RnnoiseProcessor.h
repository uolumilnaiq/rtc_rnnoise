#import <Foundation/Foundation.h>

/**
 * @brief iOS 端 WebRTC 音频降噪处理器
 * 对接 WebRTC 的 RTCAudioCustomProcessingDelegate 协议
 */
@interface RnnoiseProcessor : NSObject

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) float mixLevel;

- (void)processAudioBuffer:(float **)audioData
                numSamples:(int)numSamples
                sampleRate:(int)sampleRate
               numChannels:(int)numChannels;

- (void)releaseResources;

@end
