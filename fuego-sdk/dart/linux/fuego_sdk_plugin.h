#ifndef FUEGO_SDK_PLUGIN_H_
#define FUEGO_SDK_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FUEGO_SDK_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FUEGO_SDK_PLUGIN_EXPORT
#endif

typedef struct _FuegoSdkPlugin FuegoSdkPlugin;
typedef struct {
  GObjectClass parent_class;
} FuegoSdkPluginClass;

GType fuego_sdk_plugin_get_type();

FUEGO_SDK_PLUGIN_EXPORT void fuego_sdk_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FUEGO_SDK_PLUGIN_H_
