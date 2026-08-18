import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/utils/storage_resource.dart';

class AudioMessagePlayer extends StatefulWidget {
  final String url;
  final bool isMine;
  final Color activeColor;
  final Color inactiveColor;
  final int? durationMs;

  const AudioMessagePlayer({
    super.key,
    required this.url,
    required this.isMine,
    required this.activeColor,
    required this.inactiveColor,
    this.durationMs,
  });

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  late final AudioPlayer _player;
  late Future<String> _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _resolvedUrl = StorageResource.resolve(widget.url);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        final resolvedUrl = await _resolvedUrl;
        await _player.setUrl(resolvedUrl);
        await _player.play();
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível reproduzir o áudio.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.durationMs == null
        ? 'Áudio'
        : _formatDuration(Duration(milliseconds: widget.durationMs!));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: _toggle,
          icon: Icon(
            _player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
          color: widget.activeColor,
          tooltip: _player.playing ? 'Pausar áudio' : 'Reproduzir áudio',
        ),
        Text(
          label,
          style: TextStyle(color: widget.inactiveColor, fontSize: 12),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
