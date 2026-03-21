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
    log('CardDavContactDataSourceImpl::getAutoComplete: query="${autoCompletePattern.word}"');
    try {
      final dynamicUrlInterceptors = Get.find<DynamicUrlInterceptors>();
      final baseUrl = dynamicUrlInterceptors.jmapUrl;
      log('CardDavContactDataSourceImpl::getAutoComplete: jmapUrl=$baseUrl');

      final dashboardController = Get.find<MailboxDashBoardController>();
      final username = dashboardController.sessionCurrent?.username.value;
      log('CardDavContactDataSourceImpl::getAutoComplete: username=$username');

      if (baseUrl == null || username == null) {
        log('CardDavContactDataSourceImpl::getAutoComplete: baseUrl or username is null, returning empty');
        return [];
      }

      // Strip trailing /jmap to get server root
      final serverBase = baseUrl.replaceAll(RegExp(r'/jmap$'), '');

      // Stalwart uses short username in DAV paths
      final davUsername = username.contains('@') ? username.split('@')[0] : username;

      log('CardDavContactDataSourceImpl::getAutoComplete: searching CardDAV for "$davUsername"');

      // Search in both default and collected addressbooks
      final defaultResults = await _cardDavApi.searchContacts(
        baseUrl: serverBase,
        username: davUsername,
        query: autoCompletePattern.word,
        limit: autoCompletePattern.limit ?? 10,
        addressbook: 'default',
      );
      final collectedResults = await _cardDavApi.searchContacts(
        baseUrl: serverBase,
        username: davUsername,
        query: autoCompletePattern.word,
        limit: autoCompletePattern.limit ?? 10,
        addressbook: 'collected',
      ).catchError((_) => <EmailAddress>[]);

      // Merge and deduplicate
      final seen = <String>{};
      final results = <EmailAddress>[];
      for (final addr in [...defaultResults, ...collectedResults]) {
        final key = addr.email?.toLowerCase() ?? '';
        if (key.isNotEmpty && seen.add(key)) {
          results.add(addr);
        }
      }

      log('CardDavContactDataSourceImpl::getAutoComplete: found ${results.length} contacts (${defaultResults.length} default + ${collectedResults.length} collected)');

      return results;
    } catch (e, stackTrace) {
      log('CardDavContactDataSourceImpl::getAutoComplete: ERROR $e');
      log('CardDavContactDataSourceImpl::getAutoComplete: stackTrace=$stackTrace');
      return [];
    }
  }
}
