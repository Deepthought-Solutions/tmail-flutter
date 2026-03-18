import 'package:core/presentation/extensions/url_extension.dart';
import 'package:core/utils/app_logger.dart';

extension URIExtension on Uri {

  Uri toQualifiedUrl({required Uri baseUrl}) {
    log('SessionUtils::toQualifiedUrl():baseUrl: $baseUrl | sourceUrl: $this');
    if (hasOrigin) {
      // When behind a reverse proxy, the JMAP server may return URLs with
      // the internal scheme (e.g. http://host:8080) while the client
      // connects via https://host. Rewrite the origin to match baseUrl when
      // the hostname is the same but the scheme differs (http vs https).
      if (host == baseUrl.host && scheme != baseUrl.scheme) {
        final rewritten = baseUrl.replace(
          path: path,
          query: query.isEmpty ? null : query,
          fragment: fragment.isEmpty ? null : fragment,
        );
        log('SessionUtils::toQualifiedUrl():rewritten from $origin to ${baseUrl.origin}: $rewritten');
        return rewritten;
      }
      final qualifiedUrl = toString();
      log('SessionUtils::toQualifiedUrl():qualifiedUrl: $qualifiedUrl');
      return Uri.parse(qualifiedUrl);
    } else if (toString().isEmpty) {
      log('SessionUtils::toQualifiedUrl():qualifiedUrl: $baseUrl');
      return baseUrl;
    } else {
      final baseUrlValid = baseUrl.toString().removeLastSlashOfUrl();
      final sourceUrlValid = toString().addFirstSlashOfUrl();
      log('SessionUtils::toQualifiedUrl():baseUrlValid: $baseUrlValid | sourceUrlValid: $sourceUrlValid');
      final qualifiedUrl = baseUrlValid + sourceUrlValid;
      log('SessionUtils::toQualifiedUrl():qualifiedUrl: $qualifiedUrl');
      return Uri.parse(qualifiedUrl);
    }
  }

  bool get hasOrigin {
    try {
      return origin.isNotEmpty;
    } catch (e) {
      logWarning('URIExtension::hasOrigin:Exception = $e');
      return false;
    }
  }

  Uri ensureWebSocketUri() {
    if (scheme == 'ws' || scheme == 'wss') {
      return this;
    }
    return replace(scheme: 'wss');
  }
}