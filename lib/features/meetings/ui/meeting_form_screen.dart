import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/ui/meetings_screen.dart';

/// Create or edit form screen for a [Meeting].
class MeetingFormScreen extends ConsumerStatefulWidget {
  const MeetingFormScreen({super.key, this.initialMeeting});

  final Meeting? initialMeeting;

  @override
  ConsumerState<MeetingFormScreen> createState() => _MeetingFormScreenState();
}

class _MeetingFormScreenState extends ConsumerState<MeetingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _attendeesController;
  late final TextEditingController _agendaController;
  late final TextEditingController _notesController;

  late DateTime _scheduledAt;
  late int _reminderMinutes;
  bool _isSaving = false;

  static const List<int> _reminderOptions = [0, 5, 15, 30, 60];

  bool get _isEditing => widget.initialMeeting != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMeeting;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _locationController = TextEditingController(text: initial?.location ?? '');
    _attendeesController = TextEditingController(
      text: initial?.attendees.join(', ') ?? '',
    );
    _agendaController = TextEditingController(text: initial?.agenda ?? '');
    _notesController = TextEditingController(text: initial?.notes ?? '');

    final defaultDate = DateTime.now().add(const Duration(hours: 1));
    _scheduledAt =
        initial?.scheduledAt.toLocal() ??
        DateTime(
          defaultDate.year,
          defaultDate.month,
          defaultDate.day,
          defaultDate.hour,
          0,
        );
    _reminderMinutes = initial?.reminderMinutes ?? 15;
    if (!_reminderOptions.contains(_reminderMinutes)) {
      _reminderMinutes = 15;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _attendeesController.dispose();
    _agendaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _scheduledAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (picked == null) return;
    setState(() {
      _scheduledAt = DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final attendees = _attendeesController.text
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    try {
      final notifier = ref.read(meetingsListProvider.notifier);
      if (_isEditing) {
        await notifier.updateMeeting(
          widget.initialMeeting!.copyWith(
            title: _titleController.text,
            scheduledAt: _scheduledAt,
            location: _locationController.text,
            attendees: attendees,
            agenda: _agendaController.text,
            notes: _notesController.text,
            reminderMinutes: _reminderMinutes,
          ),
        );
      } else {
        await notifier.createMeeting(
          title: _titleController.text,
          scheduledAt: _scheduledAt,
          location: _locationController.text,
          attendees: attendees,
          agenda: _agendaController.text,
          notes: _notesController.text,
          reminderMinutes: _reminderMinutes,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _setScheduledDate(DateTime targetDate) {
    setState(() {
      _scheduledAt = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _reminderLabel(int minutes) {
    if (minutes == 0) return 'Tanpa pengingat';
    if (minutes == 60) return '1 jam sebelum';
    return '$minutes menit sebelum';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final isToday = _isSameDay(_scheduledAt, today);
    final isTomorrow = _isSameDay(_scheduledAt, tomorrow);

    return HubScaffold(
      appBar: HubAppBar(
        title: Text(_isEditing ? 'Edit Meeting' : 'Meeting Baru'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Judul Meeting
            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Judul Meeting *',
                hintText: 'Contoh: Sinkronisasi Mingguan Tim',
                prefixIcon: Icon(LucideIcons.calendar),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Judul meeting tidak boleh kosong.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 2. Tanggal & Jam (Tactile M3 dengan Chip Cepat Hari Ini / Besok)
            Text(
              'Jadwal & Waktu',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTokens.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            HubCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          formatMeetingDateTime(_scheduledAt),
                          style: HubTypography.tabular(
                            theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ) ??
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        // Quick chips Hari Ini / Besok
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            HubPill(
                              label: 'Hari Ini',
                              isSelected: isToday,
                              onTap: () => _setScheduledDate(today),
                            ),
                            HubPill(
                              label: 'Besok',
                              isSelected: isTomorrow,
                              onTap: () => _setScheduledDate(tomorrow),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(LucideIcons.calendar, size: 16),
                          label: const Text(
                            'Pilih Tanggal',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(LucideIcons.clock, size: 16),
                          label: const Text(
                            'Pilih Jam',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
              const SizedBox(height: 16),

              // 3. Lokasi / Tautan
              TextFormField(
                controller: _locationController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Lokasi / Tautan',
                  hintText: 'Contoh: Ruang Anggrek atau Google Meet',
                  prefixIcon: Icon(LucideIcons.mapPin),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Detail Tambahan Lipat
              HubCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: _isEditing ||
                        _attendeesController.text.isNotEmpty ||
                        _agendaController.text.isNotEmpty ||
                        _notesController.text.isNotEmpty,
                    leading: Icon(LucideIcons.slidersHorizontal, color: AppTokens.primary(context)),
                    title: Text(
                      'Detail Tambahan',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Peserta, Pengingat, Agenda, & Catatan',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTokens.textSecondary(context),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _attendeesController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Peserta',
                                hintText: 'Pisahkan dengan koma, misal: Budi, Sari, Andi',
                                prefixIcon: Icon(LucideIcons.users),
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              initialValue: _reminderMinutes,
                              decoration: const InputDecoration(
                                labelText: 'Pengingat',
                                prefixIcon: Icon(LucideIcons.bell),
                              ),
                              items: [
                                for (final minutes in _reminderOptions)
                                  DropdownMenuItem<int>(
                                    value: minutes,
                                    child: Text(_reminderLabel(minutes)),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _reminderMinutes = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _agendaController,
                              minLines: 2,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Agenda',
                                hintText: 'Topik utama yang akan dibahas...',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notesController,
                              minLines: 3,
                              maxLines: 8,
                              decoration: const InputDecoration(
                                labelText: 'Catatan / Notulensi',
                                hintText: 'Tulis poin diskusi dan keputusan rapat...',
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 5. Tombol Simpan
              FilledButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.primary(context),
                  foregroundColor: AppTokens.onPrimary(context),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.save),
                label: Text(_isEditing ? 'Simpan Perubahan' : 'Simpan Meeting'),
              ),
            ],
          ),
        ),
    );
  }
}
