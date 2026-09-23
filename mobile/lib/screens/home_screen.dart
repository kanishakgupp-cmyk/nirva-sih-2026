import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import '../services/offline_evidence_queue.dart';
import '../services/offline_sync_service.dart';
import 'case_list_screen.dart';
import 'offline_queue_screen.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({required this.authService, CaseService? caseService, super.key})
      : caseService = caseService ?? FastApiCaseService();

  final AuthService authService;
  final CaseService caseService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Profile?> _profileFuture;
  late final OfflineFirstEvidenceService _syncService;
  late Future<int> _pendingCount;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.authService.getCurrentProfile();
    _syncService = OfflineFirstEvidenceService();
    _pendingCount = _refreshQueue();
    _syncAndRefresh();
  }

  Future<int> _refreshQueue() => OfflineEvidenceQueue().pendingCount();

  Future<void> _syncAndRefresh() async {
    await _syncService.syncPending();
    if (mounted) setState(() => _pendingCount = _refreshQueue());
  }

  Future<void> _signOut() async {
    await widget.authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Profile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = widget.authService.currentUser;
        final profile = snapshot.data ??
            Profile(
              id: user?.id ?? '',
              displayName: user?.email ?? 'NIRVA Officer',
              role: ProfileRole.officer,
            );

        return _HomeContent(
          profile: profile,
          onSignOut: _signOut,
          caseService: widget.caseService,
          pendingCount: _pendingCount,
          onSync: _syncAndRefresh,
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.profile,
    required this.onSignOut,
    required this.caseService,
    required this.pendingCount,
    required this.onSync,
  });

  final Profile profile;
  final VoidCallback onSignOut;
  final CaseService caseService;
  final Future<int> pendingCount;
  final VoidCallback onSync;

  void _openCases(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaseListScreen(caseService: caseService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NIRVA'),
            Text('Evidence operations', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth > 760 ? 40 : 20,
            vertical: 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Field Evidence & Verification',
                                style: theme.textTheme.headlineMedium),
                            const SizedBox(height: 8),
                            Text('Welcome, ${profile.displayName}',
                                style: theme.textTheme.titleMedium),
                          ],
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.badge_outlined, size: 18),
                        label: Text(profile.role.value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<int>(
                    future: pendingCount,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Card(
                        color: theme.colorScheme.tertiaryContainer,
                        child: ListTile(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const OfflineQueueScreen(),
                            ),
                          ),
                          leading: const Icon(Icons.cloud_upload_outlined),
                          title: Text('$count evidence item${count == 1 ? '' : 's'} waiting to sync'),
                          subtitle: const Text('Local capture is preserved. Server confirmation is still required.'),
                          trailing: IconButton(
                            tooltip: 'Sync pending evidence',
                            onPressed: onSync,
                            icon: const Icon(Icons.sync),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: theme.colorScheme.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 18,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth > 600
                                ? 480
                                : constraints.maxWidth - 48,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Start with a case',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(color: Colors.white)),
                                const SizedBox(height: 6),
                                const Text(
                                  'Create or open a case, then move through kit verification, evidence capture, analysis, and finalization.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => _openCases(context),
                            icon: const Icon(Icons.folder_open_outlined),
                            label: const Text('Open Cases'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.layers_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Officer workspace',
                          style: theme.textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _WorkspaceCard(
                        icon: Icons.folder_outlined,
                        title: 'Cases',
                        subtitle: 'Manage field investigations',
                        onTap: () => _openCases(context),
                      ),
                      const _WorkspaceCard(
                        icon: Icons.fingerprint,
                        title: 'Evidence integrity',
                        subtitle: 'Hashes and audit history appear after capture',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'NIRVA DEMONSTRATION MODE  •  INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
