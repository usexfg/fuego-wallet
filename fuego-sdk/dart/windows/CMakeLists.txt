cmake_minimum_required(VERSION 3.10)
set(FUEGO_SDK_PLUGIN_NAME "fuego_sdk_plugin")

list(APPEND PLUGIN_SOURCES
  "fuego_sdk_plugin.cc"
)

add_library(${FUEGO_SDK_PLUGIN_NAME} SHARED ${PLUGIN_SOURCES})
apply_standard_settings(${FUEGO_SDK_PLUGIN_NAME})
target_compile_definitions(${FUEGO_SDK_PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# FFI plugin: use flutter_wrapper_plugin for FFI registration
find_package(PkgConfig QUIET)
target_link_libraries(${FUEGO_SDK_PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

set(fuego_sdk_bundled_libraries
  PARENT_SCOPE
)
