#import "RtcRnnoisePlugin.h"
#import "RnnoiseProcessor.h"
#import <objc/runtime.h>

@implementation RtcRnnoisePlugin {
    FlutterEventSink _eventSink;
}

static RnnoiseProcessor *_activeProcessor = nil;

+ (void)sendVadUpdate:(float)vad {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RNNoiseVadNotification" 
                                                        object:nil 
                                                      userInfo:@{@"vad": @(vad)}];
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
        if (!_activeProcessor) {
            _activeProcessor = [[RnnoiseProcessor alloc] init];
        }
        result(nil);
    } else if ([@"attach" isEqualToString:call.method]) {
        // --- 核心注入逻辑 (iOS WebRTC) ---
        [self attachToWebRTC:result];
    } else if ([@"setEnabled" isEqualToString:call.method]) {
        BOOL enabled = [call.arguments[@"enabled"] boolValue];
        if (_activeProcessor) _activeProcessor.enabled = enabled;
        result(nil);
    } else if ([@"setSuppressionLevel" isEqualToString:call.method]) {
        float level = [call.arguments[@"level"] floatValue];
        if (_activeProcessor) _activeProcessor.mixLevel = level;
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)attachToWebRTC:(FlutterResult)result {
    if (!_activeProcessor) {
        _activeProcessor = [[RnnoiseProcessor alloc] init];
    }

    // 1. 动态寻找 FlutterWebRTCPlugin
    Class webRTCPluginClass = NSClassFromString(@"FlutterWebRTCPlugin");
    if (!webRTCPluginClass) {
        NSLog(@"[RNNoiseNative] Error: FlutterWebRTCPlugin not found in runtime");
        result(@(NO));
        return;
    }

    // 2. 获取单例
    SEL sharedSelector = NSSelectorFromString(@"sharedSingleton");
    if (![webRTCPluginClass respondsToSelector:sharedSelector]) {
        result(@(NO));
        return;
    }
    
    id pluginInstance = [webRTCPluginClass performSelector:sharedSelector];
    if (!pluginInstance) {
        result(@(NO));
        return;
    }

    // 3. 获取音频管理器
    id audioManager = [pluginInstance valueForKey:@"audioManager"];
    if (!audioManager) {
        result(@(NO));
        return;
    }

    // 4. 获取 Capture 后处理适配器
    id adapter = [audioManager valueForKey:@"capturePostProcessingAdapter"];
    if (!adapter) {
        result(@(NO));
        return;
    }

    // 5. 执行注入 (addProcessing:)
    SEL addSelector = NSSelectorFromString(@"addProcessing:");
    if ([adapter respondsToSelector:addSelector]) {
        // 由于 ARC 对 performSelector:withObject: 的检查，我们使用动态调用
        IMP imp = [adapter methodForSelector:addSelector];
        void (*func)(id, SEL, id) = (void *)imp;
        func(adapter, addSelector, _activeProcessor);
        
        NSLog(@"[RNNoiseNative] Successfully attached to iOS WebRTC Capture Pipeline");
        result(@(YES));
    } else {
        result(@(NO));
    }
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
        float vad = [notification.userInfo[@"vad"] floatValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_eventSink) {
                self->_eventSink(@(vad));
            }
        });
    }
}

@end
