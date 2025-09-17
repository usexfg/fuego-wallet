// Copyright (c) 2011-2017 The Cryptonote developers
// Copyright (c) 2018 The Circle Foundation & Conceal Devs
// Copyright (c) 2018-2019 Conceal Network & Conceal Devs
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#pragma once

#include <QDialog>
#include <QScopedPointer>

namespace Ui {
class StarkSettingsDialog;
}

namespace WalletGui {

class StarkSettingsDialog : public QDialog {
  Q_OBJECT
  Q_DISABLE_COPY(StarkSettingsDialog)

public:
  explicit StarkSettingsDialog(QWidget* _parent);
  ~StarkSettingsDialog();

private slots:
  void onBrowseButtonClicked();
  void onResetButtonClicked();
  void onOkButtonClicked();

private:
  QScopedPointer<Ui::StarkSettingsDialog> m_ui;
  
  void loadSettings();
  void saveSettings();
  void resetToDefaults();
  bool validateRecipientAddress(const QString& address);
};

} // namespace WalletGui
