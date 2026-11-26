import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/ai/providers/semantic_memory_providers.dart';
import 'package:personal_hub/features/ai/services/semantic_memory_service.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/notes/ui/widgets/unified_ai_sheet.dart';

/// Distraction-free canvas screen for creating or editing a [Note],
/// with modern pill-based tag editor, compact semantic cross-links,
/// and a unified AI Assistant sheet.
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
  final FocusNode _tagFocusNode = FocusNode();

  String? _titleError;
  bool _isSaving = false;
  late bool _isPinned;
  bool _isTagInputVisible = false;

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
    _tagFocusNode.dispose();
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

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    final current = _parseTags(_tagsController.text);
    if (!current.any((t) => t.toLowerCase() == trimmed.toLowerCase())) {
      current.add(trimmed);
      setState(() {
        _tagsController.text = current.join(', ');
      });
    }
  }

  void _removeTag(String tag) {
    final current = _parseTags(_tagsController.text);
    current.removeWhere((t) => t.toLowerCase() == tag.toLowerCase());
    setState(() {
      _tagsController.text = current.join(', ');
    });
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

  Future<void> _exportCurrentNote() async {
    final currentNote = (widget.note ??
            Note(
              id: 'temp_export',
              title: _titleController.text,
              content: _contentController.text,
              tags: _parseTags(_tagsController.text),
              isPinned: _isPinned,
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            ))
        .copyWith(
      title: _titleController.text,
      content: _contentController.text,
      tags: _parseTags(_tagsController.text),
      isPinned: _isPinned,
    );

    try {
      await ref.read(notesExportServiceProvider).shareNote(currentNote);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Catatan "${currentNote.title}" berhasil diekspor.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengekspor catatan.')),
        );
      }
    }
  }

  Future<void> _openUnifiedAiSheet({int initialTab = 0}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return UnifiedAiAssistantSheet(
          noteTitle: _titleController.text.trim(),
          noteContent: _contentController.text,
          initialTabIndex: initialTab,
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

    final wordCount = _contentController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .length;

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        backgroundColor: AppTokens.canvas(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Catatan' : 'Catatan Baru',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTokens.textPrimary(context),
          ),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Ekspor ke Markdown',
              icon: const Icon(Icons.download_rounded),
              onPressed: _exportCurrentNote,
            ),
          IconButton(
            tooltip: _isPinned ? 'Lepas sematan' : 'Sematkan catatan',
            icon: Icon(
              _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: _isPinned ? AppTokens.primary(context) : null,
            ),
            onPressed: () {
              setState(() {
                _isPinned = !_isPinned;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: HubRadius.rPill),
              ),
              onPressed: _isSaving ? null : _saveNote,
              child: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Text('Simpan'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Distraction-free Canvas Body
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: HubSpacing.lg,
                  vertical: HubSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Borderless Large Title Field
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTokens.textPrimary(context),
                        letterSpacing: -0.3,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        labelText: 'Judul catatan',
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        hintText: 'Judul catatan...',
                        hintStyle: TextStyle(
                          color: AppTokens.textSecondary(context).withValues(alpha: 0.5),
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) {
                        if (_titleError != null) {
                          setState(() {
                            _titleError = null;
                          });
                        }
                      },
                    ),

                    if (_titleError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _titleError!,
                        style: TextStyle(
                          color: AppTokens.error(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(height: HubSpacing.md),

                    // Modern Pill-based Tag Editor
                    _buildTagEditorSection(theme, parsedTags),

                    const SizedBox(height: HubSpacing.sm),

                    // Compact Semantic Cross-Link Panel (Only visible when relevant links exist)
                    _SemanticCrossLinkPanel(
                      currentNoteId: widget.note?.id,
                      currentTitle: _titleController.text,
                      currentContent: _contentController.text,
                      onInsertReference: (markdownRef) {
                        final current = _contentController.text.trimRight();
                        final next = current.isEmpty
                            ? markdownRef
                            : '$current\n\n$markdownRef';
                        setState(() {
                          _contentController.text = next;
                          _contentController.selection =
                              TextSelection.collapsed(
                            offset: _contentController.text.length,
                          );
                        });
                      },
                    ),

                    const SizedBox(height: HubSpacing.sm),
                    Divider(color: AppTokens.border(context), height: 1),
                    const SizedBox(height: HubSpacing.sm),

                    // Distraction-free Content Canvas
                    TextField(
                      controller: _contentController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 14,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTokens.textPrimary(context),
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        labelText: 'Isi catatan',
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        hintText: 'Tulis catatan Anda di sini...',
                        hintStyle: TextStyle(
                          color: AppTokens.textSecondary(context).withValues(alpha: 0.45),
                        ),
                        alignLabelWithHint: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),

            // Unified AI Assistant Bottom Bar
            Container(
              decoration: BoxDecoration(
                color: AppTokens.card(context),
                border: Border(
                  top: BorderSide(
                    color: AppTokens.border(context),
                    width: 1.0,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: HubSpacing.lg,
                vertical: HubSpacing.sm,
              ),
              child: Row(
                children: [
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          AppTokens.primary(context).withValues(alpha: 0.12),
                      foregroundColor: AppTokens.primary(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: HubRadius.rPill,
                      ),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _openUnifiedAiSheet(),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text(
                      '✨ Asisten AI',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$wordCount kata',
                    style: HubTypography.tabular(
                      theme.textTheme.bodySmall?.copyWith(
                            color: AppTokens.textSecondary(context),
                            fontWeight: FontWeight.w500,
                          ) ??
                          TextStyle(
                            color: AppTokens.textSecondary(context),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagEditorSection(ThemeData theme, List<String> parsedTags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pill list of existing tags + "+ Tambah Tag" button
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in parsedTags)
              Container(
                padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: AppTokens.primary(context).withValues(alpha: 0.12),
                  borderRadius: HubRadius.rPill,
                  border: Border.all(
                    color: AppTokens.primary(context).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.primary(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _removeTag(tag),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppTokens.primary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // "+ Tambah Tag" pill
            HubPill(
              icon: Icons.add_rounded,
              label: 'Tambah Tag',
              onTap: () {
                setState(() {
                  _isTagInputVisible = !_isTagInputVisible;
                });
                if (_isTagInputVisible) {
                  _tagFocusNode.requestFocus();
                }
              },
            ),
          ],
        ),

        // Text field for tag editing & backwards compatibility with tests
        const SizedBox(height: 8),
        TextField(
          controller: _tagsController,
          focusNode: _tagFocusNode,
          decoration: InputDecoration(
            labelText: 'Tag',
            hintText: 'Pisahkan dengan koma (misal: kerja, ide)',
            prefixIcon: const Icon(Icons.label_outline_rounded, size: 16),
            isDense: true,
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
              borderSide: BorderSide(color: AppTokens.primary(context), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 8),

        // Quick tag suggestions: #ide, #kerja, #pribadi
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Saran tag:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTokens.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final suggestion in ['ide', 'kerja', 'pribadi'])
              HubPill(
                label: '#$suggestion',
                isSelected: parsedTags.any((t) => t.toLowerCase() == suggestion),
                onTap: () => _addTag(suggestion),
              ),
          ],
        ),
      ],
    );
  }
}

/// Compact semantic cross-link recommendation panel that queries [SemanticMemoryService]
/// to suggest related notes, meetings, and tasks.
/// ONLY displays if relevant links are detected.
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

    // ONLY display if there are relevant links detected!
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: HubSpacing.xs, bottom: HubSpacing.xs),
      padding: const EdgeInsets.all(HubSpacing.sm),
      decoration: BoxDecoration(
        color: AppTokens.card(context),
        borderRadius: HubRadius.rSm,
        border: Border.all(color: AppTokens.border(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: AppTokens.primary(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Rekomendasi Tautan Semantik',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTokens.textPrimary(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTokens.primary(context).withValues(alpha: 0.12),
                  borderRadius: HubRadius.rPill,
                ),
                child: Text(
                  '🔗 ${links.length} Catatan Terkait',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final link in links)
                _buildSmartLinkChip(context, link, theme),
            ],
          ),
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
        : (isTask ? Icons.done_all_rounded : Icons.description_outlined);

    final color = isMeeting
        ? AppTokens.info(context)
        : (isTask ? AppTokens.success(context) : AppTokens.primary(context));

    final displayTitle = link.targetEmbedding.metadata?['title'] as String? ??
        (link.targetText.split('\n').first);
    final pct = (link.similarityScore * 100).clamp(0, 100).toInt();

    return ActionChip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text('$displayTitle ($pct%)'),
      shape: RoundedRectangleBorder(borderRadius: HubRadius.rPill),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
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
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              HubSpacing.xl,
              0,
              HubSpacing.xl,
              HubSpacing.xxl,
            ),
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
                    color: AppTokens.primary(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTokens.textPrimary(context),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTokens.primary(context).withValues(alpha: 0.15),
                      borderRadius: HubRadius.rPill,
                    ),
                    child: Text(
                      '$pct% Mirip',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTokens.primary(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tipe: ${link.targetEntityType.toUpperCase()}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTokens.primary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTokens.canvas(context),
                  borderRadius: HubRadius.rSm,
                  border: Border.all(color: AppTokens.border(context)),
                ),
                child: Text(
                  link.targetText,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTokens.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: HubRadius.rPill),
                  ),
                  onPressed: () {
                    final refText =
                        '📌 Terkait [${link.targetEntityType.toUpperCase()}]: $title';
                    onInsertReference(refText);
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: const Text('Sisipkan Tautan ke Catatan'),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}
