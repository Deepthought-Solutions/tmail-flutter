
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/properties/event_id.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/reply/calendar_event_accept_response.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/reply/calendar_event_maybe_response.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/reply/calendar_event_reject_response.dart';
import 'package:tmail_ui_user/features/email/data/datasource/calendar_event_datasource.dart';
import 'package:tmail_ui_user/features/email/data/network/calendar_event_api.dart';
import 'package:tmail_ui_user/features/email/data/network/imip_reply_sender.dart';
import 'package:tmail_ui_user/features/email/domain/utils/calendar_event_capability_registry.dart';
import 'package:tmail_ui_user/features/email/presentation/model/blob_calendar_event.dart';
import 'package:tmail_ui_user/main/exceptions/thrower/exception_thrower.dart';

class CalendarEventDataSourceImpl extends CalendarEventDataSource {

  final CalendarEventAPI _calendarEventAPI;
  final ExceptionThrower _exceptionThrower;
  final ImipReplySender? _imipReplySender;

  CalendarEventDataSourceImpl(
    this._calendarEventAPI,
    this._exceptionThrower, [
    this._imipReplySender,
  ]);

  CalendarEventCapabilityRegistry get _registry =>
      CalendarEventCapabilityRegistry.instance;

  @override
  Future<List<BlobCalendarEvent>> parse(AccountId accountId, Set<Id> blobIds) {
    return Future.sync(() async {
      return await _calendarEventAPI.parse(
        accountId,
        blobIds,
        capabilityOverride: _registry.parseCapabilities,
        supportsAttendance: _registry.supportsAttendance,
      );
    }).catchError(_exceptionThrower.throwException);
  }

  @override
  Future<CalendarEventAcceptResponse> acceptEventInvitation(
    AccountId accountId,
    Set<Id> blobIds,
    String? language) {
    if (!_registry.supportsJmapReply && _imipReplySender != null) {
      return Future.sync(() async {
        await _doImipReply(accountId, blobIds, 'ACCEPTED');
        return CalendarEventAcceptResponse(accountId, null, accepted: [EventId(blobIds.first.value)]);
      }).catchError(_exceptionThrower.throwException);
    }
    return Future.sync(() async {
      return await _calendarEventAPI.acceptEventInvitation(
        accountId, blobIds, language,
        capabilityOverride: _registry.replyCapabilities,
      );
    }).catchError(_exceptionThrower.throwException);
  }

  @override
  Future<CalendarEventMaybeResponse> maybeEventInvitation(
    AccountId accountId,
    Set<Id> blobIds,
    String? language) {
    if (!_registry.supportsJmapReply && _imipReplySender != null) {
      return Future.sync(() async {
        await _doImipReply(accountId, blobIds, 'TENTATIVE');
        return CalendarEventMaybeResponse(accountId, null, maybe: [EventId(blobIds.first.value)]);
      }).catchError(_exceptionThrower.throwException);
    }
    return Future.sync(() async {
      return await _calendarEventAPI.maybeEventInvitation(
        accountId, blobIds, language,
        capabilityOverride: _registry.replyCapabilities,
      );
    }).catchError(_exceptionThrower.throwException);
  }

  @override
  Future<CalendarEventRejectResponse> rejectEventInvitation(
    AccountId accountId,
    Set<Id> blobIds,
    String? language) {
    if (!_registry.supportsJmapReply && _imipReplySender != null) {
      return Future.sync(() async {
        await _doImipReply(accountId, blobIds, 'DECLINED');
        return CalendarEventRejectResponse(accountId, null, rejected: [EventId(blobIds.first.value)]);
      }).catchError(_exceptionThrower.throwException);
    }
    return Future.sync(() async {
      return await _calendarEventAPI.rejectEventInvitation(
        accountId, blobIds, language,
        capabilityOverride: _registry.replyCapabilities,
      );
    }).catchError(_exceptionThrower.throwException);
  }

  @override
  Future<CalendarEventAcceptResponse> acceptCounterEvent(
    AccountId accountId,
    Set<Id> blobIds,
  ) {
    return Future.sync(() async {
      return await _calendarEventAPI.acceptCounterEvent(accountId, blobIds);
    }).catchError(_exceptionThrower.throwException);
  }

  Future<void> _doImipReply(
    AccountId accountId,
    Set<Id> blobIds,
    String partstat,
  ) async {
    final blobId = blobIds.first;
    final event = _registry.getEvent(blobId);
    final userEmail = _registry.userEmail;

    if (event == null || userEmail == null) {
      throw Exception('Cannot send iMIP reply: missing event data or user email');
    }

    await _imipReplySender!.sendReply(
      accountId: accountId,
      event: event,
      attendeeEmail: userEmail,
      partstat: partstat,
      sentMailboxId: _registry.sentMailboxId,
    );
  }
}
