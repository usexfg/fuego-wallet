#ifndef FUEGO_SDK_PLUGIN_H_
#define FUEGO_SDK_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

G_DECLARE_FINAL_TYPE(FuegoSdkPlugin, fuego_sdk_plugin, FUEGO_SDK, PLUGIN, GObject)

#ifdef FLUTTER_PLUGIN_IMPL
#define FUEGO_SDK_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FUEGO_SDK_PLUGIN_EXPORT
#endif

FUEGO_SDK_PLUGIN_EXPORT void fuego_sdk_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif
