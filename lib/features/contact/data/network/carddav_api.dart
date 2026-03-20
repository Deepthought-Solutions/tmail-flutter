import 'package:core/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

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

    log('CardDavApi::saveContact: PUT $url for $email');

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
}
