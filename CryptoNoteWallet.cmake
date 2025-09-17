# CryptoNoteWallet CMake Configuration
# This file provides CMake configuration for the CryptoNote wallet library

# Set CryptoNote source directories
set(CRYPTONOTE_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/cryptonote/src)
set(CRYPTONOTE_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/cryptonote/include)

# Add CryptoNote include directories
include_directories(${CRYPTONOTE_INCLUDE_DIR})
include_directories(${CRYPTONOTE_SOURCE_DIR})

# Set CMake policy to suppress Boost warning
cmake_policy(SET CMP0167 NEW)

# Find required libraries
# Use consistent Boost configuration across all platforms
set(Boost_NO_BOOST_CMAKE ON)
set(Boost_USE_STATIC_LIBS OFF)
set(Boost_USE_MULTITHREADED ON)
set(Boost_USE_STATIC_RUNTIME OFF)

# Try to find Boost with components first
find_package(Boost QUIET COMPONENTS system filesystem thread chrono atomic program_options)

# If that fails, try without components (for newer Boost versions)
if(NOT Boost_FOUND)
    find_package(Boost REQUIRED)
    
    # Create individual component targets if they don't exist
    if(NOT TARGET Boost::system)
        add_library(Boost::system INTERFACE IMPORTED)
        target_link_libraries(Boost::system INTERFACE ${Boost_LIBRARIES})
        target_include_directories(Boost::system INTERFACE ${Boost_INCLUDE_DIRS})
    endif()
    
    if(NOT TARGET Boost::filesystem)
        add_library(Boost::filesystem INTERFACE IMPORTED)
        target_link_libraries(Boost::filesystem INTERFACE ${Boost_LIBRARIES})
        target_include_directories(Boost::filesystem INTERFACE ${Boost_INCLUDE_DIRS})
    endif()
    
    if(NOT TARGET Boost::thread)
        add_library(Boost::thread INTERFACE IMPORTED)
        target_link_libraries(Boost::thread INTERFACE ${Boost_LIBRARIES})
        target_include_directories(Boost::thread INTERFACE ${Boost_INCLUDE_DIRS})
    endif()
    
    if(NOT TARGET Boost::chrono)
        add_library(Boost::chrono INTERFACE IMPORTED)
        target_link_libraries(Boost::chrono INTERFACE ${Boost_LIBRARIES})
        target_include_directories(Boost::chrono INTERFACE ${Boost_INCLUDE_DIRS})
    endif()
    
    if(NOT TARGET Boost::atomic)
        add_library(Boost::atomic INTERFACE IMPORTED)
        target_link_libraries(Boost::atomic INTERFACE ${Boost_LIBRARIES})
        target_include_directories(Boost::atomic INTERFACE ${Boost_INCLUDE_DIRS})
    endif()
    
    if(NOT TARGET Boost::program_options)
        add_library(Boost::program_options INTERFACE IMPORTED)
        target_link_libraries(Boost::program_options INTERFACE ${Boost_LIBRARIES})
        target_include_directories(Boost::program_options INTERFACE ${Boost_INCLUDE_DIRS})
    endif()
endif()

# CryptoNote library is already created in main CMakeLists.txt
# This file only provides Boost configuration and include directories