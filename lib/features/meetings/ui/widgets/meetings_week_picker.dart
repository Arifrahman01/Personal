import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';

/// Horizontal weekly date picker strip with capsule date pills.
class MeetingsWeekPicker extends StatelessWidget {
  const MeetingsWeekPicker({
    super.key,
    required this.startMonday,
    required this.selectedDate,
    required this.allMeetings,
    required this.onSelectDate,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onResetToThisWeek,
  });

  final DateTime startMonday;
  final DateTime? selectedDate;
  final List<Meeting> allMeetings;
  final ValueChanged<DateTime?> onSelectDate;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onResetToThisWeek;

  static const List<String> _dayNames = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  static const List<String> _monthNames = [
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasMeetingsOnDate(DateTime date) {
    return allMeetings.any((m) {
      final loc = m.scheduledAt.toLocal();
      return loc.year == date.year &&
          loc.month == date.month &&
          loc.day == date.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubColors.of(context);
    final now = DateTime.now();

    final weekDays = List.generate(
      7,
      (i) => startMonday.add(Duration(days: i)),
    );
    final endSunday = weekDays.last;

    final isCurrentWeek =
        now.isAfter(startMonday.subtract(const Duration(seconds: 1))) &&
        now.isBefore(endSunday.add(const Duration(days: 1)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${startMonday.day} ${_monthNames[startMonday.month - 1]} - ${endSunday.day} ${_monthNames[endSunday.month - 1]} ${endSunday.year}',
                  style: HubTypography.tabular(
                    theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: colors.textPrimary,
                        ) ??
                        const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isCurrentWeek) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onResetToThisWeek,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.40),
                      ),
                    ),
                    child: Text(
                      'Pekan Ini',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                tooltip: 'Pekan Sebelumnya',
                onPressed: onPreviousWeek,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.chevron_right_rounded, size: 24),
                tooltip: 'Pekan Berikutnya',
                onPressed: onNextWeek,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _AllPill(
                  isSelected: selectedDate == null,
                  onTap: () => onSelectDate(null),
                ),
                const SizedBox(width: 8),
                for (var i = 0; i < weekDays.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _DayPill(
                    dayName: _dayNames[i],
                    date: weekDays[i],
                    isSelected:
                        selectedDate != null &&
                        _isSameDay(selectedDate!, weekDays[i]),
                    isToday: _isSameDay(now, weekDays[i]),
                    hasMeetings: _hasMeetingsOnDate(weekDays[i]),
                    onTap: () => onSelectDate(weekDays[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllPill extends StatelessWidget {
  const _AllPill({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = HubColors.of(context);
    final fgColor = isSelected ? colorScheme.onPrimary : colors.textSecondary;

    return InkWell(
      key: const Key('all_days_pill'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minWidth: 58, minHeight: 74),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: isSelected ? colorScheme.primary : colors.surfaceCard,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colors.borderHairline,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_view_week_rounded,
              size: 18,
              color: fgColor,
            ),
            const SizedBox(height: 4),
            Text(
              'Semua',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: fgColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.dayName,
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.hasMeetings,
    required this.onTap,
  });

  final String dayName;
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool hasMeetings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = HubColors.of(context);

    final dayLabelColor = isSelected
        ? colorScheme.onPrimary.withValues(alpha: 0.90)
        : colors.textSecondary;
    final dateNumColor = isSelected
        ? colorScheme.onPrimary
        : (isToday ? colors.primary : colors.textPrimary);
    final dotColor = hasMeetings
        ? (isSelected ? colorScheme.onPrimary : colors.primary)
        : Colors.transparent;

    return InkWell(
      key: Key('day_pill_${date.day}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minWidth: 52, minHeight: 74),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: isSelected
              ? colorScheme.primary
              : (isToday ? colors.primarySoft : colors.surfaceCard),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : (isToday ? colors.primary : colors.borderHairline),
            width: isSelected || isToday ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: dayLabelColor,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              maxLines: 1,
              style: HubTypography.tabular(
                theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isSelected || isToday
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: dateNumColor,
                      fontSize: 16,
                    ) ??
                    const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
