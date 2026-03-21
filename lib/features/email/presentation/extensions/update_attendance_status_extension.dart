import 'package:core/presentation/state/success.dart';
import 'package:core/utils/app_logger.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/attendance/calendar_event_attendance.dart';
import 'package:tmail_ui_user/features/email/domain/state/calendar_event_accept_state.dart';
import 'package:tmail_ui_user/features/email/domain/state/calendar_event_counter_accept_state.dart';
import 'package:tmail_ui_user/features/email/domain/state/calendar_event_maybe_state.dart';
import 'package:tmail_ui_user/features/email/domain/state/calendar_event_reject_state.dart';
import 'package:tmail_ui_user/features/email/domain/state/parse_calendar_event_state.dart';
import 'package:tmail_ui_user/features/email/domain/utils/calendar_event_capability_registry.dart';
import 'package:tmail_ui_user/features/email/presentation/controller/single_email_controller.dart';

const _acceptedStatus = 'accepted';
const _tentativeStatus = 'tentative';
const _declinedStatus = 'declined';

extension UpdateAttendanceStatusExtension on SingleEmailController {
  void updateAttendanceStatus(UIState viewState) {
    attendanceStatus.value = switch (viewState) {
      ParseCalendarEventSuccess(
        blobCalendarEventList: final blobCalendarEventList,
      ) => blobCalendarEventList.firstOrNull?.attendanceStatus
            ?? _inferAttendanceFromPartstat(viewState),
      CalendarEventAccepted() => AttendanceStatus.accepted,
      CalendarEventMaybeSuccess() => AttendanceStatus.tentativelyAccepted,
      CalendarEventRejected() => AttendanceStatus.rejected,
      CalendarEventCounterAccepted() => AttendanceStatus.accepted,
      _ => attendanceStatus.value,
    };
  }

  /// When JMAP attendanceStatus is null, try to infer it from:
  /// 1. Persisted attendance status (from a previous RSVP action in this session)
  /// 2. The PARTSTAT of the current user in the parsed CalendarEvent's participants
  AttendanceStatus? _inferAttendanceFromPartstat(ParseCalendarEventSuccess success) {
    final blob = success.blobCalendarEventList.firstOrNull;
    if (blob == null) return null;

    final calEvent = blob.calendarEventList.firstOrNull;
    if (calEvent == null) return null;

    // Check persisted attendance status first (survives email reopen)
    final eventUid = calEvent.eventId?.id;
    if (eventUid != null) {
      final persisted = CalendarEventCapabilityRegistry.instance
          .getAttendanceStatus(eventUid);
      if (persisted != null) {
        log('UpdateAttendanceStatus::_inferAttendanceFromPartstat: '
            'found persisted status=$persisted for eventUid=$eventUid');
        return persisted;
      }
    }

    if (calEvent.participants == null) return null;

    final userEmail = mailboxDashBoardController.ownEmailAddress.value;
    if (userEmail.isEmpty) return null;

    final userEmailLower = userEmail.toLowerCase();

    for (final attendee in calEvent.participants!) {
      final attendeeEmail = attendee.mailto?.mailAddress.value.toLowerCase();
      if (attendeeEmail == userEmailLower) {
        final partstat = attendee.participationStatus;
        if (partstat == null) return null;

        final statusValue = partstat.value.toLowerCase();
        log('UpdateAttendanceStatus::_inferAttendanceFromPartstat: '
            'found user $userEmailLower with PARTSTAT=$statusValue');

        if (statusValue == _acceptedStatus) return AttendanceStatus.accepted;
        if (statusValue == _tentativeStatus) return AttendanceStatus.tentativelyAccepted;
        if (statusValue == _declinedStatus) return AttendanceStatus.rejected;
        return null;
      }
    }

    return null;
  }
}
