import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsedTags = _parseTags(_tagsController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Catatan' : 'Catatan Baru'),
        actions: [
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
                        if (_titleError != null) {
                          setState(() {
                            _titleError = null;
                          });
                        }
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
                      minLines: 10,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'Isi catatan',
                        hintText: 'Tulis catatan Anda di sini...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _openAiHelperSheet,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('AI Bantu'),
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
