import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/cd/cd_cubit.dart';
import '../../utils/theme.dart';

class CdScreen extends StatelessWidget {
  const CdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificates of Deposit'),
      ),
      body: BlocBuilder<CdCubit, CdState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null) {
            return Center(child: Text('Error: ${state.error}', style: const TextStyle(color: AppTheme.errorColor)));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ElevatedButton(
                onPressed: () {
                  // TODO: Show create CD dialog
                },
                child: const Text('Create New CD'),
              ),
              const SizedBox(height: 16),
              if (state.cds.isEmpty)
                const Center(child: Text('No CDs found.'))
              else
                ...state.cds.map((cd) => Card(
                  child: ListTile(
                    title: Text('Amount: ${cd.amount}'),
                    subtitle: Text('Matures at block: ${cd.unlockHeight}'),
                    trailing: ElevatedButton(
                      onPressed: cd.isMatured ? () {
                        // TODO: Claim CD
                      } : null,
                      child: const Text('Claim'),
                    ),
                  ),
                )),
            ],
          );
        },
      ),
    );
  }
}
