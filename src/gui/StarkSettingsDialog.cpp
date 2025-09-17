// Copyright (c) 2011-2017 The Cryptonote developers
// Copyright (c) 2018 The Circle Foundation & Conceal Devs
// Copyright (c) 2018-2019 Conceal Network & Conceal Devs
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include <QFileDialog>
#include <QMessageBox>
#include <QRegExp>
#include <QStandardPaths>

#include "StarkSettingsDialog.h"
#include "Settings.h"
#include "ui_starksettingsdialog.h"

namespace WalletGui {

StarkSettingsDialog::StarkSettingsDialog(QWidget* _parent) 
  : QDialog(_parent)
  , m_ui(new Ui::StarkSettingsDialog) {
  m_ui->setupUi(this);
  
  // Connect signals
  connect(m_ui->browseButton, &QPushButton::clicked, this, &StarkSettingsDialog::onBrowseButtonClicked);
  connect(m_ui->resetButton, &QPushButton::clicked, this, &StarkSettingsDialog::onResetButtonClicked);
  connect(m_ui->okButton, &QPushButton::clicked, this, &StarkSettingsDialog::onOkButtonClicked);
  
  // Load current settings
  loadSettings();
  
  // Set default storage path
  QString defaultPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/fuego-stark-proofs";
  m_ui->storagePathEdit->setText(defaultPath);
}

StarkSettingsDialog::~StarkSettingsDialog() {
}

void StarkSettingsDialog::loadSettings() {
  // Load STARK proof settings
  m_ui->enableStarkProofCheckBox->setChecked(Settings::instance().isStarkProofEnabled());
  m_ui->autoGenerateProofsCheckBox->setChecked(Settings::instance().isAutoGenerateProofs());
  
  // Load recipient address
  QString recipientAddress = Settings::instance().getDefaultRecipientAddress();
  m_ui->recipientAddressEdit->setText(recipientAddress);
  
  // Load Eldernode verification settings
  m_ui->enableEldernodeVerificationCheckBox->setChecked(Settings::instance().isEldernodeVerificationEnabled());
  m_ui->timeoutSpinBox->setValue(Settings::instance().getEldernodeTimeout());
  
  // Load cleanup settings (these would need to be added to Settings class)
  m_ui->autoCleanupCheckBox->setChecked(true); // Default enabled
  m_ui->cleanupDaysSpinBox->setValue(30); // Default 30 days
}

void StarkSettingsDialog::saveSettings() {
  // Save STARK proof settings
  Settings::instance().setStarkProofEnabled(m_ui->enableStarkProofCheckBox->isChecked());
  Settings::instance().setAutoGenerateProofs(m_ui->autoGenerateProofsCheckBox->isChecked());
  
  // Save recipient address
  QString recipientAddress = m_ui->recipientAddressEdit->text().trimmed();
  if (!recipientAddress.isEmpty() && validateRecipientAddress(recipientAddress)) {
    Settings::instance().setDefaultRecipientAddress(recipientAddress);
  }
  
  // Save Eldernode verification settings
  Settings::instance().setEldernodeVerificationEnabled(m_ui->enableEldernodeVerificationCheckBox->isChecked());
  Settings::instance().setEldernodeTimeout(m_ui->timeoutSpinBox->value());
  
  // Note: Cleanup settings would need to be added to Settings class
}

void StarkSettingsDialog::resetToDefaults() {
  // Reset to default values
  m_ui->enableStarkProofCheckBox->setChecked(true);
  m_ui->autoGenerateProofsCheckBox->setChecked(true);
  m_ui->recipientAddressEdit->clear();
  m_ui->enableEldernodeVerificationCheckBox->setChecked(true);
  m_ui->timeoutSpinBox->setValue(300);
  m_ui->autoCleanupCheckBox->setChecked(true);
  m_ui->cleanupDaysSpinBox->setValue(30);
}

bool StarkSettingsDialog::validateRecipientAddress(const QString& address) {
  // Validate Ethereum address format
  QRegExp ethAddressRegex("^0x[a-fA-F0-9]{40}$");
  return ethAddressRegex.exactMatch(address);
}

void StarkSettingsDialog::onBrowseButtonClicked() {
  QString dir = QFileDialog::getExistingDirectory(this, tr("Select Proof Storage Directory"), 
                                                 m_ui->storagePathEdit->text());
  if (!dir.isEmpty()) {
    m_ui->storagePathEdit->setText(dir);
  }
}

void StarkSettingsDialog::onResetButtonClicked() {
  QMessageBox::StandardButton reply = QMessageBox::question(this, tr("Reset Settings"),
    tr("Are you sure you want to reset all STARK proof settings to their default values?"),
    QMessageBox::Yes | QMessageBox::No);
    
  if (reply == QMessageBox::Yes) {
    resetToDefaults();
  }
}

void StarkSettingsDialog::onOkButtonClicked() {
  // Validate recipient address if provided
  QString recipientAddress = m_ui->recipientAddressEdit->text().trimmed();
  if (!recipientAddress.isEmpty() && !validateRecipientAddress(recipientAddress)) {
    QMessageBox::warning(this, tr("Invalid Address"),
      tr("The provided Ethereum address is invalid. Please enter a valid 0x-prefixed 40-character hex address."));
    return;
  }
  
  // Save settings
  saveSettings();
  
  // Accept the dialog
  accept();
}

} // namespace WalletGui

#include "StarkSettingsDialog.moc"
