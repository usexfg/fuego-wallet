#include "ProofGenerationWorker.h"
#include "StarkProofService.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QProcessEnvironment>
#include <QThread>
#include <QTimer>
#include <QMutex>
#include <QMutexLocker>

#include "WalletAdapter.h"
#include "Settings.h"

namespace WalletGui {

ProofGenerationWorker::ProofGenerationWorker() : QObject() {}

void ProofGenerationWorker::generateProof(const QString& transactionHash,
                                         const QString& recipientAddress,
                                         quint64 burnAmount) {
  // Get the path to the auto-stark-proof script
  QString scriptPath = QCoreApplication::applicationDirPath() + "/auto_stark_proof.sh";

  // Check if script exists in different locations
  if (!QFile::exists(scriptPath)) {
    scriptPath = QCoreApplication::applicationDirPath() + "/scripts/auto_stark_proof.sh";
  }

  if (!QFile::exists(scriptPath)) {
    scriptPath = QCoreApplication::applicationDirPath() + "/../scripts/auto_stark_proof.sh";
  }

  // For development/testing
  if (!QFile::exists(scriptPath)) {
    scriptPath = QCoreApplication::applicationDirPath() + "/../scripts/auto_stark_proof.sh";
  }

  // For submodule setup
  if (!QFile::exists(scriptPath)) {
    scriptPath = QCoreApplication::applicationDirPath() + "/xfgwin/scripts/auto_stark_proof.sh";
  }

  if (!QFile::exists(scriptPath)) {
    Q_EMIT proofGenerationCompleted(transactionHash, false, "Auto STARK proof script not found");
    return;
  }

  // Make script executable
  QFile scriptFile(scriptPath);
  scriptFile.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
                           QFile::ReadGroup | QFile::ExeGroup |
                           QFile::ReadOther | QFile::ExeOther);

  // Create process for xfg-stark-cli
  QProcess* process = new QProcess(this);
  
  // Store the process in StarkProofService for tracking
  StarkProofService::instance().storeProcess(transactionHash, process);

  QStringList arguments;
  arguments << transactionHash << recipientAddress << QString::number(burnAmount);

  // Set environment variables for the script
  QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
  env.insert("FUEGO_AUTO_STARK_PROOF", "true");
  env.insert("FUEGO_ELDERNODE_VERIFICATION", "true");
  env.insert("FUEGO_ELDERNODE_TIMEOUT", "300");
  process->setProcessEnvironment(env);

  // Connect process signals for progress tracking
  connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
          [this, transactionHash, process](int exitCode, QProcess::ExitStatus exitStatus) {
            bool success = (exitCode == 0 && exitStatus == QProcess::NormalExit);
            QString error = success ? "" : QString::fromUtf8(process->readAllStandardError());
            Q_EMIT proofGenerationCompleted(transactionHash, success, error);
            
            // Clean up process
            StarkProofService::instance().removeProcess(transactionHash);
            process->deleteLater();
          });

  connect(process, &QProcess::readyReadStandardOutput,
          [this, transactionHash, process]() {
            // Parse progress from xfg-stark-cli output
            QString output = QString::fromUtf8(process->readAllStandardOutput());
            // Look for progress indicators in the output
            // This would need to be customized based on xfg-stark-cli output format
            Q_EMIT proofGenerationProgress(transactionHash, 50); // Placeholder
          });

  process->start(scriptPath, arguments);

  if (!process->waitForStarted(5000)) {
    Q_EMIT proofGenerationCompleted(transactionHash, false, "Failed to start STARK proof generation");
    StarkProofService::instance().removeProcess(transactionHash);
    process->deleteLater();
    return;
  }

  // Set timeout
  QTimer::singleShot(300000, [this, transactionHash, process]() { // 5 minute timeout
    if (process->state() == QProcess::Running) {
      process->kill();
      Q_EMIT proofGenerationCompleted(transactionHash, false, "Proof generation timed out");
      StarkProofService::instance().removeProcess(transactionHash);
      process->deleteLater();
    }
  });
}

} // namespace WalletGui

#include "ProofGenerationWorker.moc"
