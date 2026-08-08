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
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(bars, (index) {
          final factor =
              0.35 + (((index % 3) + _waveController.value) % 3) * 0.16;
          return Container(
            width: 2.5,
            height: 10 + factor * 18,
            margin: const EdgeInsets.symmetric(horizontal: 1.1),
            decoration: BoxDecoration(
              color: widget.recordingColor,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
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
            color: widget.recordingColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
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
