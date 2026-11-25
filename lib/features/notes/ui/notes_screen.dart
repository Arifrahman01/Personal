import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/app.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';

/// Notes list screen with search, tag filters, pinned section, tactile HubCard layout,
/// and single 3-dot action menu per card adhering to Calm Clarity v3.0 guidelines.
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
      ..sort((a, b) {
        final aLower = a.toLowerCase();
        final bLower = b.toLowerCase();
        if (aLower == 'meeting') return -1;
        if (bLower == 'meeting') return 1;
        return aLower.compareTo(bLower);
      });
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
          backgroundColor: AppTokens.card(context),
          title: Text(
            'Hapus Catatan?',
            style: TextStyle(color: AppTokens.textPrimary(context)),
          ),
          content: Text(
            'Catatan "${note.title}" akan dihapus secara permanen.',
            style: TextStyle(color: AppTokens.textSecondary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.error(context),
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
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

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        backgroundColor: AppTokens.canvas(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Catatan',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTokens.textPrimary(context),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Asisten AI',
            icon: const Icon(LucideIcons.sparkles),
            onPressed: () => MainNavigationShell.openAiChat(context),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(LucideIcons.settings),
            onPressed: () => MainNavigationShell.openSettings(context),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opsi lainnya',
            icon: Icon(
              LucideIcons.ellipsisVertical,
              color: AppTokens.textPrimary(context),
            ),
            onSelected: (value) {
              if (value == 'export_all') {
                _exportAllNotes();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'export_all',
                child: Row(
                  children: [
                    Icon(LucideIcons.downloadCloud, size: 18),
                    SizedBox(width: 8),
                    Text('Ekspor Semua (.md)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notes_fab',
        backgroundColor: AppTokens.primary(context),
        foregroundColor: AppTokens.onPrimary(context),
        elevation: 2,
        highlightElevation: 4,
        onPressed: () => _openEditor(),
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text(
          'Catatan Baru',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.2,
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
                style: TextStyle(color: AppTokens.textSecondary(context)),
              ),
            ),
          ),
          data: (allNotes) {
            final visibleNotes = allNotes
                .where((n) => !_pendingDeleteIds.contains(n.id))
                .toList(growable: false);
            final availableTags = _extractTags(visibleNotes);
            final activeTag = _selectedTag != null &&
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
                // Search Input with hairline tactile borders
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppTokens.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Cari catatan...',
                      hintStyle: TextStyle(
                        color: AppTokens.textSecondary(context),
                      ),
                      prefixIcon: Icon(
                        LucideIcons.search,
                        size: 18,
                        color: AppTokens.textSecondary(context),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              tooltip: 'Bersihkan pencarian',
                              icon: const Icon(LucideIcons.x, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: AppTokens.card(context),
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
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

                // Horizontal Tag Filter Strip with HubPill (touch target >= 44dp)
                if (availableTags.isNotEmpty)
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: HubPill(
                                label: 'Semua',
                                isSelected: activeTag == null,
                                onTap: () {
                                  setState(() {
                                    _selectedTag = null;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        for (final tag in availableTags)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 44),
                                child: HubPill(
                                  icon: tag.toLowerCase() == 'meeting'
                                      ? LucideIcons.calendar
                                      : null,
                                  label: tag.toLowerCase() == 'meeting'
                                      ? 'Notulensi Meeting'
                                      : '#$tag',
                                  isSelected: activeTag?.toLowerCase() ==
                                      tag.toLowerCase(),
                                  onTap: () {
                                    setState(() {
                                      _selectedTag = activeTag?.toLowerCase() ==
                                              tag.toLowerCase()
                                          ? null
                                          : tag;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Notes List
                Expanded(
                  child: visibleNotes.isEmpty
                      ? _buildEmptyState()
                      : filteredNotes.isEmpty
                          ? _buildNoMatchState(theme)
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                              children: [
                                if (pinnedNotes.isNotEmpty) ...[
                                  _SectionHeader(
                                    icon: LucideIcons.pin,
                                    label: 'Disematkan',
                                  ),
                                  const SizedBox(height: 8),
                                  for (final note in pinnedNotes) ...[
                                    _buildDismissibleNoteCard(note),
                                    const SizedBox(height: 10),
                                  ],
                                  if (otherNotes.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _SectionHeader(
                                      icon: LucideIcons.fileText,
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
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(note),
      onDismissed: (_) => _deleteNote(note),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTokens.error(context).withValues(alpha: 0.15),
          borderRadius: HubRadius.rMd,
        ),
        child: Icon(
          LucideIcons.trash2,
          color: AppTokens.error(context),
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

  Widget _buildEmptyState() {
    return HubEmptyState(
      icon: LucideIcons.notebookPen,
      title: 'Belum ada catatan',
      message:
          'Ketuk tombol "Buat Catatan" untuk mulai mencatat ide, daftar tugas, atau ringkasan penting.',
      actionLabel: 'Buat Catatan',
      onAction: () => _openEditor(),
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
              LucideIcons.searchX,
              size: 40,
              color: AppTokens.textSecondary(context),
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak ada catatan yang cocok',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTokens.textPrimary(context),
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
        Icon(icon, size: 16, color: AppTokens.primary(context)),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTokens.primary(context),
          ),
        ),
      ],
    );
  }
}

/// Tactile solid HubCard for a single note item.
/// Replaces heavy BackdropFilter glassmorphism with 1px outlineVariant border.
/// Features a single 3-dot action menu (`Sematkan`, `Ekspor .md`, `Hapus`) with >=48dp touch target.
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

    return HubCard(
      onTap: onTap,
      borderRadius: HubRadius.rMd,
      borderColor: note.isPinned
          ? AppTokens.primary(context).withValues(alpha: 0.5)
          : AppTokens.border(context),
      borderWidth: 1.0,
      padding: const EdgeInsets.all(HubSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Single 3-dot Action Popup
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.isPinned) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: Icon(
                    LucideIcons.pin,
                    size: 16,
                    color: AppTokens.primary(context),
                  ),
                ),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTokens.textPrimary(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              // Single 3-dot Popup Action Menu (>= 48x48dp touch target)
              SizedBox(
                width: 48,
                height: 48,
                child: PopupMenuButton<String>(
                  tooltip: 'Aksi catatan',
                  icon: Icon(
                    LucideIcons.ellipsisVertical,
                    size: 20,
                    color: AppTokens.textSecondary(context),
                  ),
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
                      child: Row(
                        children: [
                          Icon(
                            note.isPinned ? LucideIcons.pinOff : LucideIcons.pin,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(note.isPinned ? 'Lepas Sematan' : 'Sematkan'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(LucideIcons.download, size: 18),
                          SizedBox(width: 8),
                          Text('Ekspor .md'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.trash2,
                            size: 18,
                            color: AppTokens.error(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hapus',
                            style: TextStyle(color: AppTokens.error(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (snippet.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              snippet,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTokens.textSecondary(context),
                height: 1.35,
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Bottom Row: Tags & Tabular Date
          Row(
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
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTokens.primary(context).withValues(alpha: 0.1),
                            borderRadius: HubRadius.rPill,
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.primary(context),
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
                style: HubTypography.tabular(
                  theme.textTheme.labelSmall!.copyWith(
                    color: AppTokens.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
