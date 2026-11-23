import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/backup/ui/backup_section.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/prayer/ui/prayer_schedule_screen.dart';
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
  bool _canUseBiometrics = false;
  bool _isTestingAi = false;
  String? _aiTestStatus;
  bool _aiTestSuccess = false;
  bool? _aiTestDidFallback;

  @override
  void initState() {
    super.initState();
    _loadSettingsState();
  }

  Future<void> _loadSettingsState() async {
    final config = ref.read(secureConfigStoreProvider);
    final vaultController = ref.read(vaultLockControllerProvider);

    final apiKey = await config.getApiKey();
    final baseUrl = await config.getBaseUrl();
    final hasPin = await vaultController.hasPin();
    final canBiometric = await vaultController.canUseBiometrics();

    if (!mounted) return;
    setState(() {
      _maskedApiKey = _maskSecret(apiKey);
      _baseUrl = baseUrl;
      _hasVaultPin = hasPin;
      _canUseBiometrics = canBiometric;
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
                      if (vaultLock.isUnlocked)
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
                  );
                },
              ),
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
