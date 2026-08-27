import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/audio_recording_model.dart';
import '../../core/services/audio_recording_service.dart';

class AudioRecordButton extends StatefulWidget {
  final Future<void> Function(RecordedAudio audio) onAudioReady;
  final Color color;
  final Color recordingColor;
  final Color iconColor;
  final ValueChanged<bool>? onRecordingChanged;
  final bool enabled;
  final bool fullWidth;

  const AudioRecordButton({
    super.key,
    required this.onAudioReady,
    required this.color,
    this.recordingColor = Colors.red,
    this.iconColor = Colors.white,
    this.onRecordingChanged,
    this.enabled = true,
    this.fullWidth = false,
  });

  @override
  State<AudioRecordButton> createState() => _AudioRecordButtonState();
}

class _AudioWavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final int bars;

  const _AudioWavePainter({
    required this.progress,
    required this.color,
    required this.bars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final centerY = size.height / 2;
    final count = bars < 3 ? 3 : bars;
    final spacing = size.width / (count + 1);
    for (var i = 0; i < count; i++) {
      final movement = ((i * 0.37 + progress) % 1.0);
      final amplitude = 1.5 + movement * 9;
      canvas.drawLine(
        Offset(spacing * (i + 1), centerY - amplitude),
        Offset(spacing * (i + 1), centerY + amplitude),
        paint,
      );
    }
    if (size.width > 0) {
      canvas.drawLine(Offset.zero.translate(0, centerY), Offset(size.width, centerY), paint..color = color.withValues(alpha: 0.28));
    }
  }

  @override
  bool shouldRepaint(covariant _AudioWavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.bars != bars;
}

class _AudioRecordButtonState extends State<AudioRecordButton>
    with SingleTickerProviderStateMixin {
  final _service = AudioRecordingService();
  bool _recording = false;
  bool _working = false;
  DateTime? _startedAt;
  Timer? _clock;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    _waveController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_working) return;
    if (_recording) {
      await _sendRecording();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    setState(() => _working = true);
    try {
      await _service.start();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _working = false;
        _startedAt = DateTime.now();
      });
      widget.onRecordingChanged?.call(true);
      _waveController.repeat(reverse: true);
      _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível usar o microfone: $error')),
        );
      }
    }
  }

  Future<void> _sendRecording() async {
    setState(() => _working = true);
    _clock?.cancel();
    _waveController.stop();
    try {
      final audio = await _service.stop();
      final startedAt = _startedAt;
      if (mounted) {
        setState(() {
          _recording = false;
          _working = false;
          _startedAt = null;
        });
        widget.onRecordingChanged?.call(false);
      }
      if (audio != null) {
        await widget.onAudioReady(
          RecordedAudio(
            bytes: audio.bytes,
            extension: audio.extension,
            contentType: audio.contentType,
            durationMs: startedAt == null
                ? null
                : DateTime.now().difference(startedAt).inMilliseconds,
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
        widget.onRecordingChanged?.call(false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao gravar áudio: $error')));
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (_working) return;
    setState(() => _working = true);
    _clock?.cancel();
    _waveController.stop();
    try {
      await _service.cancel();
    } catch (error) {
      debugPrint('Erro ao cancelar gravação: $error');
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _working = false;
      _startedAt = null;
    });
    widget.onRecordingChanged?.call(false);
  }

  String _elapsedLabel() {
    final elapsed = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      color: widget.recordingColor,
      padding: const EdgeInsets.all(7),
      constraints: const BoxConstraints.tightFor(width: 38, height: 42),
    );
  }

  Widget _waveform({required int bars}) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (_, __) => SizedBox(
        width: 90,
        height: 32,
        child: CustomPaint(
          painter: _AudioWavePainter(
            progress: _waveController.value,
            color: widget.recordingColor,
            bars: bars,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_recording) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.hasBoundedWidth && constraints.maxWidth < 170;
          final waveform = _waveform(bars: compact ? 3 : 7);
          return Material(
            color: Colors.transparent,
            child: Row(
              mainAxisSize: widget.fullWidth
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                _actionButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Cancelar gravação',
                  onPressed: !widget.enabled || _working
                      ? null
                      : _cancelRecording,
                ),
                if (widget.fullWidth)
                  Expanded(child: Center(child: waveform))
                else ...[
                  waveform,
                  if (!compact) const SizedBox(width: 6),
                ],
                Text(
                  _elapsedLabel(),
                  style: TextStyle(
                    color: widget.recordingColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                _actionButton(
                  icon: Icons.send_rounded,
                  tooltip: 'Enviar áudio',
                  onPressed: !widget.enabled || _working
                      ? null
                      : _sendRecording,
                ),
              ],
            ),
          );
        },
      );
    }

    return Tooltip(
      message: 'Gravar áudio',
      child: IconButton(
        onPressed: !widget.enabled || _working ? null : _toggle,
        icon: _working
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.mic_none_rounded),
        color: widget.iconColor,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(11),
          minimumSize: const Size(44, 44),
          backgroundColor: widget.color,
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
