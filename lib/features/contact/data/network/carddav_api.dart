import 'package:core/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

class CardDavApi {
  final Dio _dio;
  final Uuid _uuid;

  CardDavApi(this._dio, this._uuid);

  /// Saves a contact to Stalwart CardDAV via PUT with If-None-Match: *
  /// so it only creates new contacts and never overwrites existing ones.
  ///
  /// [baseUrl] - The server base URL (e.g. https://mail.example.com)
  /// [username] - The authenticated user's email (used in the DAV path)
  /// [displayName] - The contact's display name (FN field)
  /// [email] - The contact's email address
  Future<void> saveContact({
    required String baseUrl,
    required String username,
    required String displayName,
    required String email,
  }) async {
    final uid = _uuid.v4();
    final vcard = 'BEGIN:VCARD\r\n'
        'VERSION:4.0\r\n'
        'FN:$displayName\r\n'
        'EMAIL:$email\r\n'
        'UID:urn:uuid:$uid\r\n'
        'END:VCARD';

    final url = '$baseUrl/dav/card/$username/default/$uid.vcf';

    print('CardDavApi::saveContact: PUT $url for $email');

    await _dio.request(
      url,
      data: vcard,
      options: Options(
        method: 'PUT',
        headers: {
          'Content-Type': 'text/vcard; charset=utf-8',
          'If-None-Match': '*',
        },
        validateStatus: (status) =>
            status == 201 || status == 204 || status == 412,
      ),
    );
  }

  /// Searches contacts via CardDAV REPORT with addressbook-query filter.
  /// Returns a list of [EmailAddress] matching the query string.
  ///
  /// Uses a substring match on FN (display name) and EMAIL fields.
  Future<List<EmailAddress>> searchContacts({
    required String baseUrl,
    required String username,
    required String query,
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) return [];

    final url = '$baseUrl/dav/card/$username/default/';

    // CardDAV addressbook-query REPORT with text-match filter
    final requestBody = '''<?xml version="1.0" encoding="UTF-8"?>
<C:addressbook-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">
  <D:prop>
    <D:getetag/>
    <C:address-data/>
  </D:prop>
  <C:filter test="anyof">
    <C:prop-filter name="FN">
      <C:text-match collation="i;unicode-casemap" match-type="contains">$query</C:text-match>
    </C:prop-filter>
    <C:prop-filter name="EMAIL">
      <C:text-match collation="i;unicode-casemap" match-type="contains">$query</C:text-match>
    </C:prop-filter>
  </C:filter>
</C:addressbook-query>''';

    print('CardDavApi::searchContacts: REPORT $url for query="$query"');

    try {
      final response = await _dio.request(
        url,
        data: requestBody,
        options: Options(
          method: 'REPORT',
          headers: {
            'Content-Type': 'application/xml; charset=utf-8',
            'Depth': '1',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) =>
              status == 207 || status == 200 || status == 404,
        ),
      );

      if (response.statusCode == 404) {
        print('CardDavApi::searchContacts: addressbook not found');
        return [];
      }

      return _parseMultiStatusResponse(response.data as String, limit);
    } catch (e) {
      print('CardDavApi::searchContacts: error $e');
      return [];
    }
  }

  /// Parses a WebDAV multi-status response containing vCard data.
  List<EmailAddress> _parseMultiStatusResponse(String xmlData, int limit) {
    final results = <EmailAddress>[];

    try {
      final document = XmlDocument.parse(xmlData);
      final responses = document.findAllElements('response',
          namespace: 'DAV:');

      for (final response in responses) {
        if (results.length >= limit) break;

        final addressDataElements = response.findAllElements('address-data',
            namespace: 'urn:ietf:params:xml:ns:carddav');

        for (final addrData in addressDataElements) {
          final vcard = addrData.innerText;
          final parsed = _parseVCard(vcard);
          if (parsed != null) {
            results.add(parsed);
            if (results.length >= limit) break;
          }
        }
      }
    } catch (e) {
      print('CardDavApi::_parseMultiStatusResponse: parse error $e');
    }

    return results;
  }

  /// Extracts FN and EMAIL from a vCard string.
  EmailAddress? _parseVCard(String vcard) {
    String? fn;
    String? email;

    for (final line in vcard.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.toUpperCase().startsWith('FN:')) {
        fn = trimmed.substring(3).trim();
      } else if (trimmed.toUpperCase().startsWith('EMAIL')) {
        // Handle EMAIL:addr or EMAIL;TYPE=xxx:addr
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx >= 0 && colonIdx < trimmed.length - 1) {
          email = trimmed.substring(colonIdx + 1).trim();
        }
      }
    }

    if (email == null || email.isEmpty) return null;
    return EmailAddress(fn, email);
  }
}
