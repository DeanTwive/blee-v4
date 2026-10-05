import 'package:flutter/foundation.dart';
import '../../../core/utils/crash_reporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ICloudflareR2Repository {
  Future<String?> uploadReceiptImage({
    required String userId,
    required String runId,
    required Uint8List imageBytes,
  });
}

class CloudflareR2Repository implements ICloudflareR2Repository {
  SupabaseClient? _supabase;
  static const String _bucket = 'blee-run-receipts';
  static const String _publicCdnBase = 'https://receipts.blee.app';

  CloudflareR2Repository({SupabaseClient? supabase}) : _supabase = supabase;

  SupabaseClient? get _client {
    if (_supabase != null) return _supabase;
    try {
      _supabase = Supabase.instance.client;
      return _supabase;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> uploadReceiptImage({
    required String userId,
    required String runId,
    required Uint8List imageBytes,
  }) async {
    final client = _client;
    if (client == null) {
      debugPrint('[CloudflareR2Repository] Supabase not initialized, skipping receipt upload');
      return null;
    }
    final path = '$userId/$runId.png';
    try {
      // Upload to Supabase Storage (backed by S3/R2-compatible storage)
      await client.storage.from(_bucket).uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );

      final cdnUrl = '$_publicCdnBase/$path';

      // Persist the receipt URL to Supabase runs table if row exists
      try {
        await client
            .from('runs')
            .update({'run_receipt_url': cdnUrl})
            .eq('id', runId);
      } catch (e, st) {
        // Run record might still be syncing, log breadcrumb and continue
        AppCrashReporter.recordError(
          e,
          st,
          reason: 'update_run_receipt_url_non_blocking',
        );
      }

      return cdnUrl;
    } catch (e, st) {
      AppCrashReporter.recordError(
        e,
        st,
        reason: 'uploadReceiptImage_failed',
      );
      return null;
    }
  }
}

final cloudflareR2RepositoryProvider = Provider<ICloudflareR2Repository>((ref) {
  return CloudflareR2Repository();
});
