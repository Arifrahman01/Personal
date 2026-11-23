import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
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
  final Set<String> _pendingDeleteIds = <String>{};
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

  List<Note> _applyFilters(List<Note> notes, {String? activeTag}) {
    final query = _searchQuery.trim().toLowerCase();
    final normalizedTag = activeTag?.trim().toLowerCase();

    return notes
        .where((note) {
          if (_pendingDeleteIds.contains(note.id)) {
            return false;
          }
          if (query.isNotEmpty) {
            final matchesTitle = note.title.toLowerCase().contains(query);
            final matchesContent = note.content.toLowerCase().contains(query);
            if (!matchesTitle && !matchesContent) {
              return false;
            }
          }
          if (normalizedTag != null && normalizedTag.isNotEmpty) {
            final hasTag = note.tags.any(
              (t) => t.toLowerCase() == normalizedTag,
            );
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
    setState(() {
      _pendingDeleteIds.add(note.id);
    });
    try {
      await ref.read(notesListProvider.notifier).deleteNote(note.id);
      if (mounted) {
        setState(() {
          _pendingDeleteIds.remove(note.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Catatan "${note.title}" dihapus.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pendingDeleteIds.remove(note.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus catatan.')),
        );
      }
    }
  }

  Future<void> _togglePin(Note note) async {
    try {
      await ref.read(notesListProvider.notifier).togglePin(note.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui sematan catatan.')),
        );
      }
    }
  }

  Future<void> _exportNote(Note note) async {
    try {
      await ref.read(notesExportServiceProvider).shareNote(note);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Catatan "${note.title}" berhasil diekspor.')),
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

  Future<void> _exportAllNotes() async {
    final notes = ref.read(notesListProvider).asData?.value ?? [];
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada catatan untuk diekspor.')),
      );
      return;
    }
    try {
      await ref.read(notesExportServiceProvider).shareAllNotes(notes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${notes.length} catatan berhasil diekspor.')),
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

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final theme = Theme.of(context);

    return GlassScaffold(
      appBar: GlassAppBar(
        title: const Text('Catatan'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opsi lainnya',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'export_all') {
                _exportAllNotes();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'export_all',
                child: Text('Ekspor Semua (.md)'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: GlassFabAnchor(
        child: Container(
          decoration: BoxDecoration(
            gradient: RefleqPalette.lavenderCloud,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.42),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openEditor(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Catatan Baru',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
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
            final visibleNotes = allNotes
                .where((n) => !_pendingDeleteIds.contains(n.id))
                .toList(growable: false);
            final availableTags = _extractTags(visibleNotes);
            final activeTag =
                _selectedTag != null &&
                    availableTags.any(
                      (t) => t.toLowerCase() == _selectedTag!.toLowerCase(),
                    )
                ? _selectedTag
                : null;
            if (_selectedTag != null && activeTag == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedTag != null) {
                  setState(() {
                    _selectedTag = null;
                  });
                }
              });
            }
            final filteredNotes = _applyFilters(
              visibleNotes,
              activeTag: activeTag,
            );
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
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
                  child: visibleNotes.isEmpty
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
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: _NoteCard(
        note: note,
        onTap: () => _openEditor(note),
        onTogglePin: () => _togglePin(note),
        onExport: () => _exportNote(note),
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
        Icon(icon, size: 16, color: RefleqPalette.lavender),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: RefleqPalette.lavender,
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
    required this.onExport,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onExport;
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

  static Color resolveCategoryColor(Note note) {
    final tagsLower = note.tags.map((t) => t.toLowerCase()).toList();
    if (tagsLower.any((t) =>
        t.contains('ide') ||
        t.contains('kreatif') ||
        t.contains('ai') ||
        t.contains('desain') ||
        t.contains('design'))) {
      return RefleqPalette.lavender;
    }
    if (tagsLower.any((t) =>
        t.contains('kerja') ||
        t.contains('meeting') ||
        t.contains('rapat') ||
        t.contains('proyek') ||
        t.contains('klien'))) {
      return RefleqPalette.skyCyan;
    }
    if (tagsLower.any((t) =>
        t.contains('pribadi') ||
        t.contains('kesehatan') ||
        t.contains('olahraga') ||
        t.contains('penting') ||
        t.contains('jadwal'))) {
      return RefleqPalette.rosePink;
    }
    if (tagsLower.any((t) =>
        t.contains('uang') ||
        t.contains('keuangan') ||
        t.contains('finansial') ||
        t.contains('zakat'))) {
      return RefleqPalette.emeraldMint;
    }
    final hash = (note.id.hashCode ^ note.title.hashCode).abs();
    const cycle = [
      RefleqPalette.lavender,
      RefleqPalette.skyCyan,
      RefleqPalette.rosePink,
      RefleqPalette.amberPeach,
    ];
    return cycle[hash % cycle.length];
  }

  static Color resolveTagColor(String tag, Color fallback) {
    final t = tag.toLowerCase();
    if (t.contains('ide') || t.contains('kreatif') || t.contains('ai')) {
      return RefleqPalette.lavender;
    }
    if (t.contains('kerja') || t.contains('rapat') || t.contains('proyek')) {
      return RefleqPalette.skyCyan;
    }
    if (t.contains('pribadi') || t.contains('kesehatan') || t.contains('jadwal')) {
      return RefleqPalette.rosePink;
    }
    if (t.contains('uang') || t.contains('zakat')) {
      return RefleqPalette.emeraldMint;
    }
    return fallback;
  }

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
    final isDark = theme.brightness == Brightness.dark;
    final snippet = note.content.trim();
    final categoryColor = resolveCategoryColor(note);

    return GlassCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      borderColor: note.isPinned
          ? RefleqPalette.lavender.withValues(alpha: 0.55)
          : (isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.08)),
      tintColor: isDark
          ? RefleqPalette.surfaceCard.withValues(alpha: 0.72)
          : Colors.white.withValues(alpha: 0.72),
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Refleq Category Pastel Stripe
            Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.55),
                    blurRadius: 8,
                    offset: const Offset(1, 0),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
                                  const Icon(
                                    Icons.push_pin_rounded,
                                    size: 16,
                                    color: RefleqPalette.lavender,
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
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ekspor Markdown (.md)',
                          icon: const Icon(Icons.file_download_outlined, size: 20),
                          visualDensity: VisualDensity.compact,
                          onPressed: onExport,
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Aksi catatan',
                          onSelected: (value) {
                            if (value == 'pin') {
                              onTogglePin();
                            } else if (value == 'export') {
                              onExport();
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
                              value: 'export',
                              child: Text('Ekspor ke Markdown'),
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
                            height: 1.35,
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
                                  for (final tag in note.tags.take(3)) ...[
                                    Builder(
                                      builder: (context) {
                                        final tagColor =
                                            resolveTagColor(tag, categoryColor);
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tagColor.withValues(
                                              alpha: isDark ? 0.16 : 0.12,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(100),
                                            border: Border.all(
                                              color: tagColor.withValues(
                                                alpha: isDark ? 0.38 : 0.25,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            '#$tag',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: isDark
                                                  ? tagColor
                                                  : tagColor.withValues(
                                                      alpha: 0.95,
                                                    ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
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
          ],
        ),
      ),
    );
  }
}
