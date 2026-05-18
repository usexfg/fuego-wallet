#ifndef FUEGO_SDK_PLUGIN_H_
#define FUEGO_SDK_PLUGIN_H_

#if defined(__linux__)
#include <flutter_linux/flutter_linux.h>
#elif defined(__APPLE__)
#include <FlutterMacOS/FlutterMacOS.h>
#elif defined(_WIN32)
#include <flutter/plugin_registrar_windows.h>
#endif

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
