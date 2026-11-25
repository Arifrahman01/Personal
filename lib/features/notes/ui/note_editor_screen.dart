import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

enum _UnsavedAction { discard, cancel, save }

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _tagsController;
  late final TextEditingController _contentController;
  final FocusNode _tagFocusNode = FocusNode();

  late final String _initialTitle;
  late final String _initialContent;
  late final List<String> _initialTags;
  late final bool _initialPinned;

  String? _titleError;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _allowImmediatePop = false;
  late bool _isPinned;
  bool _isTagInputVisible = false;
  int _semanticSyncVersion = 0;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _initialTitle = widget.note?.title ?? '';
    _initialContent = widget.note?.content ?? '';
    _initialTags = List<String>.unmodifiable(
      _parseTags(widget.note?.tags.join(', ') ?? ''),
    );
    _initialPinned = widget.note?.isPinned ?? false;

    _titleController = TextEditingController(text: _initialTitle);
    _tagsController = TextEditingController(
      text: widget.note?.tags.join(', ') ?? '',
    );
    _contentController = TextEditingController(text: _initialContent);
    _isPinned = _initialPinned;

    _titleController.addListener(_onEditorChanged);
    _contentController.addListener(_onEditorChanged);
    _tagsController.addListener(_onEditorChanged);

    final initialNotes = ref.read(notesListProvider).asData?.value;
    if (initialNotes != null) {
      _syncNotesToSemanticMemory(initialNotes, notify: false);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onEditorChanged);
    _contentController.removeListener(_onEditorChanged);
    _tagsController.removeListener(_onEditorChanged);
    _titleController.dispose();
    _tagsController.dispose();
    _contentController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  bool _computeIsDirty() {
    if (_titleController.text != _initialTitle) return true;
    if (_contentController.text != _initialContent) return true;
    if (_isPinned != _initialPinned) return true;
    final currentTags = _parseTags(_tagsController.text);
    return !listEquals(currentTags, _initialTags);
  }

  void _onEditorChanged() {
    final nextDirty = _computeIsDirty();
    if (nextDirty != _isDirty && mounted) {
      setState(() {
        _isDirty = nextDirty;
      });
    }
  }

  void _syncNotesToSemanticMemory(
    List<Note> allNotes, {
    required bool notify,
  }) {
    final semanticService = ref.read(semanticMemoryServiceProvider);
    var addedAny = false;
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
        addedAny = true;
      }
    }
    if (addedAny && notify && mounted) {
      setState(() {
        _semanticSyncVersion++;
      });
    }
  }

  Future<void> _handleBackPressed() async {
    if (!_isDirty || _isSaving) {
      Navigator.of(context).pop();
      return;
    }
    await _confirmDiscardOrSave();
  }

  Future<void> _confirmDiscardOrSave() async {
    final action = await showDialog<_UnsavedAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Simpan Perubahan?'),
        content: const Text(
          'Anda memiliki perubahan yang belum disimpan pada catatan ini.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.discard),
            child: Text(
              'Buang',
              style: TextStyle(color: AppTokens.error(dialogContext)),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.cancel),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.save),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (!mounted || action == null || action == _UnsavedAction.cancel) return;
    if (action == _UnsavedAction.discard) {
      setState(() {
        _allowImmediatePop = true;
      });
      Navigator.of(context).pop();
    } else if (action == _UnsavedAction.save) {
      await _saveNote();
    }
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
      backgroundColor: Colors.transparent,
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

    ref.listen<AsyncValue<List<Note>>>(notesListProvider, (_, next) {
      final notes = next.asData?.value;
      if (notes != null) {
        _syncNotesToSemanticMemory(notes, notify: true);
      }
    });

    return PopScope(
      canPop: _allowImmediatePop || !_isDirty || _isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmDiscardOrSave();
      },
      child: Scaffold(
        backgroundColor: AppTokens.canvas(context),
        appBar: AppBar(
          backgroundColor: AppTokens.canvas(context),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            tooltip: 'Kembali',
            onPressed: _handleBackPressed,
          ),
          title: Text(
            _isEditing ? 'Edit Catatan' : 'Catatan Baru',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTokens.textPrimary(context),
            ),
          ),
          actions: [
            IconButton(
              tooltip: _isPinned ? 'Lepas sematan' : 'Sematkan catatan',
              icon: Icon(
                LucideIcons.pin,
                color: _isPinned
                    ? AppTokens.primary(context)
                    : AppTokens.textSecondary(context),
              ),
              onPressed: () {
                setState(() {
                  _isPinned = !_isPinned;
                  _isDirty = _computeIsDirty();
                });
              },
            ),
            if (_isEditing)
              PopupMenuButton<String>(
                tooltip: 'Opsi lainnya',
                icon: const Icon(LucideIcons.ellipsisVertical),
                onSelected: (value) {
                  if (value == 'export') {
                    _exportCurrentNote();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(LucideIcons.download, size: 18),
                        SizedBox(width: 8),
                        Text('Ekspor ke Markdown'),
                      ],
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4, top: 8, bottom: 8),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.primary(context),
                  foregroundColor: AppTokens.onPrimary(context),
                  shape: RoundedRectangleBorder(borderRadius: HubRadius.rPill),
                ),
                onPressed: _isSaving ? null : _saveNote,
                child: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTokens.onPrimary(context),
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
                    horizontal: HubSpacing.md,
                    vertical: HubSpacing.sm,
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
                            color: AppTokens.textSecondary(context)
                                .withValues(alpha: 0.8),
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
                        titleListenable: _titleController,
                        contentListenable: _contentController,
                        syncVersion: _semanticSyncVersion,
                        onInsertReference: (markdownRef) {
                          final current = _contentController.text.trimRight();
                          final next = current.isEmpty
                              ? markdownRef
                              : '$current\n\n$markdownRef';
                          _contentController.text = next;
                          _contentController.selection =
                              TextSelection.collapsed(
                            offset: _contentController.text.length,
                          );
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
                            color: AppTokens.textSecondary(context)
                                .withValues(alpha: 0.8),
                          ),
                          alignLabelWithHint: true,
                          contentPadding: EdgeInsets.zero,
                        ),
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
                  horizontal: HubSpacing.md,
                  vertical: HubSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 2,
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTokens.primary(
                            context,
                          ).withValues(alpha: 0.12),
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
                        icon: const Icon(LucideIcons.sparkles, size: 18),
                        label: const Text(
                          'Asisten AI',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _contentController,
                        builder: (context, value, _) {
                          final wordCount = value.text
                              .trim()
                              .split(RegExp(r'\s+'))
                              .where((s) => s.isNotEmpty)
                              .length;
                          return Text(
                            '$wordCount kata',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: HubTypography.tabular(
                              theme.textTheme.bodySmall?.copyWith(
                                    color: AppTokens.textSecondary(context),
                                    fontWeight: FontWeight.w500,
                                  ) ??
                                  TextStyle(
                                    fontSize: 12,
                                    color: AppTokens.textSecondary(context),
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              InputChip(
                label: Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.primary(context),
                  ),
                ),
                deleteIcon: Icon(
                  LucideIcons.x,
                  size: 14,
                  color: AppTokens.primary(context),
                ),
                deleteButtonTooltipMessage: 'Hapus tag $tag',
                onDeleted: () => _removeTag(tag),
                backgroundColor:
                    AppTokens.primary(context).withValues(alpha: 0.12),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: HubRadius.rPill),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),

            // "+ Tambah Tag" pill
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: HubPill(
                icon: LucideIcons.plus,
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
            ),
          ],
        ),

        if (_isTagInputVisible) ...[
          // Text field for tag editing & backwards compatibility with tests
          const SizedBox(height: 8),
          TextField(
            controller: _tagsController,
            focusNode: _tagFocusNode,
            decoration: InputDecoration(
              labelText: 'Tag',
              hintText: 'Pisahkan dengan koma (misal: kerja, ide)',
              prefixIcon: const Icon(LucideIcons.tag, size: 16),
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
      ],
    );
  }
}

