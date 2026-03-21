import 'dart:html' as html;
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/attendance/calendar_event_attendance.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/calendar_event.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:tmail_ui_user/features/email/domain/utils/calendar_event_capability_helper.dart';

class CalendarEventCapabilityRegistry {
  static CalendarEventCapabilityRegistry? _instance;
  static CalendarEventCapabilityRegistry get instance =>
      _instance ??= CalendarEventCapabilityRegistry._();

  CalendarEventCapabilityRegistry._();

  static const _storagePrefix = 'tmail_rsvp_';

  bool _isJames = false;
  bool _isIetf = false;
  String? _userEmail;
  MailboxId? _sentMailboxId;
  final Map<Id, CalendarEvent> _parsedEvents = {};

  void configure(Session session, AccountId accountId) {
    _isJames = CalendarEventCapabilityHelper.isJamesSupported(session, accountId);
    _isIetf = CalendarEventCapabilityHelper.isIetfSupported(session, accountId);
  }

  void setUserEmail(String email) => _userEmail = email;
  String? get userEmail => _userEmail;

  void setSentMailboxId(MailboxId? id) => _sentMailboxId = id;
  MailboxId? get sentMailboxId => _sentMailboxId;

  String? _identityId;
  void setIdentityId(String? id) => _identityId = id;
  String? get identityId => _identityId;

  String _languageCode = 'en';
  void setLanguageCode(String code) => _languageCode = code;
  String get languageCode => _languageCode;

  void cacheEvent(Id blobId, CalendarEvent event) => _parsedEvents[blobId] = event;
  CalendarEvent? getEvent(Id blobId) => _parsedEvents[blobId];

  /// Store the user's RSVP response for a given event UID.
  /// Persisted to localStorage so it survives page reloads.
  void setAttendanceStatus(String eventUid, AttendanceStatus status) {
    try {
      html.window.localStorage['$_storagePrefix$eventUid'] = status.name;
    } catch (_) {}
  }

  /// Retrieve the persisted attendance status for a given event UID.
  AttendanceStatus? getAttendanceStatus(String eventUid) {
    try {
      final stored = html.window.localStorage['$_storagePrefix$eventUid'];
      if (stored == null) return null;
      return AttendanceStatus.values.where((s) => s.name == stored).firstOrNull;
    } catch (_) {
      return null;
    }
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
