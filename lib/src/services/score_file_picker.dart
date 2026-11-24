import 'package:flutter/services.dart';

class PickedScoreFile {
  const PickedScoreFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  bool get isMidi {
    final lower = name.toLowerCase();
    return lower.endsWith('.mid') || lower.endsWith('.midi');
  }

  bool get isMusicXml {
    final lower = name.toLowerCase();
    return lower.endsWith('.xml') || lower.endsWith('.musicxml');
  }
}

/// 通过 Android 原生系统文件选择器选取本地 MIDI / MusicXML 文件（零第三方依赖）。
class ScoreFilePickerService {
  const ScoreFilePickerService();

  static const _channel = MethodChannel('app.breathnote/file_picker');

  Future<PickedScoreFile?> pickScoreFile() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'pickScoreFile',
      );
      if (raw == null) return null;
      final name = raw['name'] as String? ?? 'imported.mid';
      final bytes = raw['bytes'];
      if (bytes is! Uint8List || bytes.isEmpty) return null;
      return PickedScoreFile(name: name, bytes: bytes);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
