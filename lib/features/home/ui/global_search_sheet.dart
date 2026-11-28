import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/finance/ui/finance_screen.dart';
import 'package:personal_hub/features/home/providers/home_providers.dart';
import 'package:personal_hub/features/home/services/global_search_service.dart';
import 'package:personal_hub/features/meetings/ui/meeting_detail_screen.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';
import 'package:personal_hub/features/tasks/ui/tasks_habits_screen.dart';

/// Modal sheet for universal global search across Notes, Meetings, Tasks, and Finance.
/// Strictly excludes Vault entries to preserve privacy.
class GlobalSearchSheet extends ConsumerStatefulWidget {
  const GlobalSearchSheet({super.key});

  /// Displays the search modal sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const GlobalSearchSheet(),
    );
  }

  @override
  ConsumerState<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends ConsumerState<GlobalSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  GlobalSearchCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    final currentQuery = ref.read(homeSearchQueryProvider);
    _controller.text = currentQuery;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      ref.read(homeSearchQueryProvider.notifier).setQuery(query);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ref.read(homeSearchQueryProvider.notifier).setQuery(query);
    });
  }

  void _onQuerySubmitted(String query) {
    _debounce?.cancel();
    ref.read(homeSearchQueryProvider.notifier).setQuery(query);
  }

  void _clearQuery() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    ref.read(homeSearchQueryProvider.notifier).clear();
  }

  Future<void> _handleResultTap(GlobalSearchResult result) async {
    final navigator = Navigator.of(context);
    final preloadedNotes = ref.read(notesListProvider).asData?.value;
    final notesFuture = result.category == GlobalSearchCategory.note &&
            preloadedNotes == null
        ? ref.read(notesListProvider.future)
        : null;

    navigator.pop();

    switch (result.category) {
      case GlobalSearchCategory.note:
        final notes = preloadedNotes ?? await notesFuture!;
        final matched = notes.where((n) => n.id == result.id).firstOrNull;
        if (matched != null) {
          await navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => NoteEditorScreen(note: matched),
            ),
          );
        }
      case GlobalSearchCategory.meeting:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => MeetingDetailScreen(meetingId: result.id),
          ),
        );
      case GlobalSearchCategory.task:
        await navigator.push(
          MaterialPageRoute<void>(builder: (_) => const TasksHabitsScreen()),
        );
      case GlobalSearchCategory.transaction:
        await navigator.push(
          MaterialPageRoute<void>(builder: (_) => const FinanceScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(globalSearchResultsProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: SearchBar(
                        controller: _controller,
                        autoFocus: true,
                        onChanged: _onQueryChanged,
                        onSubmitted: _onQuerySubmitted,
                        hintText: 'Cari catatan, meeting, tugas, transaksi...',
                        leading: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppTokens.textSecondary(context),
                        ),
                        trailing: _controller.text.isNotEmpty
                            ? [
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: _clearQuery,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                  ],
                ),
              ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  HubPill(
                    label: 'Semua',
                    isSelected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                  const SizedBox(width: 8),
                  for (final cat in GlobalSearchCategory.values) ...[
                    HubPill(
                      label: cat.label,
                      isSelected: _selectedCategory == cat,
                      onTap: () => setState(() {
                        _selectedCategory = _selectedCategory == cat ? null : cat;
                      }),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const Divider(height: 16, thickness: 1),

            // Results List
            Flexible(
              child: searchAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Terjadi kesalahan pencarian: $err',
                      style: TextStyle(color: AppTokens.error(context)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (results) {
                  final filtered = _selectedCategory == null
                      ? results
                      : results.where((r) => r.category == _selectedCategory).toList();

                  if (_controller.text.trim().isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 40,
                              color: AppTokens.textSecondary(context).withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Ketik kata kunci untuk mencari',
                              style: TextStyle(
                                color: AppTokens.textSecondary(context),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mencakup Catatan, Meeting, Tugas, dan Keuangan',
                              style: TextStyle(
                                color: AppTokens.textSecondary(context).withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Tidak ada hasil untuk "${_controller.text}"',
                          style: TextStyle(
                            color: AppTokens.textSecondary(context),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final icon = switch (item.category) {
                        GlobalSearchCategory.note => Icons.edit_note_rounded,
                        GlobalSearchCategory.meeting => Icons.calendar_month_rounded,
                        GlobalSearchCategory.task => Icons.check_box_outlined,
                        GlobalSearchCategory.transaction => Icons.account_balance_wallet_outlined,
                      };

                      return HubCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () => _handleResultTap(item),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LuxeIconMedallion(
                              icon: icon,
                              color: AppTokens.primary(context),
                              size: 38,
                              iconSize: 18,
                              borderRadius: 11,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: AppTokens.textPrimary(context),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTokens.canvas(context),
                                          borderRadius: HubRadius.rXs,
                                          border: Border.all(
                                            color: AppTokens.border(context),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          item.category.label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTokens.textSecondary(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTokens.textSecondary(context),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
