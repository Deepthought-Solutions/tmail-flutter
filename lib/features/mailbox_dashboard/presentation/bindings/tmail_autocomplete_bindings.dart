
import 'package:core/utils/app_logger.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/base/interactors_bindings.dart';
import 'package:tmail_ui_user/features/contact/data/datasource/auto_complete_datasource.dart';
import 'package:tmail_ui_user/features/composer/data/repository/auto_complete_repository_impl.dart';
import 'package:tmail_ui_user/features/composer/domain/repository/auto_complete_repository.dart';
import 'package:tmail_ui_user/features/composer/domain/usecases/get_autocomplete_interactor.dart';
import 'package:tmail_ui_user/features/composer/domain/usecases/get_all_autocomplete_interactor.dart';
import 'package:tmail_ui_user/features/composer/domain/usecases/get_device_contact_suggestions_interactor.dart';
import 'package:tmail_ui_user/features/contact/data/datasource_impl/carddav_contact_datasource_impl.dart';
import 'package:tmail_ui_user/features/contact/data/datasource_impl/tmail_contact_datasource_impl.dart';
import 'package:tmail_ui_user/features/contact/data/network/carddav_api.dart';
import 'package:tmail_ui_user/features/contact/data/network/contact_api.dart';
import 'package:tmail_ui_user/main/exceptions/thrower/remote_exception_thrower.dart';

class TMailAutoCompleteBindings extends InteractorsBindings {

  @override
  void bindingsDataSourceImpl() {
    log('TMailAutoCompleteBindings::bindingsDataSourceImpl: START');
    try {
      Get.put(TMailContactDataSourceImpl(
        Get.find<ContactAPI>(),
        Get.find<RemoteExceptionThrower>(),
      ));
      log('TMailAutoCompleteBindings: TMailContactDataSourceImpl registered');
    } catch (e) {
      log('TMailAutoCompleteBindings: TMailContactDataSourceImpl FAILED: $e');
    }

    final isCardDavRegistered = Get.isRegistered<CardDavApi>();
    log('TMailAutoCompleteBindings: CardDavApi isRegistered=$isCardDavRegistered');
    if (isCardDavRegistered) {
      try {
        Get.put(CardDavContactDataSourceImpl(
          Get.find<CardDavApi>(),
        ));
        log('TMailAutoCompleteBindings: CardDavContactDataSourceImpl registered');
      } catch (e) {
        log('TMailAutoCompleteBindings: CardDavContactDataSourceImpl FAILED: $e');
      }
    } else {
      log('TMailAutoCompleteBindings: CardDavApi NOT registered, skipping CardDAV autocomplete');
    }
  }

  @override
  void bindingsInteractor() {
    Get.put(GetAutoCompleteInteractor(Get.find<AutoCompleteRepository>()));
    Get.put(GetAllAutoCompleteInteractor(
      Get.find<GetAutoCompleteInteractor>(),
      Get.find<GetDeviceContactSuggestionsInteractor>()
    ));
  }

  @override
  void bindingsRepository() {
    Get.put<AutoCompleteRepository>(Get.find<AutoCompleteRepositoryImpl>());
  }

  @override
  void bindingsRepositoryImpl() {
    final dataSources = <AutoCompleteDataSource>{};

    final hasCardDav = Get.isRegistered<CardDavContactDataSourceImpl>();

    // Only use TMailContact if CardDAV is NOT available (James-only feature)
    // When CardDAV is available, TMailContact generates useless 400 errors on Stalwart
    if (!hasCardDav && Get.isRegistered<TMailContactDataSourceImpl>()) {
      dataSources.add(Get.find<TMailContactDataSourceImpl>());
      log('TMailAutoCompleteBindings::bindingsRepositoryImpl: added TMailContactDataSourceImpl (no CardDAV)');
    }
    if (hasCardDav) {
      dataSources.add(Get.find<CardDavContactDataSourceImpl>());
      log('TMailAutoCompleteBindings::bindingsRepositoryImpl: added CardDavContactDataSourceImpl');
    }

    log('TMailAutoCompleteBindings::bindingsRepositoryImpl: ${dataSources.length} datasource(s)');
    Get.put(AutoCompleteRepositoryImpl(dataSources));
  }

  @override
  void bindingsDataSource() {}
}
