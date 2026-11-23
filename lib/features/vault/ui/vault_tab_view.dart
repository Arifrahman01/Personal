import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/ui/vault_gate_screen.dart';
import 'package:personal_hub/features/vault/ui/vault_list_screen.dart';

/// Root Vault tab widget switching between [VaultGateScreen] and [VaultListScreen].
class VaultTabView extends ConsumerWidget {
  const VaultTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockController = ref.watch(vaultLockControllerProvider);

    return ListenableBuilder(
      listenable: lockController,
      builder: (context, _) {
        if (lockController.isUnlocked) {
          return const VaultListScreen();
        }
        return const VaultGateScreen();
      },
    );
  }
}
