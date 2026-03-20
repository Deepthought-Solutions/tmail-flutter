import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:tmail_ui_user/features/email/domain/utils/calendar_event_capability_helper.dart';

class CalendarEventCapabilityRegistry {
  static CalendarEventCapabilityRegistry? _instance;
  static CalendarEventCapabilityRegistry get instance =>
      _instance ??= CalendarEventCapabilityRegistry._();

  CalendarEventCapabilityRegistry._();

  bool _isJames = false;
  bool _isIetf = false;

  void configure(Session session, AccountId accountId) {
    _isJames = CalendarEventCapabilityHelper.isJamesSupported(session, accountId);
    _isIetf = CalendarEventCapabilityHelper.isIetfSupported(session, accountId);
  }

  bool get isJames => _isJames;
  bool get isIetf => _isIetf && !_isJames;
  bool get supportsAttendance => _isJames;
  bool get supportsJmapReply => _isJames;

  Set<CapabilityIdentifier> get parseCapabilities {
    if (_isJames) {
      return {CapabilityIdentifier.jmapCore, CapabilityIdentifier.jamesCalendarEvent};
    }
    return {CapabilityIdentifier.jmapCore, CalendarEventCapabilityHelper.ietfCalendarsParse};
  }

  Set<CapabilityIdentifier> get replyCapabilities {
    if (_isJames) {
      return {CapabilityIdentifier.jmapCore, CapabilityIdentifier.jamesCalendarEvent};
    }
    return {CapabilityIdentifier.jmapCore, CalendarEventCapabilityHelper.ietfCalendars};
  }
}
