#pragma once

#include <QObject>
#include <QString>
#include <QThread>
#include <QMutex>
#include <QProcess>
#include <QHash>
#include <atomic>

namespace WalletGui {

class ProofGenerationWorker;

class StarkProofService : public QObject {
  Q_OBJECT
  Q_DISABLE_COPY(StarkProofService)

public:
  static StarkProofService& instance();

  // Check if a transaction is a burn transaction that needs STARK proof
  bool isBurnTransaction(const QString& transactionHash, quint64 amount);
  
  // Generate STARK proof for a burn transaction
  void generateStarkProof(const QString& transactionHash, 
                         const QString& recipientAddress,
                         quint64 burnAmount);
  
  // Get proof status for a transaction
  QString getProofStatus(const QString& transactionHash);
  
  // Retry failed proof generation
  void retryProofGeneration(const QString& transactionHash);
  
  // Get progress for a transaction
  int getProofProgress(const QString& transactionHash);
  
  // Get error message for a transaction
  QString getProofErrorMessage(const QString& transactionHash);
  
  // Check if proof generation is enabled
  bool isEnabled() const;
  
  // Enable/disable automatic proof generation
  void setEnabled(bool enabled);
  
  // Process management for xfg-stark-cli tracking
  void storeProcess(const QString& transactionHash, QProcess* process);
  void removeProcess(const QString& transactionHash);

signals:
  void proofGenerationStarted(const QString& transactionHash);
  void proofGenerationCompleted(const QString& transactionHash, bool success, const QString& errorMessage);
  void proofGenerationProgress(const QString& transactionHash, int progress);

private:
  StarkProofService();
  ~StarkProofService();

  QThread* m_workerThread;
  ProofGenerationWorker* m_worker;
  QMutex m_mutex;
  std::atomic<bool> m_enabled;
  
  // Process tracking for xfg-stark-cli
  QHash<QString, QProcess*> m_runningProcesses;
  QHash<QString, QString> m_statusMap;
  QHash<QString, QString> m_errorMap;
  QHash<QString, int> m_progressMap;
  
  void onProofGenerationCompleted(const QString& transactionHash, bool success, const QString& errorMessage);
};

} // namespace WalletGui
