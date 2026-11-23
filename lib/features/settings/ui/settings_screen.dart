import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/backup/providers/gfs_backup_providers.dart';
import 'package:personal_hub/features/backup/services/gfs_backup_service.dart';
import 'package:personal_hub/features/backup/ui/backup_section.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/prayer/ui/prayer_schedule_screen.dart';
import 'package:personal_hub/features/sync/providers/sync_providers.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';

/// Application Settings screen covering theme, Samudra AI configuration,
/// Vault security actions, Prayer/FCM shortcut, and encrypted `.phub` Backup.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _maskedApiKey;
  String _baseUrl = AiConstants.defaultBaseUrl;
  bool _hasVaultPin = false;
  bool _hasDuressPin = false;
  bool _canUseBiometrics = false;
  bool _isTestingAi = false;
  String? _aiTestStatus;
  bool _aiTestSuccess = false;
  bool? _aiTestDidFallback;

  String _syncProvider = 'WebDAV';
  final TextEditingController _syncUrlController = TextEditingController();
  final TextEditingController _syncUsernameController = TextEditingController();
  final TextEditingController _syncPasswordController = TextEditingController();
  final TextEditingController _syncPassphraseController = TextEditingController();
  bool _obscureSyncPassword = true;
  bool _obscureSyncPassphrase = true;

  @override
  void initState() {
    super.initState();
    _loadSettingsState();
  }

  @override
  void dispose() {
    _syncUrlController.dispose();
    _syncUsernameController.dispose();
    _syncPasswordController.dispose();
    _syncPassphraseController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsState() async {
    final config = ref.read(secureConfigStoreProvider);
    final vaultController = ref.read(vaultLockControllerProvider);

    final apiKey = await config.getApiKey();
    final baseUrl = await config.getBaseUrl();
    final hasPin = await vaultController.hasPin();
    final hasDuress = await vaultController.hasDuressPin();
    final canBiometric = await vaultController.canUseBiometrics();
    await vaultController.loadAutoLockTimeout();

    final syncProvider = await config.getSyncProvider();
    final syncUrl = await config.getSyncServerUrl();
    final syncUser = await config.getSyncUsername();
    final syncPass = await config.getSyncPassword();
    final syncPassphrase = await config.getSyncPassphrase();

    if (!mounted) return;
    setState(() {
      _maskedApiKey = _maskSecret(apiKey);
      _baseUrl = baseUrl;
      _hasVaultPin = hasPin;
      _hasDuressPin = hasDuress;
      _canUseBiometrics = canBiometric;
      _syncProvider = syncProvider;
      _syncUrlController.text = syncUrl;
      _syncUsernameController.text = syncUser;
      _syncPasswordController.text = syncPass;
      _syncPassphraseController.text = syncPassphrase;
    });
  }

  String? _maskSecret(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.length <= 8) {
      return '••••••••';
    }
    return '${trimmed.substring(0, 4)}••••${trimmed.substring(trimmed.length - 4)}';
  }

  Future<void> _editApiKey() async {
    final config = ref.read(secureConfigStoreProvider);
    final currentKey = await config.getApiKey() ?? '';
    if (!mounted) return;

    final controller = TextEditingController(text: currentKey);
    var obscure = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('API Key Samudra AI'),
              content: TextField(
                controller: controller,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Masukkan Bearer API key...',
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'Tampilkan' : 'Sembunyikan',
                    icon: Icon(
                      obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    await config.setApiKey(controller.text);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (saved == true) {
      await _loadSettingsState();
      if (mounted) {
        _showSnack('API key AI diperbarui.');
      }
    }
  }

  Future<void> _editBaseUrl() async {
    final config = ref.read(secureConfigStoreProvider);
    final controller = TextEditingController(text: _baseUrl);
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Base URL AI'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Endpoint OpenAI-compatible',
                  hintText: AiConstants.defaultBaseUrl,
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    controller.text = AiConstants.defaultBaseUrl;
                    setDialogState(() => errorText = null);
                  },
                  child: const Text('Reset Default'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    final trimmed = controller.text.trim();
                    final uri = Uri.tryParse(trimmed);
                    if (uri == null ||
                        !uri.hasScheme ||
                        uri.host.trim().isEmpty) {
                      setDialogState(() {
                        errorText = 'Masukkan URL yang valid (https://...).';
                      });
                      return;
                    }
                    await config.setBaseUrl(trimmed);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (saved == true) {
      await _loadSettingsState();
      if (mounted) {
        _showSnack('Base URL AI diperbarui.');
      }
    }
  }

  Future<void> _testAiConnection() async {
    if (_isTestingAi) return;
    setState(() {
      _isTestingAi = true;
      _aiTestStatus = null;
      _aiTestDidFallback = null;
    });

    try {
      final response = await ref.read(aiClientProvider).chat(
            messages: const [
              AiMessage(role: 'user', content: 'Balas singkat: OK'),
            ],
          );
      if (!mounted) return;
      setState(() {
        _isTestingAi = false;
        _aiTestSuccess = true;
        _aiTestDidFallback = response.didFallback;
        _aiTestStatus =
            'Terhubung sukses melalui ${response.usedModel}${response.didFallback ? ' (fallback)' : ''}.';
      });
    } on AiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isTestingAi = false;
        _aiTestSuccess = false;
        _aiTestStatus = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTestingAi = false;
        _aiTestSuccess = false;
        _aiTestStatus = 'Gagal menguji koneksi ke server AI.';
      });
    }
  }

  Future<void> _openPinChangeDialog() async {
    final controller = ref.read(vaultLockControllerProvider);
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String? errorText;

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_hasVaultPin ? 'Ubah PIN Brankas' : 'Atur PIN Brankas'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasVaultPin) ...[
                      TextField(
                        controller: oldPinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'PIN Saat Ini',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: newPinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PIN Baru (min. 4 angka)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Konfirmasi PIN Baru',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (_hasVaultPin) {
                      final valid = await controller.unlockWithPin(
                        oldPinController.text,
                      );
                      if (!valid) {
                        setDialogState(() {
                          errorText = 'PIN saat ini salah.';
                        });
                        return;
                      }
                    }
                    final nextPin = newPinController.text.trim();
                    if (nextPin != confirmPinController.text.trim()) {
                      setDialogState(() {
                        errorText = 'Konfirmasi PIN baru tidak cocok.';
                      });
                      return;
                    }
                    try {
                      await controller.setupPin(nextPin);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } on ValidationException catch (error) {
                      setDialogState(() {
                        errorText = error.message;
                      });
                    }
                  },
                  child: const Text('Simpan PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    oldPinController.dispose();
    newPinController.dispose();
    confirmPinController.dispose();

    if (updated == true) {
      await _loadSettingsState();
      if (mounted) {
        _showSnack('PIN Brankas berhasil diperbarui.');
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatAutoLockTimeout(AutoLockTimeout timeout) {
    switch (timeout) {
      case AutoLockTimeout.immediate:
        return 'Seketika';
      case AutoLockTimeout.seconds30:
        return '30 Detik';
      case AutoLockTimeout.minute1:
        return '1 Menit';
      case AutoLockTimeout.minutes5:
        return '5 Menit';
    }
  }

  Future<void> _openDuressPinDialog() async {
    final controller = ref.read(vaultLockControllerProvider);
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Konfigurasi Duress PIN'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duress PIN adalah PIN umpan darurat. Saat dimasukkan, brankas akan menampilkan profil akun umpan tanpa membocorkan akun asli Anda.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duress PIN Baru (min. 4 angka)',
                        hintText: 'Masukkan 4 digit atau lebih',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Konfirmasi Duress PIN',
                        hintText: 'Ulangi PIN yang sama',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final confirm = confirmController.text.trim();
                    if (pin != confirm) {
                      setDialogState(() {
                        errorText = 'Konfirmasi Duress PIN tidak cocok.';
                      });
                      return;
                    }
                    try {
                      await controller.setupDuressPin(pin);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } on ValidationException catch (e) {
                      setDialogState(() {
                        errorText = e.message;
                      });
                    } catch (_) {
                      setDialogState(() {
                        errorText = 'Gagal menyimpan Duress PIN.';
                      });
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    confirmController.dispose();

    if (saved == true) {
      await _loadSettingsState();
      if (mounted) {
        _showSnack('Duress PIN berhasil dikonfigurasi.');
      }
    }
  }

  Future<void> _saveCloudSyncConfig({bool silent = false}) async {
    final config = ref.read(secureConfigStoreProvider);
    await config.setSyncProvider(_syncProvider);
    await config.setSyncServerUrl(_syncUrlController.text.trim());
    await config.setSyncUsername(_syncUsernameController.text.trim());
    await config.setSyncPassword(_syncPasswordController.text);
    await config.setSyncPassphrase(_syncPassphraseController.text);
    if (!silent && mounted) {
      _showSnack('Konfigurasi cloud sync berhasil disimpan.');
    }
  }

  Future<void> _handleSyncNow() async {
    final passphrase = _syncPassphraseController.text.trim();
    if (passphrase.isEmpty) {
      _showSnack('Masukkan Master Sync Passphrase terlebih dahulu.');
      return;
    }

    await _saveCloudSyncConfig(silent: true);

    try {
      await ref.read(syncNotifierProvider.notifier).syncNow(passphrase: passphrase);
      if (mounted) {
        _showSnack('Sinkronisasi cloud E2EE berhasil diselesaikan.');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Gagal melakukan sinkronisasi: $e');
      }
    }
  }

  void _createGfsBackupNow() {
    final service = ref.read(gfsBackupServiceProvider);
    final now = DateTime.now();
    final tier = service.classifyTier(now);
    final fileName = service.generateSnapshotFileName(createdAt: now, tier: tier);
    final snapshot = BackupSnapshotInfo(
      fileName: fileName,
      createdAt: now,
      tier: tier,
      sizeBytes: 1024 * 64,
    );

    ref.read(gfsSnapshotsProvider.notifier).addSnapshot(snapshot);

    final allSnapshots = ref.read(gfsSnapshotsProvider);
    final eval = service.evaluateRetention(allSnapshots, now);
    if (eval.prune.isNotEmpty) {
      ref.read(gfsSnapshotsProvider.notifier).removeSnapshots(eval.prune);
    }

    _showSnack('Snapshot ${tier.displayName} ($fileName) berhasil dibuat & dievaluasi GFS.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final vaultLock = ref.watch(vaultLockControllerProvider);
    final prayerPrefsAsync = ref.watch(prayerPrefsProvider);

    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Pengaturan')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const GlassIconTile(
                        icon: LucideIcons.palette,
                        size: 38,
                        iconSize: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Tampilan Aplikasi',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Sistem'),
                          icon: Icon(LucideIcons.monitor, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Terang'),
                          icon: Icon(LucideIcons.sun, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Gelap'),
                          icon: Icon(LucideIcons.moon, size: 16),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (selection) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(selection.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const GlassIconTile(
                        icon: LucideIcons.sparkles,
                        size: 38,
                        iconSize: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Konfigurasi AI (Samudra AI)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prioritas Model Otomatis',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const GlassBadge(
                              label: '1. Free: ${AiConstants.freeModel}',
                            ),
                            const Icon(LucideIcons.arrowRight, size: 14),
                            GlassBadge(
                              label: '2. Fallback: ${AiConstants.fallbackModel}',
                              backgroundColor: theme
                                  .colorScheme
                                  .tertiaryContainer
                                  .withValues(alpha: 0.72),
                              foregroundColor:
                                  theme.colorScheme.onTertiaryContainer,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.keyRound, size: 20),
                    title: const Text('API Key'),
                    subtitle: Text(_maskedApiKey ?? 'Belum diatur'),
                    trailing: TextButton(
                      onPressed: _editApiKey,
                      child: const Text('Ubah'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.globe, size: 20),
                    title: const Text('Base URL'),
                    subtitle: Text(
                      _baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: TextButton(
                      onPressed: _editBaseUrl,
                      child: const Text('Ubah'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _isTestingAi ? null : _testAiConnection,
                      icon: _isTestingAi
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.activity, size: 18),
                      label: Text(
                        _isTestingAi ? 'Menguji Koneksi...' : 'Tes Koneksi AI',
                      ),
                    ),
                  ),
                  if (_aiTestStatus != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_aiTestSuccess
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.errorContainer)
                            .withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _aiTestSuccess
                                ? LucideIcons.circleCheck
                                : LucideIcons.circleAlert,
                            size: 18,
                            color: _aiTestSuccess
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _aiTestStatus!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _aiTestSuccess
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          if (_aiTestSuccess && _aiTestDidFallback != null)
                            GlassBadge(
                              label: _aiTestDidFallback! ? 'Fallback' : 'Free',
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: vaultLock,
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const GlassIconTile(
                            icon: LucideIcons.shieldCheck,
                            size: 38,
                            iconSize: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Keamanan & Brankas',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          GlassBadge(
                            label: vaultLock.isUnlocked ? 'Terbuka' : 'Terkunci',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(LucideIcons.key, size: 20),
                        title: Text(
                          _hasVaultPin
                              ? 'PIN Brankas Terpasang'
                              : 'PIN Brankas Belum Diatur',
                        ),
                        subtitle: Text(
                          _canUseBiometrics
                              ? 'Autentikasi biometrik tersedia di perangkat ini.'
                              : 'Menggunakan PIN lokal & enkripsi AES-256-GCM.',
                        ),
                        trailing: TextButton(
                          onPressed: _openPinChangeDialog,
                          child: Text(_hasVaultPin ? 'Ubah PIN' : 'Atur PIN'),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(LucideIcons.timer, size: 20),
                        title: const Text('Kunci Otomatis (Auto-Lock)'),
                        subtitle: Text(
                          _formatAutoLockTimeout(vaultLock.autoLockTimeout),
                        ),
                        trailing: DropdownButton<AutoLockTimeout>(
                          value: vaultLock.autoLockTimeout,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(
                              value: AutoLockTimeout.immediate,
                              child: Text('Seketika'),
                            ),
                            DropdownMenuItem(
                              value: AutoLockTimeout.seconds30,
                              child: Text('30 Detik'),
                            ),
                            DropdownMenuItem(
                              value: AutoLockTimeout.minute1,
                              child: Text('1 Menit'),
                            ),
                            DropdownMenuItem(
                              value: AutoLockTimeout.minutes5,
                              child: Text('5 Menit'),
                            ),
                          ],
                          onChanged: (timeout) {
                            if (timeout != null) {
                              vaultLock.setAutoLockTimeout(timeout);
                            }
                          },
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(LucideIcons.shieldAlert, size: 20),
                        title: const Text('Duress PIN (Anti-Pemaksaan)'),
                        subtitle: Text(
                          _hasDuressPin
                              ? 'Aktif • Menampilkan brankas umpan jika dipaksa.'
                              : 'Belum diatur • Lindungi brankas dari pemaksaan fisik.',
                        ),
                        trailing: TextButton(
                          onPressed: _openDuressPinDialog,
                          child: Text(_hasDuressPin ? 'Ubah' : 'Atur'),
                        ),
                      ),
                      if (vaultLock.isUnlocked) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              vaultLock.lock();
                              _showSnack('Brankas dikunci.');
                            },
                            icon: const Icon(LucideIcons.lock, size: 17),
                            label: const Text('Kunci Brankas Sekarang'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            // Multi-Device E2EE Cloud Sync Panel
            Consumer(
              builder: (context, ref, _) {
                final syncStateAsync = ref.watch(syncNotifierProvider);
                final syncState = syncStateAsync.value ?? const SyncState();

                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const GlassIconTile(
                            icon: LucideIcons.cloud,
                            size: 38,
                            iconSize: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Multi-Device E2EE Cloud Sync',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sinkronisasi antar perangkat terenkripsi AES-256-GCM.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const GlassBadge(label: 'E2EE Cloud'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Penyedia Layanan Cloud (Provider)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'WebDAV',
                              label: Text('WebDAV'),
                              icon: Icon(LucideIcons.folderSync, size: 14),
                            ),
                            ButtonSegment(
                              value: 'Nextcloud',
                              label: Text('Nextcloud'),
                              icon: Icon(LucideIcons.cloudRain, size: 14),
                            ),
                            ButtonSegment(
                              value: 'Google Drive AppData',
                              label: Text('Google Drive'),
                              icon: Icon(LucideIcons.hardDrive, size: 14),
                            ),
                          ],
                          selected: {_syncProvider},
                          onSelectionChanged: (selection) {
                            setState(() => _syncProvider = selection.first);
                            ref
                                .read(secureConfigStoreProvider)
                                .setSyncProvider(selection.first);
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _syncUrlController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Server URL',
                          hintText: _syncProvider == 'Nextcloud'
                              ? 'https://cloud.example.com/remote.php/dav/files/user/'
                              : 'https://dav.example.com/remote.php/webdav/',
                          prefixIcon: const Icon(LucideIcons.globe, size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _syncUsernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'Nama pengguna akun cloud',
                          prefixIcon: Icon(LucideIcons.user, size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _syncPasswordController,
                        obscureText: _obscureSyncPassword,
                        decoration: InputDecoration(
                          labelText: 'Password / Token',
                          hintText: 'Kata sandi atau app token cloud',
                          prefixIcon: const Icon(LucideIcons.lock, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureSyncPassword
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              size: 18,
                            ),
                            onPressed: () => setState(
                              () =>
                                  _obscureSyncPassword = !_obscureSyncPassword,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _syncPassphraseController,
                        obscureText: _obscureSyncPassphrase,
                        decoration: InputDecoration(
                          labelText: 'Master Sync Passphrase',
                          hintText: 'Passphrase enkripsi end-to-end',
                          helperText:
                              'Kunci enkripsi zero-knowledge (server cloud tidak dapat membaca data).',
                          prefixIcon:
                              const Icon(LucideIcons.keyRound, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureSyncPassphrase
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              size: 18,
                            ),
                            onPressed: () => setState(
                              () => _obscureSyncPassphrase =
                                  !_obscureSyncPassphrase,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.clock,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    syncState.lastSyncTime != null
                                        ? 'Terakhir disinkronkan: ${DateFormat('dd MMM yyyy, HH:mm').format(syncState.lastSyncTime!.toLocal())}'
                                        : 'Status: Belum pernah disinkronkan',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                GlassBadge(
                                  label:
                                      '${syncState.pendingCount} Tertunda',
                                ),
                              ],
                            ),
                            if (syncState.isSyncing) ...[
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(),
                            ],
                            if (syncState.errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Error: ${syncState.errorMessage}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                syncState.isSyncing ? null : _handleSyncNow,
                            icon: syncState.isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(LucideIcons.refreshCw, size: 16),
                            label: const Text('Sinkronkan Sekarang'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _saveCloudSyncConfig(),
                            icon: const Icon(LucideIcons.save, size: 16),
                            label: const Text('Simpan Konfigurasi'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            // Automated Background Backup (GFS) Panel
            Consumer(
              builder: (context, ref, _) {
                final gfsService = ref.watch(gfsBackupServiceProvider);
                final summary = ref.watch(gfsRetentionSummaryProvider);
                final policy = gfsService.policy;

                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const GlassIconTile(
                            icon: LucideIcons.archive,
                            size: 38,
                            iconSize: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Automated Background Backup (GFS)',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rotasi otomatis: 7 harian, 4 mingguan, 3 bulanan.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const GlassBadge(
                            label: 'Rotasi GFS',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // 3-Column Retention Metric Cards
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF84CC16)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF84CC16)
                                      .withValues(alpha: 0.28),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${summary.keptDailyCount} / ${policy.maxDaily}',
                                    style:
                                        theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF84CC16),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '7 Harian (Daily)',
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Son cycle',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.28),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${summary.keptWeeklyCount} / ${policy.maxWeekly}',
                                    style:
                                        theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF38BDF8),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '4 Mingguan',
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Father cycle',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.28),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${summary.keptMonthlyCount} / ${policy.maxMonthly}',
                                    style:
                                        theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF8B5CF6),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '3 Bulanan',
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Grandfather',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Total snapshot: ${summary.totalSnapshots} (Aktif: ${summary.keptCount}, Dipangkas: ${summary.prunedCount})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            summary.keptSizeBytes < 1024
                                ? '${summary.keptSizeBytes} B'
                                : '${(summary.keptSizeBytes / 1024).toStringAsFixed(1)} KB',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _createGfsBackupNow,
                          icon: const Icon(LucideIcons.filePlus, size: 16),
                          label: const Text('Buat Backup Baru Sekarang'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(8),
              child: ListTile(
                leading: const GlassIconTile(
                  icon: LucideIcons.compass,
                  size: 40,
                  iconSize: 20,
                ),
                title: const Text('Jadwal Sholat & Notifikasi Adzan'),
                subtitle: Text(
                  prayerPrefsAsync.when(
                    data: (prefs) =>
                        '${prefs.cityName} • ${prefs.notificationMode.label}',
                    loading: () => 'Memuat preferensi...',
                    error: (_, _) => 'Atur lokasi, hisab, dan pengingat adzan',
                  ),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrayerScheduleScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            const BackupSection(),
          ],
        ),
      ),
    );
  }
}
