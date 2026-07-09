import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/cd/cd_cubit.dart';
import '../../../models/cd.dart';
import '../../../utils/theme.dart';
import 'create_cd_dialog.dart';

class CdOverviewScreen extends StatelessWidget {
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

    final activeCds = state.myCds.where((cd) => !cd.matured && !cd.forSale).toList()
      ..sort((a, b) => a.blocksToMaturity.compareTo(b.blocksToMaturity));
    final completeCds = state.myCds.where((cd) => cd.matured && !cd.forSale).toList()
      ..sort((a, b) => b.depositHeight.compareTo(a.depositHeight));
    final withdrawnCds = state.myCds.where((cd) => cd.forSale).toList()
      ..sort((a, b) => b.depositHeight.compareTo(a.depositHeight));

    return RefreshIndicator(
      onRefresh: () => context.read<CdCubit>().loadAll(),
      child: CustomScrollView(
        slivers: [
          // ── Marketplace Section ──
          SliverToBoxAdapter(
            child: _MarketplaceSection(listings: state.marketListings),
          ),

          // ── My CDs Section ──
          if (activeCds.isNotEmpty || completeCds.isNotEmpty || withdrawnCds.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text('MY CDs', style: TextStyle(
                  color: AppTheme.textMuted, fontSize: 12,
                  fontWeight: FontWeight.w600, letterSpacing: 1)),
              ),
            ),

          // Active CDs
          if (activeCds.isNotEmpty)
            SliverToBoxAdapter(
              child: _StatusGroup(
                label: 'Active',
                icon: Icons.schedule,
                color: AppTheme.primaryColor,
                cds: activeCds,
              ),
            ),

          // Complete CDs
          if (completeCds.isNotEmpty)
            SliverToBoxAdapter(
              child: _StatusGroup(
                label: 'Matured',
                icon: Icons.check_circle,
                color: AppTheme.successColor,
                cds: completeCds,
              ),
            ),

          // For Sale CDs
          if (withdrawnCds.isNotEmpty)
            SliverToBoxAdapter(
              child: _StatusGroup(
                label: 'For Sale',
                icon: Icons.store,
                color: AppTheme.accentColor,
                cds: withdrawnCds,
              ),
            ),

          // Empty state
          if (state.myCds.isEmpty && state.marketListings.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.savings, size: 64, color: AppTheme.textMuted),
                    SizedBox(height: 12),
                    Text('No CDs yet', style: TextStyle(fontSize: 18, color: AppTheme.textMuted)),
                    SizedBox(height: 4),
                    Text('Create one or browse the market', style: TextStyle(color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ),

          // Bottom padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
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

// ── Marketplace Section ──

class _MarketplaceSection extends StatelessWidget {
  final List<CdMarketListing> listings;

  const _MarketplaceSection({required this.listings});

  @override
  Widget build(BuildContext context) {
    // Group by amount bucket
    final buckets = <String, List<CdMarketListing>>{};
    for (final l in listings) {
      final bucket = _amountBucket(l.amount);
      buckets.putIfAbsent(bucket, () => []).add(l);
    }

    // Sort each bucket by blocksRemaining (least to most)
    for (final b in buckets.values) {
      b.sort((a, b) => a.blocksRemaining.compareTo(b.blocksRemaining));
    }

    // Sort buckets by amount
    final sortedBuckets = buckets.entries.toList()
      ..sort((a, b) => _parseBucketAmount(a.key).compareTo(_parseBucketAmount(b.key)));

    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store, size: 16, color: AppTheme.accentColor),
              const SizedBox(width: 6),
              Text('MARKETPLACE', style: TextStyle(
                color: AppTheme.textMuted, fontSize: 12,
                fontWeight: FontWeight.w600, letterSpacing: 1)),
              const Spacer(),
              if (listings.isNotEmpty)
                Text('${listings.length} listings', style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),

          if (listings.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront, size: 20, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Text('No CDs listed for sale', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            )
          else
            ...sortedBuckets.map((entry) => _MarketBucket(
              amount: entry.key,
              listings: entry.value,
            )),
        ],
      ),
    );
  }

  String _amountBucket(String amount) {
    final parsed = double.tryParse(amount.replaceAll(',', '')) ?? 0;
    if (parsed <= 8) return '8 XFG';
    if (parsed <= 80) return '80 XFG';
    if (parsed <= 800) return '800 XFG';
    return '8,000 XFG';
  }

  int _parseBucketAmount(String bucket) {
    return int.tryParse(bucket.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }
}

class _MarketBucket extends StatelessWidget {
  final String amount;
  final List<CdMarketListing> listings;

  const _MarketBucket({required this.amount, required this.listings});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Text(amount, style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Text('${listings.length} ${listings.length == 1 ? 'CD' : 'CDs'}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text('TERM', style: _headerStyle)),
                Expanded(flex: 2, child: Text('AMOUNT', style: _headerStyle)),
                Expanded(flex: 2, child: Text('PRICE', style: _headerStyle)),
                SizedBox(width: 48),
              ],
            ),
          ),
          // Listings
          ...listings.map((l) => _MarketRow(listing: l)),
        ],
      ),
    );
  }
}

