#ifndef FUEGO_ALIAS_SERVICE_H
#define FUEGO_ALIAS_SERVICE_H

#include "fuego_sdk.h"
#include <string>
#include <vector>

namespace fuego {

class AliasService {
public:
    static FuegoError registerAlias(const std::string& alias, const std::string& walletAddress,
                                     const std::string& walletFile, const std::string& walletPassword,
                                     char* txHash, size_t txHashSize);

    static FuegoError resolveAlias(const std::string& alias, char* walletAddress, size_t addressSize);

    static FuegoError getOwnedAliases(const std::string& walletAddress, char** aliases, size_t* count);
};

} // namespace fuego

#endif // FUEGO_ALIAS_SERVICE_H
