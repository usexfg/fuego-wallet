#import "fuego_sdk_plugin.h"

@implementation FuegoSdkPlugin
+ (void)registerWithRegistrar:(id<FlutterPluginRegistrar>)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"fuego_sdk"
            binaryMessenger:[registrar messenger]];
  [registrar addMethodCallDelegate:[self sharedInstance] channel:channel];
}

+ (instancetype)sharedInstance {
  static FuegoSdkPlugin* instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[FuegoSdkPlugin alloc] init];
  });
  return instance;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  result(FlutterMethodNotImplemented);
}
@end
