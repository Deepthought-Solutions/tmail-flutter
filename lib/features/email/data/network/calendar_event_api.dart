import 'dart:async';

import 'package:core/utils/app_logger.dart';
import 'package:jmap_dart_client/http/http_client.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/request/request_invocation.dart';
import 'package:jmap_dart_client/jmap/core/response/response_object.dart';
import 'package:jmap_dart_client/jmap/jmap_request.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/attendance/get_calendar_event_attendance_method.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/attendance/get_calendar_event_attendance_response.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/parse/calendar_event_parse_method.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/parse/calendar_event_parse_response.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/reply/calendar_event_accept_method.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/reply/calendar_event_accept_response.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/reply/calendar_event_counter_accept_method.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/reply/calendar_event_maybe_method.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/reply/calendar_event_maybe_response.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/reply/calendar_event_reject_method.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/reply/calendar_event_reject_response.dart';
import 'package:tmail_ui_user/features/email/domain/exceptions/calendar_event_exceptions.dart';
import 'package:tmail_ui_user/features/email/presentation/model/blob_calendar_event.dart';

class CalendarEventAPI {

  final HttpClient _httpClient;

  CalendarEventAPI(this._httpClient);

  Future<List<BlobCalendarEvent>> parse(
    AccountId accountId,
    Set<Id> blobIds, {
    Set<CapabilityIdentifier>? capabilityOverride,
    bool supportsAttendance = true,
  }) async {
    final requestBuilder = JmapRequestBuilder(_httpClient, ProcessingInvocation());

    // Parse
    final calendarEventParseMethod = CalendarEventParseMethod(accountId, blobIds);
    final calendarEventParseInvocation = requestBuilder.invocation(calendarEventParseMethod);

    // Free/Busy query — only when the server supports it (James, not Stalwart)
    RequestInvocation? calendarEventAttendanceGetInvocation;
    if (supportsAttendance) {
      final calendarEventAttendanceGetMethod = GetCalendarEventAttendanceMethod(
        accountId,
        blobIds.toList(),
      );
      calendarEventAttendanceGetInvocation = requestBuilder.invocation(
        calendarEventAttendanceGetMethod,
      );
    }

    final capabilities = capabilityOverride ?? calendarEventParseMethod.requiredCapabilities;
    final response = await (requestBuilder
        ..usings(capabilities))
      .build()
      .execute();

    final calendarEventParseResponse = response.parse<CalendarEventParseResponse>(
      calendarEventParseInvocation.methodCallId,
      _deserializeParseResponse);

    GetCalendarEventAttendanceResponse? calendarEventAttendanceGetResponse;
    if (calendarEventAttendanceGetInvocation != null) {
      calendarEventAttendanceGetResponse = _parseCalendarEventAttendance(
        response,
        calendarEventAttendanceGetInvocation.methodCallId,
      );
    }

    final calendarBlobIdStatusMap = Map.fromEntries(
      (calendarEventAttendanceGetResponse?.list ?? []).map(
        (calendarEventAttendance) => MapEntry(
          calendarEventAttendance.blobId,
          (
            isFree: calendarEventAttendance.isFree,
            attendanceStatus: calendarEventAttendance.eventAttendanceStatus,
          ),
        ),
      ),
    );

    if (calendarEventParseResponse?.parsed?.isNotEmpty == true) {
      return calendarEventParseResponse!.parsed!.entries
        .map((entry) => BlobCalendarEvent(
          blobId: entry.key,
          isFree: calendarBlobIdStatusMap[entry.key]?.isFree ?? true,
          attendanceStatus: calendarBlobIdStatusMap[entry.key]?.attendanceStatus,
          calendarEventList: entry.value))
        .toList();
    } else if (calendarEventParseResponse?.notParsable?.isNotEmpty == true) {
      throw NotParsableCalendarEventException();
    } else if (calendarEventParseResponse?.notFound?.isNotEmpty == true) {
      throw NotFoundCalendarEventException();
    } else {
      throw NotParsableCalendarEventException();
    }
  }

