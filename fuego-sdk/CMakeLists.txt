cmake_minimum_required(VERSION 3.10)
project(fuego_sdk VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(FUEGO_SDK_BUILD_SHARED "Build shared library" ON)
option(FUEGO_SDK_TESTNET "Build with testnet support" OFF)
option(FUEGO_SDK_BUILD_EMBEDDED_NODE "Build with embedded node support" OFF)

if(APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "10.14" CACHE STRING "Minimum macOS deployment version")
endif()

# Fuego submodule path
set(FUEGO_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../fuego")

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${FUEGO_DIR}/include
    ${FUEGO_DIR}/src
    ${FUEGO_DIR}/external
)

# Find required packages
find_package(Boost 1.55 REQUIRED COMPONENTS date_time filesystem program_options regex serialization thread chrono system)
find_package(Threads REQUIRED)

# SDK source files
set(FUEGO_SDK_SOURCES
    src/sdk.cpp
    src/node/node_manager.cpp
    src/mining/miner.cpp
    src/cd/deposit.cpp
    src/swap/atomic_swap.cpp
    src/heat/heat_proof.cpp
    src/alias/alias_service.cpp
)

# Define fuego core libraries
set(FUEGO_CORE_LIBS 
    CryptoNoteCore 
    CryptoNoteProtocol 
    P2p 
    Rpc 
    Logging 
    Common 
    System
)

# Path to fuego core build artifacts
set(FUEGO_LIB_DIR "${FUEGO_DIR}/build/src")

# Add library search path
link_directories(${FUEGO_LIB_DIR})

# Build shared or static library
if(FUEGO_SDK_BUILD_SHARED)
    add_library(fuego_sdk SHARED ${FUEGO_SDK_SOURCES})
    target_compile_definitions(fuego_sdk PRIVATE FUEGO_SDK_EXPORTS)
else()
    add_library(fuego_sdk STATIC ${FUEGO_SDK_SOURCES})
endif()

target_include_directories(fuego_sdk PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
    ${FUEGO_DIR}/src
    ${FUEGO_DIR}/include
)

target_link_libraries(fuego_sdk PUBLIC
    ${Boost_LIBRARIES}
    ${FUEGO_CORE_LIBS}
    Threads::Threads
)

target_link_libraries(fuego_sdk PUBLIC
    ${Boost_LIBRARIES}
    Threads::Threads
)

# Platform-specific settings
if(WIN32)
    target_link_libraries(fuego_sdk PUBLIC ws2_32)
elseif(APPLE)
    target_link_libraries(fuego_sdk PUBLIC "-framework Foundation")
elseif(UNIX AND NOT APPLE)
    target_link_libraries(fuego_sdk PUBLIC dl)
endif()

# Set visibility
set_target_properties(fuego_sdk PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# Install targets
install(TARGETS fuego_sdk
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

install(DIRECTORY include/ DESTINATION include)

# Print configuration
message(STATUS "Fuego SDK Configuration:")
message(STATUS "  Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Shared Library: ${FUEGO_SDK_BUILD_SHARED}")
message(STATUS "  Testnet: ${FUEGO_SDK_TESTNET}")
message(STATUS "  Install Prefix: ${CMAKE_INSTALL_PREFIX}")
