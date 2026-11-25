import 'package:flutter/services.dart';

class ShareService {
  const ShareService();

  static const _channel = MethodChannel('app.breathnote/share');

  Future<bool> sharePngImage({
    required Uint8List bytes,
    required String fileName,
    String? text,
    String? subject,
  }) async {
    if (bytes.isEmpty) return false;
    try {
      final shared = await _channel.invokeMethod<bool>('shareImage', {
        'bytes': bytes,
        'fileName': fileName,
        'text': ?text,
        'subject': ?subject,
      });
      return shared ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
