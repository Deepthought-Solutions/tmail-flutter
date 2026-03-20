import 'package:core/presentation/utils/theme_utils.dart';
import 'package:date_format/date_format.dart' as date_format;
import 'package:flutter/material.dart';
import 'package:tmail_ui_user/features/email/domain/model/caldav_conflict.dart';
import 'package:tmail_ui_user/features/email/presentation/styles/calendar_event_conflict_styles.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:tmail_ui_user/main/utils/app_utils.dart';

class CalendarEventConflictWidget extends StatelessWidget {
  final List<CalDavConflict> conflicts;

  const CalendarEventConflictWidget({
    super.key,
    required this.conflicts,
  });

  @override
  Widget build(BuildContext context) {
    if (conflicts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsetsDirectional.symmetric(
        vertical: CalendarEventConflictStyles.verticalMargin,
        horizontal: CalendarEventConflictStyles.horizontalMargin,
      ),
      padding: const EdgeInsets.all(CalendarEventConflictStyles.padding),
      decoration: BoxDecoration(
        color: CalendarEventConflictStyles.warningBackgroundColor,
        border: Border.all(
          color: CalendarEventConflictStyles.warningBorderColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(
          CalendarEventConflictStyles.borderRadius,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: CalendarEventConflictStyles.iconSize,
                color: CalendarEventConflictStyles.warningIconColor,
              ),
              const SizedBox(
                width: CalendarEventConflictStyles.spaceBetweenIconAndText,
              ),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).calendarConflictWarning(
                    conflicts.length,
                  ),
                  style: ThemeUtils.defaultTextStyleInterFont.copyWith(
                    fontSize: CalendarEventConflictStyles.titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: CalendarEventConflictStyles.warningTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CalendarEventConflictStyles.spaceBetweenItems),
          ...conflicts.map((conflict) => Padding(
                padding: const EdgeInsets.only(
                  top: CalendarEventConflictStyles.spaceBetweenItems,
                  left: CalendarEventConflictStyles.iconSize +
                      CalendarEventConflictStyles.spaceBetweenIconAndText,
                ),
                child: Text(
                  _formatConflictItem(conflict),
                  style: ThemeUtils.defaultTextStyleInterFont.copyWith(
                    fontSize: CalendarEventConflictStyles.itemFontSize,
                    fontWeight: FontWeight.w400,
                    color: CalendarEventConflictStyles.conflictItemTextColor,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  String _formatConflictItem(CalDavConflict conflict) {
    final locale = AppUtils.getCurrentDateLocale();
    final startTime = date_format.formatDate(
      conflict.start.toLocal(),
      [date_format.hh, ':', date_format.nn, ' ', date_format.am],
      locale: locale,
    );
    final endTime = date_format.formatDate(
      conflict.end.toLocal(),
      [date_format.hh, ':', date_format.nn, ' ', date_format.am],
      locale: locale,
    );
    return '${conflict.title} ($startTime - $endTime)';
  }
}
