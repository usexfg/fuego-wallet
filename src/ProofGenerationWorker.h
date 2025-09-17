#pragma once

#include <QObject>
#include <QString>

namespace WalletGui {

class ProofGenerationWorker : public QObject {
  Q_OBJECT

public:
  ProofGenerationWorker();

public slots:
  void generateProof(const QString& transactionHash, 
                    const QString& recipientAddress,
                    quint64 burnAmount);

signals:
  void proofGenerationCompleted(const QString& transactionHash, bool success, const QString& errorMessage);
  void proofGenerationProgress(const QString& transactionHash, int progress);
};

} // namespace WalletGui
