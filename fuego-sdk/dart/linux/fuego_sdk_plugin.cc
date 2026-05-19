#include "fuego_sdk_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#define FUEGO_SDK_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), fuego_sdk_plugin_get_type(), \
                              FuegoSdkPlugin))

struct _FuegoSdkPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FuegoSdkPlugin, fuego_sdk_plugin, g_object_get_type())

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
}

static void fuego_sdk_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(fuego_sdk_plugin_parent_class)->dispose(object);
}

static void fuego_sdk_plugin_class_init(FuegoSdkPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = fuego_sdk_plugin_dispose;
}

static void fuego_sdk_plugin_init(FuegoSdkPlugin* self) {}

void fuego_sdk_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FuegoSdkPlugin* plugin = FUEGO_SDK_PLUGIN(
      g_object_new(fuego_sdk_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "fuego_sdk",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
