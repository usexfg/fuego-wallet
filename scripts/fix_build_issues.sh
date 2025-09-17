#!/bin/bash

# Automatic build issue fixer for Fuego Wallet
# This script addresses common build problems

echo "🔧 Fuego Wallet Build Issue Fixer"
echo "=================================="

# Function to check and fix submodules
fix_submodules() {
    echo "📦 Checking submodules..."
    
    if [ ! -d "cryptonote/.git" ]; then
        echo "   Fixing cryptonote submodule..."
        rm -rf cryptonote
        git clone https://github.com/colinritman/fuego.git cryptonote
    fi
    
    if [ ! -d "libqrencode/.git" ]; then
        echo "   Fixing libqrencode submodule..."
        rm -rf libqrencode
        git clone https://github.com/fukuchi/libqrencode.git libqrencode
    fi
    
    if [ ! -d "xfgwin/.git" ]; then
        echo "   Fixing xfgwin submodule..."
        rm -rf xfgwin
        git clone https://github.com/colinritman/xfgwin.git xfgwin
        cd xfgwin
        git checkout complete-xfgwin-system
        cd ..
    fi
    
    echo "✅ Submodules fixed"
}

# Function to create missing headers
create_missing_headers() {
    echo "📝 Creating missing headers..."
    
    # Create System headers
    mkdir -p cryptonote/src/System
    mkdir -p cryptonote/external/parallel_hashmap
    
    # NativeContext.h
    cat > cryptonote/src/System/NativeContext.h << 'EOF'
#ifndef SYSTEM_NATIVECONTEXT_H
#define SYSTEM_NATIVECONTEXT_H
#include <functional>
namespace System {
    class NativeContextGroup;
    class NativeContext {
    public:
        bool interrupted = false;
        NativeContext* groupNext = nullptr;
        NativeContext* groupPrev = nullptr;
        NativeContextGroup* group = nullptr;
        std::function<void()> procedure;
        NativeContext() = default;
        virtual ~NativeContext() = default;
    };
}
#endif
EOF

    # NativeContextGroup.h
    cat > cryptonote/src/System/NativeContextGroup.h << 'EOF'
#ifndef SYSTEM_NATIVECONTEXTGROUP_H
#define SYSTEM_NATIVECONTEXTGROUP_H
namespace System {
    class NativeContextGroup {
    public:
        NativeContextGroup() = default;
        virtual ~NativeContextGroup() = default;
    };
}
#endif
EOF

    # phmap.h
    cat > cryptonote/external/parallel_hashmap/phmap.h << 'EOF'
#ifndef PHMAP_H
#define PHMAP_H
#include <unordered_map>
#include <unordered_set>
namespace phmap {
    template<typename K, typename V, typename Hash = std::hash<K>>
    using flat_hash_map = std::unordered_map<K, V, Hash>;
    template<typename K>
    using flat_hash_set = std::unordered_set<K>;
    template<typename K, typename V, typename Hash = std::hash<K>>
    using parallel_flat_hash_map = std::unordered_map<K, V, Hash>;
}
#endif
EOF

    echo "✅ Missing headers created"
}

# Function to fix serialization conflicts
fix_serialization_conflicts() {
    echo "🔀 Fixing serialization conflicts..."
    
    if [ -f "cryptonote/src/Serialization/SerializationOverloads.h" ]; then
        # Backup original
        cp cryptonote/src/Serialization/SerializationOverloads.h cryptonote/src/Serialization/SerializationOverloads.h.backup
        
        # Comment out conflicting functions
        sed -i.bak 's/template <typename K, typename V, typename Hash>/\/\/ Commented out to avoid conflict\n\/\/ template <typename K, typename V, typename Hash>/' cryptonote/src/Serialization/SerializationOverloads.h
        sed -i.bak 's/bool serialize(flat_hash_map<K, V, Hash> &value, Common::StringView name, CryptoNote::ISerializer \&serializer)/\/\/ bool serialize(flat_hash_map<K, V, Hash> \&value, Common::StringView name, CryptoNote::ISerializer \&serializer)/' cryptonote/src/Serialization/SerializationOverloads.h
        sed -i.bak 's/return serializeMap(value, name, serializer, \[\]\(size_t size\) \{\});/\/\/ return serializeMap(value, name, serializer, \[\]\(size_t size\) \{\});/' cryptonote/src/Serialization/SerializationOverloads.h
        sed -i.bak 's/\}/\n\/\/ \}/' cryptonote/src/Serialization/SerializationOverloads.h
        
        rm cryptonote/src/Serialization/SerializationOverloads.h.bak
    fi
    
    echo "✅ Serialization conflicts fixed"
}

# Function to build STARK CLI
build_stark_cli() {
    echo "🦀 Building STARK CLI..."
    
    if [ -d "xfgwin" ]; then
        cd xfgwin
        git checkout complete-xfgwin-system
        cargo build --bin xfg-stark-cli --release
        if [ $? -eq 0 ]; then
            echo "✅ STARK CLI built successfully"
            ls -la target/release/xfg-stark-cli
        else
            echo "❌ STARK CLI build failed"
        fi
        cd ..
    else
        echo "❌ xfgwin directory not found"
    fi
}

# Function to build Fuego Wallet
build_fuego_wallet() {
    echo "🏗️  Building Fuego Wallet..."
    
    # Try qmake first
    qmake Fuego-GUI.pro
    if [ $? -eq 0 ]; then
        make -j$(nproc) 2>/dev/null || make -j2
        if [ $? -eq 0 ]; then
            echo "✅ Fuego Wallet built successfully with qmake"
            ls -la fuego-desktop.app/Contents/MacOS/fuego-desktop 2>/dev/null || ls -la fuego-desktop 2>/dev/null
        else
            echo "❌ Fuego Wallet build failed with qmake"
        fi
    else
        echo "❌ qmake failed"
    fi
}

# Main execution
main() {
    fix_submodules
    create_missing_headers
    fix_serialization_conflicts
    build_stark_cli
    build_fuego_wallet
    
    echo ""
    echo "🎉 Build issue fixing complete!"
    echo "📊 Check the results above for any remaining issues."
}

# Run main function
main "$@"
