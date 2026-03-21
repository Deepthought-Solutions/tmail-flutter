
import 'package:core/utils/app_logger.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:model/autocomplete/auto_complete_pattern.dart';
import 'package:tmail_ui_user/features/composer/domain/repository/auto_complete_repository.dart';
import 'package:tmail_ui_user/features/contact/data/datasource/auto_complete_datasource.dart';

class AutoCompleteRepositoryImpl extends AutoCompleteRepository {

  final Set<AutoCompleteDataSource> autoCompleteDataSources;

  AutoCompleteRepositoryImpl(this.autoCompleteDataSources);

  @override
  Future<List<EmailAddress>> getAutoComplete(AutoCompletePattern autoCompletePattern) async {
    print('AutoCompleteRepositoryImpl::getAutoComplete: query="${autoCompletePattern.word}" '
        'datasources=${autoCompleteDataSources.length} '
        'types=${autoCompleteDataSources.map((d) => d.runtimeType).toList()}');
    if (autoCompleteDataSources.isEmpty) {
      print('AutoCompleteRepositoryImpl::getAutoComplete: NO datasources available');
      return [];
    }
    // Query all data sources in parallel, catch individual errors
    // so one failing source doesn't block the others
    final results = await Future.wait(
      autoCompleteDataSources.map((datasource) =>
        datasource.getAutoComplete(autoCompletePattern).catchError((error) {
          print('AutoCompleteRepositoryImpl::getAutoComplete: '
              '${datasource.runtimeType} failed: $error');
          return <EmailAddress>[];
        })
      ),
    );

    final listEmailAddress = <EmailAddress>[];
    for (final list in results) {
      listEmailAddress.addAll(list);
    }

    // Deduplicate by email address
    final seen = <String>{};
    listEmailAddress.retainWhere((addr) {
      final email = addr.email?.toLowerCase() ?? '';
      if (email.isEmpty || seen.contains(email)) return false;
      seen.add(email);
      return true;
    });

    return listEmailAddress;
  }
}
