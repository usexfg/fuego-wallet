cmake_minimum_required(VERSION 3.10)
set(FUEGO_SDK_PLUGIN_NAME "fuego_sdk_plugin")

list(APPEND PLUGIN_SOURCES
  "fuego_sdk_plugin.mm"
)

add_library(${FUEGO_SDK_PLUGIN_NAME} SHARED ${PLUGIN_SOURCES})
apply_standard_settings(${FUEGO_SDK_PLUGIN_NAME})
target_compile_definitions(${FUEGO_SDK_PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_link_libraries(${FUEGO_SDK_PLUGIN_NAME} PRIVATE flutter)
set_target_properties(${FUEGO_SDK_PLUGIN_NAME} PROPERTIES
  LINK_FLAGS "-Wl,-undefined,dynamic_lookup"
)
