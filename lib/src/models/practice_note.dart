import 'dart:math' as math;

class PracticeNote {
  const PracticeNote({
    required this.note,
    required this.octave,
    required this.tab,
    this.requiresBend = false,
  });

  factory PracticeNote.fromJson(Map<String, Object?> json) {
    return PracticeNote(
      note: json['note'] as String,
      octave: (json['octave'] as num).toInt(),
      tab: json['tab'] as String,
      requiresBend: json['bend'] as bool? ?? false,
    );
  }

  final String note;
  final int octave;
  final String tab;
  final bool requiresBend;

  String get label => '$note$octave';

  bool get isBlow => tab.contains('↑');

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

  double frequencyForKey(String key) {
    final targetMidi = midi + harmonicaKeyOffset(key);
    return (440 * math.pow(2, (targetMidi - 69) / 12)).toDouble();
  }

  String labelForKey(String key) {
    return noteLabelForMidi(midi + harmonicaKeyOffset(key));
  }

  double centsFromFrequency(double frequency, String key) {
    if (frequency <= 0) return 0;
    final rawCents =
        1200 * math.log(frequency / frequencyForKey(key)) / math.ln2;
    if (rawCents.abs() <= 600) return rawCents;
    final octaveShift = (rawCents / 1200).round().clamp(-3, 3);
    return rawCents - octaveShift * 1200;
  }

  Map<String, Object> toJson() {
    return {
      'note': note,
      'octave': octave,
      'tab': tab,
      if (requiresBend) 'bend': true,
    };
  }
}

String noteLabelForMidi(int midi) {
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
  return '${names[((midi % 12) + 12) % 12]}${midi ~/ 12 - 1}';
}

/// 标准 10 孔 Richter 调音口琴相对 C 调的半音偏移（真实物理八度范围：G3 ~ F#4 起音）。
///
/// 常见 12 调实琴按从低到高排列为：G(-5) · A♭(-4) · A(-3) · B♭(-2) · B(-1) · C(0) ·
/// D♭(+1) · D(+2) · E♭(+3) · E(+4) · F(+5) · F#(+6)。
/// 例如：G 调 4 孔吹气为 G4 (392 Hz)，A 调为 A4 (440 Hz)，C 调为 C5 (523.25 Hz)，
/// F 调为 F5 (698.46 Hz)。
int harmonicaKeyOffset(String key) {
  const offsets = {
    'G': -5,
    'A♭': -4,
    'A': -3,
    'B♭': -2,
    'B': -1,
    'C': 0,
    'D♭': 1,
    'D': 2,
    'E♭': 3,
    'E': 4,
    'F': 5,
    'F#': 6,
  };
  return offsets[key] ?? 0;
}
