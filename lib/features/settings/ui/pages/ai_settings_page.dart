import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

    if (!mounted) return;
    setState(() {
      _maskedApiKey = _maskSecret(apiKey);
      _baseUrl = baseUrl;
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
              hintText: 'https://api.samudra.ai/v1',
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Model Policy Card
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.sparkles, size: 20, color: primary),
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
                  'Aplikasi selalu mengutamakan model gratis (${AiConstants.freeModel}) dan otomatis beralih ke (${AiConstants.fallbackModel}) saat kuota model gratis terbatas.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTokens.textSecondary(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // API Key & Base URL
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.key, size: 20, color: primary),
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
          const SizedBox(height: 16),

          // Test Connection Card
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.activity, size: 20, color: primary),
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
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                  ),
                  onPressed: _isTestingAi ? null : _testAiConnection,
                  icon: _isTestingAi
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.play, size: 16),
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
    );
  }
}
