# QREncode CMake Configuration
# This file provides CMake configuration for the QR code encoding library

if(WIN32)
    # On Windows, use vcpkg to find libqrencode
    find_package(QREncode CONFIG QUIET)
    if(QREncode_FOUND)
        add_library(qrencode ALIAS QREncode::QREncode)
    else()
        # Fallback to manual configuration
        find_library(QRENCODE_LIBRARIES qrencode)
        find_path(QRENCODE_INCLUDE_DIRS qrencode.h)
        if(QRENCODE_LIBRARIES AND QRENCODE_INCLUDE_DIRS)
            add_library(qrencode INTERFACE IMPORTED)
            target_link_libraries(qrencode INTERFACE ${QRENCODE_LIBRARIES})
            target_include_directories(qrencode INTERFACE ${QRENCODE_INCLUDE_DIRS})
        else()
            message(FATAL_ERROR "libqrencode not found")
        endif()
    endif()
else()
    # On Unix systems, use PkgConfig
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(QRENCODE REQUIRED libqrencode)
    
    # Create imported target for qrencode
    add_library(qrencode INTERFACE IMPORTED)
    target_link_libraries(qrencode INTERFACE ${QRENCODE_LIBRARIES})
    target_include_directories(qrencode INTERFACE ${QRENCODE_INCLUDE_DIRS})
    target_compile_options(qrencode INTERFACE ${QRENCODE_CFLAGS_OTHER})
endif()

# Set compile definitions for QR encode
target_compile_definitions(qrencode INTERFACE
    MAJOR_VERSION=4
    MINOR_VERSION=1
    MICRO_VERSION=2
    VERSION="4.1.2"
)