#pragma once

#include <QFrame>
#include <QValidator>
#include <QRegularExpression>

namespace Ui {
class BurnDepositsFrame;
}

namespace WalletGui {

class BurnDepositsFrame : public QFrame {
  Q_OBJECT
  Q_DISABLE_COPY(BurnDepositsFrame)

public:
  explicit BurnDepositsFrame(QWidget* _parent);
  ~BurnDepositsFrame();

private:
  QScopedPointer<Ui::BurnDepositsFrame> m_ui;
  
  // Ethereum address validation
  bool isValidEthereumAddress(const QString& address);
  void validateEthereumAddress();
  
private Q_SLOTS:
  void onEthereumAddressChanged();
  void onCreateBurnDepositClicked();
  void onValidateAddressClicked();
  
Q_SIGNALS:
  void burnDepositCreated(const QString& ethereumAddress, quint64 amount);
  void addressValidated(bool isValid, const QString& message);
};

} // namespace WalletGui
