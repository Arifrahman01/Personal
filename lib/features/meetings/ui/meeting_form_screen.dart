import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
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

  String _reminderLabel(int minutes) {
    if (minutes == 0) return 'Tanpa pengingat';
    if (minutes == 60) return '1 jam sebelum';
    return '$minutes menit sebelum';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassScaffold(
      appBar: GlassAppBar(
        title: Text(_isEditing ? 'Edit Meeting' : 'Meeting Baru'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Judul Meeting *',
                  hintText: 'Contoh: Sinkronisasi Mingguan Tim',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Judul meeting tidak boleh kosong.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Jadwal',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatMeetingDateTime(_scheduledAt),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: const Text('Pilih Tanggal'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTime,
                              icon: const Icon(Icons.access_time_rounded),
                              label: const Text('Pilih Jam'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Lokasi / Tautan',
                  hintText: 'Contoh: Ruang Anggrek atau Google Meet',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _attendeesController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Peserta',
                  hintText: 'Pisahkan dengan koma, misal: Budi, Sari, Andi',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _reminderMinutes,
                decoration: const InputDecoration(labelText: 'Pengingat'),
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
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Catatan / Notulensi',
                  hintText: 'Tulis poin diskusi dan keputusan rapat...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isEditing ? 'Simpan Perubahan' : 'Simpan Meeting'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
