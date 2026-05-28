#include "miner.h"

#include "node/node_manager.h"
#include "Logging/LoggerManager.h"

#include <chrono>
#include <thread>
#include <future>

namespace fuego {

static Logging::LoggerManager g_minerLogger;

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

    try {
        m_walletAddress = walletAddress;
        
        auto node = NodeManager::instance().getNode();
        if (!node) {
            return FUEGO_ERROR_NOT_INITIALIZED;
        }

        std::promise<std::error_code> promise;
        node->startMining(walletAddress, 1, [&promise](std::error_code ec) {
            promise.set_value(ec);
        });
        
        auto ec = promise.get_future().get();
        if (ec) {
            return FUEGO_ERROR_MINING;
        }
        
        m_running = true;
        return FUEGO_OK;
    } catch (...) {
        m_running = false;
        return FUEGO_ERROR_MINING;
    }
}

void Miner::stop() {
    if (!m_running) {
        return;
    }

    m_running = false;
    
    auto node = NodeManager::instance().getNode();
    if (node) {
        std::promise<std::error_code> promise;
        node->stopMining([&promise](std::error_code ec) {
            promise.set_value(ec);
        });
        promise.get_future().get();
    }
}

bool Miner::isRunning() const {
    return m_running;
}

double Miner::getHashrate() const {
    // TODO: implement actual hashrate retrieval if supported by node
    return m_hashrate;
}

} // namespace fuego
