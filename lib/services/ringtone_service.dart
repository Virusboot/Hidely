import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  factory RingtoneService() => _instance;
  RingtoneService._internal();

  AudioPlayer? _incomingPlayer;
  AudioPlayer? _outgoingPlayer;

  Timer? _vibrationTimer;
  bool _isIncomingPlaying = false;
  bool _isOutgoingPlaying = false;

  Uint8List? _incomingWavBytes;
  Uint8List? _ringbackWavBytes;

  /// Plays incoming call ringtone (melodic chime loop + haptics)
  Future<void> playIncomingRingtone() async {
    if (_isIncomingPlaying) return;
    _isIncomingPlaying = true;

    try {
      _stopOutgoingInternal();

      _incomingPlayer ??= AudioPlayer();
      await _incomingPlayer!.setReleaseMode(ReleaseMode.loop);
      await _incomingPlayer!.setVolume(1.0);

      _incomingWavBytes ??= _generateMelodicRingtone();
      await _incomingPlayer!.play(BytesSource(_incomingWavBytes!));

      // Periodic haptic feedback on mobile devices
      if (!kIsWeb) {
        _vibrationTimer?.cancel();
        HapticFeedback.heavyImpact();
        _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
          if (!_isIncomingPlaying) return;
          HapticFeedback.vibrate();
        });
      }
    } catch (e) {
      debugPrint('[RingtoneService] Error playing incoming ringtone: $e');
    }
  }

  /// Stops incoming call ringtone
  Future<void> stopIncomingRingtone() async {
    _isIncomingPlaying = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    try {
      if (_incomingPlayer != null) {
        await _incomingPlayer!.stop();
      }
    } catch (e) {
      debugPrint('[RingtoneService] Error stopping incoming ringtone: $e');
    }
  }

  /// Plays outgoing call ringback tone (phone "Tring... Tring..." dual-tone loop)
  Future<void> playOutgoingRingback() async {
    if (_isOutgoingPlaying) return;
    _isOutgoingPlaying = true;

    try {
      _stopIncomingInternal();

      _outgoingPlayer ??= AudioPlayer();
      await _outgoingPlayer!.setReleaseMode(ReleaseMode.loop);
      await _outgoingPlayer!.setVolume(0.85);

      _ringbackWavBytes ??= _generateRingbackTone();
      await _outgoingPlayer!.play(BytesSource(_ringbackWavBytes!));
    } catch (e) {
      debugPrint('[RingtoneService] Error playing outgoing ringback tone: $e');
    }
  }

  /// Stops outgoing call ringback tone
  Future<void> stopOutgoingRingback() async {
    _isOutgoingPlaying = false;
    try {
      if (_outgoingPlayer != null) {
        await _outgoingPlayer!.stop();
      }
    } catch (e) {
      debugPrint('[RingtoneService] Error stopping outgoing ringback tone: $e');
    }
  }

  /// Stops all active tones
  Future<void> stopAll() async {
    await stopIncomingRingtone();
    await stopOutgoingRingback();
  }

  void _stopIncomingInternal() {
    _isIncomingPlaying = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _incomingPlayer?.stop();
  }

  void _stopOutgoingInternal() {
    _isOutgoingPlaying = false;
    _outgoingPlayer?.stop();
  }

  /// Generates a North American / European standard ringback tone WAV
  /// Dual tone: 440 Hz + 480 Hz.
  /// 1.5 seconds ON, 2.5 seconds OFF (4.0s total cycle).
  static Uint8List _generateRingbackTone() {
    const int sampleRate = 22050;
    const double duration = 4.0;
    const double toneDuration = 1.5;
    final int totalSamples = (sampleRate * duration).toInt();
    final int toneSamples = (sampleRate * toneDuration).toInt();

    final pcmSamples = Int16List(totalSamples);
    const double freq1 = 440.0;
    const double freq2 = 480.0;
    const double twoPi = 2.0 * math.pi;

    // 10ms smooth fade ramp to eliminate clicks
    final int fadeSamples = (sampleRate * 0.015).toInt();

    for (int i = 0; i < toneSamples; i++) {
      final double t = i / sampleRate;
      double ramp = 1.0;
      if (i < fadeSamples) {
        ramp = i / fadeSamples;
      } else if (i > toneSamples - fadeSamples) {
        ramp = (toneSamples - i) / fadeSamples;
      }

      final double s1 = math.sin(twoPi * freq1 * t);
      final double s2 = math.sin(twoPi * freq2 * t);
      final double val = (s1 + s2) * 0.42 * ramp;
      pcmSamples[i] = (val * 32767).toInt().clamp(-32768, 32767);
    }

    // Silence for remainder of duration
    for (int i = toneSamples; i < totalSamples; i++) {
      pcmSamples[i] = 0;
    }

    return _buildWavHeaderAndData(sampleRate, pcmSamples);
  }

  /// Generates a pleasant, modern melodic marimba chime ringtone WAV
  /// Repeated chord arpeggio with natural harmonic decay.
  /// 3.2 seconds total cycle.
  static Uint8List _generateMelodicRingtone() {
    const int sampleRate = 22050;
    const double duration = 3.2;
    final int totalSamples = (sampleRate * duration).toInt();
    final pcmSamples = Int16List(totalSamples);
    const double twoPi = 2.0 * math.pi;

    // Sequence of musical notes (freq, start_sec, decay_rate, amplitude)
    const notes = <_Note>[
      _Note(freq: 523.25, start: 0.00, decay: 4.0, amp: 0.60), // C5
      _Note(freq: 659.25, start: 0.22, decay: 4.0, amp: 0.65), // E5
      _Note(freq: 783.99, start: 0.44, decay: 4.0, amp: 0.70), // G5
      _Note(freq: 1046.50, start: 0.66, decay: 3.5, amp: 0.75), // C6
      _Note(freq: 880.00, start: 1.05, decay: 3.5, amp: 0.70), // A5
      _Note(freq: 783.99, start: 1.27, decay: 4.0, amp: 0.65), // G5
      _Note(freq: 659.25, start: 1.49, decay: 4.0, amp: 0.60), // E5
      _Note(freq: 587.33, start: 1.71, decay: 3.0, amp: 0.65), // D5
      _Note(freq: 523.25, start: 1.93, decay: 2.2, amp: 0.75), // C5 (sustained)
    ];

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      double sampleVal = 0.0;

      for (final note in notes) {
        if (t >= note.start) {
          final double dt = t - note.start;
          if (dt < 1.2) {
            final double env = math.exp(-note.decay * dt);
            // Fundamental + 2nd harmonic + 3rd harmonic for rich chime timbre
            final double fundamental = math.sin(twoPi * note.freq * dt);
            final double h2 = math.sin(twoPi * note.freq * 2.0 * dt) * 0.28;
            final double h3 = math.sin(twoPi * note.freq * 3.0 * dt) * 0.12;
            sampleVal += (fundamental + h2 + h3) * note.amp * env;
          }
        }
      }

      pcmSamples[i] = (sampleVal * 22000).toInt().clamp(-32768, 32767);
    }

    return _buildWavHeaderAndData(sampleRate, pcmSamples);
  }

  /// Builds a valid 44-byte canonical WAV header and attaches 16-bit PCM data
  static Uint8List _buildWavHeaderAndData(int sampleRate, Int16List pcmData) {
    const int numChannels = 1; // mono
    const int bitsPerSample = 16;
    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    const int blockAlign = numChannels * (bitsPerSample ~/ 8);
    final int subChunk2Size = pcmData.lengthInBytes;
    final int chunkSize = 36 + subChunk2Size;

    final bytes = Uint8List(44 + subChunk2Size);
    final byteData = ByteData.view(bytes.buffer);

    // "RIFF"
    bytes[0] = 0x52; // R
    bytes[1] = 0x49; // I
    bytes[2] = 0x46; // F
    bytes[3] = 0x46; // F
    byteData.setUint32(4, chunkSize, Endian.little);

    // "WAVE"
    bytes[8] = 0x57; // W
    bytes[9] = 0x41; // A
    bytes[10] = 0x56; // V
    bytes[11] = 0x45; // E

    // "fmt "
    bytes[12] = 0x66; // f
    bytes[13] = 0x6D; // m
    bytes[14] = 0x74; // t
    bytes[15] = 0x20; // ' '
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, blockAlign, Endian.little);
    byteData.setUint16(34, bitsPerSample, Endian.little);

    // "data"
    bytes[36] = 0x64; // d
    bytes[37] = 0x61; // a
    bytes[38] = 0x74; // t
    bytes[39] = 0x61; // a
    byteData.setUint32(40, subChunk2Size, Endian.little);

    // Copy PCM data
    final pcmBytes = Uint8List.view(pcmData.buffer);
    bytes.setRange(44, 44 + subChunk2Size, pcmBytes);

    return bytes;
  }
}

class _Note {
  final double freq;
  final double start;
  final double decay;
  final double amp;

  const _Note({
    required this.freq,
    required this.start,
    required this.decay,
    required this.amp,
  });
}
