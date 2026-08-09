class ProgressVideoModel {
  final String id;
  final String userId;
  final String exerciseName;
  final String videoUrl;
  final DateTime createdAt;
  final String uploadedBy;
  final String status; // pending, approved, rejected
  final String? feedback;
  final DateTime? reviewedAt;

  const ProgressVideoModel({
    this.id = '',
    required this.userId,
    required this.exerciseName,
    required this.videoUrl,
    required this.createdAt,
    required this.uploadedBy,
    this.status = 'pending',
    this.feedback,
    this.reviewedAt,
  });

  factory ProgressVideoModel.fromMap(
    String id,
    String userId,
    Map<String, dynamic> map,
  ) {
    return ProgressVideoModel(
      id: id,
      userId: userId,
      exerciseName: map['exerciseName'] as String? ?? 'Exercício',
      videoUrl: map['videoUrl'] as String? ?? '',
      createdAt:
          _date(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      uploadedBy: map['uploadedBy'] as String? ?? userId,
      status: map['status'] as String? ?? 'pending',
      feedback: map['feedback'] as String?,
      reviewedAt: _date(map['reviewedAt']),
    );
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(value.toString());
    }
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'exerciseName': exerciseName,
    'videoUrl': videoUrl,
    'createdAt': createdAt,
    'uploadedBy': uploadedBy,
    'status': status,
    if (feedback != null) 'feedback': feedback,
    if (reviewedAt != null) 'reviewedAt': reviewedAt,
  };

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
}