  static CalendarEventParseResponse _deserializeParseResponse(Map<String, dynamic> json) {
    final parsed = json['parsed'];
    if (parsed is Map<String, dynamic>) {
      for (final entry in parsed.entries) {
        if (entry.value is List) {
          for (final event in entry.value) {
            if (event is Map<String, dynamic>) {
              _normalizeCalendarEvent(event);
            }
          }
        }
      }
    }
    return CalendarEventParseResponse.deserialize(json);
  }

  static void _normalizeCalendarEvent(Map<String, dynamic> event) {
    // method: lowercase → uppercase (Stalwart vs James)
    if (event['method'] is String) {
      event['method'] = (event['method'] as String).toUpperCase();
    }

    // participants: Stalwart returns Map<uuid, Participant>, James expects List<Attendee>
    final participants = event['participants'];
    if (participants is Map<String, dynamic>) {
      final attendeeList = <Map<String, dynamic>>[];
      for (final participant in participants.values) {
        if (participant is Map<String, dynamic>) {
          final attendee = <String, dynamic>{};

          // calendarAddress → mailto (strip mailto: prefix)
          final addr = participant['calendarAddress'] as String?;
          if (addr != null) {
            attendee['mailto'] = addr.startsWith('mailto:')
                ? addr.substring(7)
                : addr;
          }

          // name
          if (participant['name'] != null) {
            attendee['name'] = participant['name'];
          }

          // roles Map<String,bool> → single role string
          final roles = participant['roles'];
          if (roles is Map<String, dynamic>) {
            final roleKey = roles.keys.firstOrNull;
            if (roleKey != null) {
              attendee['role'] = roleKey.toLowerCase();
            }
          }

          // participationStatus
          if (participant['participationStatus'] != null) {
            attendee['participationStatus'] = participant['participationStatus'];
          }

          attendeeList.add(attendee);
        }
      }
      event['participants'] = attendeeList;
    }

    // organizer: Stalwart uses organizerCalendarAddress, James uses organizer object
    if (event['organizer'] == null && event['organizerCalendarAddress'] is String) {
      final addr = event['organizerCalendarAddress'] as String;
      event['organizer'] = {
        'mailto': addr.startsWith('mailto:') ? addr.substring(7) : addr,
      };
    }

    // locations: Stalwart returns Map<uuid, Location>, extract first as string
    final locations = event['locations'];
    if (event['location'] == null && locations is Map<String, dynamic>) {
      final firstLoc = locations.values.firstOrNull;
      if (firstLoc is Map<String, dynamic> && firstLoc['name'] != null) {
        event['location'] = firstLoc['name'];
      }
    }

    // status: keep as-is (enum uses lowercase: confirmed, cancelled, tentative)
  }

  GetCalendarEventAttendanceResponse? _parseCalendarEventAttendance(
    ResponseObject response,
    MethodCallId methodCallId,
  ) {
    try {
      return response.parse<GetCalendarEventAttendanceResponse>(
        methodCallId,
        GetCalendarEventAttendanceResponse.deserialize);
    } catch (e) {
      logWarning('CalendarEventAPI.parse free/busy query error: $e');
      return null;
    }
  }

  Future<CalendarEventAcceptResponse> acceptEventInvitation(
    AccountId accountId,
    Set<Id> blobIds,
    String? language, {
    Set<CapabilityIdentifier>? capabilityOverride,
  }) async {
    final requestBuilder = JmapRequestBuilder(_httpClient, ProcessingInvocation());
    final calendarEventAcceptMethod = CalendarEventAcceptMethod(
      accountId,
      blobIds: blobIds.toList());
    if (language != null) {
      calendarEventAcceptMethod.addLanguage(language);
    }
    final calendarEventAcceptInvocation = requestBuilder.invocation(calendarEventAcceptMethod);
    final capabilities = capabilityOverride ?? calendarEventAcceptMethod.requiredCapabilities;
    final response = await (requestBuilder..usings(capabilities))
      .build()
      .execute();

    final calendarEventAcceptResponse = response.parse<CalendarEventAcceptResponse>(
      calendarEventAcceptInvocation.methodCallId,
      CalendarEventAcceptResponse.deserialize);

    if (calendarEventAcceptResponse == null) {
      throw NotAcceptableCalendarEventException();
    }

    if (calendarEventAcceptResponse.accepted?.isNotEmpty == true) {
      return calendarEventAcceptResponse;
    } else {
      throw CannotReplyCalendarEventException(mapErrors: calendarEventAcceptResponse.notAccepted);
    }
  }

