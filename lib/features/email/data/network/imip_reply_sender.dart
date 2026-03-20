import 'package:http_parser/http_parser.dart';
import 'package:jmap_dart_client/http/http_client.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/reference_id.dart';
import 'package:jmap_dart_client/jmap/core/reference_prefix.dart';
import 'package:jmap_dart_client/jmap/core/request/request_invocation.dart';
import 'package:jmap_dart_client/jmap/jmap_request.dart';
import 'package:jmap_dart_client/jmap/mail/calendar/calendar_event.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_body_part.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_body_value.dart';
import 'package:jmap_dart_client/jmap/mail/email/keyword_identifier.dart';
import 'package:jmap_dart_client/jmap/mail/email/set/set_email_method.dart';
import 'package:jmap_dart_client/jmap/mail/email/set/set_email_response.dart';
import 'package:jmap_dart_client/jmap/mail/email/submission/address.dart';
import 'package:jmap_dart_client/jmap/mail/email/submission/email_submission.dart';
import 'package:jmap_dart_client/jmap/mail/email/submission/envelope.dart';
import 'package:jmap_dart_client/jmap/mail/email/submission/set/set_email_submission_method.dart';
import 'package:jmap_dart_client/jmap/mail/email/submission/set/set_email_submission_response.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:uuid/uuid.dart';

/// Sends iMIP REPLY emails for calendar event RSVP when the server
/// doesn't support JMAP CalendarEvent/accept (e.g. Stalwart).
class ImipReplySender {
  final HttpClient _httpClient;
  final Uuid _uuid = const Uuid();

  ImipReplySender(this._httpClient);

  /// Send an iMIP REPLY email for Accept/Maybe/Reject.
  /// [partstat] is one of: ACCEPTED, TENTATIVE, DECLINED
  Future<void> sendReply({
    required AccountId accountId,
    required CalendarEvent event,
    required String attendeeEmail,
    required String partstat,
    required MailboxId? sentMailboxId,
  }) async {
    final organizerEmail = _extractEmail(event.organizer?.mailto?.value);
    if (organizerEmail == null) {
      throw Exception('Cannot send iMIP reply: no organizer email');
    }

    final uid = event.eventId?.value ?? '';
    final summary = event.title ?? 'Event';
    final dtStart = _formatDateTime(event.startDate);
    final dtEnd = event.endDate != null
        ? 'DTEND:${_formatDateTime(event.endDate)}'
        : event.duration != null
            ? 'DURATION:${event.duration!.value}'
            : '';
    final sequence = event.sequence?.value ?? 0;
    final timeZone = event.timeZone;

    // Build VCALENDAR REPLY per RFC 5546 §3.2.3
    final icsContent = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Twake Mail//Traktion//EN',
      'METHOD:REPLY',
      'BEGIN:VEVENT',
      'UID:$uid',
      if (dtStart.isNotEmpty) 'DTSTART:$dtStart',
      if (dtEnd.isNotEmpty) dtEnd,
      if (timeZone != null) 'TZID:$timeZone',
      'SEQUENCE:$sequence',
      // RFC 5546: REPLY preserves original SUMMARY, no STATUS
      'SUMMARY:$summary',
      'ORGANIZER:mailto:$organizerEmail',
      'ATTENDEE;PARTSTAT=$partstat;CN=$attendeeEmail:mailto:$attendeeEmail',
      'DTSTAMP:${_nowUtcStamp()}',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    // Build the email with text/calendar body
    final calPartId = PartId('cal');
    final textPartId = PartId('text');

    final statusLabel = _partstatLabel(partstat);
    final textContent = '$statusLabel: $summary';

    final email = Email(
      from: {EmailAddress(null, attendeeEmail)},
      to: {EmailAddress(null, organizerEmail)},
      subject: '$statusLabel: $summary',
      keywords: {KeyWordIdentifier.emailSeen: true},
      mailboxIds: sentMailboxId != null ? {sentMailboxId: true} : null,
      bodyStructure: EmailBodyPart(
        type: MediaType('multipart', 'alternative'),
        subParts: {
          EmailBodyPart(
            partId: textPartId,
            type: MediaType('text', 'plain'),
            charset: 'UTF-8',
          ),
          EmailBodyPart(
            partId: calPartId,
            type: MediaType('text', 'calendar', {'method': 'REPLY'}),
            charset: 'UTF-8',
          ),
        },
      ),
      bodyValues: {
        textPartId: EmailBodyValue(value: textContent, isEncodingProblem: false, isTruncated: false),
        calPartId: EmailBodyValue(value: icsContent, isEncodingProblem: false, isTruncated: false),
      },
    );

    // Send via Email/set + EmailSubmission/set
    final requestBuilder = JmapRequestBuilder(_httpClient, ProcessingInvocation());
    final emailCreateId = Id(_uuid.v1());

    final setEmailMethod = SetEmailMethod(accountId)
      ..addCreate(emailCreateId, email);

    final submissionCreateId = Id(_uuid.v1());
    final emailSubmission = EmailSubmission(
      emailId: EmailId(ReferenceId(ReferencePrefix.defaultPrefix, emailCreateId)),
      envelope: Envelope(
        Address(attendeeEmail),
        {Address(organizerEmail)},
      ),
    );

    final setSubmissionMethod = SetEmailSubmissionMethod(accountId)
      ..addCreate(submissionCreateId, emailSubmission);

    final setEmailInvocation = requestBuilder.invocation(setEmailMethod);
    final setSubmissionInvocation = requestBuilder.invocation(setSubmissionMethod);

    final response = await (requestBuilder
        ..usings({
          CapabilityIdentifier.jmapCore,
          CapabilityIdentifier.jmapMail,
          CapabilityIdentifier.jmapSubmission,
        }))
      .build()
      .execute();

    final setEmailResponse = response.parse<SetEmailResponse>(
      setEmailInvocation.methodCallId,
      SetEmailResponse.deserialize,
    );

    final setSubmissionResponse = response.parse<SetEmailSubmissionResponse>(
      setSubmissionInvocation.methodCallId,
      SetEmailSubmissionResponse.deserialize,
      methodName: setEmailInvocation.methodName,
    );

    final created = setEmailResponse?.created?[emailCreateId];
    if (created == null) {
      final errors = setEmailResponse?.notCreated;
      throw Exception('iMIP reply failed: email not created. Errors: $errors');
    }

    final submitted = setSubmissionResponse?.created?[submissionCreateId];
    if (submitted == null) {
      final errors = setSubmissionResponse?.notCreated;
      throw Exception('iMIP reply failed: submission failed. Errors: $errors');
    }
  }

  String? _extractEmail(String? mailtoOrEmail) {
    if (mailtoOrEmail == null) return null;
    if (mailtoOrEmail.startsWith('mailto:')) {
      return mailtoOrEmail.substring(7);
    }
    return mailtoOrEmail;
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}'
        'T${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  String _nowUtcStamp() {
    final now = DateTime.now().toUtc();
    return '${_formatDateTime(now)}Z';
  }

  String _partstatLabel(String partstat) {
    switch (partstat) {
      case 'ACCEPTED':
        return 'Accepted';
      case 'TENTATIVE':
        return 'Tentative';
      case 'DECLINED':
        return 'Declined';
      default:
        return partstat;
    }
  }
}
