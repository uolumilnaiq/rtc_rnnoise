#import <Flutter/Flutter.h>

@interface RtcRnnoisePlugin : NSObject<FlutterPlugin, FlutterStreamHandler>

/**
 * 供原生数据源异步推送 VAD 更新
 */
+ (void)sendVadUpdate:(float)vad;

@end
