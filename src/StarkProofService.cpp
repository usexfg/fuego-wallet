#include "StarkProofService.h"
#include "ProofGenerationWorker.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QThread>
#include <QTimer>
#include <QMutex>
#include <QMutexLocker>

#include "WalletAdapter.h"
#include "Settings.h"

namespace WalletGui {

StarkProofService& StarkProofService::instance() {
  static StarkProofService inst;
  return inst;
}

StarkProofService::StarkProofService() 
  : QObject()
  , m_workerThread(nullptr)
  , m_worker(nullptr)
  , m_enabled(true) {
  
  // Create worker thread for proof generation
  m_workerThread = new QThread(this);
  m_worker = new ProofGenerationWorker();
  m_worker->moveToThread(m_workerThread);
  
  // Connect worker signals
  connect(m_worker, &ProofGenerationWorker::proofGenerationCompleted,
          this, &StarkProofService::onProofGenerationCompleted);
  connect(m_worker, &ProofGenerationWorker::proofGenerationProgress,
          this, &StarkProofService::proofGenerationProgress);
  
  // Start worker thread
  m_workerThread->start();
}

StarkProofService::~StarkProofService() {
  if (m_workerThread) {
    m_workerThread->quit();
    m_workerThread->wait();
  }
}

bool StarkProofService::isBurnTransaction(const QString& transactionHash, quint64 amount) {
  // TODO: Implement proper transaction lookup by hash
  // For now, return false as a placeholder
  // The real implementation would need to iterate through transactions
  // or find another way to get transaction details by hash
  return false;
}

void StarkProofService::generateStarkProof(const QString& transactionHash, 
                                          const QString& recipientAddress,
                                          quint64 burnAmount) {
  if (!m_enabled) {
    return;
  }
  
  QMutexLocker locker(&m_mutex);
  
  // Emit started signal
  Q_EMIT proofGenerationStarted(transactionHash);
  
  // Queue the proof generation in the worker thread
  QMetaObject::invokeMethod(m_worker, "generateProof", Qt::QueuedConnection,
                          Q_ARG(QString, transactionHash),
                          Q_ARG(QString, recipientAddress),
                          Q_ARG(quint64, burnAmount));
}

bool StarkProofService::isEnabled() const {
  return m_enabled;
}

void StarkProofService::setEnabled(bool enabled) {
  m_enabled = enabled;
}

void StarkProofService::onProofGenerationCompleted(const QString& transactionHash, 
                                                   bool success, 
                                                   const QString& errorMessage) {
  QMutexLocker locker(&m_mutex);
  
  // Update status and error maps
  if (success) {
    m_statusMap[transactionHash] = "completed";
    m_progressMap[transactionHash] = 100;
    m_errorMap.remove(transactionHash);
  } else {
    m_statusMap[transactionHash] = "failed";
    m_errorMap[transactionHash] = errorMessage;
  }
  
  Q_EMIT proofGenerationCompleted(transactionHash, success, errorMessage);
}

void StarkProofService::retryProofGeneration(const QString& transactionHash) {
  // Get the original transaction details from storage or cache
  // For now, we'll just reset the status to allow retry
  QMutexLocker locker(&m_mutex);
  m_statusMap[transactionHash] = "pending";
  m_progressMap[transactionHash] = 0;
  m_errorMap.remove(transactionHash);
  
  // Re-emit the started signal
  Q_EMIT proofGenerationStarted(transactionHash);
}

int StarkProofService::getProofProgress(const QString& transactionHash) {
  QMutexLocker locker(&m_mutex);
  return m_progressMap.value(transactionHash, 0);
}

QString StarkProofService::getProofErrorMessage(const QString& transactionHash) {
  QMutexLocker locker(&m_mutex);
  return m_errorMap.value(transactionHash, "");
}

QString StarkProofService::getProofStatus(const QString& transactionHash) {
  QMutexLocker locker(&m_mutex);
  
  // Check if we have a running process for this transaction
  if (m_runningProcesses.contains(transactionHash)) {
    QProcess* process = m_runningProcesses.value(transactionHash);
    if (process && process->state() == QProcess::Running) {
      return "running";
    } else if (process && process->state() == QProcess::NotRunning) {
      // Process finished, check exit code
      if (process->exitCode() == 0) {
        return "completed";
      } else {
        return "failed";
      }
    }
  }
  
  // Return stored status or default
  return m_statusMap.value(transactionHash, "none");
}

void StarkProofService::storeProcess(const QString& transactionHash, QProcess* process) {
  QMutexLocker locker(&m_mutex);
  m_runningProcesses.insert(transactionHash, process);
  m_statusMap.insert(transactionHash, "running");
}

void StarkProofService::removeProcess(const QString& transactionHash) {
  QMutexLocker locker(&m_mutex);
  m_runningProcesses.remove(transactionHash);
}

} // namespace WalletGui

#include "StarkProofService.moc"
