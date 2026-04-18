#import <Foundation/Foundation.h>

/**
 * 为了避免直接依赖 flutter_webrtc 的物理路径（增加耦合），
 * 我们在本地定义一个与之匹配的协议。
 * 只要方法签名一致，Objective-C 运行时就能完成注入。
 */
@protocol RtcRnnoiseExternalAudioProcessingDelegate <NSObject>
- (void)audioProcessingInitializeWithSampleRate:(size_t)sampleRateHz channels:(size_t)channels;
- (void)audioProcessingProcess:(id)audioBuffer; // 传入 RTCAudioBuffer
- (void)audioProcessingRelease;
@end

@interface RnnoiseProcessor : NSObject <RtcRnnoiseExternalAudioProcessingDelegate>

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) float mixLevel;

- (void)releaseResources;

@end
