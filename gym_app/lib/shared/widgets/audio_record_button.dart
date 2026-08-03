import 'package:flutter/material.dart';

import '../../core/services/audio_recording_model.dart';
import '../../core/services/audio_recording_service.dart';

class AudioRecordButton extends StatefulWidget {
  final Future<void> Function(RecordedAudio audio) onAudioReady;
  final Color color;
  final Color recordingColor;
  final Color iconColor;

  const AudioRecordButton({
    super.key,
    required this.onAudioReady,
    required this.color,
    this.recordingColor = Colors.red,
    this.iconColor = Colors.white,
  });

  @override
  State<AudioRecordButton> createState() => _AudioRecordButtonState();
}

class _AudioRecordButtonState extends State<AudioRecordButton> {
  final _service = AudioRecordingService();
  bool _recording = false;
  bool _working = false;
  DateTime? _startedAt;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_working) return;
    if (_recording) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    setState(() => _working = true);
    try {
      await _service.start();
      if (mounted) {
        setState(() {
          _recording = true;
          _working = false;
          _startedAt = DateTime.now();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível usar o microfone: $error')),
        );
      }
    }
  }

  Future<void> _stop() async {
    setState(() => _working = true);
    try {
      final audio = await _service.stop();
      final startedAt = _startedAt;
      if (mounted) {
        setState(() {
          _recording = false;
          _working = false;
          _startedAt = null;
        });
      }
      if (audio != null) {
        final duration = startedAt == null
            ? null
            : DateTime.now().difference(startedAt).inMilliseconds;
        await widget.onAudioReady(
          RecordedAudio(
            bytes: audio.bytes,
            extension: audio.extension,
            contentType: audio.contentType,
            durationMs: duration,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _recording = false;
          _working = false;
          _startedAt = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao gravar áudio: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _recording;
    return Tooltip(
      message: active ? 'Parar gravação' : 'Gravar áudio',
      child: IconButton(
        onPressed: _working ? null : _toggle,
        icon: _working
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(active ? Icons.stop_rounded : Icons.mic_none_rounded),
        color: active ? widget.recordingColor : widget.iconColor,
        style: IconButton.styleFrom(
          backgroundColor: active
              ? widget.recordingColor.withValues(alpha: 0.12)
              : widget.color,
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