  Future<CalendarEventMaybeResponse> maybeEventInvitation(
    AccountId accountId,
    Set<Id> blobIds,
    String? language, {
    Set<CapabilityIdentifier>? capabilityOverride,
  }) async {
    final requestBuilder = JmapRequestBuilder(_httpClient, ProcessingInvocation());
    final calendarEventMaybeMethod = CalendarEventMaybeMethod(
      accountId,
      blobIds: blobIds.toList());
    if (language != null) {
      calendarEventMaybeMethod.addLanguage(language);
    }
    final calendarEventMaybeInvocation = requestBuilder.invocation(calendarEventMaybeMethod);
    final capabilities = capabilityOverride ?? calendarEventMaybeMethod.requiredCapabilities;
    final response = await (requestBuilder..usings(capabilities))
      .build()
      .execute();

    final calendarEventMaybeResponse = response.parse<CalendarEventMaybeResponse>(
      calendarEventMaybeInvocation.methodCallId,
      CalendarEventMaybeResponse.deserialize);

    if (calendarEventMaybeResponse == null) {
      throw NotMaybeableCalendarEventException();
    }

    if (calendarEventMaybeResponse.maybe?.isNotEmpty == true) {
      return calendarEventMaybeResponse;
    } else {
      throw CannotReplyCalendarEventException(mapErrors: calendarEventMaybeResponse.notMaybe);
    }
  }

  Future<CalendarEventRejectResponse> rejectEventInvitation(
    AccountId accountId,
    Set<Id> blobIds,
    String? language, {
    Set<CapabilityIdentifier>? capabilityOverride,
  }) async {
    final requestBuilder = JmapRequestBuilder(_httpClient, ProcessingInvocation());
    final calendarEventRejectMethod = CalendarEventRejectMethod(
      accountId,
      blobIds: blobIds.toList());
    if (language != null) {
      calendarEventRejectMethod.addLanguage(language);
    }
    final calendarEventRejectInvocation = requestBuilder.invocation(calendarEventRejectMethod);
    final capabilities = capabilityOverride ?? calendarEventRejectMethod.requiredCapabilities;
    final response = await (requestBuilder..usings(capabilities))
      .build()
      .execute();

    final calendarEventRejectResponse = response.parse<CalendarEventRejectResponse>(
      calendarEventRejectInvocation.methodCallId,
      CalendarEventRejectResponse.deserialize);

    if (calendarEventRejectResponse == null) {
      throw NotRejectableCalendarEventException();
    }

    if (calendarEventRejectResponse.rejected?.isNotEmpty == true) {
      return calendarEventRejectResponse;
    } else {
      throw CannotReplyCalendarEventException(mapErrors: calendarEventRejectResponse.notRejected);
    }
  }

  Future<CalendarEventAcceptResponse> acceptCounterEvent(
    AccountId accountId,
    Set<Id> blobIds,
  ) async {
    final requestBuilder = JmapRequestBuilder(_httpClient, ProcessingInvocation());
    final calendarEventCounterAcceptMethod = CalendarEventCounterAcceptMethod(
      accountId,
      blobIds: blobIds.toList());
    final calendarEventAcceptInvocation = requestBuilder.invocation(
      calendarEventCounterAcceptMethod,
    );
    final response = await (requestBuilder
        ..usings(calendarEventCounterAcceptMethod.requiredCapabilities))
      .build()
      .execute();

    final calendarEventAcceptResponse = response.parse<CalendarEventAcceptResponse>(
      calendarEventAcceptInvocation.methodCallId,
      CalendarEventAcceptResponse.deserialize);

    if (calendarEventAcceptResponse == null) {
      throw NotAcceptableCalendarEventException();
    }

    if (calendarEventAcceptResponse.accepted?.isNotEmpty == true) {
      return calendarEventAcceptResponse;
    } else {
      throw CannotReplyCalendarEventException(mapErrors: calendarEventAcceptResponse.notAccepted);
    }
  }
}