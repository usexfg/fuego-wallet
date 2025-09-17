// Copyright (c) 2011-2017 The Cryptonote developers
// Copyright (c) 2014-2017 XDN developers
//  
// Copyright (c) 2018 The Circle Foundation & Conceal Devs
// Copyright (c) 2018-2019 Conceal Network & Conceal Devs
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include "LoggerAdapter.h"
#include "Settings.h"
#include <ctime>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <Logging/LoggerRef.h>

namespace WalletGui {

LoggerAdapter& LoggerAdapter::instance() {
  static LoggerAdapter inst;
  return inst;
}

void LoggerAdapter::init() {
  Common::JsonValue loggerConfiguration(Common::JsonValue::OBJECT);
  int64_t logLevel =
#ifdef DEBUG
	  Logging::TRACE
#else
		Logging::INFO
#endif
  ;
  loggerConfiguration.insert("globalLevel", logLevel);
  Common::JsonValue& cfgLoggers = loggerConfiguration.insert("loggers", Common::JsonValue::ARRAY);
  Common::JsonValue& fileLogger = cfgLoggers.pushBack(Common::JsonValue::OBJECT);
  fileLogger.insert("type", "file");
  fileLogger.insert("filename", Settings::instance().getDataDir().absoluteFilePath("Fuegowallet.log").toStdString());
  fileLogger.insert("level", logLevel);
  m_logManager.configure(loggerConfiguration);
  
  // Test if logging is working by creating a test log entry
  std::string testMessage = "LoggerAdapter initialized successfully - " + std::to_string(time(nullptr));
  Logging::LoggerRef logger(m_logManager, "test");
  logger(Logging::INFO) << testMessage;
  
  // Also create a simple test log file to verify file creation works
  QString logFilePath = Settings::instance().getDataDir().absoluteFilePath("Fuegowallet.log");
  QFile testLogFile(logFilePath);
  if (testLogFile.open(QIODevice::WriteOnly | QIODevice::Append))
  {
    QTextStream stream(&testLogFile);
    stream << QDateTime::currentDateTime().toString().toStdString().c_str() << " - LoggerAdapter test entry\n";
    testLogFile.close();
  }
}

LoggerAdapter::LoggerAdapter() : m_logManager() {
}

LoggerAdapter::~LoggerAdapter() {
}

Logging::LoggerManager& LoggerAdapter::getLoggerManager() {
  return m_logManager;
}

}
