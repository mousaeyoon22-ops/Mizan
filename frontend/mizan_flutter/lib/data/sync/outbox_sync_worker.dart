import '../local/mizan_local_db.dart';
import '../remote/mizan_api_client.dart';

class SyncRunReport {
  final int synced;
  final int conflicts;
  final int deferred;
  const SyncRunReport({required this.synced, required this.conflicts, required this.deferred});
}

/// Processes queued offline SQLite mutations in strict chronological FIFO order.
/// - 200/201 -> SYNCED (Idempotent replay on server also returns 200/201)
/// - 409/422 -> CONFLICT (Preserved for explicit user resolution, never silently dropped)
/// - 5xx / Network error -> Reverts to PENDING for retry
class OutboxSyncWorker {
  final MizanLocalDb _db;
  final MizanApiClient _api;

  OutboxSyncWorker(this._db, this._api);

  Future<SyncRunReport> runOnce() async {
    final pending = await _db.fetchPendingOutbox();
    int synced = 0, conflicts = 0, deferred = 0;

    for (final row in pending) {
      final id = row['id'] as String;
      await _db.markOutboxStatus(id, 'SYNCING');
      try {
        final res = await _api.sendRaw(
          method: row['http_method'] as String,
          endpoint: row['endpoint'] as String,
          orgId: row['org_id'] as String,
          idempotencyKey: row['idempotency_key'] as String,
          payloadJson: row['payload_json'] as String,
        );

        if (res.statusCode >= 200 && res.statusCode < 300) {
          await _db.markOutboxStatus(id, 'SYNCED');
          synced++;
        } else if (res.statusCode == 409 || res.statusCode == 422 || res.statusCode == 403) {
          await _db.markOutboxStatus(id, 'CONFLICT', error: 'HTTP ${res.statusCode}: ${res.body}');
          conflicts++;
        } else {
          await _db.markOutboxStatus(id, 'PENDING', error: 'Transient HTTP ${res.statusCode}');
          deferred++;
        }
      } catch (e) {
        await _db.markOutboxStatus(id, 'PENDING', error: e.toString());
        deferred++;
      }
    }
    return SyncRunReport(synced: synced, conflicts: conflicts, deferred: deferred);
  }
}
