import 'package:core/utils/app_logger.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:model/autocomplete/auto_complete_pattern.dart';
import 'package:tmail_ui_user/features/contact/data/datasource/auto_complete_datasource.dart';
import 'package:tmail_ui_user/features/contact/data/network/carddav_api.dart';
import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';

/// Autocomplete data source that queries CardDAV contacts from Stalwart.
class CardDavContactDataSourceImpl extends AutoCompleteDataSource {
  final CardDavApi _cardDavApi;

  CardDavContactDataSourceImpl(this._cardDavApi);

  @override
  Future<List<EmailAddress>> getAutoComplete(AutoCompletePattern autoCompletePattern) async {
    try {
      final dynamicUrlInterceptors = Get.find<DynamicUrlInterceptors>();
      final baseUrl = dynamicUrlInterceptors.jmapUrl;
      final dashboardController = Get.find<MailboxDashBoardController>();
      final username = dashboardController.sessionCurrent?.username.value;

      if (baseUrl == null || username == null) {
        log('CardDavContactDataSourceImpl::getAutoComplete: baseUrl or username is null');
        return [];
      }

      // Strip trailing /jmap to get server root
      final serverBase = baseUrl.replaceAll(RegExp(r'/jmap$'), '');

      // Stalwart uses short username in DAV paths
      final davUsername = username.contains('@') ? username.split('@')[0] : username;

      final results = await _cardDavApi.searchContacts(
        baseUrl: serverBase,
        username: davUsername,
        query: autoCompletePattern.word,
        limit: autoCompletePattern.limit ?? 10,
      );

      log('CardDavContactDataSourceImpl::getAutoComplete: '
          'found ${results.length} CardDAV contacts for "${autoCompletePattern.word}"');

      return results;
    } catch (e) {
      log('CardDavContactDataSourceImpl::getAutoComplete: error $e');
      return [];
    }
  }
}
