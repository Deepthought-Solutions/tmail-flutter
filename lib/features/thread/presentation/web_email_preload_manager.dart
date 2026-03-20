import 'package:core/presentation/utils/html_transformer/transform_configuration.dart';
import 'package:core/utils/app_logger.dart';
import 'package:core/utils/platform_info.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:model/model.dart';
import 'package:tmail_ui_user/features/email/domain/repository/email_repository.dart';
import 'package:tmail_ui_user/features/email/presentation/model/email_loaded.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';

class WebEmailPreloadManager {
  static const int _maxPreloadCount = 10;
  static const Duration _throttleDelay = Duration(milliseconds: 300);
  static bool _isPreloading = false;

  static Future<void> preloadUnreadEmails({
    required Session session,
    required AccountId accountId,
    required List<PresentationEmail> emails,
  }) async {
    if (!PlatformInfo.isWeb || _isPreloading) return;

    final cutoff = DateTime.now().subtract(const Duration(hours: 48));
    final unreadRecent = emails.where((email) {
      if (email.hasRead) return false;
      if (email.id == null) return false;
      final receivedAt = email.receivedAt?.value;
      return receivedAt != null && receivedAt.isAfter(cutoff);
    }).take(_maxPreloadCount).toList();

    if (unreadRecent.isEmpty) return;

    _isPreloading = true;
    try {
      final dashboardController = Get.find<MailboxDashBoardController>();
      final emailRepository = Get.find<EmailRepository>();
      final baseDownloadUrl = session.getDownloadUrl(
        jmapUrl: dashboardController.dynamicUrlInterceptors.jmapUrl,
      );

      for (final presentationEmail in unreadRecent) {
        final emailId = presentationEmail.id!;
        if (dashboardController.preloadedEmailContent.containsKey(emailId)) {
          continue;
        }

        try {
          final email = await emailRepository.getEmailContent(
            session,
            accountId,
            emailId,
          );
          final listAttachments = email.allAttachments
              .getListAttachmentsDisplayedOutside(email.htmlBodyAttachments);
          final listInlineImages =
              email.allAttachments.listAttachmentsDisplayedInContent;

          String htmlContent = '';
          if (email.emailContentList.isNotEmpty) {
            final mapCidImageDownloadUrl =
                listInlineImages.toMapCidImageDownloadUrl(
              accountId: accountId,
              downloadUrl: baseDownloadUrl,
            );
            final newEmailContents =
                await emailRepository.transformEmailContent(
              email.emailContentList,
              mapCidImageDownloadUrl,
              TransformConfiguration.forPreviewEmailOnWeb(),
            );
            htmlContent = newEmailContents.asHtmlString;
          }

          dashboardController.preloadedEmailContent[emailId] = EmailLoaded(
            htmlContent: htmlContent,
            attachments: listAttachments,
            inlineImages: listInlineImages,
            emailCurrent: email,
          );

          log('WebEmailPreloadManager::preloadUnreadEmails: preloaded ${emailId.asString}');
        } catch (e) {
          log('WebEmailPreloadManager::preloadUnreadEmails: failed for ${emailId.asString}: $e');
        }

        await Future.delayed(_throttleDelay);
      }
    } catch (e) {
      log('WebEmailPreloadManager::preloadUnreadEmails: error: $e');
    } finally {
      _isPreloading = false;
    }
  }
}
