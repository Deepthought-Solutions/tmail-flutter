
import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:core/presentation/views/button/tmail_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tmail_ui_user/main/utils/app_utils.dart';

class CalendarButtonWidget extends StatelessWidget {

  final ImagePaths imagePaths;
  final String calendarUrl;

  const CalendarButtonWidget({
    super.key,
    required this.imagePaths,
    required this.calendarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        top: 0,
        bottom: 8,
      ),
      width: ResponsiveUtils.defaultSizeMenu,
      alignment: Alignment.centerLeft,
      child: TMailButtonWidget(
        key: const Key('calendar_button'),
        text: 'Calendrier',
        icon: imagePaths.icCalendar,
        borderRadius: 10,
        iconSize: 24,
        height: 44,
        iconColor: AppColor.blue700,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
        backgroundColor: Colors.white,
        border: Border.all(color: AppColor.blue700, width: 1.5),
        textStyle: ThemeUtils.textStyleBodyBody2(color: AppColor.blue700),
        onTapActionCallback: _onTap,
      ),
    );
  }

  void _onTap() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final separator = calendarUrl.contains('?') ? '&' : '?';
    final fullUrl = '$calendarUrl${separator}date=$today&view=timeGridWeek';
    AppUtils.launchLink(fullUrl);
  }
}
