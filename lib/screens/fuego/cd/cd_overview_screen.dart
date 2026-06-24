import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/cd/cd_cubit.dart';
import '../../../models/cd.dart';
import '../../../utils/theme.dart';
import 'create_cd_dialog.dart';
  const CdOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CdCubit, CdState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text('Certificates of Deposit'),
            backgroundColor: AppTheme.surfaceColor,
            actions: [
              if (state.apy != null)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${state.apy!.currentApy.toStringAsFixed(1)}% APY',
                      style: const TextStyle(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: _buildBody(context, state),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateCdSheet(context),
            backgroundColor: AppTheme.primaryColor,
            icon: const Icon(Icons.add),
            label: const Text('New CD'),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, CdState state) {
    if (state.status == CdLoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == CdLoadStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(state.error ?? 'Failed to load', style: const TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.read<CdCubit>().loadAll(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.myCds.isEmpty && state.marketListings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.savings, size: 64, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('No CDs yet', style: TextStyle(fontSize: 18, color: AppTheme.textMuted)),
            SizedBox(height: 4),
            Text('Create one or browse the market', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<CdCubit>().loadAll(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── My CDs ──
          if (state.myCds.isNotEmpty) ...[
            const Text('MY CDs', style: TextStyle(
              color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
            const SizedBox(height: 8),
            ...state.myCds.map((cd) => _CdCard(cd: cd, isMine: true)),
            const SizedBox(height: 24),
          ],

          // ── Market ──
          if (state.marketListings.isNotEmpty) ...[
            const Text('MARKET', style: TextStyle(
              color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
            const SizedBox(height: 8),
            ...state.marketListings.map((l) => _MarketCard(listing: l)),
          ],
        ],
      ),
    );
  }

  void _showCreateCdSheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CdCubit>(),
        child: const CreateCdDialog(),
      ),
    );
  }
}

class _CdCard extends StatelessWidget {
  final CdInfo cd;
  final bool isMine;

  const _CdCard({required this.cd, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final matured = cd.matured;
    final color = matured ? AppTheme.successColor : AppTheme.primaryColor;
    final blocksLeft = cd.blocksToMaturity;
    final totalBlocks = cd.maturityHeight - cd.depositHeight;
    final progress = totalBlocks > 0 ? 1.0 - (blocksLeft / totalBlocks) : 0.0;

    return Card(
      color: AppTheme.cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    matured ? 'MATURED' : 'ACTIVE',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (cd.forSale)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('FOR SALE', style: TextStyle(
                      color: AppTheme.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                if (isMine && !matured && !cd.forSale)
                  TextButton(
                    onPressed: () => context.read<CdCubit>().claimCd(cd.cdId),
                    child: const Text('Claim'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(cd.amount, style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('${cd.interestRate} APY — Accrued: ${cd.accruedInterest} ${cd.coin}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            if (!matured) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppTheme.surfaceColor,
                  color: color,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text('$blocksLeft blocks to maturity',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  final CdMarketListing listing;

  const _MarketCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.amount, style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Price: ${listing.price} — ${listing.interestRate} APY',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  Text('${listing.blocksRemaining} blocks remaining',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => context.read<CdCubit>().buyCd(listing.listingId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Buy'),
            ),
          ],
        ),
      ),
    );
  }
}
