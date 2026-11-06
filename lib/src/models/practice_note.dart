import 'dart:math' as math;

class PracticeNote {
  const PracticeNote({
    required this.note,
    required this.octave,
    required this.tab,
  });

  factory PracticeNote.fromJson(Map<String, Object?> json) {
    return PracticeNote(
      note: json['note'] as String,
      octave: (json['octave'] as num).toInt(),
      tab: json['tab'] as String,
    );
  }

  final String note;
  final int octave;
  final String tab;

  String get label => '$note$octave';

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
    return 1200 * math.log(frequency / frequencyForKey(key)) / math.ln2;
  }

  Map<String, Object> toJson() {
    return {'note': note, 'octave': octave, 'tab': tab};
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

int harmonicaKeyOffset(String key) {
  const offsets = {
    'C': 0,
    'D♭': 1,
    'D': 2,
    'E♭': 3,
    'E': 4,
    'F': 5,
    'F#': 6,
    'G': 7,
    'A♭': 8,
    'A': 9,
    'B♭': 10,
    'B': 11,
  };
  return offsets[key] ?? 0;
}
