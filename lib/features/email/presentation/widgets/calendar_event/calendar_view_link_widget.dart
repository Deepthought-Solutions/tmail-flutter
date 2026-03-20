import 'package:core/presentation/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:tmail_ui_user/features/email/presentation/styles/calendar_event_conflict_styles.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:tmail_ui_user/main/utils/app_utils.dart';

class CalendarViewLinkWidget extends StatelessWidget {
  final String calendarUrl;
  final DateTime? eventDate;

  const CalendarViewLinkWidget({
    super.key,
    required this.calendarUrl,
    this.eventDate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: 8,
        start: CalendarEventConflictStyles.horizontalMargin,
        end: CalendarEventConflictStyles.horizontalMargin,
        bottom: 4,
      ),
      child: InkWell(
        onTap: () => _openCalendar(),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today,
                size: 16,
                color: CalendarEventConflictStyles.viewInCalendarColor,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).viewInCalendar,
                style: ThemeUtils.defaultTextStyleInterFont.copyWith(
                  fontSize: CalendarEventConflictStyles.viewInCalendarFontSize,
                  fontWeight: FontWeight.w500,
                  color: CalendarEventConflictStyles.viewInCalendarColor,
                  decoration: TextDecoration.underline,
                  decorationColor: CalendarEventConflictStyles.viewInCalendarColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCalendar() {
    String url = calendarUrl;
    if (eventDate != null) {
      final dateStr =
          '${eventDate!.year}-${eventDate!.month.toString().padLeft(2, '0')}-${eventDate!.day.toString().padLeft(2, '0')}';
      final separator = url.contains('?') ? '&' : '?';
      url = '$url${separator}date=$dateStr&view=timeGridDay';
    }
    AppUtils.launchLink(url);
  }
}
