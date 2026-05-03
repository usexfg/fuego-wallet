#include "node_manager.h"

#include "INode.h"
#include "Logging/LoggerManager.h"
#include "PaymentGate/NodeFactory.h"
#include "Common/PathTools.h"

#ifdef BUILD_EMBEDDED_NODE
#include "InProcessNode/InProcessNode.h"
#include "CryptoNoteCore/CoreConfig.h"
#include "P2p/NetNodeConfig.h"
#endif

#include <System/Dispatcher.h>
#include <System/Context.h>

namespace fuego {

NodeManager& NodeManager::instance() {
    static NodeManager instance;
    return instance;
}

NodeManager::~NodeManager() {
    stop();
}

FuegoError NodeManager::startEmbedded(const std::string& dataDir, bool testnet) {
#ifdef BUILD_EMBEDDED_NODE
    if (m_running) {
        return FUEGO_ERROR_NODE;
    }

    try {
        m_logger = std::make_unique<Logging::LoggerManager>();
        
        CryptoNote::CoreConfig coreConfig;
        coreConfig.setTestnet(testnet);
        coreConfig.setDataDir(dataDir);

        CryptoNote::NetNodeConfig netNodeConfig;
        netNodeConfig.setTestnet(testnet);

        m_node = CryptoNote::createInProcessNode(
            coreConfig,
            netNodeConfig,
            *m_logger
        );

        if (!m_node) {
            return FUEGO_ERROR_NODE;
        }

        System::Dispatcher dispatcher;
        bool initFailed = false;
        System::Context<void> initContext(dispatcher, [this, &initFailed]() {
            m_node->init([&initFailed](std::error_code err) {
                if (err) {
                    initFailed = true;
                }
            });
        });
        dispatcher.yield();

        if (initFailed) {
            m_node.reset();
            return FUEGO_ERROR_NODE;
        }

        m_running = true;
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_NODE;
    }
#else
    return FUEGO_ERROR_NOT_INITIALIZED;
#endif
}

FuegoError NodeManager::startRemote(const std::string& host, uint16_t port) {
    if (m_running) {
        return FUEGO_ERROR_NODE;
    }

    try {
        m_logger = std::make_unique<Logging::LoggerManager>();
        
        // Use NodeFactory for remote node creation
        m_node = std::unique_ptr<CryptoNote::INode>(PaymentService::NodeFactory::createNode(host, port));

        if (!m_node) {
            return FUEGO_ERROR_NODE;
        }

        System::Dispatcher dispatcher;
        bool initFailed = false;
        System::Context<void> initContext(dispatcher, [this, &initFailed]() {
            m_node->init([&initFailed](std::error_code err) {
                if (err) {
                    initFailed = true;
                }
            });
        });
        dispatcher.yield();

        if (initFailed) {
            m_node.reset();
            return FUEGO_ERROR_NODE;
        }

        m_running = true;
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_NODE;
    }
}

void NodeManager::stop() {
    if (!m_running || !m_node) {
        return;
    }

    try {
        m_node->shutdown();
        m_node.reset();
        m_logger.reset();
        m_running = false;
    } catch (...) {
        // Ignore errors during shutdown
    }
}

bool NodeManager::isRunning() const {
    return m_running && m_node != nullptr;
}

uint32_t NodeManager::getPeerCount() const {
    if (!isRunning()) {
        return 0;
    }
    return static_cast<uint32_t>(m_node->getPeerCount());
}

uint32_t NodeManager::getBlockHeight() const {
    if (!isRunning()) {
        return 0;
    }
    return m_node->getLastLocalBlockHeight();
}

bool NodeManager::isSynchronized() const {
    if (!isRunning()) {
        return false;
    }
    
    return m_node->getLastLocalBlockHeight() >= m_node->getLastKnownBlockHeight();
}

} // namespace fuego
