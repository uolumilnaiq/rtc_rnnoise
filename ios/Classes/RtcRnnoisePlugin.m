#import "RtcRnnoisePlugin.h"
#import "RnnoiseProcessor.h"
#import <objc/runtime.h>

@implementation RtcRnnoisePlugin {
    FlutterEventSink _eventSink;
}

static RnnoiseProcessor    *_activeProcessor    = nil;
static RtcRnnoisePlugin    *_sharedInstance     = nil;
static id                   _captureAdapter     = nil;  // 持有已注册的 adapter，用于 removeProcessing:

+ (void)sendVadUpdate:(float)vad {
    if (isnan(vad) || vad < 0.0f || vad > 1.0f) return;
    RtcRnnoisePlugin *instance = _sharedInstance;
    if (!instance || !instance->_eventSink) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (instance->_eventSink) instance->_eventSink(@(vad));
    });
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
        methodChannelWithName:@"rtc_rnnoise"
        binaryMessenger:[registrar messenger]];
    RtcRnnoisePlugin* instance = [[RtcRnnoisePlugin alloc] init];
    _sharedInstance = instance;
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

    // AudioManager 是 flutter_webrtc 内部单例，管理 WebRTC APM 处理链。
    // capturePostProcessingAdapter 对应 Android 的 capturePostProcessing。
    Class audioManagerClass = NSClassFromString(@"AudioManager");
    if (!audioManagerClass) {
        NSLog(@"[RNNoiseNative] AudioManager class not found");
        result(@(NO));
        return;
    }
    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
    if (![audioManagerClass respondsToSelector:sharedSel]) {
        NSLog(@"[RNNoiseNative] AudioManager has no sharedInstance");
        result(@(NO));
        return;
    }
    id audioManager = [audioManagerClass performSelector:sharedSel];
    if (!audioManager) {
        NSLog(@"[RNNoiseNative] AudioManager.sharedInstance is nil");
        result(@(NO));
        return;
    }

    // 用 respondsToSelector: + performSelector: 代替 valueForKey:，
    // 避免属性不存在时 KVC 抛出 NSUndefinedKeyException。
    SEL getterSel = NSSelectorFromString(@"capturePostProcessingAdapter");
    if (![audioManager respondsToSelector:getterSel]) {
        NSLog(@"[RNNoiseNative] capturePostProcessingAdapter not found");
        result(@(NO));
        return;
    }
    id captureAdapter = [audioManager performSelector:getterSel];
    if (!captureAdapter) {
        NSLog(@"[RNNoiseNative] capturePostProcessingAdapter is nil");
        result(@(NO));
        return;
    }

    SEL addSel    = NSSelectorFromString(@"addProcessing:");
    SEL removeSel = NSSelectorFromString(@"removeProcessing:");
    if (![captureAdapter respondsToSelector:addSel]) {
        NSLog(@"[RNNoiseNative] addProcessing: not available");
        result(@(NO));
        return;
    }

    // 防止重复 attach：先移除旧注册，再重新添加。
    if (_captureAdapter && [_captureAdapter respondsToSelector:removeSel]) {
        [_captureAdapter performSelector:removeSel withObject:_activeProcessor];
    }
    _captureAdapter = captureAdapter;
    [captureAdapter performSelector:addSel withObject:_activeProcessor];
    NSLog(@"[RNNoiseNative] ✅ RNNoise registered on capturePostProcessingAdapter");
    result(@(YES));
}

#pragma mark - FlutterStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    _eventSink = events;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    _eventSink = nil;
    return nil;
}

@end
