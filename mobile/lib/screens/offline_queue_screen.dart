import 'package:flutter/material.dart';

import '../services/offline_evidence_queue.dart';
import '../services/offline_sync_service.dart';

class OfflineQueueScreen extends StatefulWidget {
  const OfflineQueueScreen({this.syncService, super.key});

  final OfflineFirstEvidenceService? syncService;

  @override
  State<OfflineQueueScreen> createState() => _OfflineQueueScreenState();
}

class _OfflineQueueScreenState extends State<OfflineQueueScreen> {
  late final OfflineEvidenceQueue _queue;
  late final OfflineFirstEvidenceService _syncService;
  late Future<List<PendingEvidence>> _items;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _queue = OfflineEvidenceQueue();
    _syncService = widget.syncService ?? OfflineFirstEvidenceService(queue: _queue);
    _items = _queue.list();
  }

  Future<void> _sync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    await _syncService.retryFailed();
    await _syncService.syncPending();
    if (mounted) {
      setState(() {
        _items = _queue.list();
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending synchronization'),
        actions: [
          IconButton(
            tooltip: 'Sync pending evidence',
            onPressed: _isSyncing ? null : _sync,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: FutureBuilder<List<PendingEvidence>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <PendingEvidence>[];
          if (items.isEmpty) {
            return const Center(child: Text('No evidence is waiting to sync.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: Icon(_iconFor(item.state)),
                  title: Text(_labelFor(item.state)),
                  subtitle: Text(
                    'Test ${item.testId}\n'
                    '${item.lastError ?? 'Waiting for server connection.'}',
                  ),
                  isThreeLine: true,
                  trailing: Text('${item.retryCount} retries'),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _isSyncing ? null : _sync,
            icon: const Icon(Icons.sync),
            label: const Text('Retry synchronization'),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(EvidenceSyncState state) {
    switch (state) {
      case EvidenceSyncState.pendingUpload:
      case EvidenceSyncState.retryPending:
        return Icons.schedule_outlined;
      case EvidenceSyncState.uploading:
        return Icons.cloud_upload_outlined;
      case EvidenceSyncState.syncFailed:
        return Icons.error_outline;
    }
  }

  static String _labelFor(EvidenceSyncState state) {
    switch (state) {
      case EvidenceSyncState.pendingUpload:
        return 'Pending upload';
      case EvidenceSyncState.uploading:
        return 'Uploading';
      case EvidenceSyncState.retryPending:
        return 'Retry pending';
      case EvidenceSyncState.syncFailed:
        return 'Synchronization failed';
    }
  }
}
