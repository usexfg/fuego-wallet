cmake_minimum_required(VERSION 3.10)

# Set project name before including other files
set(CN_PROJECT_NAME "FuegoWallet")

if(APPLE)
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.12" CACHE STRING "Minimum OS X deployment version")  
endif(APPLE)

# Enable both C and C++ languages before including other files that need it
project(${CN_PROJECT_NAME} C CXX)

# Force C++17 standard and compiler flags
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Force C99 standard for C files
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# Force C++17 flag for all compilers
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99")
    message(STATUS "Using GNU compiler with C++17 and C99")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99")
    message(STATUS "Using Clang compiler with C++17 and C99")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99")
    message(STATUS "Using AppleClang compiler with C++17 and C99")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /std:c++17")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /std:c99")
    message(STATUS "Using MSVC compiler with C++17 and C99")
endif()

message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "C++ Flags: ${CMAKE_CXX_FLAGS}")
message(STATUS "C Standard: ${CMAKE_C_STANDARD}")
message(STATUS "C Flags: ${CMAKE_C_FLAGS}")

# Add compiler flags to handle potential compilation issues
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-unused-variable -Wno-unused-function -Wno-error -Wno-deprecated-builtins")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-unused-variable -Wno-unused-function -Wno-error")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-unused-variable -Wno-unused-function -Wno-error -Wno-deprecated-builtins -Wno-unused-command-line-argument")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-unused-variable -Wno-unused-function -Wno-error -Wno-unused-command-line-argument")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-unused-variable -Wno-unused-function -Wno-error -Wno-deprecated-builtins -Wno-unused-command-line-argument")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-unused-variable -Wno-unused-function -Wno-error -Wno-unused-command-line-argument")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W3 /WX-")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /W3 /WX-")
endif()

# Set STARK CLI path for binary download
if(WIN32)
    set(STARK_CLI_PATH "bin/xfg-stark-cli.exe")
elseif(APPLE)
    set(STARK_CLI_PATH "bin/xfg-stark-cli")
else()
    set(STARK_CLI_PATH "bin/xfg-stark-cli")
endif()

include(CryptoNoteWallet.cmake)
include(QREncode.cmake)

execute_process(COMMAND git log -1 --pretty=format:%h
WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
OUTPUT_VARIABLE GIT_REVISION)

set(CRYPTONOTE_LIB cryptonote)
# Set Qt5 path from environment variable
message(STATUS "=== Qt5 Detection Debug ===")
message(STATUS "Qt5_DIR env: $ENV{Qt5_DIR}")
message(STATUS "Qt5_Dir env: $ENV{Qt5_Dir}")
message(STATUS "CMAKE_PREFIX_PATH env: $ENV{CMAKE_PREFIX_PATH}")
message(STATUS "Current CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")

if(DEFINED ENV{Qt5_DIR})
    # Qt5_DIR points to the cmake directory, we need the parent directory
    get_filename_component(QT5_ROOT_DIR "$ENV{Qt5_DIR}" DIRECTORY)
    get_filename_component(QT5_ROOT_DIR "${QT5_ROOT_DIR}" DIRECTORY)
    set(CMAKE_PREFIX_PATH "${QT5_ROOT_DIR}")
    message(STATUS "Using Qt5_DIR: $ENV{Qt5_DIR}")
    message(STATUS "Derived Qt5 root: ${QT5_ROOT_DIR}")
elseif(DEFINED ENV{Qt5_Dir})
    # Qt5_Dir points to the cmake directory, we need the parent directory
    get_filename_component(QT5_ROOT_DIR "$ENV{Qt5_Dir}" DIRECTORY)
    get_filename_component(QT5_ROOT_DIR "${QT5_ROOT_DIR}" DIRECTORY)
    set(CMAKE_PREFIX_PATH "${QT5_ROOT_DIR}")
    message(STATUS "Using Qt5_Dir: $ENV{Qt5_Dir}")
    message(STATUS "Derived Qt5 root: ${QT5_ROOT_DIR}")
