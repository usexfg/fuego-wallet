// Copyright (c) 2011-2017 The Cryptonote developers
// Copyright (c) 2014-2017 XDN developers
// Copyright (c) 2016 The Karbowanec developers
// Copyright (c) 2018 The Circle Foundation & Conceal Devs
// Copyright (c) 2018-2019 Conceal Network & Conceal Devs
//
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include <QApplication>
#include <QDesktopWidget>
#include <QLocale>
#include <QLockFile>
#include <QMessageBox>
#include <QRegularExpression>
#include <QStyle>
#include <QStyleFactory>
#include <QDateTime>
#include <QTextStream>

#include "CommandLineParser.h"
#include "CurrencyAdapter.h"
#include "LogFileWatcher.h"
#include "LoggerAdapter.h"
#include "NodeAdapter.h"
#include "Settings.h"
#include "SignalHandler.h"
#include "TranslatorManager.h"
#include "UpdateManager.h"
#include "WalletAdapter.h"
#include "gui/MainWindow.h"
#include "gui/SplashScreen.h"

#define DEBUG 1

using namespace WalletGui;

const QRegularExpression LOG_SPLASH_REG_EXP("(?<=] ).*");

SplashScreen* splashScreen(nullptr);

inline void newLogString(const QString& _string)
{
  QRegularExpressionMatch match = LOG_SPLASH_REG_EXP.match(_string);
  if (match.hasMatch())
  {
    QString message = match.captured(0).toUpper();
    splashScreen->showMessage(message, Qt::AlignCenter | Qt::AlignBottom, Qt::darkGray);
  }
}

