#ifndef FUEGO_NODE_MANAGER_H
#define FUEGO_NODE_MANAGER_H

#include "fuego_sdk.h"
#include <string>
#include <memory>

#include "INode.h"
#include "Logging/LoggerManager.h"

namespace fuego {

class NodeManager {
public:
    static NodeManager& instance();

    FuegoError startEmbedded(const std::string& dataDir, bool testnet);
    FuegoError startRemote(const std::string& host, uint16_t port);
    void stop();
    bool isRunning() const;
    uint32_t getPeerCount() const;
    uint32_t getBlockHeight() const;
    std::string getTailId() const;
    bool isSynchronized() const;


private:
    NodeManager() = default;
    ~NodeManager();

    NodeManager(const NodeManager&) = delete;
    NodeManager& operator=(const NodeManager&) = delete;

    std::unique_ptr<CryptoNote::INode> m_node;
    std::unique_ptr<Logging::LoggerManager> m_logger;
    std::string m_nodeHost;
    uint16_t m_nodePort = 0;
    bool m_running = false;
};

} // namespace fuego

#endif // FUEGO_NODE_MANAGER_H
