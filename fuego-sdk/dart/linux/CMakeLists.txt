cmake_minimum_required(VERSION 3.10)
set(FUEGO_SDK_PLUGIN_NAME "fuego_sdk_plugin")

list(APPEND PLUGIN_SOURCES
  "fuego_sdk_plugin.cc"
)

add_library(${FUEGO_SDK_PLUGIN_NAME} SHARED ${PLUGIN_SOURCES})
apply_standard_settings(${FUEGO_SDK_PLUGIN_NAME})
target_compile_definitions(${FUEGO_SDK_PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${FUEGO_SDK_PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${FUEGO_SDK_PLUGIN_NAME} PRIVATE flutter)
