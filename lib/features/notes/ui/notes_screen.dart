import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';

/// Notes list screen with search, tag filters, pinned section, and swipe/menu actions.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTag;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _extractTags(List<Note> notes) {
    final byLower = <String, String>{};
    for (final note in notes) {
      for (final tag in note.tags) {
        final key = tag.toLowerCase();
        byLower.putIfAbsent(key, () => tag);
      }
    }
    final tags = byLower.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  List<Note> _applyFilters(List<Note> notes) {
    final query = _searchQuery.trim().toLowerCase();
    final activeTag = _selectedTag?.trim().toLowerCase();

    return notes
        .where((note) {
          if (query.isNotEmpty) {
            final matchesTitle = note.title.toLowerCase().contains(query);
            final matchesContent = note.content.toLowerCase().contains(query);
            if (!matchesTitle && !matchesContent) {
              return false;
            }
          }
          if (activeTag != null && activeTag.isNotEmpty) {
            final hasTag = note.tags.any((t) => t.toLowerCase() == activeTag);
            if (!hasTag) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  Future<void> _openEditor([Note? note]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
    );
  }

  Future<bool> _confirmDelete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Catatan?'),
          content: Text(
            'Catatan "${note.title}" akan dihapus secara permanen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _deleteNote(Note note) async {
    await ref.read(notesListProvider.notifier).deleteNote(note.id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Catatan "${note.title}" dihapus.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Catatan')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notes_fab',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catatan Baru'),
      ),
      body: SafeArea(
        child: notesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Gagal memuat catatan: $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (allNotes) {
            final availableTags = _extractTags(allNotes);
            final activeTag =
                _selectedTag != null &&
                    availableTags.any(
                      (t) => t.toLowerCase() == _selectedTag!.toLowerCase(),
                    )
                ? _selectedTag
                : null;
            final filteredNotes = _applyFilters(allNotes);
            final pinnedNotes = filteredNotes
                .where((n) => n.isPinned)
                .toList(growable: false);
            final otherNotes = filteredNotes
                .where((n) => !n.isPinned)
                .toList(growable: false);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari catatan...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              tooltip: 'Bersihkan pencarian',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                if (availableTags.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('Semua'),
                            selected: activeTag == null,
                            onSelected: (_) {
                              setState(() {
                                _selectedTag = null;
                              });
                            },
                          ),
                        ),
                        for (final tag in availableTags)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('#$tag'),
                              selected:
                                  activeTag?.toLowerCase() == tag.toLowerCase(),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedTag = selected ? tag : null;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: allNotes.isEmpty
                      ? _buildEmptyState(theme)
                      : filteredNotes.isEmpty
                      ? _buildNoMatchState(theme)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          children: [
                            if (pinnedNotes.isNotEmpty) ...[
                              _SectionHeader(
                                icon: Icons.push_pin_rounded,
                                label: 'Disematkan',
                              ),
                              const SizedBox(height: 8),
                              for (final note in pinnedNotes) ...[
                                _buildDismissibleNoteCard(note),
                                const SizedBox(height: 10),
                              ],
                              if (otherNotes.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                const _SectionHeader(
                                  icon: Icons.notes_rounded,
                                  label: 'Catatan Lainnya',
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                            for (final note in otherNotes) ...[
                              _buildDismissibleNoteCard(note),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDismissibleNoteCard(Note note) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(note),
      onDismissed: (_) => _deleteNote(note),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: _NoteCard(
        note: note,
        onTap: () => _openEditor(note),
        onTogglePin: () =>
            ref.read(notesListProvider.notifier).togglePin(note.id),
        onDelete: () async {
          if (await _confirmDelete(note)) {
            await _deleteNote(note);
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.note_alt_rounded, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  'Belum ada catatan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ketuk tombol "Catatan Baru" untuk mulai mencatat ide, daftar tugas, atau ringkasan penting.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMatchState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak ada catatan yang cocok',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedTag = null;
                });
              },
              child: const Text('Reset Filter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  String _formatUpdatedAt(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = _shortMonths[local.month - 1];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month ${local.year}, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snippet = note.content.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (note.isPinned) ...[
                            Icon(
                              Icons.push_pin_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Aksi catatan',
                    onSelected: (value) {
                      if (value == 'pin') {
                        onTogglePin();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'pin',
                        child: Text(
                          note.isPinned ? 'Lepas Sematan' : 'Sematkan',
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Hapus'),
                      ),
                    ],
                  ),
                ],
              ),
              if (snippet.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    if (note.tags.isNotEmpty)
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final tag in note.tags.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      const Spacer(),
                    Text(
                      _formatUpdatedAt(note.updatedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
}
