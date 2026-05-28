#ifndef FUEGO_MINER_H
#define FUEGO_MINER_H

#include "fuego_sdk.h"
#include <string>
#include <atomic>

namespace fuego {

class Miner {
public:
    static Miner& instance();

    FuegoError start(const std::string& walletAddress);
    void stop();
    bool isRunning() const;
    double getHashrate() const;

private:
    Miner() = default;
    ~Miner();

    Miner(const Miner&) = delete;
    Miner& operator=(const Miner&) = delete;

    std::atomic<bool> m_running{false};
    std::string m_walletAddress;
    mutable double m_hashrate = 0.0;
};

} // namespace fuego

#endif // FUEGO_MINER_H