int main(int argc, char* argv[])
{
/*#if QT_VERSION >= QT_VERSION_CHECK(5, 6, 0)
  QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif*/
  QApplication app(argc, argv);
  QApplication::setApplicationName("Fuego Desktop Wallet");
  QApplication::setApplicationVersion(Settings::instance().getVersion());
  QApplication::setQuitOnLastWindowClosed(false);

#ifndef Q_OS_MAC
  QApplication::setStyle(QStyleFactory::create("Fusion"));
#endif

  CommandLineParser cmdLineParser(nullptr);
  Settings::instance().setCommandLineParser(&cmdLineParser);
  bool cmdLineParseResult = cmdLineParser.process(QApplication::arguments());
  Settings::instance().load();

  // Translator must be created before the application's widgets.
  TranslatorManager* tManager = TranslatorManager::instance();
  Q_UNUSED(tManager)

  setlocale(LC_ALL, "");

#ifdef Q_OS_WIN
  if (!cmdLineParseResult)
  {
    QMessageBox::critical(&MainWindow::instance(), QObject::tr("Error"),
                          cmdLineParser.getErrorText());
    return app.exec();
  }
  else if (cmdLineParser.hasHelpOption())
  {
    QMessageBox::information(&MainWindow::instance(), QObject::tr("Help"),
                             cmdLineParser.getHelpText());
    return app.exec();
  }
#else
  Q_UNUSED(cmdLineParseResult)
#endif

  // Add debug logging before data directory creation
  QString debugLogPath = QDir::homePath() + "/Library/Application Support/fuego/early_debug.log";
  QDir().mkpath(QFileInfo(debugLogPath).absolutePath());
  QFile earlyDebugLog(debugLogPath);
  if (earlyDebugLog.open(QIODevice::WriteOnly | QIODevice::Append))
  {
    QTextStream stream(&earlyDebugLog);
    stream << QDateTime::currentDateTime().toString() << " - App started, about to get data dir\n";
    earlyDebugLog.close();
  }
  
  QString dataDirPath = Settings::instance().getDataDir().absolutePath();
  if (earlyDebugLog.open(QIODevice::WriteOnly | QIODevice::Append))
  {
    QTextStream stream(&earlyDebugLog);
    stream << QDateTime::currentDateTime().toString() << " - Data dir: " << dataDirPath << "\n";
    earlyDebugLog.close();
  }
  
  if (!QDir().exists(dataDirPath))
  {
    QDir().mkpath(dataDirPath);
    if (earlyDebugLog.open(QIODevice::WriteOnly | QIODevice::Append))
    {
      QTextStream stream(&earlyDebugLog);
      stream << QDateTime::currentDateTime().toString() << " - Created data directory: " << dataDirPath << "\n";
      earlyDebugLog.close();
    }
  }

  // Create early debug log file
  QString mainDebugLogPath = dataDirPath + "/debug.log";
  QFile debugLog(mainDebugLogPath);
  if (debugLog.open(QIODevice::WriteOnly | QIODevice::Append))
  {
    QTextStream stream(&debugLog);
    stream << QDateTime::currentDateTime().toString() << " - App started, data dir: " << dataDirPath << "\n";
    stream << QDateTime::currentDateTime().toString() << " - About to initialize logger\n";
    debugLog.close();
  }

  // Add debug logging before logger initialization
  if (earlyDebugLog.open(QIODevice::WriteOnly | QIODevice::Append))
  {
    QTextStream stream(&earlyDebugLog);
    stream << QDateTime::currentDateTime().toString() << " - About to initialize logger\n";
    earlyDebugLog.close();
  }
  
  LoggerAdapter::instance().init();
  
  // Add debug logging after logger initialization
  if (earlyDebugLog.open(QIODevice::WriteOnly | QIODevice::Append))
  {
    QTextStream stream(&earlyDebugLog);
    stream << QDateTime::currentDateTime().toString() << " - Logger initialized successfully\n";
    
    // Test if the main log file was created
    QString mainLogPath = dataDirPath + "/Fuegowallet.log";
    if (QFile::exists(mainLogPath))
    {
      stream << QDateTime::currentDateTime().toString() << " - Main log file exists: " << mainLogPath << "\n";
    }
    else
    {
      stream << QDateTime::currentDateTime().toString() << " - Main log file NOT found: " << mainLogPath << "\n";
    }
    earlyDebugLog.close();
  }

  QLockFile lockFile(Settings::instance().getDataDir().absoluteFilePath(
      QApplication::applicationName() + ".lock"));
  if (!lockFile.tryLock())
  {
    QMessageBox::warning(nullptr, QObject::tr("Fail"),
                         QString("%1 wallet already running")
                             .arg(CurrencyAdapter::instance().getCurrencyDisplayName()));
    return 0;
  }

  QLocale::setDefault(QLocale::c());

  SignalHandler::instance().init();
  QObject::connect(&SignalHandler::instance(), &SignalHandler::quitSignal, &app,
                   &QApplication::quit);

  if (splashScreen == nullptr)
  {
    splashScreen = new SplashScreen();
   splashScreen->centerOnScreen(&app);
  }

  splashScreen->show();

  LogFileWatcher* logWatcher = new LogFileWatcher(
      Settings::instance().getDataDir().absoluteFilePath("Fuegowallet.log"), &app);
  QObject::connect(logWatcher, &LogFileWatcher::newLogStringSignal, &app, &newLogString);

  QApplication::processEvents();
  qRegisterMetaType<CryptoNote::TransactionId>("CryptoNote::TransactionId");
  qRegisterMetaType<quintptr>("quintptr");
  
  // Add debug logging before NodeAdapter init
  if (debugLog.open(QIODevice::WriteOnly | QIODevice::Append))
  {
    QTextStream stream(&debugLog);
    stream << QDateTime::currentDateTime().toString() << " - About to initialize NodeAdapter\n";
    debugLog.close();
  }
  
  if (!NodeAdapter::instance().init())
  {
    // Add debug logging if NodeAdapter init fails
    if (debugLog.open(QIODevice::WriteOnly | QIODevice::Append))
    {
      QTextStream stream(&debugLog);
      stream << QDateTime::currentDateTime().toString() << " - NodeAdapter init failed\n";
      debugLog.close();
    }
    return 0;
  }
  
  // Add debug logging after successful NodeAdapter init
  if (debugLog.open(QIODevice::WriteOnly | QIODevice::Append))
  {
    QTextStream stream(&debugLog);
    stream << QDateTime::currentDateTime().toString() << " - NodeAdapter init successful\n";
    debugLog.close();
  }

  splashScreen->finish(&MainWindow::instance());

  logWatcher->deleteLater();
  logWatcher = nullptr;

  splashScreen->deleteLater();
  splashScreen = nullptr;

  Updater* d = new Updater();
  d->checkForUpdate();
  MainWindow::instance().show();

  WalletAdapter::instance().open("");
  QObject::connect(QApplication::instance(), &QApplication::aboutToQuit, []() {
    MainWindow::instance().quit();
    if (WalletAdapter::instance().isOpen())
    {
      WalletAdapter::instance().close();
    }

    NodeAdapter::instance().deinit();
  });

  return QApplication::exec();
}
