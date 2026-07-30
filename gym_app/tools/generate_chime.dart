import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Generates a soft, harmonic notification chime WAV file.
///
/// Sound: warm ascending C-major arpeggio (C5 → E5 → G5 → C6)
/// with a gentle bell-like timbre, soft attack and natural decay.
/// Output: assets/sounds/chime.wav (mono, 44100 Hz, 16-bit PCM)
void main() {
  const sampleRate = 44100;
  const bitDepth = 16;
  const channels = 1;

  // ── Note frequencies (C-major arpeggio) ──
  const c5 = 523.25;
  const e5 = 659.25;
  const g5 = 783.99;
  const c6 = 1046.50;

  // ── Timing: each note starts with a slight overlap ──
  const noteLen = 0.13; // base duration per note
  const overlap = 0.04; // overlap between consecutive notes
  final offsets = [0.0, noteLen - overlap, (noteLen - overlap) * 2, (noteLen - overlap) * 3];
  final freqs = [c5, e5, g5, c6];
  final durations = [noteLen, noteLen, noteLen, noteLen + 0.06]; // last note rings longer

  final totalDuration = offsets.last + durations.last + 0.04;
  final totalSamples = (totalDuration * sampleRate).ceil();
  final samples = Float64List(totalSamples);

  for (var i = 0; i < totalSamples; i++) {
    final t = i / sampleRate;
    double sample = 0.0;

    for (var n = 0; n < 4; n++) {
      final localT = t - offsets[n];
      if (localT < 0 || localT >= durations[n]) continue;

      final env = _bellEnvelope(localT, durations[n]);

      // Warm fundamental (sine) — body of the sound
      sample += _sine(freqs[n], localT) * 0.18 * env;

      // Soft second harmonic for brightness
      sample += _sine(freqs[n] * 2, localT) * 0.06 * env;

      // Very subtle third harmonic for sparkle on the top note
      if (n == 3) {
        sample += _sine(freqs[n] * 3, localT) * 0.025 * env;
      }
    }

    // Very subtle sub-bass warmth on the first note only
    final localT0 = t - offsets[0];
    if (localT0 >= 0 && localT0 < durations[0]) {
      final env = _bellEnvelope(localT0, durations[0]);
      sample += _sine(c5 * 0.5, localT0) * 0.06 * env;
    }

    samples[i] = sample.clamp(-1.0, 1.0);
  }

  // ── Convert to 16-bit PCM ──
  final pcmData = Int16List(totalSamples);
  for (var i = 0; i < totalSamples; i++) {
    pcmData[i] = (samples[i] * 32767).round().clamp(-32768, 32767);
  }

  // ── Build WAV ──
  final byteData = BytesBuilder();
  final dataSize = pcmData.lengthInBytes;
  final blockAlign = channels * (bitDepth ~/ 8);
  final byteRate = sampleRate * blockAlign;

  _writeString(byteData, 'RIFF');
  _writeInt32(byteData, 36 + dataSize);
  _writeString(byteData, 'WAVE');

  _writeString(byteData, 'fmt ');
  _writeInt32(byteData, 16);
  _writeInt16(byteData, 1); // PCM
  _writeInt16(byteData, channels);
  _writeInt32(byteData, sampleRate);
  _writeInt32(byteData, byteRate);
  _writeInt16(byteData, blockAlign);
  _writeInt16(byteData, bitDepth);

  _writeString(byteData, 'data');
  _writeInt32(byteData, dataSize);
  byteData.add(pcmData.buffer.asUint8List());

  // ── Write ──
  final outputDir = Directory('assets/sounds');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final file = File('assets/sounds/chime.wav');
  file.writeAsBytesSync(byteData.toBytes());
  print('✅ Chime WAV gerado: ${file.path} (${dataSize + 44} bytes)');
}

/// Bell-like envelope: quick soft attack, gentle exponential decay.
double _bellEnvelope(double t, double duration) {
  const attack = 0.008; // 8ms — imperceptível, evita click
  if (t < attack) {
    // Smooth cosine fade-in
    return 0.5 - 0.5 * math.cos(math.pi * t / attack);
  }
  // Exponential-style decay for natural bell ring
  final decay = (t - attack) / (duration - attack);
  return math.exp(-decay * 3.5);
}

double _sine(double freq, double t) {
  return math.sin(2.0 * math.pi * freq * t);
}

// ── WAV helpers ──

void _writeString(BytesBuilder bb, String s) {
  bb.add(s.codeUnits);
}

void _writeInt32(BytesBuilder bb, int value) {
  bb.add([
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ]);
}

void _writeInt16(BytesBuilder bb, int value) {
  bb.add([
    value & 0xFF,
    (value >> 8) & 0xFF,
  ]);
}
