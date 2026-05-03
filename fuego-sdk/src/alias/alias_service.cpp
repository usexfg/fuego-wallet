#include "alias_service.h"

#include "CryptoNoteCore/AliasIndex.h"
#include "crypto/hash.h"
#include "Common/StringTools.h"

#include <map>
#include <mutex>
#include <cstring>

namespace fuego {

namespace {
    // The actual Fuego AliasIndex instance
    CryptoNote::AliasIndex g_aliasIndex;
    std::mutex g_aliasMutex;
    
    Crypto::Hash computeHash(const std::string& s) {
        Crypto::Hash h;
        Crypto::cn_fast_hash(s.data(), s.length(), h);
        return h;
    }
}

FuegoError AliasService::registerAlias(const std::string& alias, const std::string& walletAddress,
                                        const std::string& /*walletFile*/, const std::string& /*walletPassword*/,
                                        char* txHash, size_t txHashSize) {
    if (txHash == nullptr || txHashSize < 65 || alias.empty() || walletAddress.empty()) {
        return FUEGO_ERROR_INVALID_PARAM;
    }

    if (!CryptoNote::AliasIndex::isValidRegularAlias(alias)) {
        return FUEGO_ERROR_ALIAS;
    }

    try {
        std::lock_guard<std::mutex> lock(g_aliasMutex);
        
        CryptoNote::AliasEntry entry;
        entry.alias = alias;
        entry.aliasHash = computeHash(alias);
        entry.addressHash = computeHash(walletAddress);
        entry.aliasType = 1;

        if (!g_aliasIndex.registerAlias(entry)) {
            return FUEGO_ERROR_ALIAS;
        }

        std::string placeholderHash = "alias_reg_" + alias;
        strncpy(txHash, placeholderHash.c_str(), txHashSize - 1);
        txHash[txHashSize - 1] = '\0';

        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_ALIAS;
    }
}

FuegoError AliasService::resolveAlias(const std::string& alias, char* walletAddress, size_t addressSize) {
    if (walletAddress == nullptr || addressSize == 0 || alias.empty()) {
        return FUEGO_ERROR_INVALID_PARAM;
    }

    try {
        std::lock_guard<std::mutex> lock(g_aliasMutex);
        
        auto entry = g_aliasIndex.getAliasByName(alias);
        if (!entry) {
            return FUEGO_ERROR_ALIAS;
        }

        strncpy(walletAddress, "resolved_address_placeholder", addressSize - 1);
        walletAddress[addressSize - 1] = '\0';

        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_ALIAS;
    }
}

FuegoError AliasService::getOwnedAliases(const std::string& walletAddress, char** aliases, size_t* count) {
    if (walletAddress.empty() || aliases == nullptr || count == nullptr) {
        return FUEGO_ERROR_INVALID_PARAM;
    }

    try {
        std::lock_guard<std::mutex> lock(g_aliasMutex);

        std::vector<CryptoNote::AliasEntry> all = g_aliasIndex.getAllAliases();
        std::vector<std::string> owned;
        
        Crypto::Hash addrHash = computeHash(walletAddress);
        
        for (const auto& entry : all) {
            if (entry.addressHash == addrHash) {
                owned.push_back(entry.alias);
            }
        }

        *count = owned.size();
        if (*count == 0) {
            *aliases = nullptr;
            return FUEGO_OK;
        }

        *aliases = static_cast<char*>(malloc(sizeof(char*) * (*count)));
        auto aliasesArray = reinterpret_cast<char**>(*aliases);
        for (size_t i = 0; i < *count; ++i) {
            aliasesArray[i] = static_cast<char*>(malloc(owned[i].length() + 1));
            strncpy(aliasesArray[i], owned[i].c_str(), owned[i].length());
            aliasesArray[i][owned[i].length()] = '\0';
        }

        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_ALIAS;
    }
}

} // namespace fuego
