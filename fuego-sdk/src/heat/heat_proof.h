#ifndef FUEGO_HEAT_PROOF_H
#define FUEGO_HEAT_PROOF_H

#include "fuego_sdk.h"
#include <string>

namespace fuego {

class HEATProver {
public:
    static FuegoError generateProof(const std::string& rpc_url,
                                    const std::string& checkpoint_hash,
                                    uint32_t block_start,
                                    uint32_t block_end,
                                    const std::string& wallet_file,
                                    const std::string& wallet_password,
                                    FuegoHEATProof* proof);

    static FuegoError verifyProof(const FuegoHEATProof* proof, bool* valid);
};

} // namespace fuego

#endif // FUEGO_HEAT_PROOF_H

