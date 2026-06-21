#include "miner.h"

#include "node/node_manager.h"

#include <chrono>
#include <thread>
#include <future>

namespace fuego {

Miner& Miner::instance() {
    static Miner instance;
    return instance;
}

Miner::~Miner() {
    stop();
}

FuegoError Miner::start(const std::string& walletAddress) {
    if (m_running) {
        return FUEGO_ERROR_MINING;
    }

    auto node = NodeManager::instance().getNode();
    if (!node) {
        return FUEGO_ERROR_NOT_INITIALIZED;
    }

    // INode does not expose startMining/stopMining directly.
    // Mining requires MinerManager with a Dispatcher, which is not
    // available through the lightweight SDK wrapper.
    // TODO: integrate MinerManager for embedded mining support.
    return FUEGO_ERROR_NOT_INITIALIZED;
}

void Miner::stop() {
    m_running = false;
}

bool Miner::isRunning() const {
    return m_running;
}

double Miner::getHashrate() const {
    return m_hashrate;
}

} // namespace fuego
