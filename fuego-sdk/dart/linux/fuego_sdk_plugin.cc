#include "fuego_sdk_plugin.h"

#include <flutter_linux/flutter_linux.h>

static void fuego_sdk_plugin_dispose(GObject* object) {
}

static void fuego_sdk_plugin_class_init(FuegoSdkPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = fuego_sdk_plugin_dispose;
}

static void fuego_sdk_plugin_init(FuegoSdkPlugin* self) {
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  g_autoptr(FlMethodResponse) response = nullptr;
  response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
}

void fuego_sdk_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "fuego_sdk",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, nullptr, nullptr);
}
