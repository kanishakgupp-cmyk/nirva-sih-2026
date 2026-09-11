import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.authService, super.key});

  final AuthService authService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Profile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.authService.getCurrentProfile();
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
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.profile, required this.onSignOut});

  final Profile profile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final features = const [
      ('Cases', Icons.folder_outlined),
      ('Start Test', Icons.play_circle_outline),
      ('Evidence History', Icons.history),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('NIRVA'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Field Evidence & Verification',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome, ${profile.displayName}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Chip(
                  avatar: const Icon(Icons.badge_outlined, size: 18),
                  label: Text(profile.role.value),
                ),
                const SizedBox(height: 28),
                ...features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: Icon(feature.$2),
                      label: Text('${feature.$1} - Coming in next phase'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
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
    );
  }
}
