#ifndef FUEGO_DEPOSIT_H
#define FUEGO_DEPOSIT_H

#include "fuego_sdk.h"
#include <string>

namespace fuego {

class DepositManager {
public:
    static FuegoError createDeposit(uint64_t amount, uint64_t lockTime,
                                     const std::string& walletFile,
                                     const std::string& walletPassword,
                                     FuegoCDInfo* cdInfo);

    static FuegoError redeemDeposit(const std::string& txHash,
                                     const std::string& walletFile,
                                     const std::string& walletPassword,
                                     uint64_t* redeemedAmount);

    static FuegoError getDepositInfo(const std::string& txHash, FuegoCDInfo* cdInfo);
};

} // namespace fuego

#endif // FUEGO_DEPOSIT_H
