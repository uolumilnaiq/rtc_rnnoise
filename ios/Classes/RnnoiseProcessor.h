#import <Foundation/Foundation.h>

@protocol RtcRnnoiseExternalAudioProcessingDelegate <NSObject>
- (void)audioProcessingInitializeWithSampleRate:(size_t)sampleRateHz channels:(size_t)channels;
- (void)audioProcessingProcess:(id)audioBuffer;
- (void)audioProcessingRelease;
@end

@interface RnnoiseProcessor : NSObject <RtcRnnoiseExternalAudioProcessingDelegate>

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) float mixLevel;

- (void)releaseResources;

@end
