import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
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
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
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
            tooltip: 'AI Copilot',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => MainNavigationShell.openAiChat(context),
          ),
          MenuAnchor(
            builder: (context, controller, child) {
              return IconButton(
                tooltip: 'Opsi lainnya',
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: AppTokens.textPrimary(context),
                ),
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              );
            },
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.cloud_download_outlined, size: 18),
                onPressed: _exportAllNotes,
                child: const Text('Ekspor Semua (.md)'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notes_fab',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded, size: 20),
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
          loading: () => const HubSkeletonList(),
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
                // Material 3 SearchBar
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HubSpacing.lg,
                    HubSpacing.sm,
                    HubSpacing.lg,
                    HubSpacing.xs,
                  ),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Cari catatan...',
                    leading: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppTokens.textSecondary(context),
                    ),
                    trailing: _searchQuery.isNotEmpty
                        ? [
                            IconButton(
                              tooltip: 'Bersihkan pencarian',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            ),
                          ]
                        : null,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

                // Horizontal Tag Filter Strip with HubPill (touch target >= 48dp)
                if (availableTags.isNotEmpty) ...[
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: HubSpacing.lg,
                      ),
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(right: HubSpacing.sm),
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
                        for (final tag in availableTags)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: HubSpacing.sm,
                              ),
                              child: HubPill(
                                icon: tag.toLowerCase() == 'meeting'
                                    ? Icons.calendar_month_rounded
                                    : null,
                                label: tag.toLowerCase() == 'meeting'
                                    ? 'Notulensi Meeting'
                                    : '#$tag',
                                isSelected:
                                    activeTag?.toLowerCase() == tag.toLowerCase(),
                                onTap: () {
                                  setState(() {
                                    _selectedTag =
                                        activeTag?.toLowerCase() == tag.toLowerCase()
                                            ? null
                                            : tag;
                                  });
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Notes List
                Expanded(
                  child: visibleNotes.isEmpty
                      ? _buildEmptyState(theme)
                      : filteredNotes.isEmpty
                          ? _buildNoMatchState(theme)
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(
                                HubSpacing.lg,
                                HubSpacing.sm,
                                HubSpacing.lg,
                                96,
                              ),
                              children: [
                                if (pinnedNotes.isNotEmpty) ...[
                                  HubSectionHeader(
                                    title: 'Disematkan',
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: HubSpacing.xs,
                                      vertical: HubSpacing.xs,
                                    ),
                                    trailing: Icon(
                                      Icons.push_pin_rounded,
                                      size: 16,
                                      color: AppTokens.primary(context),
                                    ),
                                  ),
                                  const SizedBox(height: HubSpacing.xs),
                                  for (final note in pinnedNotes) ...[
                                    _buildDismissibleNoteCard(note),
                                    const SizedBox(height: HubSpacing.md),
                                  ],
                                  if (otherNotes.isNotEmpty) ...[
                                    const SizedBox(height: HubSpacing.sm),
                                    HubSectionHeader(
                                      title: 'Catatan Lainnya',
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: HubSpacing.xs,
                                        vertical: HubSpacing.xs,
                                      ),
                                    ),
                                    const SizedBox(height: HubSpacing.xs),
                                  ],
                                ],
                                for (final note in otherNotes) ...[
                                  _buildDismissibleNoteCard(note),
                                  const SizedBox(height: HubSpacing.md),
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
          Icons.delete_outline_rounded,
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

  Widget _buildEmptyState(ThemeData theme) {
    return const HubEmptyState(
      icon: Icons.edit_note_rounded,
      title: 'Belum ada catatan',
      message:
          'Ketuk tombol "Catatan Baru" untuk mulai mencatat ide, daftar tugas, atau ringkasan penting.',
    );
  }

  Widget _buildNoMatchState(ThemeData theme) {
    return HubEmptyState(
      icon: Icons.search_off_rounded,
      title: 'Tidak ada catatan yang cocok',
      message: 'Coba ubah kata kunci pencarian atau pilih filter tag lain.',
      action: TextButton(
        onPressed: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
            _selectedTag = null;
          });
        },
        child: const Text('Reset Filter'),
      ),
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
          ? AppTokens.primary(context).withValues(alpha: 0.45)
          : AppTokens.border(context),
      borderWidth: 1.0,
      padding: const EdgeInsets.fromLTRB(
        HubSpacing.lg,
        HubSpacing.md,
        HubSpacing.sm,
        HubSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Single 3-dot Action Popup
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (note.isPinned) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 16,
                    color: AppTokens.primary(context),
                  ),
                ),
              ],
              Expanded(
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
              // Single 3-dot MenuAnchor Action Menu (>= 48x48dp touch target)
              SizedBox(
                width: 48,
                height: 48,
                child: MenuAnchor(
                  builder: (context, controller, child) {
                    return IconButton(
                      tooltip: 'Aksi catatan',
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: AppTokens.textSecondary(context),
                      ),
                      onPressed: () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                    );
                  },
                  menuChildren: [
                    MenuItemButton(
                      leadingIcon: Icon(
                        note.isPinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin_rounded,
                        size: 18,
                      ),
                      onPressed: onTogglePin,
                      child: Text(note.isPinned ? 'Lepas Sematan' : 'Sematkan'),
                    ),
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.download_rounded, size: 18),
                      onPressed: onExport,
                      child: const Text('Ekspor .md'),
                    ),
                    MenuItemButton(
                      leadingIcon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppTokens.error(context),
                      ),
                      onPressed: onDelete,
                      child: Text(
                        'Hapus',
                        style: TextStyle(color: AppTokens.error(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (snippet.isNotEmpty) ...[
            const SizedBox(height: HubSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(right: HubSpacing.sm),
              child: Text(
                snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTokens.textSecondary(context),
                  height: 1.4,
                ),
              ),
            ),
          ],

          const SizedBox(height: HubSpacing.md),

          // Bottom Row: Tags & Tabular Date
          Padding(
            padding: const EdgeInsets.only(right: HubSpacing.sm),
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
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTokens.primary(context)
                                  .withValues(alpha: 0.1),
                              borderRadius: HubRadius.rPill,
                              border: Border.all(
                                color: AppTokens.primary(context)
                                    .withValues(alpha: 0.25),
                              ),
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
          ),
        ],
      ),
    );
  }
}
