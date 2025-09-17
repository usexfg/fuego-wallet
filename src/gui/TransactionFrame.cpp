// Copyright (c) 2011-2017 The Cryptonote developers
// Copyright (c) 2018 The Circle Foundation & Conceal Devs
// Copyright (c) 2018-2019 Conceal Network & Conceal Devs
//  
// Copyright (c) 2018 The Circle Foundation & Conceal Devs
// Copyright (c) 2018-2019 Conceal Network & Conceal Devs
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include <QFontDatabase>

#include "MainWindow.h"
#include "TransactionFrame.h"
#include "TransactionsModel.h"
#include "OverviewFrame.h"
#include "StarkProofService.h"
#include "ui_transactionframe.h"

namespace WalletGui {

class RecentTransactionDelegate : public QStyledItemDelegate {
  Q_OBJECT

public:
  RecentTransactionDelegate(QObject* _parent) : QStyledItemDelegate(_parent) {

  }

  ~RecentTransactionDelegate() {
  }

  void setEditorData(QWidget* _editor, const QModelIndex& _index) const Q_DECL_OVERRIDE {
    switch(_index.column()) {

    case TransactionsModel::COLUMN_HASH: {
      QString txhash = _index.data(TransactionsModel::ROLE_HASH).toByteArray().toHex().toUpper();
      std::string theAddress = txhash.toStdString();
      std::string start = theAddress.substr(0, 8);
      std::string end = theAddress.substr(56, 8);
      static_cast<QLabel *>(_editor)->setText("Hash: " + QString::fromStdString(start) + "....." + QString::fromStdString(end));
      return;
    }

    case TransactionsModel::COLUMN_DATE:
      {static_cast<QLabel*>(_editor)->setText(_index.data().toString());
      return;
    }
    case TransactionsModel::COLUMN_MESSAGE: {
      QFontMetrics fm(_editor->font());
      QString elidedText = fm.elidedText(_index.data().toString(), Qt::ElideRight, 425);
      static_cast<QLabel*>(_editor)->setText(elidedText);
      return;
    }

    case TransactionsModel::COLUMN_TYPE: {
      QString txtype = _index.data(TransactionsModel::ROLE_TYPE).toString();
      QString txtext = tr("Incoming TX");
      if (txtype == "0") 
      {
        txtext = tr("New Block");
      } 
      else if (txtype == "2")
      {
        txtext = tr("Outgoing TX");
      }
      else if (txtype == "3")
      {
        txtext = tr("Optimization");
      }
      else if (txtype == "4")
      {
        txtext = tr("New Deposit");
      }    
      static_cast<QLabel*>(_editor)->setText(txtext);
      return;
    }

    case TransactionsModel::COLUMN_AMOUNT:
    {
        static_cast<QLabel *>(_editor)->setText(_index.data().toString());
        return;
    }
    case TransactionsModel::COLUMN_CONFIRMATIONS:
    {
        static_cast<QLabel *>(_editor)->setText(_index.data().toString());
        return;
    }

    default:
      return;
    }
  }
};

TransactionFrame::TransactionFrame(const QModelIndex& _index, QWidget* _parent) : QFrame(_parent),
  m_ui(new Ui::TransactionFrame), m_dataMapper(this), m_index(_index) {
  m_ui->setupUi(this);


  m_dataMapper.setModel(const_cast<QAbstractItemModel*>(m_index.model()));
  m_dataMapper.setItemDelegate(new RecentTransactionDelegate(this));
  
  // Update STARK status
  updateStarkStatus();
  m_dataMapper.addMapping(m_ui->m_iconLabel, TransactionsModel::COLUMN_TYPE);
  m_dataMapper.addMapping(m_ui->o_amountLabel, TransactionsModel::COLUMN_AMOUNT);
  m_dataMapper.addMapping(m_ui->m_timeLabel, TransactionsModel::COLUMN_DATE);
  m_dataMapper.addMapping(m_ui->m_confirmationsLabel, TransactionsModel::COLUMN_CONFIRMATIONS);
  m_dataMapper.addMapping(m_ui->m_txLabel, TransactionsModel::COLUMN_HASH);
  m_dataMapper.setCurrentModelIndex(m_index);
}

TransactionFrame::~TransactionFrame() {
}

void TransactionFrame::mousePressEvent(QMouseEvent* _event) {
  MainWindow::instance().scrollToTransaction(TransactionsModel::instance().index(m_index.data(TransactionsModel::ROLE_ROW).toInt(), 0));
}

void TransactionFrame::updateStarkStatus() {
  // Get transaction hash from the model
  QString txHash = m_index.data(TransactionsModel::ROLE_HASH).toByteArray().toHex().toUpper();
  
  if (txHash.isEmpty()) {
    m_ui->m_starkStatusLabel->setVisible(false);
    return;
  }
  
  // Get STARK proof status
  QString status = StarkProofService::instance().getProofStatus(txHash);
  
  if (status.isEmpty() || status == "none") {
    m_ui->m_starkStatusLabel->setVisible(false);
    return;
  }
  
  m_ui->m_starkStatusLabel->setVisible(true);
  
  // Set status text and style based on status
  if (status == "completed") {
    m_ui->m_starkStatusLabel->setText(tr("HEAT Ready"));
    m_ui->m_starkStatusLabel->setStyleSheet("color: #4CAF50; background-color: #E8F5E8; border: 1px solid #4CAF50; padding: 2px 4px; border-radius: 3px;");
  } else if (status == "stark_pending") {
    m_ui->m_starkStatusLabel->setText(tr("Generating..."));
    m_ui->m_starkStatusLabel->setStyleSheet("color: #FF9800; background-color: #FFF3E0; border: 1px solid #FF9800; padding: 2px 4px; border-radius: 3px;");
  } else if (status == "eldernode_pending") {
    m_ui->m_starkStatusLabel->setText(tr("Verifying..."));
    m_ui->m_starkStatusLabel->setStyleSheet("color: #2196F3; background-color: #E3F2FD; border: 1px solid #2196F3; padding: 2px 4px; border-radius: 3px;");
  } else if (status == "failed") {
    m_ui->m_starkStatusLabel->setText(tr("Failed"));
    m_ui->m_starkStatusLabel->setStyleSheet("color: #F44336; background-color: #FFEBEE; border: 1px solid #F44336; padding: 2px 4px; border-radius: 3px;");
  } else {
    m_ui->m_starkStatusLabel->setText(tr("Pending"));
    m_ui->m_starkStatusLabel->setStyleSheet("color: #999; background-color: #F5F5F5; border: 1px solid #999; padding: 2px 4px; border-radius: 3px;");
  }
}

}

#include "TransactionFrame.moc"
