#ifndef FUEGO_SDK_PLUGIN_H_
#define FUEGO_SDK_PLUGIN_H_

#include <FlutterMacOS/FlutterMacOS.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FUEGO_SDK_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FUEGO_SDK_PLUGIN_EXPORT
#endif

@interface FuegoSdkPlugin : NSObject <FlutterPlugin>
@end

#endif
