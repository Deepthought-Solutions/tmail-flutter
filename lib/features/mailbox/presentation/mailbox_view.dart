import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/utils/platform_info.dart';
import 'package:flutter/material.dart';
import 'package:tmail_ui_user/features/base/widget/application_version_widget.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/base_mailbox_view.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/widgets/calendar_button_widget.dart';
import 'package:tmail_ui_user/features/quotas/presentation/quotas_view.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';

class MailboxView extends BaseMailboxView {

  MailboxView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: InputBorder.none,
      shadowColor: AppColor.blackAlpha20,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PopScope(
              canPop: false,
              onPopInvokedWithResult: (_, __) {
                if (!PlatformInfo.isAndroid) return;
                controller.mailboxDashBoardController.closeMailboxMenuDrawer();
              },
              child: buildMailboxAppBar(),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColor.primaryColor,
                onRefresh: controller.refreshAllMailbox,
                child: buildListMailbox(context),
              ),
            ),
            if (AppConfig.calendarUrl != null)
              CalendarButtonWidget(
                imagePaths: controller.imagePaths,
                calendarUrl: AppConfig.calendarUrl!,
              ),
            const QuotasView(),
            Container(
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsetsDirectional.only(
                bottom: 16,
                start: 24,
                end: 24,
              ),
              child: ApplicationVersionWidget(
                title: '${AppLocalizations.of(context).version.toLowerCase()} ',
              ),
            ),
          ],
        ),
      ),
    );
  }
}