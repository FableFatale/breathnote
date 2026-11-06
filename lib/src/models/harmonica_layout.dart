import 'pitch_reading.dart';
import 'practice_note.dart';

String? tabForReading(PitchReading reading, String key) {
  if (!reading.detected) return null;
  const blow = [60, 64, 67, 72, 76, 79, 84, 88, 91, 96];
  const draw = [62, 67, 71, 74, 77, 81, 83, 86, 89, 93];
  final offset = harmonicaKeyOffset(key);

  for (var index = 0; index < blow.length; index++) {
    if (blow[index] + offset == reading.midi) {
      return '${index + 1} 孔 · 吹气';
    }
    if (draw[index] + offset == reading.midi) {
      return '${index + 1} 孔 · 吸气';
    }
  }
  return null;
}
