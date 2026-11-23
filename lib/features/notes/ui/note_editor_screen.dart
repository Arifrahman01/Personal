import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/providers/local_slm_providers.dart';
import 'package:personal_hub/features/ai/providers/semantic_memory_providers.dart';
import 'package:personal_hub/features/ai/services/semantic_memory_service.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';

/// Screen for creating or editing a [Note], with an inline AI Note Helper sheet.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.note});

  final Note? note;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _tagsController;
  late final TextEditingController _contentController;

  String? _titleError;
  bool _isSaving = false;
  late bool _isPinned;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _tagsController = TextEditingController(
      text: widget.note?.tags.join(', ') ?? '',
    );
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _isPinned = widget.note?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  List<String> _parseTags(String raw) {
    final seen = <String>{};
    final tags = <String>[];
    for (final part in raw.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed.toLowerCase())) {
        tags.add(trimmed);
      }
    }
    return tags;
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _titleError = null;
    });

    try {
      final notifier = ref.read(notesListProvider.notifier);
      final tags = _parseTags(_tagsController.text);

      if (_isEditing) {
        await notifier.updateNote(
          widget.note!.copyWith(
            title: _titleController.text,
            content: _contentController.text,
            tags: tags,
            isPinned: _isPinned,
          ),
        );
      } else {
        final created = await notifier.createNote(
          title: _titleController.text,
          content: _contentController.text,
          tags: tags,
        );
        if (_isPinned) {
          await notifier.togglePin(created.id);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ValidationException catch (error) {
      if (mounted) {
        setState(() {
          _titleError = error.message;
          _isSaving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan catatan.')),
        );
      }
    }
  }

  Future<void> _openAiHelperSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _AiNoteHelperSheet(
          noteTitle: _titleController.text.trim(),
          noteContent: _contentController.text,
          onReplace: (result) {
            setState(() {
              _contentController.text = result;
              _contentController.selection = TextSelection.collapsed(
                offset: _contentController.text.length,
              );
            });
            Navigator.of(sheetContext).pop();
          },
          onAppend: (result) {
            final current = _contentController.text.trimRight();
            final nextText = current.isEmpty ? result : '$current\n\n$result';
            setState(() {
              _contentController.text = nextText;
              _contentController.selection = TextSelection.collapsed(
                offset: _contentController.text.length,
              );
            });
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  Future<void> _summarizeWithLocalSlm() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tulis isi catatan terlebih dahulu sebelum meringkas.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _LocalSlmSummarySheet(
          noteTitle: _titleController.text.trim(),
          noteContent: content,
          onAppend: (result) {
            final current = _contentController.text.trimRight();
            final nextText = current.isEmpty ? result : '$current\n\n$result';
            setState(() {
              _contentController.text = nextText;
              _contentController.selection = TextSelection.collapsed(
                offset: _contentController.text.length,
              );
            });
            Navigator.of(sheetContext).pop();
          },
          onReplace: (result) {
            setState(() {
              _contentController.text = result;
              _contentController.selection = TextSelection.collapsed(
                offset: _contentController.text.length,
              );
            });
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  Future<void> _extractTaskWithLocalSlm() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tulis isi catatan terlebih dahulu untuk mengekstrak tugas.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _LocalSlmTaskSheet(
          noteTitle: _titleController.text.trim(),
          noteContent: content,
          onInsertTask: (taskMarkdown) {
            final current = _contentController.text.trimRight();
            final nextText =
                current.isEmpty ? taskMarkdown : '$current\n\n$taskMarkdown';
            setState(() {
              _contentController.text = nextText;
              _contentController.selection = TextSelection.collapsed(
                offset: _contentController.text.length,
              );
            });
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final parsedTags = _parseTags(_tagsController.text);

    // Synchronize other notes into semantic memory for intelligent cross-linking
    final allNotes = ref.watch(notesListProvider).asData?.value ?? [];
    final semanticService = ref.watch(semanticMemoryServiceProvider);
    for (final otherNote in allNotes) {
      if (otherNote.id != widget.note?.id &&
          semanticService.getById('note_${otherNote.id}') == null) {
        semanticService.embedAndStore(
          id: 'note_${otherNote.id}',
          entityType: 'note',
          entityId: otherNote.id,
          text: '${otherNote.title}\n${otherNote.content}',
          metadata: {'title': otherNote.title, 'tags': otherNote.tags},
        );
      }
    }

    return GlassScaffold(
      appBar: GlassAppBar(
        title: Text(_isEditing ? 'Edit Catatan' : 'Catatan Baru'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Ekspor ke Markdown',
              icon: const Icon(Icons.download_rounded),
              onPressed: () async {
                final currentNote = widget.note!.copyWith(
                  title: _titleController.text,
                  content: _contentController.text,
                  tags: _parseTags(_tagsController.text),
                  isPinned: _isPinned,
                );
                try {
                  await ref
                      .read(notesExportServiceProvider)
                      .shareNote(currentNote);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Catatan "${currentNote.title}" berhasil diekspor.',
                        ),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gagal mengekspor catatan.'),
                      ),
                    );
                  }
                }
              },
            ),
          IconButton(
            tooltip: _isPinned ? 'Lepas sematan' : 'Sematkan catatan',
            icon: Icon(
              _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: _isPinned ? theme.colorScheme.primary : null,
            ),
            onPressed: () {
              setState(() {
                _isPinned = !_isPinned;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isSaving ? null : _saveNote,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Judul catatan',
                        hintText: 'Masukkan judul catatan...',
                        errorText: _titleError,
                      ),
                      onChanged: (_) {
                        setState(() {
                          _titleError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tag',
                        hintText: 'Pisahkan dengan koma (misal: kerja, ide)',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    // Quick tag suggestions
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Saran tag:',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        for (final suggestion in ['ide', 'kerja', 'pribadi']) ...[
                          Builder(
                            builder: (context) {
                              final (pastelColor, pastelBg) = suggestion == 'ide'
                                  ? (RefleqPalette.lavender, RefleqPalette.lavenderSurface)
                                  : (suggestion == 'kerja'
                                      ? (RefleqPalette.skyCyan, RefleqPalette.skyCyanSurface)
                                      : (RefleqPalette.rosePink, RefleqPalette.rosePinkSurface));
                              return ActionChip(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                  side: BorderSide(
                                    color: pastelColor.withValues(
                                      alpha: isDark ? 0.35 : 0.25,
                                    ),
                                  ),
                                ),
                                backgroundColor: isDark
                                    ? pastelBg
                                    : pastelColor.withValues(alpha: 0.10),
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  '#$suggestion',
                                  style: TextStyle(
                                    color: isDark
                                        ? pastelColor
                                        : pastelColor.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  final currentTags =
                                      _parseTags(_tagsController.text);
                                  if (!currentTags.any(
                                    (t) => t.toLowerCase() == suggestion,
                                  )) {
                                    currentTags.add(suggestion);
                                    setState(() {
                                      _tagsController.text =
                                          currentTags.join(', ');
                                    });
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    if (parsedTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in parsedTags)
                            Chip(
                              label: Text('#$tag'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contentController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 8,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'Isi catatan',
                        hintText: 'Tulis catatan Anda di sini...',
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    // Semantic Cross-Link Recommendation Panel
                    _SemanticCrossLinkPanel(
                      currentNoteId: widget.note?.id,
                      currentTitle: _titleController.text,
                      currentContent: _contentController.text,
                      onInsertReference: (markdownRef) {
                        final current = _contentController.text.trimRight();
                        final next =
                            current.isEmpty ? markdownRef : '$current\n\n$markdownRef';
                        setState(() {
                          _contentController.text = next;
                          _contentController.selection = TextSelection.collapsed(
                            offset: _contentController.text.length,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // Refleq Dark Glass AI Toolbar above keyboard with Pastel SLM buttons
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? RefleqPalette.surface.withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.88),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark
                                ? RefleqPalette.lavenderSurface
                                : const Color(0xFFEDE9FE),
                            foregroundColor: isDark
                                ? RefleqPalette.lavender
                                : const Color(0xFF6D28D9),
                            side: BorderSide(
                              color: RefleqPalette.lavender.withValues(
                                alpha: isDark ? 0.35 : 0.25,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _openAiHelperSheet,
                          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: const Text('AI Bantu'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark
                                ? RefleqPalette.skyCyanSurface
                                : const Color(0xFFE0F2FE),
                            foregroundColor: isDark
                                ? RefleqPalette.skyCyan
                                : const Color(0xFF0369A1),
                            side: BorderSide(
                              color: RefleqPalette.skyCyan.withValues(
                                alpha: isDark ? 0.35 : 0.25,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _summarizeWithLocalSlm,
                          icon: const Icon(Icons.offline_bolt_rounded, size: 18),
                          label: const Text('Ringkas via AI Lokal (Offline)'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark
                                ? RefleqPalette.rosePinkSurface
                                : const Color(0xFFFFE4E6),
                            foregroundColor: isDark
                                ? RefleqPalette.rosePink
                                : const Color(0xFFBE123C),
                            side: BorderSide(
                              color: RefleqPalette.rosePink.withValues(
                                alpha: isDark ? 0.35 : 0.25,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _extractTaskWithLocalSlm,
                          icon: const Icon(
                            Icons.playlist_add_check_rounded,
                            size: 18,
                          ),
                          label: const Text('Ekstrak Tugas'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Semantic cross-link recommendation panel that queries [SemanticMemoryService]
/// to suggest related notes, meetings, and tasks with intelligent chips.
class _SemanticCrossLinkPanel extends ConsumerWidget {
  const _SemanticCrossLinkPanel({
    required this.currentNoteId,
    required this.currentTitle,
    required this.currentContent,
    required this.onInsertReference,
  });

  final String? currentNoteId;
  final String currentTitle;
  final String currentContent;
  final ValueChanged<String> onInsertReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fullText = '$currentTitle\n$currentContent'.trim();

    final semanticService = ref.watch(semanticMemoryServiceProvider);

    List<EntityLink> links = [];
    if (fullText.isNotEmpty) {
      final vector = semanticService.pseudoEmbedder.embed(fullText);
      links = semanticService.discoverEntityLinksFromStore(
        currentNoteId ?? 'draft_note_temp',
        vector,
        threshold: 0.20,
      );
    }

    return GlassCard(
      borderRadius: BorderRadius.circular(18),
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hub_outlined,
                size: 18,
                color: RefleqPalette.lavender,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rekomendasi Tautan Semantik',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GlassBadge(
                label: links.isEmpty ? 'SLM Semantic' : '${links.length} Tautan',
                foregroundColor: RefleqPalette.lavender,
                backgroundColor: RefleqPalette.lavenderSurface,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            links.isEmpty
                ? 'Menghubungkan catatan & agenda rapat relevan secara otomatis berdasarkan makna semantik.'
                : 'Catatan & agenda rapat terkait (ketuk untuk menyisipkan referensi):',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (links.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in links)
                  _buildSmartLinkChip(context, link, theme),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmartLinkChip(
    BuildContext context,
    EntityLink link,
    ThemeData theme,
  ) {
    final isMeeting = link.targetEntityType == 'meeting';
    final isTask = link.targetEntityType == 'task';

    final icon = isMeeting
        ? Icons.calendar_month_rounded
        : (isTask ? Icons.task_alt_rounded : Icons.description_outlined);

    final color = isMeeting
        ? RefleqPalette.rosePink
        : (isTask ? RefleqPalette.skyCyan : RefleqPalette.lavender);

    final displayTitle = link.targetEmbedding.metadata?['title'] as String? ??
        (link.targetText.split('\n').first);
    final pct = (link.similarityScore * 100).clamp(0, 100).toInt();

    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text('$displayTitle ($pct%)'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
      ),
      onPressed: () {
        _showLinkDetail(context, link, displayTitle, pct);
      },
    );
  }

  void _showLinkDetail(
    BuildContext context,
    EntityLink link,
    String title,
    int pct,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    link.targetEntityType == 'meeting'
                        ? Icons.calendar_month_rounded
                        : Icons.description_outlined,
                    color: RefleqPalette.lavender,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GlassBadge(
                    label: '$pct% Mirip',
                    foregroundColor: RefleqPalette.lavender,
                    backgroundColor: RefleqPalette.lavenderSurface,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tipe: ${link.targetEntityType.toUpperCase()}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  link.targetText,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final refText =
                        '📌 Terkait [${link.targetEntityType.toUpperCase()}]: $title';
                    onInsertReference(refText);
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Sisipkan Tautan ke Catatan'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Offline note summarizer sheet powered by [localSlmEngineServiceProvider].
class _LocalSlmSummarySheet extends ConsumerStatefulWidget {
  const _LocalSlmSummarySheet({
    required this.noteTitle,
    required this.noteContent,
    required this.onAppend,
    required this.onReplace,
  });

  final String noteTitle;
  final String noteContent;
  final ValueChanged<String> onAppend;
  final ValueChanged<String> onReplace;

  @override
  ConsumerState<_LocalSlmSummarySheet> createState() =>
      _LocalSlmSummarySheetState();
}

class _LocalSlmSummarySheetState extends ConsumerState<_LocalSlmSummarySheet> {
  bool _isLoading = true;
  String? _summary;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runSummary();
  }

  Future<void> _runSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final slmEngine = ref.read(localSlmEngineServiceProvider);
      final result =
          await slmEngine.summarizeNoteLocally(widget.noteContent);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _summary = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal meringkas secara offline: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.offline_bolt_rounded,
                  color: RefleqPalette.skyCyan,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ringkasan AI Lokal (Offline)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const GlassBadge(
                  label: '100% Offline',
                  foregroundColor: RefleqPalette.skyCyan,
                  backgroundColor: RefleqPalette.skyCyanSurface,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Diproses langsung di perangkat Anda via model SLM on-device tanpa memerlukan koneksi internet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Meringkas isi catatan dengan SLM lokal...',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            if (_summary != null) ...[
              const SizedBox(height: 16),
              GlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hasil Ringkasan',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _summary!.trim(),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                widget.onAppend(_summary!.trim()),
                            child: const Text('Sisipkan di bawah'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                widget.onReplace(_summary!.trim()),
                            child: const Text('Terapkan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Offline task extraction sheet powered by [localSlmEngineServiceProvider].
class _LocalSlmTaskSheet extends ConsumerStatefulWidget {
  const _LocalSlmTaskSheet({
    required this.noteTitle,
    required this.noteContent,
    required this.onInsertTask,
  });

  final String noteTitle;
  final String noteContent;
  final ValueChanged<String> onInsertTask;

  @override
  ConsumerState<_LocalSlmTaskSheet> createState() =>
      _LocalSlmTaskSheetState();
}

class _LocalSlmTaskSheetState extends ConsumerState<_LocalSlmTaskSheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _taskData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runExtraction();
  }

  Future<void> _runExtraction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final slmEngine = ref.read(localSlmEngineServiceProvider);
      final result =
          await slmEngine.extractTaskLocally(widget.noteContent);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _taskData = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal mengekstrak tugas: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final title = _taskData?['title'] as String? ?? '';
    final priority = (_taskData?['priority'] as String?)?.toLowerCase() ?? 'medium';
    final dueDate = _taskData?['dueDate'] as String?;

    final priorityColor = priority == 'high'
        ? const Color(0xFFF472B6)
        : (priority == 'low'
            ? const Color(0xFF84CC16)
            : const Color(0xFFFB923C));

    final priorityLabel = priority == 'high'
        ? 'Tinggi (High)'
        : (priority == 'low' ? 'Rendah (Low)' : 'Sedang (Medium)');

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.playlist_add_check_rounded,
                  color: Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ekstrak Tugas via SLM',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const GlassBadge(
                  label: 'SLM On-Device',
                  foregroundColor: Color(0xFF8B5CF6),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Menganalisis isi catatan secara cerdas untuk menemukan butir tugas, tingkat prioritas, dan tenggat waktu.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mengekstrak tugas via on-device SLM...',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            if (_taskData != null) ...[
              const SizedBox(height: 16),
              GlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tugas Terdeteksi',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title.isNotEmpty ? title : '(Tidak ada judul spesifik)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Chip(
                          avatar: Icon(Icons.flag_rounded, size: 16, color: priorityColor),
                          label: Text(priorityLabel),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (dueDate != null && dueDate.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.event_rounded, size: 16),
                            label: Text('Tenggat: $dueDate'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final buffer = StringBuffer('- [ ] $title');
                          if (dueDate != null && dueDate.isNotEmpty) {
                            buffer.write(' (Tenggat: $dueDate)');
                          }
                          buffer.write(' #$priority');
                          widget.onInsertTask(buffer.toString());
                        },
                        icon: const Icon(Icons.add_task_rounded),
                        label: const Text('Tambahkan Checklist ke Catatan'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _NoteAiAction {
  summarize(
    label: 'Ringkas catatan',
    icon: Icons.compress_rounded,
    systemPrompt:
        'Kamu adalah asisten catatan pribadi. Ringkas catatan berikut secara padat, jelas, dan mudah dipindai dalam Bahasa Indonesia. Langsung berikan hasil ringkasannya tanpa basa-basi.',
  ),
  polish(
    label: 'Rapikan bahasa',
    icon: Icons.edit_note_rounded,
    systemPrompt:
        'Kamu adalah editor bahasa Indonesia. Rapikan tata bahasa, ejaan, dan alur tulisan catatan berikut agar lebih jelas dan enak dibaca tanpa mengubah makna aslinya. Langsung berikan teks hasil perbaikannya.',
  ),
  checklist(
    label: 'Ubah jadi checklist',
    icon: Icons.checklist_rounded,
    systemPrompt:
        'Ubah poin-poin penting atau langkah tindak lanjut dari catatan berikut menjadi daftar tugas checklist Markdown menggunakan format "- [ ] ..." dalam Bahasa Indonesia. Langsung berikan daftar checklistnya.',
  );

  const _NoteAiAction({
    required this.label,
    required this.icon,
    required this.systemPrompt,
  });

  final String label;
  final IconData icon;
  final String systemPrompt;
}

class _AiNoteHelperSheet extends ConsumerStatefulWidget {
  const _AiNoteHelperSheet({
    required this.noteTitle,
    required this.noteContent,
    required this.onReplace,
    required this.onAppend,
  });

  final String noteTitle;
  final String noteContent;
  final ValueChanged<String> onReplace;
  final ValueChanged<String> onAppend;

  @override
  ConsumerState<_AiNoteHelperSheet> createState() => _AiNoteHelperSheetState();
}

class _AiNoteHelperSheetState extends ConsumerState<_AiNoteHelperSheet> {
  _NoteAiAction? _activeAction;
  bool _isLoading = false;
  String? _errorMessage;
  AiResponse? _response;

  Future<void> _runAction(_NoteAiAction action) async {
    final trimmedContent = widget.noteContent.trim();
    if (trimmedContent.isEmpty) {
      setState(() {
        _activeAction = action;
        _errorMessage =
            'Tulis isi catatan terlebih dahulu sebelum menggunakan AI Bantu.';
        _response = null;
      });
      return;
    }

    setState(() {
      _activeAction = action;
      _isLoading = true;
      _errorMessage = null;
      _response = null;
    });

    final promptBuffer = StringBuffer();
    if (widget.noteTitle.isNotEmpty) {
      promptBuffer.writeln('Judul: ${widget.noteTitle}');
      promptBuffer.writeln();
    }
    promptBuffer.write(trimmedContent);

    try {
      final response = await ref
          .read(aiClientProvider)
          .chat(
            messages: [
              AiMessage(role: 'user', content: promptBuffer.toString()),
            ],
            systemPrompt: action.systemPrompt,
          );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _response = response;
      });
    } on AiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Terjadi kesalahan saat menghubungi asisten AI.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Bantu Catatan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih aksi sekali ketuk untuk memproses isi catatan dengan Samudra AI.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in _NoteAiAction.values)
                  ActionChip(
                    avatar: Icon(action.icon, size: 18),
                    label: Text(action.label),
                    backgroundColor: _activeAction == action
                        ? theme.colorScheme.primaryContainer
                        : null,
                    onPressed: _isLoading ? null : () => _runAction(action),
                  ),
              ],
            ),
            if (_isLoading) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Memproses "${_activeAction?.label ?? ''}"...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_response != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Pratinjau Hasil',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          _AiModelBadge(
                            didFallback: _response!.didFallback,
                            usedModel: _response!.usedModel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _response!.content.trim(),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  widget.onAppend(_response!.content.trim()),
                              child: const Text('Sisipkan di bawah'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  widget.onReplace(_response!.content.trim()),
                              child: const Text('Terapkan'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiModelBadge extends StatelessWidget {
  const _AiModelBadge({required this.didFallback, required this.usedModel});

  final bool didFallback;
  final String usedModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = didFallback
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.secondaryContainer;
    final fgColor = didFallback
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSecondaryContainer;
    final label = didFallback ? 'Fallback' : 'Free';

    return Tooltip(
      message: usedModel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: fgColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