elseif(DEFINED ENV{CMAKE_PREFIX_PATH})
    set(CMAKE_PREFIX_PATH "$ENV{CMAKE_PREFIX_PATH}")
    message(STATUS "Using CMAKE_PREFIX_PATH: $ENV{CMAKE_PREFIX_PATH}")
else()
    # Try to find Qt5 automatically
    message(STATUS "No Qt environment variables found, searching automatically...")
    find_path(QT5_CMAKE_DIR Qt5Config.cmake
        PATHS
        /usr/local/lib/cmake/Qt5
        /opt/homebrew/lib/cmake/Qt5
        /usr/lib/cmake/Qt5
        /Applications/Qt/5.15.2/macos/lib/cmake/Qt5
        /Users/runner/Qt/5.15.2/macos/lib/cmake/Qt5
        NO_DEFAULT_PATH
    )
    if(QT5_CMAKE_DIR)
        # Get the root directory from the cmake directory
        get_filename_component(QT5_ROOT_DIR "${QT5_CMAKE_DIR}" DIRECTORY)
        get_filename_component(QT5_ROOT_DIR "${QT5_ROOT_DIR}" DIRECTORY)
        set(CMAKE_PREFIX_PATH "${QT5_ROOT_DIR}")
        message(STATUS "Found Qt5 automatically at: ${QT5_CMAKE_DIR}")
        message(STATUS "Derived Qt5 root: ${QT5_ROOT_DIR}")
    else()
        message(WARNING "Qt5_DIR, Qt5_Dir, CMAKE_PREFIX_PATH not set and Qt5 not found automatically")
    endif()
endif()

message(STATUS "Final CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")
message(STATUS "=== End Qt5 Detection Debug ===")

