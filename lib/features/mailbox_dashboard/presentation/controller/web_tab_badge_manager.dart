import 'package:core/utils/platform_info.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:universal_html/html.dart' as html;

class WebTabBadgeManager {
  static const String _defaultTitle = 'Twake Mail';

  static void updateBadge(Map<MailboxId, PresentationMailbox> mapMailboxById) {
    if (!PlatformInfo.isWeb) return;

    final inboxUnread = _getInboxUnreadCount(mapMailboxById);
    _updateDocumentTitle(inboxUnread);
    _updateFavicon(inboxUnread);
  }

  static int _getInboxUnreadCount(
    Map<MailboxId, PresentationMailbox> mapMailboxById,
  ) {
    for (final mailbox in mapMailboxById.values) {
      if (mailbox.role == PresentationMailbox.roleInbox) {
        return mailbox.unreadEmails?.value.value.toInt() ?? 0;
      }
    }
    return 0;
  }

  static void _updateDocumentTitle(int unreadCount) {
    if (unreadCount > 0) {
      final display = unreadCount > 999 ? '999+' : '$unreadCount';
      html.document.title = '($display) $_defaultTitle';
    } else {
      html.document.title = _defaultTitle;
    }
  }

  static void _updateFavicon(int unreadCount) {
    final linkElement = html.document.querySelector('link[rel="icon"]');
    if (linkElement == null) return;

    if (unreadCount <= 0) {
      linkElement.setAttribute('href', 'favicon.svg');
      return;
    }

    final display = unreadCount > 99 ? '99+' : '$unreadCount';
    final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <image href="favicon.svg" width="32" height="32"/>
  <circle cx="24" cy="8" r="8" fill="#E53935"/>
  <text x="24" y="11" text-anchor="middle" font-size="${display.length > 2 ? 7 : 9}" font-family="Arial,sans-serif" font-weight="bold" fill="white">$display</text>
</svg>''';
    final encoded = Uri.encodeFull(svg);
    linkElement.setAttribute('href', 'data:image/svg+xml,$encoded');
  }
}
