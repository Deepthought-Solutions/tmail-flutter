import 'package:core/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:tmail_ui_user/features/email/domain/model/caldav_conflict.dart';

class CalDavApi {
  final Dio _dio;

  CalDavApi(this._dio);

  /// Query CalDAV server for events overlapping with [start]-[end] time range.
  /// Uses REPORT method with calendar-query and time-range filter.
  /// [calendarPath] is the full URL to the CalDAV calendar collection.
  Future<List<CalDavConflict>> queryConflicts({
    required String calendarPath,
    required DateTime start,
    required DateTime end,
  }) async {
    final startStr = _formatUtcDate(start);
    final endStr = _formatUtcDate(end);

    final requestBody = '<?xml version="1.0" encoding="utf-8"?>'
        '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
        '<d:prop><d:getetag/><c:calendar-data/></d:prop>'
        '<c:filter>'
        '<c:comp-filter name="VCALENDAR">'
        '<c:comp-filter name="VEVENT">'
        '<c:time-range start="$startStr" end="$endStr"/>'
        '</c:comp-filter>'
        '</c:comp-filter>'
        '</c:filter>'
        '</c:calendar-query>';

    log('CalDavApi::queryConflicts: path=$calendarPath start=$startStr end=$endStr');

    try {
      final response = await _dio.request(
        calendarPath,
        data: requestBody,
        options: Options(
          method: 'REPORT',
          headers: {
            'Content-Type': 'application/xml; charset=utf-8',
            'Depth': '1',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      if (response.statusCode == 207) {
        return _parseMultiStatusResponse(response.data as String);
      }

      log('CalDavApi::queryConflicts: unexpected status ${response.statusCode}');
      return [];
    } catch (e) {
      log('CalDavApi::queryConflicts: error=$e');
      return [];
    }
  }

  /// Parse WebDAV multistatus XML response to extract iCalendar data blocks.
  /// Uses regex-based extraction to avoid dependency on xml package.
  List<CalDavConflict> _parseMultiStatusResponse(String xmlString) {
    final conflicts = <CalDavConflict>[];

    try {
      // Extract all calendar-data content blocks from the XML
      // Handles both <c:calendar-data> and <cal:calendar-data> prefixes
      final calendarDataPattern = RegExp(
        r'<[^>]*calendar-data[^>]*>([\s\S]*?)</[^>]*calendar-data>',
        caseSensitive: false,
      );

      final matches = calendarDataPattern.allMatches(xmlString);
      for (final match in matches) {
        final icsData = match.group(1)?.trim();
        if (icsData != null && icsData.isNotEmpty) {
          final conflict = _parseICalendarData(icsData);
          if (conflict != null) {
            conflicts.add(conflict);
          }
        }
      }
    } catch (e) {
      log('CalDavApi::_parseMultiStatusResponse: parse error=$e');
    }

    log('CalDavApi::_parseMultiStatusResponse: found ${conflicts.length} conflicts');
    return conflicts;
  }

  CalDavConflict? _parseICalendarData(String icsData) {
    String? summary;
    DateTime? dtStart;
    DateTime? dtEnd;

    final lines = icsData.split(RegExp(r'\r?\n'));

    // Handle iCalendar line folding (lines starting with space or tab are continuations)
    final unfoldedLines = <String>[];
    for (final line in lines) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (unfoldedLines.isNotEmpty) {
          unfoldedLines[unfoldedLines.length - 1] += line.substring(1);
        }
      } else {
        unfoldedLines.add(line);
      }
    }

    for (final line in unfoldedLines) {
      if (line.startsWith('SUMMARY')) {
        summary = _extractIcsValue(line);
      } else if (line.startsWith('DTSTART')) {
        dtStart = _parseIcsDateTime(line);
      } else if (line.startsWith('DTEND')) {
        dtEnd = _parseIcsDateTime(line);
      }
    }

    if (dtStart != null) {
      return CalDavConflict(
        title: summary ?? 'Untitled event',
        start: dtStart,
        end: dtEnd ?? dtStart.add(const Duration(hours: 1)),
      );
    }

    return null;
  }

  String _extractIcsValue(String line) {
    // Handle properties with parameters like SUMMARY;LANGUAGE=en:The Title
    final colonIndex = line.indexOf(':');
    if (colonIndex >= 0) {
      return line.substring(colonIndex + 1).trim();
    }
    return line;
  }

  DateTime? _parseIcsDateTime(String line) {
    final colonIndex = line.indexOf(':');
    if (colonIndex < 0) return null;

    final value = line.substring(colonIndex + 1).trim();

    try {
      // Format: 20260320T140000Z (UTC)
      if (value.endsWith('Z')) {
        return _parseBasicDateTime(
          value.substring(0, value.length - 1),
          isUtc: true,
        );
      }

      // Check for TZID parameter — treat as local time for conflict detection
      final upperLine = line.toUpperCase();
      if (upperLine.contains('TZID=')) {
        return _parseBasicDateTime(value, isUtc: false);
      }

      // Floating time (no timezone)
      return _parseBasicDateTime(value, isUtc: false);
    } catch (e) {
      log('CalDavApi::_parseIcsDateTime: parse error for $value: $e');
      return null;
    }
  }

  DateTime? _parseBasicDateTime(String value, {required bool isUtc}) {
    // Format: 20260320T140000
    if (value.length < 15) {
      // Date-only format: 20260320
      if (value.length >= 8) {
        final year = int.parse(value.substring(0, 4));
        final month = int.parse(value.substring(4, 6));
        final day = int.parse(value.substring(6, 8));
        return isUtc
            ? DateTime.utc(year, month, day)
            : DateTime(year, month, day);
      }
      return null;
    }

    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(4, 6));
    final day = int.parse(value.substring(6, 8));
    final hour = int.parse(value.substring(9, 11));
    final minute = int.parse(value.substring(11, 13));
    final second = int.parse(value.substring(13, 15));

    return isUtc
        ? DateTime.utc(year, month, day, hour, minute, second)
        : DateTime(year, month, day, hour, minute, second);
  }

  String _formatUtcDate(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}'
        'T'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}'
        'Z';
  }
}
