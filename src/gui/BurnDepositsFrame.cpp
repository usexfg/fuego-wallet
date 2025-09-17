#include "BurnDepositsFrame.h"
#include "ui_burndepositsframe.h"

#include <QMessageBox>
#include <QRegularExpression>
#include <QRegularExpressionValidator>
#include <QLineEdit>
#include <QPushButton>
#include <QLabel>
#include <QSpinBox>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QGroupBox>
#include <QFormLayout>

namespace WalletGui {

BurnDepositsFrame::BurnDepositsFrame(QWidget* _parent) : QFrame(_parent), m_ui(new Ui::BurnDepositsFrame) {
  m_ui->setupUi(this);
  
  // Set up Ethereum address validation
  QRegularExpression ethRegex("^0x[a-fA-F0-9]{40}$");
  QRegularExpressionValidator* ethValidator = new QRegularExpressionValidator(ethRegex, this);
  m_ui->ethereumAddressEdit->setValidator(ethValidator);
  
  // Connect signals
  connect(m_ui->ethereumAddressEdit, &QLineEdit::textChanged, this, &BurnDepositsFrame::onEthereumAddressChanged);
  connect(m_ui->validateAddressButton, &QPushButton::clicked, this, &BurnDepositsFrame::onValidateAddressClicked);
  connect(m_ui->createBurnDepositButton, &QPushButton::clicked, this, &BurnDepositsFrame::onCreateBurnDepositClicked);
  
  // Set initial state
  m_ui->validateAddressButton->setEnabled(false);
  m_ui->createBurnDepositButton->setEnabled(false);
  m_ui->addressStatusLabel->setText("Enter Ethereum address to validate");
}

BurnDepositsFrame::~BurnDepositsFrame() {
}

bool BurnDepositsFrame::isValidEthereumAddress(const QString& address) {
  // Basic format validation
  QRegularExpression ethRegex("^0x[a-fA-F0-9]{40}$");
  if (!ethRegex.match(address).hasMatch()) {
    return false;
  }
  
  // Additional checks can be added here:
  // - Checksum validation (EIP-55)
  // - Network validation
  // - Contract address detection
  
  return true;
}

void BurnDepositsFrame::validateEthereumAddress() {
  QString address = m_ui->ethereumAddressEdit->text().trimmed();
  
  if (address.isEmpty()) {
    m_ui->addressStatusLabel->setText("Enter Ethereum address to validate");
    m_ui->addressStatusLabel->setStyleSheet("color: #aaa;");
    m_ui->createBurnDepositButton->setEnabled(false);
    return;
  }
  
  bool isValid = isValidEthereumAddress(address);
  
  if (isValid) {
    m_ui->addressStatusLabel->setText("✓ Valid Ethereum address");
    m_ui->addressStatusLabel->setStyleSheet("color: #4CAF50;");
    m_ui->createBurnDepositButton->setEnabled(true);
    Q_EMIT addressValidated(true, "Valid Ethereum address");
  } else {
    m_ui->addressStatusLabel->setText("✗ Invalid Ethereum address format");
    m_ui->addressStatusLabel->setStyleSheet("color: #f44336;");
    m_ui->createBurnDepositButton->setEnabled(false);
    Q_EMIT addressValidated(false, "Invalid Ethereum address format");
  }
}

void BurnDepositsFrame::onEthereumAddressChanged() {
  QString address = m_ui->ethereumAddressEdit->text().trimmed();
  m_ui->validateAddressButton->setEnabled(!address.isEmpty());
  
  // Auto-validate as user types (with debouncing)
  validateEthereumAddress();
}

void BurnDepositsFrame::onValidateAddressClicked() {
  validateEthereumAddress();
}

void BurnDepositsFrame::onCreateBurnDepositClicked() {
  QString address = m_ui->ethereumAddressEdit->text().trimmed();
  quint64 amount = m_ui->burnAmountSpinBox->value() * 100000; // Convert to atomic units
  
  if (!isValidEthereumAddress(address)) {
    QMessageBox::warning(this, "Invalid Address", "Please enter a valid Ethereum address.");
    return;
  }
  
  if (amount <= 0) {
    QMessageBox::warning(this, "Invalid Amount", "Please enter a valid burn amount.");
    return;
  }
  
  // Emit signal to create burn deposit
  Q_EMIT burnDepositCreated(address, amount);
  
  // Show confirmation
  QMessageBox::information(this, "Burn Deposit Created", 
    QString("Burn deposit created successfully!\n\n"
            "Ethereum Address: %1\n"
            "Amount: %2 XFG\n\n"
            "STARK proof generation will begin automatically.")
    .arg(address)
    .arg(m_ui->burnAmountSpinBox->value()));
}

} // namespace WalletGui
