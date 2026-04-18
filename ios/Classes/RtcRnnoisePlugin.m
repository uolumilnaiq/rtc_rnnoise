#import "RtcRnnoisePlugin.h"
#import "RnnoiseProcessor.h"

@implementation RtcRnnoisePlugin {
    FlutterEventSink _eventSink;
}

// 静态持有当前处理器，供宿主注入
static RnnoiseProcessor *_activeProcessor = nil;

+ (RnnoiseProcessor *)activeProcessor {
    return _activeProcessor;
}

+ (void)setActiveProcessor:(RnnoiseProcessor *)processor {
    _activeProcessor = processor;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
        methodChannelWithName:@"rtc_rnnoise"
        binaryMessenger:[registrar messenger]];
    RtcRnnoisePlugin* instance = [[RtcRnnoisePlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];

    FlutterEventChannel* eventChannel = [FlutterEventChannel
        eventChannelWithName:@"rtc_rnnoise_events"
        binaryMessenger:[registrar messenger]];
    [eventChannel setStreamHandler:instance];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"init" isEqualToString:call.method]) {
        result(nil);
    } else if ([@"setEnabled" isEqualToString:call.method]) {
        BOOL enabled = [call.arguments[@"enabled"] boolValue];
        if (_activeProcessor) {
            _activeProcessor.enabled = enabled;
        }
        result(nil);
    } else if ([@"setSuppressionLevel" isEqualToString:call.method]) {
        float level = [call.arguments[@"level"] floatValue];
        if (_activeProcessor) {
            _activeProcessor.mixLevel = level;
        }
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

// 供原生 Processor 调用回传 VAD
+ (void)sendVadUpdate:(float)vad {
    // 由于 iOS 插件实例通常由 Flutter 管理，我们利用通知或单例寻找实例
    // 这里简化处理，直接通过单例或静态变量（在实际复杂工程中建议用观察者模式）
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RNNoiseVadNotification" 
                                                        object:nil 
                                                      userInfo:@{@"vad": @(vad)}];
}

#pragma mark - FlutterStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    _eventSink = events;
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleVadNotification:) 
                                                 name:@"RNNoiseVadNotification" 
                                               object:nil];
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _eventSink = nil;
    return nil;
}

- (void)handleVadNotification:(NSNotification *)notification {
    if (_eventSink) {
        _eventSink(notification.userInfo[@"vad"]);
    }
}

@end
