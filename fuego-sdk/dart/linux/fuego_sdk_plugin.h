#ifndef FUEGO_SDK_PLUGIN_H_
#define FUEGO_SDK_PLUGIN_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FUEGO_SDK_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FUEGO_SDK_PLUGIN_EXPORT
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FUEGO_SDK_PLUGIN_EXPORT void FuegoSdkPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FUEGO_SDK_PLUGIN_H_
