import 'package:flutter_test/flutter_test.dart';
import 'package:mizan_app/domain/models/mizan_models.dart';

void main() {
  test('Perishable dispute blocks gallery upload and enforces 30-min window', () {
    final delivered = DateTime.utc(2026, 11, 24, 10, 0);

    final galleryAttempt = DisputeAntiFraudGuard.validate(
      deliveredAtUtc: delivered,
      nowUtc: delivered.add(const Duration(minutes: 10)),
      isPerishable: true,
      isLiveInAppCamera: false,
    );
    expect(galleryAttempt.allowed, isFalse);
    expect(galleryAttempt.reason, 'GALLERY_UPLOAD_BLOCKED');

    final liveWithinWindow = DisputeAntiFraudGuard.validate(
      deliveredAtUtc: delivered,
      nowUtc: delivered.add(const Duration(minutes: 25)),
      isPerishable: true,
      isLiveInAppCamera: true,
    );
    expect(liveWithinWindow.allowed, isTrue);

    final liveAfterWindow = DisputeAntiFraudGuard.validate(
      deliveredAtUtc: delivered,
      nowUtc: delivered.add(const Duration(minutes: 31)),
      isPerishable: true,
      isLiveInAppCamera: true,
    );
    expect(liveAfterWindow.allowed, isFalse);
    expect(liveAfterWindow.reason, 'DISPUTE_WINDOW_EXPIRED');
  });
}
