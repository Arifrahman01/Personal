import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/ui/finance_screen.dart';
import 'package:personal_hub/features/home/providers/universal_quick_capture_providers.dart';
import 'package:personal_hub/features/meetings/ui/meeting_form_screen.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/ui/tasks_habits_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Universal Quick Capture modal sheet supporting natural language parsing,
/// speech-to-text mic input, and 1-tap manual entry shortcuts.
class QuickCaptureSheet extends ConsumerStatefulWidget {
  const QuickCaptureSheet({super.key});

  /// Displays the Quick Capture modal sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickCaptureSheet(),
    );
  }

  @override
  ConsumerState<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<QuickCaptureSheet> {
  final TextEditingController _textController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _speechInitialized = false;
  String _speechStatus = '';

  @override
  void initState() {
    super.initState();
    final currentState = ref.read(quickCaptureControllerProvider);
    if (currentState.rawInput.isNotEmpty) {
      _textController.text = currentState.rawInput;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    if (_isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    try {
      if (!_speechInitialized) {
        _speechInitialized = await _speech.initialize(
          onError: (val) {
            if (mounted) {
              setState(() {
                _isListening = false;
                _speechStatus = 'Mikrofon: ${val.errorMsg}';
              });
            }
          },
          onStatus: (val) {
            if (val == 'done' || val == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
        );
      }

      if (_speechInitialized) {
        setState(() {
          _isListening = true;
          _speechStatus = 'Mendengarkan...';
        });
        await _speech.listen(
          listenOptions: stt.SpeechListenOptions(
            localeId: 'id_ID',
            partialResults: true,
          ),
          onResult: (result) {
            if (mounted) {
              setState(() {
                _textController.text = result.recognizedWords;
              });
              ref
                  .read(quickCaptureControllerProvider.notifier)
                  .parseInput(result.recognizedWords);
            }
          },
        );
      } else {
        if (mounted) {
          setState(() {
            _speechStatus = 'Izin mikrofon tidak tersedia';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _speechStatus = 'Gagal memulai rekaman suara';
        });
      }
    }
  }

  void _onTextChanged(String text) {
    ref.read(quickCaptureControllerProvider.notifier).parseInput(text);
  }

  Future<void> _saveAll() async {
    final notifier = ref.read(quickCaptureControllerProvider.notifier);
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    notifier.parseInput(text);
    final success = await notifier.commitAll();
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil dicatat ke Personal Hub!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final captureState = ref.watch(quickCaptureControllerProvider);
    final batch = captureState.batch;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppTokens.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(HubRadius.lg)),
        border: Border(
          top: BorderSide(color: AppTokens.border(context), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTokens.border(context),
                    borderRadius: HubRadius.rPill,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title and Mic row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTokens.primary(context).withValues(alpha: 0.12),
                      borderRadius: HubRadius.rSm,
                    ),
                    child: Icon(
                      LucideIcons.sparkles,
                      size: 20,
                      color: AppTokens.primary(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catat Cepat Serbaguna',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.textPrimary(context),
                          ),
                        ),
                        Text(
                          'Tulis alami atau gunakan suara untuk multi-catatan',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTokens.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleListening,
                    tooltip: _isListening ? 'Hentikan Rekam' : 'Bicara Sekarang',
                    style: IconButton.styleFrom(
                      backgroundColor: _isListening
                          ? AppTokens.error(context).withValues(alpha: 0.15)
                          : AppTokens.primary(context).withValues(alpha: 0.12),
                    ),
                    icon: Icon(
                      _isListening ? LucideIcons.micOff : LucideIcons.mic,
                      color: _isListening
                          ? AppTokens.error(context)
                          : AppTokens.primary(context),
                    ),
                  ),
                ],
              ),
              if (_speechStatus.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _speechStatus,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isListening
                        ? AppTokens.primary(context)
                        : AppTokens.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),

              // Natural Input Field
              TextField(
                controller: _textController,
                maxLines: 3,
                minLines: 2,
                autofocus: true,
                onChanged: _onTextChanged,
                decoration: InputDecoration(
                  hintText:
                      'Misal: "Beli kopi 25rb besok meeting sprint lalu kerjakan slide"',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppTokens.textSecondary(context),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  filled: true,
                  fillColor: AppTokens.canvas(context),
                  border: OutlineInputBorder(
                    borderRadius: HubRadius.rSm,
                    borderSide: BorderSide(color: AppTokens.border(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: HubRadius.rSm,
                    borderSide: BorderSide(color: AppTokens.border(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: HubRadius.rSm,
                    borderSide: BorderSide(
                      color: AppTokens.primary(context),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Shortcuts row (horizontally scrollable to avoid overflow on narrow screens)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pintas Manual:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ShortcutChip(
                          icon: LucideIcons.notebookPen,
                          label: 'Catatan',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const NoteEditorScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _ShortcutChip(
                          icon: LucideIcons.checkSquare,
                          label: 'Tugas',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const TasksHabitsScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _ShortcutChip(
                          icon: LucideIcons.walletCards,
                          label: 'Transaksi',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const FinanceScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _ShortcutChip(
                          icon: LucideIcons.calendar,
                          label: 'Meeting',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const MeetingFormScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Parsed Drafts Preview
              if (batch.isNotEmpty) ...[
                Text(
                  'Pratinjau Hasil Ekstraksi (${batch.totalCount} item)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),

                // Finance Drafts
                for (final item in batch.financeDrafts)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTokens.surfaceSubtle(context),
                      borderRadius: HubRadius.rSm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.walletCards,
                          size: 16,
                          color: item.type == TransactionType.expense
                              ? AppTokens.error(context)
                              : AppTokens.success(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.description.isNotEmpty
                                ? item.description
                                : item.category,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTokens.textPrimary(context),
                            ),
                          ),
                        ),
                        Text(
                          currencyFmt.format(item.amount),
                          style: HubTypography.tabular(
                            TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: item.type == TransactionType.expense
                                  ? AppTokens.error(context)
                                  : AppTokens.success(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Task Drafts
                for (final item in batch.taskDrafts)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTokens.surfaceSubtle(context),
                      borderRadius: HubRadius.rSm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.checkSquare,
                          size: 16,
                          color: AppTokens.info(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTokens.textPrimary(context),
                            ),
                          ),
                        ),
                        if (item.priority != TaskPriority.medium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: item.priority == TaskPriority.high
                                  ? AppTokens.error(context).withValues(alpha: 0.12)
                                  : AppTokens.card(context),
                              borderRadius: HubRadius.rXs,
                            ),
                            child: Text(
                              item.priority == TaskPriority.high ? 'Tinggi' : 'Rendah',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: item.priority == TaskPriority.high
                                    ? AppTokens.tonalForeground(
                                        context,
                                        AppTokens.error(context),
                                      )
                                    : AppTokens.textSecondary(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Note Drafts
                for (final item in batch.noteDrafts)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTokens.surfaceSubtle(context),
                      borderRadius: HubRadius.rSm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.notebookPen,
                          size: 16,
                          color: AppTokens.primary(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTokens.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
              ],

              if (captureState.errorMessage != null) ...[
                Text(
                  captureState.errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTokens.error(context),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Commit button
              FilledButton.icon(
                onPressed: captureState.isSaving || batch.isEmpty ? null : _saveAll,
                icon: captureState.isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTokens.onPrimary(context),
                        ),
                      )
                    : const Icon(LucideIcons.check, size: 18),
                label: Text(
                  captureState.isSaving
                      ? 'Menyimpan...'
                      : (batch.isEmpty
                          ? 'Tulis Kalimat untuk Menyimpan'
                          : 'Simpan ${batch.totalCount} Entri'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppTokens.primary(context),
                  foregroundColor: AppTokens.onPrimary(context),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: HubRadius.rPill,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(
          widthFactor: 1.0,
          heightFactor: 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTokens.canvas(context),
              borderRadius: HubRadius.rPill,
              border: Border.all(color: AppTokens.border(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: AppTokens.primary(context)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTokens.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