/// Compact semantic cross-link recommendation panel that queries [SemanticMemoryService]
/// to suggest related notes, meetings, and tasks.
/// ONLY displays if relevant links are detected.
class _SemanticCrossLinkPanel extends ConsumerStatefulWidget {
  const _SemanticCrossLinkPanel({
    required this.currentNoteId,
    required this.titleListenable,
    required this.contentListenable,
    required this.syncVersion,
    required this.onInsertReference,
  });

  final String? currentNoteId;
  final ValueListenable<TextEditingValue> titleListenable;
  final ValueListenable<TextEditingValue> contentListenable;
  final int syncVersion;
  final ValueChanged<String> onInsertReference;

  @override
  ConsumerState<_SemanticCrossLinkPanel> createState() =>
      _SemanticCrossLinkPanelState();
}

class _SemanticCrossLinkPanelState
    extends ConsumerState<_SemanticCrossLinkPanel> {
  bool _isExpanded = false;
  Timer? _debounceTimer;
  List<EntityLink> _links = const [];

  @override
  void initState() {
    super.initState();
    widget.titleListenable.addListener(_scheduleRefresh);
    widget.contentListenable.addListener(_scheduleRefresh);
    _links = _computeLinks();
  }

  @override
  void didUpdateWidget(covariant _SemanticCrossLinkPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.titleListenable != oldWidget.titleListenable) {
      oldWidget.titleListenable.removeListener(_scheduleRefresh);
      widget.titleListenable.addListener(_scheduleRefresh);
    }
    if (widget.contentListenable != oldWidget.contentListenable) {
      oldWidget.contentListenable.removeListener(_scheduleRefresh);
      widget.contentListenable.addListener(_scheduleRefresh);
    }
    if (widget.syncVersion != oldWidget.syncVersion ||
        widget.currentNoteId != oldWidget.currentNoteId) {
      _links = _computeLinks();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.titleListenable.removeListener(_scheduleRefresh);
    widget.contentListenable.removeListener(_scheduleRefresh);
    super.dispose();
  }

  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final nextLinks = _computeLinks();
      setState(() {
        _links = nextLinks;
      });
    });
  }

  List<EntityLink> _computeLinks() {
    final fullText =
        '${widget.titleListenable.value.text}\n${widget.contentListenable.value.text}'
            .trim();
    if (fullText.isEmpty) return const [];
    final semanticService = ref.read(semanticMemoryServiceProvider);
    final vector = semanticService.pseudoEmbedder.embed(fullText);
    return semanticService.discoverEntityLinksFromStore(
      widget.currentNoteId ?? 'draft_note_temp',
      vector,
      threshold: 0.20,
    );
  }

  String _localizedEntityType(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return 'Rapat';
      case 'task':
        return 'Tugas';
      case 'note':
      default:
        return 'Catatan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final links = _links;

    // ONLY display if there are relevant links detected!
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }

    if (!_isExpanded) {
      return Padding(
        padding: const EdgeInsets.only(top: HubSpacing.xs, bottom: HubSpacing.xs),
        child: InkWell(
          onTap: () => setState(() => _isExpanded = true),
          borderRadius: HubRadius.rPill,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTokens.primary(context).withValues(alpha: 0.12),
              borderRadius: HubRadius.rPill,
              border: Border.all(
                color: AppTokens.primary(context).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.link2,
                  size: 12,
                  color: AppTokens.primary(context),
                ),
                const SizedBox(width: 4),
                Text(
                  '${links.length} Catatan Terkait',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.primary(context),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.chevronDown,
                  size: 14,
                  color: AppTokens.primary(context),
                ),
              ],
            ),
          ),
        ),
      );
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
          InkWell(
            onTap: () => setState(() => _isExpanded = false),
            borderRadius: HubRadius.rSm,
            child: Row(
              children: [
                Icon(
                  LucideIcons.sparkles,
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.link2,
                        size: 12,
                        color: AppTokens.primary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${links.length} Catatan Terkait',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.primary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.chevronUp,
                  size: 15,
                  color: AppTokens.textSecondary(context),
                ),
              ],
            ),
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
        ? LucideIcons.calendar
        : (isTask ? LucideIcons.checkCheck : LucideIcons.fileText);

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
      backgroundColor: AppTokens.card(context),
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
                        ? LucideIcons.calendar
                        : LucideIcons.fileText,
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
                'Tipe: ${_localizedEntityType(link.targetEntityType)}',
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
                    backgroundColor: AppTokens.primary(context),
                    foregroundColor: AppTokens.onPrimary(context),
                    shape: RoundedRectangleBorder(borderRadius: HubRadius.rPill),
                  ),
                  onPressed: () {
                    final refText =
                        'Terkait [${link.targetEntityType.toUpperCase()}]: $title';
                    widget.onInsertReference(refText);
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(LucideIcons.link, size: 16),
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
