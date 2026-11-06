import 'dart:math' as math;

class PitchReading {
  const PitchReading({
    required this.detected,
    required this.frequency,
    required this.note,
    required this.octave,
    required this.cents,
    required this.confidence,
    required this.levelDb,
    required this.timestampMicros,
  });

  const PitchReading.silent()
    : detected = false,
      frequency = 0,
      note = '',
      octave = 0,
      cents = 0,
      confidence = 0,
      levelDb = -120,
      timestampMicros = 0;

  factory PitchReading.fromMap(Map<Object?, Object?> map) {
    return PitchReading(
      detected: map['detected'] as bool? ?? false,
      frequency: (map['frequency'] as num?)?.toDouble() ?? 0,
      note: map['note'] as String? ?? '',
      octave: (map['octave'] as num?)?.toInt() ?? 0,
      cents: (map['cents'] as num?)?.toDouble() ?? 0,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      levelDb: (map['levelDb'] as num?)?.toDouble() ?? -120,
      timestampMicros: (map['timestampMicros'] as num?)?.toInt() ?? 0,
    );
  }

  final bool detected;
  final double frequency;
  final String note;
  final int octave;
  final double cents;
  final double confidence;
  final double levelDb;
  final int timestampMicros;

  String get noteWithOctave => detected ? '$note$octave' : '--';

  int get midi {
    const names = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    return (octave + 1) * 12 + names.indexOf(note);
  }

  bool matchesFrequency(double target, {double toleranceCents = 28}) {
    if (!detected || frequency <= 0 || target <= 0) return false;
    final difference = 1200 * math.log(frequency / target) / math.ln2;
    return difference.abs() <= toleranceCents;
  }
}
