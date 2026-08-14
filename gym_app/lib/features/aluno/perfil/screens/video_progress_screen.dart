import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../data/models/progress_video_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';

final progressVideosProvider =
    FutureProvider.family<List<ProgressVideoModel>, String>((ref, userId) {
      return ref.read(progressVideoRepositoryProvider).getVideos(userId);
    });

class VideoProgressScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool isAdmin;
  final UserModel? student;

  const VideoProgressScreen({
    super.key,
    required this.userId,
    this.isAdmin = false,
    this.student,
  });

  @override
  ConsumerState<VideoProgressScreen> createState() =>
      _VideoProgressScreenState();
}

class _VideoProgressScreenState extends ConsumerState<VideoProgressScreen> {
  final _picker = ImagePicker();
  final _exerciseController = TextEditingController();
  bool _uploading = false;

  @override
  void dispose() {
    _exerciseController.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final exercise = _exerciseController.text.trim();
    if (exercise.isEmpty) return;
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = Uint8List.fromList(await picked.readAsBytes());
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'mp4';
      await ref
          .read(progressVideoRepositoryProvider)
          .uploadVideo(
            userId: widget.userId,
            uploaderId: ref.read(authProvider).user?.uid ?? widget.userId,
            exerciseName: exercise,
            bytes: bytes,
            extension: extension,
            contentType: 'video/$extension',
          );
      _exerciseController.clear();
      ref.invalidate(progressVideosProvider(widget.userId));
      if (mounted) _message('Vídeo enviado para aprovação.', false);
    } catch (_) {
      if (mounted) _message('Não foi possível enviar o vídeo.', true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _review(ProgressVideoModel video, String status) async {
    final feedbackController = TextEditingController(
      text: video.feedback ?? '',
    );
    final feedback = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'approved' ? 'Aprovar vídeo' : 'Rejeitar vídeo'),
        content: TextField(
          controller: feedbackController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Feedback (opcional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, feedbackController.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    feedbackController.dispose();
    if (feedback == null) return;
    await ref
        .read(progressVideoRepositoryProvider)
        .reviewVideo(
          widget.userId,
          video.id,
          status: status,
          feedback: feedback.isEmpty ? null : feedback,
        );
    ref.invalidate(progressVideosProvider(widget.userId));
  }

  void _message(String message, bool error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(progressVideosProvider(widget.userId));
    final title = widget.isAdmin
        ? 'Vídeos de progressão'
        : 'Progressão em vídeo';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _intro(),
          const SizedBox(height: 16),
          _uploadCard(),
          const SizedBox(height: 20),
          videosAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (_, __) =>
                const Text('Não foi possível carregar os vídeos.'),
            data: (videos) => videos.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(
                      child: Text('Ainda não existem vídeos de progressão.'),
                    ),
                  )
                : Column(children: videos.map(_videoCard).toList()),
          ),
        ],
      ),
    );
  }

  Widget _intro() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.outline),
    ),
    child: Row(
      children: [
        const Icon(Icons.videocam_outlined, color: AppColors.primary, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.isAdmin
                ? 'Analisa a execução do aluno e aprova ou rejeita cada vídeo.'
                : 'Envia vídeos da tua execução. O teu personal irá revê-los antes de os aprovar.',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _uploadCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isAdmin ? 'Enviar correção do personal' : 'Novo vídeo',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _exerciseController,
          decoration: const InputDecoration(
            labelText: 'Exercício',
            prefixIcon: Icon(Icons.fitness_center_outlined),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(_uploading ? 'A enviar...' : 'Escolher vídeo'),
          ),
        ),
      ],
    ),
  );

  Widget _videoCard(ProgressVideoModel video) {
    final statusColor = video.isApproved
        ? AppColors.success
        : video.isPending
        ? AppColors.warning
        : AppColors.error;
    final label = video.isApproved
        ? 'APROVADO'
        : video.isPending
        ? 'PENDENTE'
        : 'REJEITADO';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  video.exerciseName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(video.createdAt),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          if (video.feedback?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              video.feedback!,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _openVideo(video.videoUrl),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Ver vídeo'),
              ),
              if (widget.isAdmin && video.isPending) ...[
                const Spacer(),
                TextButton(
                  onPressed: () => _review(video, 'rejected'),
                  child: const Text('Rejeitar'),
                ),
                FilledButton(
                  onPressed: () => _review(video, 'approved'),
                  child: const Text('Aprovar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openVideo(String url) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ProgressVideoPlayer(url: url),
    );
  }
}

class _ProgressVideoPlayer extends StatefulWidget {
  final String url;
  const _ProgressVideoPlayer({required this.url});

  @override
  State<_ProgressVideoPlayer> createState() => _ProgressVideoPlayerState();
}

class _ProgressVideoPlayerState extends State<_ProgressVideoPlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialization = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vídeo de progressão'),
      content: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              width: 420,
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const Text('Não foi possível reproduzir este vídeo.');
          }
          return AspectRatio(
            aspectRatio: _controller.value.aspectRatio == 0
                ? 16 / 9
                : _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        FutureBuilder<void>(
          future: _initialization,
          builder: (context, snapshot) => FilledButton.icon(
            onPressed: snapshot.connectionState == ConnectionState.done
                ? () => setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  })
                : null,
            icon: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
            label: Text(_controller.value.isPlaying ? 'Pausar' : 'Reproduzir'),
          ),
        ),
      ],
    );
  }
}
