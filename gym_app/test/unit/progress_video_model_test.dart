import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/progress_video_model.dart';

void main() {
  test('creates pending progression video by default', () {
    final video = ProgressVideoModel(
      userId: 'u1',
      exerciseName: 'Agachamento',
      videoUrl: 'https://example.com/video.mp4',
      createdAt: DateTime(2026, 8, 9),
      uploadedBy: 'u1',
    );
    expect(video.isPending, isTrue);
    expect(video.isApproved, isFalse);
    expect(video.toMap()['exerciseName'], 'Agachamento');
  });
}