const _headerStyle = TextStyle(
  color: AppTheme.textMuted, fontSize: 10,
  fontWeight: FontWeight.w600, letterSpacing: 0.5);

class _MarketRow extends StatelessWidget {
  final CdMarketListing listing;

  const _MarketRow({required this.listing});

  @override
  Widget build(BuildContext context) {
    final daysRemaining = (listing.blocksRemaining / 1440).floor();

    return InkWell(
      onTap: () => context.read<CdCubit>().buyCd(listing.listingId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.surfaceColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(flex: 2, child: _termWidget(daysRemaining)),
            Expanded(flex: 2, child: Text(listing.amount,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
            Expanded(flex: 2, child: Text('${listing.price} XFG',
              style: const TextStyle(color: AppTheme.accentColor, fontSize: 13, fontWeight: FontWeight.w600))),
            SizedBox(
              width: 48,
              child: Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _termWidget(int days) {
    String label;
    Color color;
    if (days <= 7) {
      label = '${days}d';
      color = AppTheme.successColor;
    } else if (days <= 30) {
      label = '${days}d';
      color = AppTheme.primaryColor;
    } else if (days <= 90) {
      label = '${(days / 30).floor()}mo';
      color = AppTheme.warningColor;
    } else {
      label = '${(days / 30).floor()}mo';
      color = AppTheme.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ── User's CDs ──

class _StatusGroup extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<CdInfo> cds;

  const _StatusGroup({
    required this.label,
    required this.icon,
    required this.color,
    required this.cds,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label.toUpperCase(), style: TextStyle(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const Spacer(),
              Text('${cds.length}', style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          ...cds.map((cd) => _UserCdCard(cd: cd)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _UserCdCard extends StatelessWidget {
  final CdInfo cd;

  const _UserCdCard({required this.cd});

  @override
  Widget build(BuildContext context) {
    final matured = cd.matured;
    final color = matured ? AppTheme.successColor : AppTheme.primaryColor;
    final blocksLeft = cd.blocksToMaturity;
    final totalBlocks = cd.maturityHeight - cd.depositHeight;
    final progress = totalBlocks > 0 ? 1.0 - (blocksLeft / totalBlocks) : 0.0;
    final daysLeft = (blocksLeft / 1440).floor();

    return Card(
      color: AppTheme.cardColor,
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    matured ? 'MATURED' : '${daysLeft}d left',
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(cd.coin, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const Spacer(),
                Text(cd.amount, style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${cd.interestRate} APY', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const Spacer(),
                Text('Earned: ${cd.accruedInterest}', style: const TextStyle(color: AppTheme.successColor, fontSize: 11)),
              ],
            ),
            if (!matured) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppTheme.surfaceColor,
                  color: color,
                  minHeight: 3,
                ),
              ),
            ],
            if (matured) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.read<CdCubit>().claimCd(cd.cdId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Claim', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
