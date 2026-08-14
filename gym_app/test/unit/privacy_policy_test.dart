import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/user_model.dart';

void main() {
  test('reads and writes versioned privacy consent', () {
    final acceptedAt = DateTime(2026, 8, 9);
    final user = UserModel.fromMap('u1', {
      'privacyPolicyAcceptedAt': acceptedAt,
      'privacyPolicyVersion': 'privacy-2026-08-draft',
    });
    expect(user.hasAcceptedPrivacyPolicy, isTrue);
    expect(user.toMap()['privacyPolicyVersion'], 'privacy-2026-08-draft');
  });
}
