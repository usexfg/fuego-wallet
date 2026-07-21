import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dns_client/dns_client.dart' hide DnsClient;
import 'package:dns_client/src/dns_over_https.dart';
import '../../bloc/wallet/wallet_cubit.dart';
import '../../utils/theme.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  bool _isResolvingAlias = false;
  String? _resolvedAddress;

  @override
  void initState() {
    super.initState();
    _addressFocusNode.addListener(_onAddressFocusChange);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _addressFocusNode.removeListener(_onAddressFocusChange);
    _addressFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _onAddressFocusChange() {
    if (!_addressFocusNode.hasFocus) {
      _resolveOpenAlias();
    }
  }

  Future<void> _resolveOpenAlias() async {
    final address = _addressController.text.trim();
    if (!address.contains('@')) return;

    setState(() {
      _isResolvingAlias = true;
      _errorMessage = null;
      _resolvedAddress = null;
    });

    try {
      final parts = address.split('@');
      if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
        throw Exception('Invalid OpenAlias format. Use: user@domain.com');
      }
      final domain = parts[1];

      final client = DnsOverHttps.cloudflare();
      final records = await client.lookupDataByRRType(domain, RRType.TXT);

      String? fuegoAddress;
      for (final record in records) {
        final oaPos = record.indexOf('oa1:xfg');
        if (oaPos == -1) continue;

        final addrStart = record.indexOf('recipient_address=', oaPos);
        if (addrStart == -1) continue;

        final valueStart = addrStart + 'recipient_address='.length;
        final addrEnd = record.indexOf(';', valueStart);

        if (addrEnd == -1 || (addrEnd - valueStart) != 98) continue;

        fuegoAddress = record.substring(valueStart, addrEnd);
        break;
      }

      if (fuegoAddress != null) {
        setState(() {
          _resolvedAddress = fuegoAddress;
          _addressController.text = fuegoAddress!;
        });
      } else {
        throw Exception('No valid Fuego address found for this OpenAlias');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resolve OpenAlias: $e';
      });
    } finally {
      setState(() {
        _isResolvingAlias = false;
      });
    }
  }

  void _showConfirmDialog() {
    if (!_formKey.currentState!.validate()) return;

    final address = _addressController.text.trim();
    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr) ?? 0;
    final fee = 0.008;
    final total = amount + fee;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Confirm Send', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Recipient', address.length > 30
                ? '${address.substring(0, 15)}...${address.substring(address.length - 10)}'
                : address),
            const SizedBox(height: 8),
            _confirmRow('Amount', '${amount.toStringAsFixed(7)} XFG'),
            const SizedBox(height: 8),
            _confirmRow('Fee', '${fee.toStringAsFixed(7)} XFG'),
            const Divider(color: AppTheme.textMuted),
            _confirmRow('Total', '${total.toStringAsFixed(7)} XFG', bold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _sendTransaction();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Confirm & Send'),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        Text(value, style: TextStyle(
          color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        )),
      ],
    );
  }

  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cubit = context.read<WalletCubit>();

      final txHash = await cubit.sendTransaction(
        address: _addressController.text.trim(),
        amount: double.tryParse(_amountController.text.trim()) ?? 0,
        fee: 0.008,
        mixin: 7,
      );

      if (txHash != null && mounted) {
        _showSuccessDialog(txHash);
      } else {
        setState(() {
          _errorMessage = cubit.state.error ?? 'Transaction failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String txHash) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.successColor),
              SizedBox(width: 8),
              Text('Transaction Sent', style: TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your transaction has been broadcast to the network.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Transaction ID:',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.textMuted.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        txHash,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: txHash));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaction ID copied'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData?.text != null) {
      _addressController.text = clipboardData!.text!;
    }
  }

  void _setMaxAmount() {
    final state = context.read<WalletCubit>().state;
    final availableBalance = state.unlockedBalanceXfg;
    final maxAmount = (availableBalance - 0.01).clamp(0.0, availableBalance);
    _amountController.text = maxAmount.toStringAsFixed(7);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send XFG'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) {
          final availableBalance = state.unlockedBalanceXfg;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Available balance
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Balance',
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${availableBalance.toStringAsFixed(7)} XFG',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: _setMaxAmount,
                              child: const Text('MAX'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recipient address or alias
                  const Text(
                    'Recipient Address or Alias',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressController,
                    focusNode: _addressFocusNode,
                    decoration: InputDecoration(
                      hintText: 'fire... or user@domain.com',
                      suffixIcon: _isResolvingAlias
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: _pasteFromClipboard,
                                  icon: const Icon(Icons.paste),
                                  tooltip: 'Paste',
                                ),
                                IconButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('QR scanner coming soon')),
                                    );
                                  },
                                  icon: const Icon(Icons.qr_code_scanner),
                                  tooltip: 'Scan QR',
                                ),
                              ],
                            ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter recipient address';
                      }
                      if (value.contains('@')) return null;
                      if (!value.startsWith('fire') || value.length != 98) {
                        return 'Invalid address (must be fire... and 98 chars)';
                      }
                      return null;
                    },
                    maxLines: 3,
                    minLines: 1,
                  ),
                  if (_resolvedAddress != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Resolved to: $_resolvedAddress',
                        style: const TextStyle(color: AppTheme.successColor),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Amount
                  const Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    focusNode: _amountFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0.0000000',
                      suffixText: 'XFG',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      if (amount > availableBalance) {
                        return 'Insufficient balance';
                      }
                      return null;
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}')),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.errorColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppTheme.errorColor, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading || availableBalance <= 0 ? null : _showConfirmDialog,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Send Transaction',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Security notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Transactions cannot be reversed. Please double-check the recipient address before sending.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
