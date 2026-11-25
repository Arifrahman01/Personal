import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/providers/local_slm_providers.dart';

/// Unified AI Assistant Sheet for notes: combines Cloud AI, on-device offline summarization,
/// grammar polishing, and task checklist extraction into a single structured modal sheet.
class UnifiedAiAssistantSheet extends ConsumerStatefulWidget {
  const UnifiedAiAssistantSheet({
    super.key,
    required this.noteTitle,
    required this.noteContent,
    required this.onReplace,
    required this.onAppend,
    required this.onInsertTask,
    this.initialTabIndex = 0,
  });

  final String noteTitle;
  final String noteContent;
  final ValueChanged<String> onReplace;
  final ValueChanged<String> onAppend;
  final ValueChanged<String> onInsertTask;
  final int initialTabIndex;

  @override
  ConsumerState<UnifiedAiAssistantSheet> createState() =>
      _UnifiedAiAssistantSheetState();
}

class _UnifiedAiAssistantSheetState
    extends ConsumerState<UnifiedAiAssistantSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Cloud AI state (scoped by source tab index to prevent cross-tab leakage)
  bool _isCloudLoading = false;
  int? _cloudSourceTabIndex;
  String? _cloudError;
  AiResponse? _cloudResponse;
  String? _activeCloudAction;

  // Local offline summary state
  bool _isSlmSummaryLoading = false;
  String? _slmSummaryError;
  String? _slmSummaryResult;

  // Local offline task extraction state
  bool _isSlmTaskLoading = false;
  String? _slmTaskError;
  Map<String, dynamic>? _slmTaskResult;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initial,
    );
    _tabController.addListener(_onTabChanged);
    if (initial == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _slmTaskResult == null && !_isSlmTaskLoading) {
          _runTaskExtraction();
        }
      });
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging &&
        _tabController.index == 2 &&
        _slmTaskResult == null &&
        !_isSlmTaskLoading) {
      _runTaskExtraction();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runCloudAction({
    required String actionLabel,
    required String systemPrompt,
  }) async {
    final sourceTab = _tabController.index;
    final trimmedContent = widget.noteContent.trim();
    if (trimmedContent.isEmpty) {
      setState(() {
        _cloudSourceTabIndex = sourceTab;
        _activeCloudAction = actionLabel;
        _cloudError = 'Tulis isi catatan terlebih dahulu sebelum menggunakan Asisten AI.';
        _cloudResponse = null;
      });
      return;
    }

    setState(() {
      _cloudSourceTabIndex = sourceTab;
      _activeCloudAction = actionLabel;
      _isCloudLoading = true;
      _cloudError = null;
      _cloudResponse = null;
    });

    final promptBuffer = StringBuffer();
    if (widget.noteTitle.isNotEmpty) {
      promptBuffer.writeln('Judul: ${widget.noteTitle}');
      promptBuffer.writeln();
    }
    promptBuffer.write(trimmedContent);

    try {
      final response = await ref.read(aiClientProvider).chat(
        messages: [
          AiMessage(role: 'user', content: promptBuffer.toString()),
        ],
        systemPrompt: systemPrompt,
      );
      if (!mounted) return;
      setState(() {
        _isCloudLoading = false;
        _cloudResponse = response;
      });
    } on AiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isCloudLoading = false;
        _cloudError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCloudLoading = false;
        _cloudError = 'Terjadi kesalahan saat menghubungi asisten AI.';
      });
    }
  }

  Future<void> _runSlmSummary() async {
    final trimmedContent = widget.noteContent.trim();
    if (trimmedContent.isEmpty) {
      setState(() {
        _slmSummaryError = 'Tulis isi catatan terlebih dahulu sebelum meringkas.';
      });
      return;
    }

    setState(() {
      _isSlmSummaryLoading = true;
      _slmSummaryError = null;
      _slmSummaryResult = null;
    });

    try {
      final slmEngine = ref.read(localSlmEngineServiceProvider);
      final result = await slmEngine.summarizeNoteLocally(trimmedContent);
      if (!mounted) return;
      setState(() {
        _isSlmSummaryLoading = false;
        _slmSummaryResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSlmSummaryLoading = false;
        _slmSummaryError = 'Gagal meringkas secara offline: $e';
      });
    }
  }

  Future<void> _runTaskExtraction() async {
    final trimmedContent = widget.noteContent.trim();
    if (trimmedContent.isEmpty) {
      setState(() {
        _slmTaskError = 'Tulis isi catatan terlebih dahulu untuk mengekstrak tugas.';
      });
      return;
    }

    setState(() {
      _isSlmTaskLoading = true;
      _slmTaskError = null;
      _slmTaskResult = null;
    });

    try {
      final slmEngine = ref.read(localSlmEngineServiceProvider);
      final result = await slmEngine.extractTaskLocally(trimmedContent);
      if (!mounted) return;
      setState(() {
        _isSlmTaskLoading = false;
        _slmTaskResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSlmTaskLoading = false;
        _slmTaskError = 'Gagal mengekstrak tugas: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final topSafePadding = MediaQuery.paddingOf(context).top;
    final maxSheetHeight = (viewportHeight - topSafePadding - bottomInset - 80)
        .clamp(200.0, viewportHeight * 0.72);

    return Container(
      decoration: BoxDecoration(
        color: AppTokens.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(HubRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            HubSpacing.md,
            HubSpacing.sm,
            HubSpacing.md,
            HubSpacing.md + bottomInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      LucideIcons.sparkles,
                      size: 20,
                      color: AppTokens.primary(context),
                    ),
                    const SizedBox(width: HubSpacing.sm),
                    Expanded(
                      child: Text(
                        'Asisten AI',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTokens.textPrimary(context),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  'Pusat kecerdasan catatan: Ringkasan offline & cloud, perbaikan bahasa, dan ekstrak tugas.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTokens.textSecondary(context),
                  ),
                ),
                const SizedBox(height: HubSpacing.sm),

                // TabBar Navigation
                Container(
                  decoration: BoxDecoration(
                    color: AppTokens.canvas(context),
                    borderRadius: HubRadius.rPill,
                    border: Border.all(color: AppTokens.border(context), width: 1),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppTokens.primary(context),
                      borderRadius: HubRadius.rPill,
                    ),
                    labelColor: AppTokens.onPrimary(context),
                    unselectedLabelColor: AppTokens.textSecondary(context),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Ringkas'),
                      Tab(text: 'Gaya Bahasa'),
                      Tab(text: 'Ekstrak Tugas'),
                    ],
                  ),
                ),
                const SizedBox(height: HubSpacing.md),

                // TabBar Content with Expanded
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRingkasTab(theme),
                      _buildGayaBahasaTab(theme),
                      _buildEkstrakTugasTab(theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // TAB 1: Ringkas (Cloud & Offline)
  Widget _buildRingkasTab(ThemeData theme) {
    final isTab1Cloud = _cloudSourceTabIndex == 0;
    final showCloudLoading = _isCloudLoading && isTab1Cloud;
    final tab1CloudError = isTab1Cloud ? _cloudError : null;
    final tab1CloudResponse = isTab1Cloud ? _cloudResponse : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih metode ringkasan yang diinginkan:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: HubSpacing.sm),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                    side: BorderSide(color: AppTokens.border(context)),
                  ),
                  onPressed: _isCloudLoading
                      ? null
                      : () => _runCloudAction(
                            actionLabel: 'Ringkas catatan',
                            systemPrompt:
                                'Kamu adalah asisten catatan pribadi. Ringkas catatan berikut secara padat, jelas, dan mudah dipindai dalam Bahasa Indonesia. Langsung berikan hasil ringkasannya tanpa basa-basi.',
                          ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.cloud, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Ringkas catatan',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTokens.primary(context).withValues(alpha: 0.1),
                          borderRadius: HubRadius.rPill,
                        ),
                        child: Text(
                          'Cloud',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTokens.primary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: HubSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                  ),
                  onPressed: _isSlmSummaryLoading ? null : _runSlmSummary,
                  child: Row(
                    children: [
                      const Icon(LucideIcons.cpu, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Ringkas via AI Lokal (Offline)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTokens.primary(context).withValues(alpha: 0.15),
                          borderRadius: HubRadius.rPill,
                        ),
                        child: Text(
                          'Offline',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTokens.primary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Loading indicators
          if (showCloudLoading || _isSlmSummaryLoading) ...[
            const SizedBox(height: HubSpacing.md),
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: HubSpacing.sm),
                Expanded(
                  child: Text(
                    showCloudLoading
                        ? 'Meringkas via Samudra AI Cloud...'
                        : 'Meringkas secara offline (tanpa internet)...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTokens.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Errors
          if (tab1CloudError != null || _slmSummaryError != null) ...[
            const SizedBox(height: HubSpacing.md),
            HubCard(
              backgroundColor: AppTokens.error(context).withValues(alpha: 0.1),
              borderColor: AppTokens.error(context).withValues(alpha: 0.3),
              padding: const EdgeInsets.all(HubSpacing.sm),
              child: Row(
                children: [
                  Icon(LucideIcons.circleAlert, size: 18, color: AppTokens.error(context)),
                  const SizedBox(width: HubSpacing.sm),
                  Expanded(
                    child: Text(
                      tab1CloudError ?? _slmSummaryError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTokens.error(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Cloud Result
          if (tab1CloudResponse != null) ...[
            const SizedBox(height: HubSpacing.md),
            _buildResultCard(
              title: 'Hasil Ringkasan',
              content: tab1CloudResponse.content.trim(),
              badge: _AiModelBadge(
                didFallback: tab1CloudResponse.didFallback,
                usedModel: tab1CloudResponse.usedModel,
              ),
            ),
          ],

          // Local Offline Result
          if (_slmSummaryResult != null) ...[
            const SizedBox(height: HubSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ringkasan AI Lokal (Offline)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTokens.textPrimary(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: HubSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTokens.primary(context).withValues(alpha: 0.15),
                        borderRadius: HubRadius.rPill,
                      ),
                      child: Text(
                        '100% Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.primary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HubSpacing.sm),
                _buildResultCard(
                  title: 'Hasil Ringkasan',
                  content: _slmSummaryResult!.trim(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // TAB 2: Gaya Bahasa (Rapikan & Checklist)
  Widget _buildGayaBahasaTab(ThemeData theme) {
    final isTab2Cloud = _cloudSourceTabIndex == 1;
    final showCloudLoading = _isCloudLoading && isTab2Cloud;
    final tab2CloudError = isTab2Cloud ? _cloudError : null;
    final tab2CloudResponse = isTab2Cloud ? _cloudResponse : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perbaiki kualitas tulisan atau susun checklist tindak lanjut:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: HubSpacing.sm),
          Wrap(
            spacing: HubSpacing.sm,
            runSpacing: HubSpacing.sm,
            children: [
              ActionChip(
                avatar: const Icon(LucideIcons.penLine, size: 16),
                label: const Text('Rapikan bahasa'),
                backgroundColor: isTab2Cloud && _activeCloudAction == 'Rapikan bahasa'
                    ? AppTokens.primary(context).withValues(alpha: 0.15)
                    : null,
                onPressed: _isCloudLoading
                    ? null
                    : () => _runCloudAction(
                          actionLabel: 'Rapikan bahasa',
                          systemPrompt:
                              'Kamu adalah editor bahasa Indonesia. Rapikan tata bahasa, ejaan, dan alur tulisan catatan berikut agar lebih jelas dan enak dibaca tanpa mengubah makna aslinya. Langsung berikan teks hasil perbaikannya.',
                        ),
              ),
              ActionChip(
                avatar: const Icon(LucideIcons.listTodo, size: 16),
                label: const Text('Ubah jadi checklist'),
                backgroundColor:
                    isTab2Cloud && _activeCloudAction == 'Ubah jadi checklist'
                        ? AppTokens.primary(context).withValues(alpha: 0.15)
                        : null,
                onPressed: _isCloudLoading
                    ? null
                    : () => _runCloudAction(
                          actionLabel: 'Ubah jadi checklist',
                          systemPrompt:
                              'Ubah poin-poin penting atau langkah tindak lanjut dari catatan berikut menjadi daftar tugas checklist Markdown menggunakan format "- [ ] ..." dalam Bahasa Indonesia. Langsung berikan daftar checklistnya.',
                        ),
              ),
            ],
          ),

          if (showCloudLoading) ...[
            const SizedBox(height: HubSpacing.md),
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: HubSpacing.sm),
                Expanded(
                  child: Text(
                    'Memproses "$_activeCloudAction"...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTokens.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (tab2CloudError != null) ...[
            const SizedBox(height: HubSpacing.md),
            HubCard(
              backgroundColor: AppTokens.error(context).withValues(alpha: 0.1),
              borderColor: AppTokens.error(context).withValues(alpha: 0.3),
              padding: const EdgeInsets.all(HubSpacing.sm),
              child: Row(
                children: [
                  Icon(LucideIcons.circleAlert, size: 18, color: AppTokens.error(context)),
                  const SizedBox(width: HubSpacing.sm),
                  Expanded(
                    child: Text(
                      tab2CloudError,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTokens.error(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (tab2CloudResponse != null) ...[
            const SizedBox(height: HubSpacing.md),
            _buildResultCard(
              title: 'Pratinjau Hasil',
              content: tab2CloudResponse.content.trim(),
              badge: _AiModelBadge(
                didFallback: tab2CloudResponse.didFallback,
                usedModel: tab2CloudResponse.usedModel,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // TAB 3: Ekstrak Tugas (Offline On-Device)
  Widget _buildEkstrakTugasTab(ThemeData theme) {
    final title = _slmTaskResult?['title'] as String? ?? '';
    final priority = (_slmTaskResult?['priority'] as String?)?.toLowerCase() ?? 'medium';
    final dueDate = _slmTaskResult?['dueDate'] as String?;

    final priorityColor = priority == 'high'
        ? AppTokens.error(context)
        : (priority == 'low' ? AppTokens.success(context) : AppTokens.warning(context));

    final priorityLabel = priority == 'high'
        ? 'Tinggi (High)'
        : (priority == 'low' ? 'Rendah (Low)' : 'Sedang (Medium)');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ekstrak Daftar Tugas',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTokens.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: HubSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTokens.primary(context).withValues(alpha: 0.15),
                  borderRadius: HubRadius.rPill,
                ),
                child: Text(
                  'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Menganalisis isi catatan secara cerdas untuk menemukan butir tugas, tingkat prioritas, dan tenggat waktu.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: HubSpacing.sm),

          if (_slmTaskResult == null && !_isSlmTaskLoading) ...[
            FilledButton.icon(
              onPressed: _runTaskExtraction,
              icon: const Icon(LucideIcons.listPlus, size: 16),
              label: const Text('Ekstrak Tugas'),
            ),
          ],

          if (_isSlmTaskLoading) ...[
            const SizedBox(height: HubSpacing.md),
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: HubSpacing.sm),
                Expanded(
                  child: Text(
                    'Mengekstrak daftar tugas secara offline...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTokens.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_slmTaskError != null) ...[
            const SizedBox(height: HubSpacing.md),
            HubCard(
              backgroundColor: AppTokens.error(context).withValues(alpha: 0.1),
              borderColor: AppTokens.error(context).withValues(alpha: 0.3),
              padding: const EdgeInsets.all(HubSpacing.sm),
              child: Row(
                children: [
                  Icon(LucideIcons.circleAlert, size: 18, color: AppTokens.error(context)),
                  const SizedBox(width: HubSpacing.sm),
                  Expanded(
                    child: Text(
                      _slmTaskError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTokens.error(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_slmTaskResult != null) ...[
            const SizedBox(height: HubSpacing.md),
            HubCard(
              padding: const EdgeInsets.all(HubSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tugas Terdeteksi',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: HubSpacing.sm),
                  Text(
                    title.isNotEmpty ? title : '(Tidak ada judul spesifik)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: HubSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        avatar: Icon(LucideIcons.flag, size: 14, color: priorityColor),
                        label: Text(priorityLabel),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (dueDate?.isNotEmpty == true)
                        Chip(
                          avatar: const Icon(LucideIcons.calendar, size: 14),
                          label: Text('Tenggat: $dueDate'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: HubSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTokens.primary(context),
                        foregroundColor: AppTokens.onPrimary(context),
                      ),
                      onPressed: () {
                        final buffer = StringBuffer('- [ ] $title');
                        if (dueDate != null && dueDate.isNotEmpty) {
                          buffer.write(' (Tenggat: $dueDate)');
                        }
                        buffer.write(' #$priority');
                        widget.onInsertTask(buffer.toString());
                      },
                      icon: const Icon(LucideIcons.listCheck, size: 16),
                      label: const Text('Tambahkan Checklist ke Catatan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String content,
    Widget? badge,
  }) {
    final theme = Theme.of(context);
    return HubCard(
      padding: const EdgeInsets.all(HubSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTokens.textPrimary(context),
                  ),
                ),
              ),
              ?badge,
            ],
          ),
          const SizedBox(height: HubSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTokens.textPrimary(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: HubSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    side: BorderSide(color: AppTokens.border(context)),
                  ),
                  onPressed: () => widget.onAppend(content),
                  child: const Text(
                    'Sisipkan di bawah',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: HubSpacing.sm),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    backgroundColor: AppTokens.primary(context),
                    foregroundColor: AppTokens.onPrimary(context),
                  ),
                  onPressed: () => widget.onReplace(content),
                  child: const Text(
                    'Terapkan',
                    textAlign: TextAlign.center,
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

class _AiModelBadge extends StatelessWidget {
  const _AiModelBadge({required this.didFallback, required this.usedModel});

  final bool didFallback;
  final String usedModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = didFallback
        ? AppTokens.warning(context).withValues(alpha: 0.15)
        : AppTokens.success(context).withValues(alpha: 0.15);
    final fgColor = didFallback
        ? AppTokens.warning(context)
        : AppTokens.success(context);
    final label = didFallback ? 'Fallback' : 'Free';

    return Tooltip(
      message: usedModel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: HubRadius.rPill,
          border: Border.all(color: fgColor.withValues(alpha: 0.3)),
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
