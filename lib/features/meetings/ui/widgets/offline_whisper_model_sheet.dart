import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/services/whisper_model_manager.dart';

/// Modal bottom sheet to download, import locally, select, or delete
/// 100% offline Whisper GGML speech-to-text models.
class OfflineWhisperModelSheet extends ConsumerStatefulWidget {
  const OfflineWhisperModelSheet({super.key});

  /// Opens the offline Whisper model setup sheet.
  /// Returns `true` if at least one offline model is installed when dismissed.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OfflineWhisperModelSheet(),
    );
  }

  @override
  ConsumerState<OfflineWhisperModelSheet> createState() =>
      _OfflineWhisperModelSheetState();
}

class _OfflineWhisperModelSheetState
    extends ConsumerState<OfflineWhisperModelSheet> {
  final Map<OfflineWhisperModelOption, bool> _installed = {};
  final Map<OfflineWhisperModelOption, int?> _sizes = {};
  OfflineWhisperModelOption? _preferred;

  OfflineWhisperModelOption? _downloadingOption;
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  int? _totalBytes;
  bool _cancelRequested = false;
  bool _isImporting = false;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _refreshModels();
  }

  Future<void> _refreshModels() async {
    final manager = ref.read(whisperModelManagerProvider);
    final nextInstalled = <OfflineWhisperModelOption, bool>{};
    final nextSizes = <OfflineWhisperModelOption, int?>{};
    for (final option in OfflineWhisperModelOption.values) {
      nextInstalled[option] = await manager.isModelInstalled(option);
      nextSizes[option] = await manager.getModelSizeBytes(option);
    }
    final preferred = await manager.getInstalledPreferredModel();
    if (!mounted) return;
    setState(() {
      _installed
        ..clear()
        ..addAll(nextInstalled);
      _sizes
        ..clear()
        ..addAll(nextSizes);
      _preferred = preferred;
    });
  }

  Future<void> _download(OfflineWhisperModelOption option) async {
    if (_downloadingOption != null || _isImporting) return;
    setState(() {
      _downloadingOption = option;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
      _totalBytes = null;
      _cancelRequested = false;
      _errorMessage = null;
      _statusMessage = 'Mengunduh ${option.displayName}...';
    });

    final manager = ref.read(whisperModelManagerProvider);
    try {
      await manager.downloadModel(
        option,
        isCancelled: () => _cancelRequested || !mounted,
        onProgress: (progress, received, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = progress;
            _receivedBytes = received;
            _totalBytes = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _downloadingOption = null;
        _statusMessage = '${option.displayName} siap digunakan 100% offline.';
      });
      await _refreshModels();
    } on WhisperModelDownloadCancelledException {
      if (!mounted) return;
      setState(() {
        _downloadingOption = null;
        _statusMessage = 'Unduhan dibatalkan.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloadingOption = null;
        _statusMessage = null;
        _errorMessage =
            'Gagal mengunduh model: $error. Periksa koneksi atau gunakan Impor File (.bin).';
      });
    }
  }

  Future<void> _importLocalBin() async {
    if (_downloadingOption != null || _isImporting) return;
    setState(() {
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Pilih Berkas Model Whisper (.bin)',
        type: FileType.any,
      );
      final path = files.isNotEmpty ? files.first.path : null;
      if (path == null || path.trim().isEmpty || !mounted) return;

      final lowerName = path.toLowerCase();
      final targetOption = lowerName.contains('tiny')
          ? OfflineWhisperModelOption.tinyQ5
          : OfflineWhisperModelOption.baseQ5;

      setState(() {
        _isImporting = true;
        _statusMessage = 'Menyalin berkas model offline...';
      });

      final manager = ref.read(whisperModelManagerProvider);
      await manager.importModelFromFile(path, targetOption);
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _statusMessage =
            'Model berhasil diimpor sebagai ${targetOption.displayName}.';
      });
      await _refreshModels();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _statusMessage = null;
        _errorMessage = 'Gagal mengimpor file model: $error';
      });
    }
  }

  Future<void> _selectPreferred(OfflineWhisperModelOption option) async {
    final manager = ref.read(whisperModelManagerProvider);
    await manager.setPreferredModel(option);
    await _refreshModels();
  }

  Future<void> _deleteModel(OfflineWhisperModelOption option) async {
    final manager = ref.read(whisperModelManagerProvider);
    await manager.deleteModel(option);
    await _refreshModels();
  }

  String _formatMb(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAnyReady = _installed.values.any((v) => v);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTokens.card(context),
          borderRadius: HubRadius.rLg,
          border: Border.all(color: AppTokens.border(context)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTokens.primarySoft(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.cpu,
                      size: 20,
                      color: AppTokens.primary(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Model Transkripsi Offline (Whisper)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Unduh sekali, lalu transkrip rapat tanpa internet selamanya.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTokens.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.of(context).pop(hasAnyReady),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              for (final option in OfflineWhisperModelOption.values) ...[
                _buildOptionCard(context, theme, option),
                const SizedBox(height: 10),
              ],

              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTokens.primarySoft(context),
                    borderRadius: HubRadius.rSm,
                  ),
                  child: Text(
                    _statusMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTokens.primary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTokens.danger(context).withValues(alpha: 0.1),
                    borderRadius: HubRadius.rSm,
                  ),
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTokens.danger(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              OutlinedButton.icon(
                key: const Key('import_whisper_bin_button'),
                onPressed: (_downloadingOption != null || _isImporting)
                    ? null
                    : _importLocalBin,
                icon: const Icon(LucideIcons.folderOpen, size: 18),
                label: const Text('Impor File Model (.bin) dari Perangkat'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(hasAnyReady),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppTokens.primary(context),
                  foregroundColor: AppTokens.onPrimary(context),
                ),
                child: Text(hasAnyReady ? 'Selesai & Gunakan' : 'Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context,
    ThemeData theme,
    OfflineWhisperModelOption option,
  ) {
    final isInstalled = _installed[option] == true;
    final sizeBytes = _sizes[option];
    final isPreferred = _preferred == option;
    final isDownloading = _downloadingOption == option;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTokens.surfaceSubtle(context),
        borderRadius: HubRadius.rMd,
        border: Border.all(
          color: isPreferred
              ? AppTokens.primary(context)
              : AppTokens.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              HubPill(
                label: isInstalled
                    ? (isPreferred ? 'Aktif' : 'Terpasang')
                    : '~${option.approxSizeMb} MB',
                color: isInstalled
                    ? AppTokens.success(context)
                    : AppTokens.info(context),
                isSelected: isPreferred,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            option.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTokens.textSecondary(context),
            ),
          ),
          if (sizeBytes != null) ...[
            const SizedBox(height: 4),
            Text(
              'Ukuran lokal: ${_formatMb(sizeBytes)}',
              style: HubTypography.tabular(
                (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
                  color: AppTokens.textSecondary(context),
                ),
              ),
            ),
          ],
          if (isDownloading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _totalBytes != null && _totalBytes! > 0
                  ? _downloadProgress
                  : null,
              borderRadius: HubRadius.rPill,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _totalBytes != null && _totalBytes! > 0
                      ? '${(_downloadProgress * 100).round()}% (${_formatMb(_receivedBytes)} / ${_formatMb(_totalBytes!)})'
                      : _formatMb(_receivedBytes),
                  style: HubTypography.tabular(
                    theme.textTheme.labelSmall ?? const TextStyle(),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _cancelRequested = true),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isInstalled) ...[
                  if (!isPreferred)
                    TextButton(
                      onPressed: () => _selectPreferred(option),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Pilih Aktif'),
                    ),
                  IconButton(
                    tooltip: 'Hapus model',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 18,
                      color: AppTokens.danger(context),
                    ),
                    onPressed: () => _deleteModel(option),
                  ),
                ] else ...[
                  FilledButton.tonalIcon(
                    key: Key('download_${option.id}_button'),
                    onPressed: (_downloadingOption != null || _isImporting)
                        ? null
                        : () => _download(option),
                    icon: const Icon(LucideIcons.download, size: 16),
                    label: Text('Unduh (~${option.approxSizeMb} MB)'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