include_directories(${CMAKE_BINARY_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
    src
    cryptonote/external
    cryptonote/include
    cryptonote/src
    cryptonote/src/crypto)

find_package(Qt5Gui REQUIRED)
find_package(Qt5Widgets REQUIRED)
find_package(Qt5Network REQUIRED)
find_package(Qt5Charts)

# Find miniupnpc library for UPNP functionality
find_package(PkgConfig REQUIRED)
pkg_check_modules(MINIUPNPC miniupnpc)
if(MINIUPNPC_FOUND)
    message(STATUS "Found miniupnpc via pkg-config: ${MINIUPNPC_LIBRARIES}")
    # Use the full library path from pkg-config
    set(MINIUPNPC_LIB ${MINIUPNPC_LIBRARIES})
    # Also add the library directories
    link_directories(${MINIUPNPC_LIBRARY_DIRS})
else()
    find_library(MINIUPNPC_LIB miniupnpc)
    if(MINIUPNPC_LIB)
        message(STATUS "Found miniupnpc library: ${MINIUPNPC_LIB}")
    else()
        message(WARNING "miniupnpc library not found - UPNP functionality may not work")
        set(MINIUPNPC_LIB "")
    endif()
endif()

# Find Boost libraries (program_options and filesystem)
find_package(Boost REQUIRED COMPONENTS program_options filesystem)
if(Boost_FOUND)
    message(STATUS "Found Boost libraries: ${Boost_LIBRARIES}")
else()
    message(FATAL_ERROR "Boost libraries not found")
endif()

# Find QR code library
find_package(PkgConfig REQUIRED)
pkg_check_modules(QRENCODE QREncode)
if(QRENCODE_FOUND)
    message(STATUS "Found QREncode via pkg-config: ${QRENCODE_LIBRARIES}")
    set(QRENCODE_LIB ${QRENCODE_LIBRARIES})
else()
    find_library(QRENCODE_LIB qrencode)
    if(QRENCODE_LIB)
        message(STATUS "Found QREncode library: ${QRENCODE_LIB}")
    else()
        message(WARNING "QREncode library not found - QR code functionality may not work")
        set(QRENCODE_LIB "")
    endif()
endif()

# Handle OpenGL on macOS
if(APPLE)
    find_library(OPENGL_LIBRARY OpenGL)
    find_library(AGL_LIBRARY AGL)
    set(OPENGL_LIBRARIES ${OPENGL_LIBRARY} ${AGL_LIBRARY})
    include_directories(/System/Library/Frameworks/OpenGL.framework/Headers)
    include_directories(/System/Library/Frameworks/AGL.framework/Headers)
else()
    find_package(OpenGL REQUIRED)
endif()

set(Boost_NO_BOOST_CMAKE ON)
set(Boost_USE_STATIC_LIBS ON)
if(WIN32)
  set(Boost_USE_STATIC_RUNTIME OFF)
else(WIN32)
  set(Boost_USE_STATIC_RUNTIME ON)
endif(WIN32)

# Boost is now handled in CryptoNoteWallet.cmake
# find_package(Boost 1.82 REQUIRED COMPONENTS date_time filesystem program_options regex serialization system thread chrono)
if ((${Boost_MAJOR_VERSION} EQUAL 1) AND (${Boost_MINOR_VERSION} EQUAL 54))
	message(SEND_ERROR "Boost version 1.54 is unsupported, more details are available here http://goo.gl/RrCFmA")
endif ()

include_directories(${Boost_INCLUDE_DIRS})
link_directories(${Boost_LIBRARY_DIRS})

set(VERSION "")
configure_file("cryptonote/src/version.h.in" "version.h")
configure_file("src/CryptoNoteWalletConfig.h.in" "CryptoNoteWalletConfig.h")

add_definitions(-DVERSION=\"${CN_VERSION}\")
add_definitions(-DGIT_REVISION=\"${GIT_REVISION}\")

set(CMAKE_AUTOMOC ON)

set(CRYPTONOTE_SOURCES
  cryptonote/external/miniupnpc/connecthostport.c
  cryptonote/external/miniupnpc/igd_desc_parse.c
  cryptonote/external/miniupnpc/minisoap.c
  cryptonote/external/miniupnpc/miniupnpc.c
  cryptonote/external/miniupnpc/miniwget.c
  cryptonote/external/miniupnpc/minixml.c
  cryptonote/external/miniupnpc/portlistingparse.c
  cryptonote/external/miniupnpc/receivedata.c
  cryptonote/external/miniupnpc/upnpcommands.c
  cryptonote/external/miniupnpc/upnpreplyparse.c
  cryptonote/src/Common/Base58.cpp
  cryptonote/src/Common/Base64.cpp  
  cryptonote/src/Common/CommandLine.cpp
  cryptonote/src/Common/Util.cpp
  cryptonote/src/Common/StringTools.cpp
  cryptonote/src/Common/JsonValue.cpp
  cryptonote/src/Common/ConsoleTools.cpp
  cryptonote/src/Common/MemoryInputStream.cpp
  cryptonote/src/Common/PathTools.cpp
  cryptonote/src/Common/DnsTools.cpp
  cryptonote/src/Common/StdInputStream.cpp
  cryptonote/src/Common/StdOutputStream.cpp
  cryptonote/src/Common/StreamTools.cpp
  cryptonote/src/Common/StringOutputStream.cpp
  cryptonote/src/Common/StringView.cpp
  cryptonote/src/Common/VectorOutputStream.cpp
  cryptonote/src/crypto/chacha8.c
  cryptonote/src/crypto/soft_aes.hpp
  cryptonote/src/crypto/crypto-ops-data.c
  cryptonote/src/crypto/crypto-ops.c
  cryptonote/src/crypto/crypto.cpp
  cryptonote/src/crypto/hash.c
  cryptonote/src/crypto/keccak.c
  cryptonote/src/crypto/random.c
  cryptonote/src/crypto/tree-hash.c
  cryptonote/src/crypto/blake256.c
  cryptonote/src/crypto/groestl.c
  cryptonote/src/crypto/hash-extra-blake.c
  cryptonote/src/crypto/hash-extra-groestl.c
  cryptonote/src/crypto/hash-extra-jh.c
  cryptonote/src/crypto/hash-extra-skein.c
  cryptonote/src/crypto/jh.c
  cryptonote/src/crypto/oaes_lib.c
  cryptonote/src/crypto/skein.c
  cryptonote/src/crypto/slow-hash.c
  cryptonote/src/crypto/slow-hash.cpp
  cryptonote/src/crypto/aesb.c
  cryptonote/src/CryptoNoteCore/BlockchainIndices.cpp
  cryptonote/src/CryptoNoteCore/BlockchainMessages.cpp
  cryptonote/src/CryptoNoteCore/BlockIndex.cpp
  cryptonote/src/CryptoNoteCore/CoreConfig.cpp
  cryptonote/src/CryptoNoteCore/CryptoNoteBasic.cpp
  cryptonote/src/CryptoNoteCore/CryptoNoteTools.cpp
  cryptonote/src/CryptoNoteCore/Currency.cpp
  cryptonote/src/CryptoNoteCore/DepositIndex.cpp
  cryptonote/src/CryptoNoteCore/InvestmentIndex.cpp
  cryptonote/src/CryptoNoteCore/MinerConfig.cpp
  cryptonote/src/CryptoNoteCore/Transaction.cpp
  cryptonote/src/CryptoNoteCore/Account.cpp
  cryptonote/src/CryptoNoteCore/Blockchain.cpp
  cryptonote/src/CryptoNoteCore/Checkpoints.cpp
  cryptonote/src/CryptoNoteCore/CryptoNoteBasicImpl.cpp
  cryptonote/src/CryptoNoteCore/Core.cpp
  cryptonote/src/CryptoNoteCore/CryptoNoteFormatUtils.cpp
  cryptonote/src/CryptoNoteCore/CryptoNoteSerialization.cpp
  cryptonote/src/CryptoNoteCore/Difficulty.cpp
  cryptonote/src/CryptoNoteCore/IBlock.cpp
  cryptonote/src/CryptoNoteCore/Miner.cpp
  cryptonote/src/CryptoNoteCore/TransactionExtra.cpp
  cryptonote/src/CryptoNoteCore/TransactionPool.cpp
  cryptonote/src/CryptoNoteCore/TransactionPrefixImpl.cpp
  cryptonote/src/CryptoNoteCore/TransactionUtils.cpp
  cryptonote/src/InProcessNode/InProcessNode.cpp
  cryptonote/src/InProcessNode/InProcessNodeErrors.cpp
  cryptonote/src/NodeRpcProxy/NodeErrors.cpp
  cryptonote/src/NodeRpcProxy/NodeRpcProxy.cpp
  cryptonote/src/P2p/NetNodeConfig.cpp
  cryptonote/src/Serialization/BinaryInputStreamSerializer.cpp
  cryptonote/src/Serialization/BinaryOutputStreamSerializer.cpp
  cryptonote/src/Serialization/JsonInputValueSerializer.cpp
  cryptonote/src/Serialization/JsonOutputStreamSerializer.cpp
  cryptonote/src/Serialization/KVBinaryInputStreamSerializer.cpp
  cryptonote/src/Serialization/KVBinaryOutputStreamSerializer.cpp
  cryptonote/src/Serialization/SerializationOverloads.cpp
  cryptonote/src/Transfers/BlockchainSynchronizer.cpp
  cryptonote/src/Transfers/SynchronizationState.cpp
  cryptonote/src/Transfers/TransfersConsumer.cpp
  cryptonote/src/Transfers/TransfersContainer.cpp
  cryptonote/src/Transfers/TransfersSubscription.cpp
  cryptonote/src/Transfers/TransfersSynchronizer.cpp
  cryptonote/src/Wallet/LegacyKeysImporter.cpp
  cryptonote/src/Wallet/WalletAsyncContextCounter.cpp
  cryptonote/src/Wallet/WalletErrors.cpp
  cryptonote/src/WalletLegacy/KeysStorage.cpp
  cryptonote/src/WalletLegacy/WalletLegacy.cpp
  cryptonote/src/WalletLegacy/WalletHelper.cpp
  cryptonote/src/WalletLegacy/WalletLegacySerializer.cpp
  cryptonote/src/WalletLegacy/WalletLegacySerialization.cpp
  cryptonote/src/WalletLegacy/WalletTransactionSender.cpp
  cryptonote/src/WalletLegacy/WalletUnconfirmedTransactions.cpp
  cryptonote/src/WalletLegacy/WalletUserTransactionsCache.cpp
  cryptonote/src/BurnTransactionHandler.cpp
  cryptonote/src/System/ContextGroup.cpp
  cryptonote/src/System/Event.cpp
  cryptonote/src/System/EventLock.cpp
  cryptonote/src/System/InterruptedException.cpp
  cryptonote/src/System/Ipv4Address.cpp
  cryptonote/src/System/TcpStream.cpp
  cryptonote/src/HTTP/HttpRequest.cpp
  cryptonote/src/HTTP/HttpParser.cpp
  cryptonote/src/HTTP/HttpParserErrorCodes.cpp
  cryptonote/src/HTTP/HttpResponse.cpp
  cryptonote/src/Rpc/HttpClient.cpp
  cryptonote/src/Rpc/JsonRpc.cpp
  cryptonote/src/P2p/NetNode.cpp
  cryptonote/src/P2p/LevinProtocol.cpp
  cryptonote/src/P2p/NetNodeConfig.cpp
  cryptonote/src/P2p/PeerListManager.cpp
  cryptonote/src/CryptoNoteProtocol/CryptoNoteProtocolHandler.cpp
  cryptonote/src/Logging/ILogger.cpp
  cryptonote/src/Logging/LoggerGroup.cpp
  cryptonote/src/Logging/CommonLogger.cpp
  cryptonote/src/Logging/LoggerManager.cpp
  cryptonote/src/Logging/FileLogger.cpp
  cryptonote/src/Logging/StreamLogger.cpp
  cryptonote/src/Logging/ConsoleLogger.cpp
  cryptonote/src/Logging/LoggerMessage.cpp
  cryptonote/src/Logging/LoggerRef.cpp
  cryptonote/src/BlockchainExplorer/BlockchainExplorer.cpp
  cryptonote/src/BlockchainExplorer/BlockchainExplorerDataBuilder.cpp
  cryptonote/src/BlockchainExplorer/BlockchainExplorerErrors.cpp
)

# Create the cryptonote library
add_library(${CRYPTONOTE_LIB} STATIC ${CRYPTONOTE_SOURCES})

# Set target properties for cryptonote library
set_target_properties(${CRYPTONOTE_LIB} PROPERTIES
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
)

# C source files will be compiled with C99 standard automatically

# Link cryptonote library with required libraries
target_link_libraries(${CRYPTONOTE_LIB} ${Boost_LIBRARIES})

# Add platform-specific sources to cryptonote library
if(UNIX AND NOT APPLE)
  target_sources(${CRYPTONOTE_LIB} PRIVATE cryptonote/external/miniupnpc/minissdpc.c)
endif()

file(GLOB_RECURSE SOURCES src/*.cpp)
file(GLOB_RECURSE HEADERS src/*.h)
file(GLOB_RECURSE FORMS src/gui/ui/*.ui)

set(QRC src/resources.qrc)

qt5_wrap_ui(UIS ${FORMS})
qt5_add_resources(RCC ${QRC})

if("${ARCH}" STREQUAL "default")
    set(ARCH_FLAG "")
  else()
    # Set appropriate architecture flag based on platform
    if(APPLE)
      # For Apple Silicon (ARM64), don't use -march flag as it's not needed
      if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
        set(ARCH_FLAG "")
      else()
        # For Intel Macs, use x86-64
        set(ARCH_FLAG "-march=x86-64")
      endif()
    else()
      # For other platforms, use x86-64
      set(ARCH_FLAG "-march=x86-64")
    endif()
  endif()

if (WIN32)
  if (NOT MSVC)
	message(FATAL_ERROR "Only MSVC is supported on this platform")
  endif ()
  add_definitions(/D_CRT_SECURE_NO_WARNINGS /D_WIN32_WINNT=0x0600 /DSTATICLIB)
  include_directories(cryptonote/src/platform/msc)

  set(PLATFORM_DIR Windows)
  set(BUILD_PLATFORM WIN32)
  set(BUILD_RESOURCES fuego.rc)
  set(QTMAIN Qt5::WinMain)

elseif (UNIX)
  if (APPLE)
    enable_language(ASM)
    file(GLOB_RECURSE OBJC_SOURCES src/*.mm)
    set(SOURCES ${SOURCES} ${OBJC_SOURCES})
    set(PLATFORM_DIR OSX)
    set(MACOSX_BUNDLE_BUNDLE_NAME "Fuego Wallet")
    set(MACOSX_BUNDLE_INFO_STRING ${CN_VERSION})
    set(MACOSX_BUNDLE_LONG_VERSION_STRING ${CN_VERSION})
    set(MACOSX_BUNDLE_SHORT_VERSION_STRING ${CN_VERSION})
    set(MACOSX_BUNDLE_BUNDLE_VERSION ${CN_VERSION})

    find_package(Qt5PrintSupport REQUIRED)

    include_directories(/usr/include/malloc)

    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${ARCH_FLAG} -maes -std=c++11 -stdlib=libc++")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c11 ${ARCH_FLAG} -maes -D_DARWIN_C_SOURCE")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework Cocoa -framework OpenGL -framework CoreFoundation -framework Carbon -framework IOKit -L/usr/lib")

    set(MACOSX_BUNDLE_ICON_FILE fuego.icns)
    set(APPLICATION_ICON src/images/appicon/fuego.icns)
    set_source_files_properties(${APPLICATION_ICON} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")

    set(BUILD_PLATFORM MACOSX_BUNDLE)
    set(BUILD_RESOURCES ${APPLICATION_ICON})
	
    GET_TARGET_PROPERTY(QT_LIB_DIR "${Qt5Widgets_LIBRARIES}" LOCATION)
    GET_FILENAME_COMPONENT(QT_LIB_DIR "${QT_LIB_DIR}" PATH)
  else(APPLE)
    set(PLATFORM_DIR Linux)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -maes -std=c++11")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -maes -std=c11")
  endif (APPLE)
endif ()

include_directories(cryptonote/src/Platform/${PLATFORM_DIR})
file(GLOB PLATFORM_SOURCES cryptonote/src/Platform/${PLATFORM_DIR}/System/*)

# Add platform-specific sources to cryptonote library
if(PLATFORM_SOURCES)
  target_sources(${CRYPTONOTE_LIB} PRIVATE ${PLATFORM_SOURCES})
endif()


add_executable(${PROJECT_NAME} ${BUILD_PLATFORM} ${BUILD_RESOURCES} ${SOURCES} ${HEADERS} ${UIS} ${RCC})
set_target_properties(${PROJECT_NAME} PROPERTIES COMPILE_DEFINITIONS _GNU_SOURCE)
if(APPLE)
  set_target_properties(${PROJECT_NAME} PROPERTIES MACOSX_BUNDLE_BUNDLE_NAME "Fuego Wallet")
endif()
target_link_libraries(${PROJECT_NAME} ${Boost_LIBRARIES} ${QTMAIN} ${CRYPTONOTE_LIB} ${QRENCODE_LIB} ${MINIUPNPC_LIB})

if (APPLE)
  qt5_use_modules(${PROJECT_NAME} PrintSupport)
  add_definitions(/DHAVE_ROTR)
  target_link_libraries(${PROJECT_NAME} -lpthread resolv)
elseif (UNIX)
  target_link_libraries(${PROJECT_NAME} -lpthread resolv)
  add_definitions(/DHAVE_ROTR)
elseif (WIN32)
  target_link_libraries(${PROJECT_NAME} Imm32 Iphlpapi Winmm)
endif (APPLE)

# qt5_use_modules(${PROJECT_NAME} Widgets Gui Network)
target_link_libraries(${PROJECT_NAME} Qt5::Gui)
target_link_libraries(${PROJECT_NAME} Qt5::Widgets)
target_link_libraries(${PROJECT_NAME} Qt5::Network)
if(Qt5Charts_FOUND)
add_definitions(/DHAVE_CHART)
target_link_libraries(${PROJECT_NAME} Qt5::Charts)  
endif(Qt5Charts_FOUND)

# Installation

set(CPACK_PACKAGE_NAME ${CN_PROJECT_NAME})
set(CPACK_PACKAGE_VERSION ${CN_VERSION})
set(CPACK_PACKAGE_VENDOR "Fandom Gold Society")
set(CPACK_PACKAGE_CONTACT "https://github.com/fandomgold/")
set(CPACK_STRIP_FILES ON)
if (APPLE)
    set(CPACK_GENERATOR ZIP)
    install(TARGETS ${PROJECT_NAME} BUNDLE DESTINATION .)
    
    # Install STARK CLI and scripts
    install(FILES ${STARK_CLI_PATH} DESTINATION .)
    install(FILES scripts/auto_stark_proof.sh DESTINATION .)
    install(FILES scripts/stark_proof_generator.py DESTINATION .)
    install(FILES scripts/progress_logger.py DESTINATION .)
    
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}.-${VERSION_RELEASE}")
elseif (UNIX)
    install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION bin)
    install(FILES src/fuegowallet.desktop DESTINATION share/applications)
    install(FILES src/images/fuego.png DESTINATION share/pixmaps)
    install(FILES COPYRIGHT DESTINATION share/doc/fuegowallet)
    
    # Install STARK CLI and scripts
    install(FILES ${STARK_CLI_PATH} DESTINATION bin)
    install(FILES scripts/auto_stark_proof.sh DESTINATION bin)
    install(FILES scripts/stark_proof_generator.py DESTINATION bin)
    install(FILES scripts/progress_logger.py DESTINATION bin)
    # Make scripts executable
    install(CODE "execute_process(COMMAND chmod +x \$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/bin/auto_stark_proof.sh)")
    install(CODE "execute_process(COMMAND chmod +x \$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/bin/stark_proof_generator.py)")
    install(CODE "execute_process(COMMAND chmod +x \$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/bin/progress_logger.py)")

	SET(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
	SET(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
	SET(CPACK_PACKAGE_ICON src/images/fuego.png)
	
    if (NOT PACKRPM)
        set(CPACK_GENERATOR DEB)
        set(CPACK_DEBIAN_PACKAGE_NAME ${CPACK_PACKAGE_NAME})
        set(CPACK_SYSTEM_NAME amd64)
        set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_VENDOR} <fandomgold@pm.me>")
        set(CPACK_DEBIAN_PACKAGE_SECTION Office)
        set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
        set(CPACK_DEBIAN_PACKAGE_DESCRIPTION "Fuego Wallet
 Fuego is a decentralized privacy protected peer-to-peer
 untraceable cryptocurrency. Fuego is
 open-source; its design is public, no one owns or controls the network and
 everyone can take part.")
set(CPACK_PACKAGE_FILE_NAME "${CPACK_DEBIAN_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${VERSION_RELEASE}.${CPACK_SYSTEM_NAME}")
	else ()
        set(CPACK_GENERATOR RPM)
        set(CPACK_SYSTEM_NAME x86_64)
        set(CPACK_RPM_PACKAGE_RELEASE ${VERSION_RELEASE})
        set(CPACK_RPM_PACKAGE_LICENSE "GPL3")
        set(CPACK_RPM_PACKAGE_GROUP Office)
        set(CPACK_RPM_PACKAGE_REQUIRES "qt5-qtbase >= 5.3.2, qt5-qtbase-gui >= 5.3.2")
        set(CPACK_RPM_PACKAGE_SUMMARY "Fuego Wallet")
        set(CPACK_RPM_PACKAGE_DESCRIPTION "Open-source Fuego wallet
 Fuego is a decentralized privacy protected peer-to-peer
 untraceable cryptocurrency. Fuego is
 open-source; its design is public, no one owns or controls the network and
 everyone can take part.")
set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${VERSION_RELEASE}.${CPACK_SYSTEM_NAME}")
    endif ()
elseif (WIN32)
  install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION .)
  
  # Install STARK CLI and scripts
  install(FILES ${STARK_CLI_PATH} DESTINATION .)
  install(FILES scripts/auto_stark_proof.sh DESTINATION .)
  install(FILES scripts/stark_proof_generator.py DESTINATION .)
  install(FILES scripts/progress_logger.py DESTINATION .)
endif (APPLE)

include(CPack)

# XFG STARK CLI is downloaded as pre-built binary in CI/CD workflows
message(STATUS "XFG STARK CLI will be downloaded as pre-built binary")
