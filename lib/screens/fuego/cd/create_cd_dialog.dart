import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/cd/cd_cubit.dart';
import '../../../utils/theme.dart';

class CreateCdDialog extends StatefulWidget {
  const CreateCdDialog({super.key});

  @override
  State<CreateCdDialog> createState() => _CreateCdDialogState();
}

class _CreateCdDialogState extends State<CreateCdDialog> {
  final _amountController = TextEditingController();
  int _termEpochs = 12;
  bool _submitting = false;
  String? _error;

  static const _epochBlocks = 900;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalBlocks = _termEpochs * _epochBlocks;
    final blockTimeSec = 480;
    final days = (totalBlocks * blockTimeSec) ~/ 86400;

    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('Create CD', style: TextStyle(color: AppTheme.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Amount (HEAT)', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '1000.0',
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            const Text('Term (epochs)', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _termEpochs.toDouble(),
                    min: 1,
                    max: 52,
                    divisions: 51,
                    label: '$_termEpochs epochs',
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) => setState(() => _termEpochs = v.round()),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text('$_termEpochs', style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('≈ $days days — ${_termEpochs * _epochBlocks} blocks at 8 min/block',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)),
              ),
            const Text('0.1% fee to @fuegoxfg developer fund',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final amount = _amountController.text.trim();
    if (amount.isEmpty) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await context.read<CdCubit>().createCd(
            coin: 'HEAT',
            amount: amount,
            durationBlocks: _termEpochs * _epochBlocks,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _submitting = false; _error = e.toString(); });
    }
  }
}
