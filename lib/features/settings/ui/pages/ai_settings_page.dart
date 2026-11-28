import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';

/// Modular sub-page for Samudra AI settings:
/// API Key, Base URL, Connection test, and model info.
class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  String? _maskedApiKey;
  String _baseUrl = AiConstants.defaultBaseUrl;
  String _primaryModel = AiConstants.freeModel;
  String _fallbackModel = AiConstants.fallbackModel;
  bool _isTestingAi = false;
  String? _aiTestStatus;
  bool _aiTestSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final config = ref.read(secureConfigStoreProvider);
    final apiKey = await config.getApiKey();
    final baseUrl = await config.getBaseUrl();
    final primaryModel = await config.getPrimaryModel();
    final fallbackModel = await config.getFallbackModel();
    if (!mounted) return;
    setState(() {
      _maskedApiKey = _maskSecret(apiKey);
      _baseUrl = baseUrl;
      _primaryModel = primaryModel;
      _fallbackModel = fallbackModel;
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
                  hintText: 'Tempel API key (misal: smdr-..., tanpa kata Bearer)',
                  helperText: 'Kosongkan untuk memakai key bawaan build (jika tersedia).',
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'Tampilkan' : 'Sembunyikan',
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
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

    if (saved == true && mounted) {
      await _loadState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key Samudra AI berhasil diperbarui.')),
      );
    }
  }

  Future<void> _editBaseUrl() async {
    final config = ref.read(secureConfigStoreProvider);
    final currentUrl = await config.getBaseUrl();
    if (!mounted) return;

    final controller = TextEditingController(text: currentUrl);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Base URL AI'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: AiConstants.defaultBaseUrl,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.text = AiConstants.defaultBaseUrl;
              },
              child: const Text('Reset Default'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                await config.setBaseUrl(controller.text);
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

    controller.dispose();

    if (saved == true && mounted) {
      await _loadState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base URL AI berhasil diperbarui.')),
      );
    }
  }

  Future<void> _editModel({required bool isPrimary}) async {
    final config = ref.read(secureConfigStoreProvider);
    final current = isPrimary
        ? await config.getPrimaryModel()
        : await config.getFallbackModel();
    final defaultModel = isPrimary
        ? AiConstants.freeModel
        : AiConstants.fallbackModel;
    if (!mounted) return;

    final controller = TextEditingController(text: current);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isPrimary ? 'Model Utama AI' : 'Model Cadangan AI'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: isPrimary ? 'Model Utama' : 'Model Cadangan',
              hintText: defaultModel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.text = defaultModel;
              },
              child: const Text('Reset Default'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                if (isPrimary) {
                  await config.setPrimaryModel(controller.text);
                } else {
                  await config.setFallbackModel(controller.text);
                }
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

    controller.dispose();

    if (saved == true && mounted) {
      await _loadState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPrimary
                ? 'Model utama AI berhasil diperbarui.'
                : 'Model cadangan AI berhasil diperbarui.',
          ),
        ),
      );
    }
  }

  Future<void> _testAiConnection() async {
    setState(() {
      _isTestingAi = true;
      _aiTestStatus = 'Menguji koneksi ke Samudra AI...';
      _aiTestSuccess = false;
    });

    try {
      final client = ref.read(aiClientProvider);
      final response = await client.chat(
        messages: const [
          AiMessage(
            role: 'user',
            content: 'Ping test koneksi aplikasi. Jawab singkat: "OK".',
          ),
        ],
      );

      if (!mounted) return;
      setState(() {
        _isTestingAi = false;
        _aiTestSuccess = true;
        final model = response.usedModel;
        _aiTestStatus =
            'Berhasil! Model: $model (${response.didFallback ? "Fallback" : "Free-First"})\nRespon: "${response.content.trim()}"';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTestingAi = false;
        _aiTestSuccess = false;
        _aiTestStatus = 'Koneksi gagal: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppTokens.primary(context);

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        title: const Text('Asisten AI'),
        backgroundColor: AppTokens.canvas(context),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: HubSpacing.lg,
            vertical: HubSpacing.lg,
          ),
          children: [
            const HubSectionHeader(
              title: 'KEBIJAKAN MODEL',
              padding: EdgeInsets.symmetric(
                horizontal: HubSpacing.xs,
                vertical: HubSpacing.xs,
              ),
            ),
            const SizedBox(height: HubSpacing.xs),
            // Model Policy Card
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 20, color: primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kebijakan Free-First AI',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    HubPill(
                      label: 'Free-First',
                      color: AppTokens.success(context),
                      isSelected: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Aplikasi mengutamakan model utama ($_primaryModel) dan otomatis beralih ke ($_fallbackModel) saat kuota model utama terbatas.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTokens.textSecondary(context),
                    height: 1.35,
                  ),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Model Utama',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _primaryModel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTokens.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _editModel(isPrimary: true),
                      child: const Text('Ubah'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Model Cadangan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fallbackModel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTokens.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _editModel(isPrimary: false),
                      child: const Text('Ubah'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: HubSpacing.lg),
          const HubSectionHeader(
            title: 'KREDENSIAL & SERVER',
            padding: EdgeInsets.symmetric(
              horizontal: HubSpacing.xs,
              vertical: HubSpacing.xs,
            ),
          ),
          const SizedBox(height: HubSpacing.xs),

          // API Key & Base URL
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 20, color: primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kredensial Samudra AI',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // API Key Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'API Key',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _maskedApiKey ?? 'Bawaan aplikasi (default)',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTokens.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _editApiKey,
                      child: const Text('Ubah'),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Base URL Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Base URL',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _baseUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTokens.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _editBaseUrl,
                      child: const Text('Ubah'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: HubSpacing.lg),
          const HubSectionHeader(
            title: 'DIAGNOSTIK KONEKSI',
            padding: EdgeInsets.symmetric(
              horizontal: HubSpacing.xs,
              vertical: HubSpacing.xs,
            ),
          ),
          const SizedBox(height: HubSpacing.xs),

          // Test Connection Card
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_heart_outlined, size: 20, color: primary),
                    const SizedBox(width: 10),
                    Text(
                      'Uji Konektivitas AI',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Kirim sinyal ping pengujian ke server Samudra AI untuk memastikan konfigurasi API Key dan rute fallback berfungsi normal.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTokens.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                  ),
                  onPressed: _isTestingAi ? null : _testAiConnection,
                  icon: _isTestingAi
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 16),
                  label: Text(_isTestingAi ? 'Menguji...' : 'Uji Koneksi AI'),
                ),
                if (_aiTestStatus != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _aiTestSuccess
                          ? AppTokens.success(context).withValues(alpha: 0.12)
                          : AppTokens.error(context).withValues(alpha: 0.12),
                      borderRadius: HubRadius.rSm,
                      border: Border.all(
                        color: _aiTestSuccess
                            ? AppTokens.success(context).withValues(alpha: 0.4)
                            : AppTokens.error(context).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _aiTestStatus!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _aiTestSuccess
                            ? AppTokens.success(context)
                            : AppTokens.error(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}
