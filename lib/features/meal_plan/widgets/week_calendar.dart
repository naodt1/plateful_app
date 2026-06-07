import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';

class WeekCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime weekStart;
  final void Function(DateTime) onDaySelected;

  const WeekCalendar({
    super.key,
    required this.selectedDate,
    required this.weekStart,
    required this.onDaySelected,
  });

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7,
        itemBuilder: (context, index) {
          final day = weekStart.add(Duration(days: index));
          final isSelected = _isSameDay(day, selectedDate);
          final isToday = _isSameDay(day, DateTime.now());

          return GestureDetector(
            onTap: () => onDaySelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isToday && !isSelected
                      ? AppColors.primary
                      : colors.border,
                  width: isToday && !isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(day).substring(0, 1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white70 : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? AppColors.primary
                              : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
