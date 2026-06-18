#ifndef FUEGO_SDK_PLUGIN_H_
#define FUEGO_SDK_PLUGIN_H_

#include <stddef.h>

#ifdef _WIN32
  #ifdef FLUTTER_PLUGIN_IMPL
    #define FUEGO_SDK_PLUGIN_EXPORT __declspec(dllexport)
  #else
    #define FUEGO_SDK_PLUGIN_EXPORT __declspec(dllimport)
  #endif
#else
  #ifdef FLUTTER_PLUGIN_IMPL
    #define FUEGO_SDK_PLUGIN_EXPORT __attribute__((visibility("default")))
  #else
    #define FUEGO_SDK_PLUGIN_EXPORT
  #endif
#endif

typedef void* FlutterDesktopPluginRegistrarRef;

#if defined(__cplusplus)
extern "C" {
#endif

FUEGO_SDK_PLUGIN_EXPORT void FuegoSdkPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FUEGO_SDK_PLUGIN_H_
