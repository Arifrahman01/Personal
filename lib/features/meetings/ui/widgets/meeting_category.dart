import 'package:flutter/material.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';

/// Categories for meetings providing color-coded visual differentiation
/// with adaptive Light and Dark mode contrast.
enum MeetingCategory {
  healthPersonal(
    label: 'Personal & Sehat',
    stripeColor: Color(0xFFFB7185),
    icon: Icons.favorite_rounded,
  ),
  clientWork(
    label: 'Client Call',
    stripeColor: Color(0xFF38BDF8),
    icon: Icons.headset_mic_rounded,
  ),
  teamMeeting(
    label: 'Meeting Tim',
    stripeColor: Color(0xFFA78BFA),
    icon: Icons.groups_rounded,
  ),
  designReview(
    label: 'Review Desain',
    stripeColor: Color(0xFFA78BFA),
    icon: Icons.palette_rounded,
  ),
  research(
    label: 'Riset & Diskusi',
    stripeColor: Color(0xFFA78BFA),
    icon: Icons.lightbulb_rounded,
  ),
  general(
    label: 'Agenda Rapat',
    stripeColor: Color(0xFF38BDF8),
    icon: Icons.calendar_month_rounded,
  );

  const MeetingCategory({
    required this.label,
    required this.stripeColor,
    required this.icon,
  });

  final String label;
  final Color stripeColor;
  final IconData icon;

  /// Alias for backward compatibility with existing tests and theme helpers.
  Color get color => stripeColor;

  /// Resolves a WCAG AA/AAA compliant accent color for both Light and Dark modes.
  Color accentColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (this) {
      MeetingCategory.healthPersonal =>
        isDark ? const Color(0xFFFB7185) : const Color(0xFFBE123C),
      MeetingCategory.clientWork || MeetingCategory.general =>
        isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
      MeetingCategory.teamMeeting ||
      MeetingCategory.designReview ||
      MeetingCategory.research =>
        isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
    };
  }

  /// Detects category based on meeting keywords in title, agenda, and notes.
  static MeetingCategory detect(Meeting meeting) {
    final text =
        '${meeting.title} ${meeting.agenda} ${meeting.notes}'.toLowerCase();

    if (text.contains('sehat') ||
        text.contains('kesehatan') ||
        text.contains('health') ||
        text.contains('personal') ||
        text.contains('pribadi') ||
        text.contains('dokter') ||
        text.contains('gym') ||
        text.contains('workout') ||
        text.contains('olahraga') ||
        text.contains('medis') ||
        text.contains('klinik') ||
        text.contains('istirahat')) {
      return MeetingCategory.healthPersonal;
    }

    if (text.contains('klien') ||
        text.contains('client') ||
        text.contains('customer') ||
        text.contains('sales') ||
        text.contains('call') ||
        text.contains('demo') ||
        text.contains('pitch') ||
        text.contains('partnership') ||
        text.contains('bisnis') ||
        text.contains('business') ||
        text.contains('kerja') ||
        text.contains('work')) {
      return MeetingCategory.clientWork;
    }

    if (text.contains('desain') ||
        text.contains('design') ||
        text.contains('ui') ||
        text.contains('ux') ||
        text.contains('figma')) {
      return MeetingCategory.designReview;
    }

    if (text.contains('riset') ||
        text.contains('research') ||
        text.contains('brainstorm')) {
      return MeetingCategory.research;
    }

    if (text.contains('tim') ||
        text.contains('team') ||
        text.contains('sprint') ||
        text.contains('standup') ||
        text.contains('kickoff') ||
        text.contains('evaluasi') ||
        text.contains('koordinasi') ||
        text.contains('sync') ||
        text.contains('diskusi')) {
      return MeetingCategory.teamMeeting;
    }

    return MeetingCategory.general;
  }
}

/// Formats a UTC/local [DateTime] into a readable Indonesian local date/time string.
String formatMeetingDateTime(DateTime dateTime) {
  const weekdays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  const months = [
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

  final local = dateTime.toLocal();
  final dayName = weekdays[local.weekday - 1];
  final monthName = months[local.month - 1];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$dayName, ${local.day} $monthName ${local.year} • $hour:$minute';
}
