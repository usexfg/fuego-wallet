import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/hearth/hearth_cubit.dart';
import '../../utils/theme.dart';

class AddLiquidityDialog extends StatefulWidget {
  const AddLiquidityDialog({super.key});

  @override
  State<AddLiquidityDialog> createState() => _AddLiquidityDialogState();
}

class _AddLiquidityDialogState extends State<AddLiquidityDialog> {
  final _xfgController = TextEditingController();
  final _heatController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _xfgController.dispose();
    _heatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('Add Liquidity', style: TextStyle(color: AppTheme.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _xfgController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'XFG Amount',
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _heatController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'HEAT Amount',
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text('Provide equal-value amounts of both tokens',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final xfg = _xfgController.text.trim();
    final heat = _heatController.text.trim();
    if (xfg.isEmpty || heat.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await context.read<HearthCubit>().addLiquidity(xfgAmount: xfg, heatAmount: heat);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class RemoveLiquidityDialog extends StatefulWidget {
  const RemoveLiquidityDialog({super.key});

  @override
  State<RemoveLiquidityDialog> createState() => _RemoveLiquidityDialogState();
}

class _RemoveLiquidityDialogState extends State<RemoveLiquidityDialog> {
  final _sharesController = TextEditingController();
  final _minXfgController = TextEditingController();
  final _minHeatController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _sharesController.dispose();
    _minXfgController.dispose();
    _minHeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('Remove Liquidity', style: TextStyle(color: AppTheme.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _sharesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'LP Shares',
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minXfgController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Min XFG',
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minHeatController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Min HEAT',
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
        ],
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Remove'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final shares = _sharesController.text.trim();
    final minXfg = _minXfgController.text.trim();
    final minHeat = _minHeatController.text.trim();
    if (shares.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await context.read<HearthCubit>().removeLiquidity(
            shares: shares,
            minXfg: minXfg,
            minHeat: minHeat,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
