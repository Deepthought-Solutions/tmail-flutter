import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:tmail_ui_user/main/error/capability_validator.dart';

class CalendarEventCapabilityHelper {
  static final ietfCalendarsParse = CapabilityIdentifier(
    Uri.parse('urn:ietf:params:jmap:calendars:parse'),
  );

  static final ietfCalendars = CapabilityIdentifier(
    Uri.parse('urn:ietf:params:jmap:calendars'),
  );

  static bool isParseSupported(Session session, AccountId accountId) {
    return CapabilityIdentifier.jamesCalendarEvent.isSupported(session, accountId) ||
        ietfCalendarsParse.isSupported(session, accountId);
  }

  static bool isJamesSupported(Session session, AccountId accountId) {
    return CapabilityIdentifier.jamesCalendarEvent.isSupported(session, accountId);
  }

  static bool isIetfSupported(Session session, AccountId accountId) {
    return ietfCalendarsParse.isSupported(session, accountId);
  }

  static Set<CapabilityIdentifier> getParseCapabilities(Session session, AccountId accountId) {
    if (CapabilityIdentifier.jamesCalendarEvent.isSupported(session, accountId)) {
      return {CapabilityIdentifier.jmapCore, CapabilityIdentifier.jamesCalendarEvent};
    }
    return {CapabilityIdentifier.jmapCore, ietfCalendarsParse};
  }

  static Set<CapabilityIdentifier> getReplyCapabilities(Session session, AccountId accountId) {
    if (CapabilityIdentifier.jamesCalendarEvent.isSupported(session, accountId)) {
      return {CapabilityIdentifier.jmapCore, CapabilityIdentifier.jamesCalendarEvent};
    }
    return {CapabilityIdentifier.jmapCore, ietfCalendars};
  }
}
