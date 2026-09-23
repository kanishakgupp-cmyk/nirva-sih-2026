import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/profile.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/supervisor_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'services/supervisor_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    runApp(
      const StartupErrorApp(
        message: 'Missing Supabase configuration. Start the app with '
            'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY passed through '
            '--dart-define.',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  } on Object catch (error) {
    runApp(StartupErrorApp(message: 'Unable to initialize Supabase: $error'));
    return;
  }

  runApp(NirvaApp());
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NIRVA',
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NirvaApp extends StatelessWidget {
  NirvaApp({super.key, AuthService? authService})
      : authService = authService ?? SupabaseAuthService();

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NIRVA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5563),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F8F8),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Color(0xFFF5F8F8),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFDCE6E7)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: AuthGate(authService: authService),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.authService,
    this.supervisorService,
    super.key,
  });

  final AuthService authService;

  /// Injectable for tests; created lazily for the authenticated supervisor shell.
  final SupervisorService? supervisorService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Profile?>? _profileFuture;
  String? _profileUserId;
  SupervisorService? _supervisorService;

  SupervisorService get _resolvedSupervisorService =>
      _supervisorService ??= widget.supervisorService ?? FastApiSupervisorService();

  @override
  void initState() {
    super.initState();
    _syncProfileFuture();
  }

  /// Reuse the in-flight/completed profile lookup so stream rebuilds do not
  /// replace the future and flash a loading indicator.
  void _syncProfileFuture() {
    final user = widget.authService.currentUser;
    if (user == null) {
      _profileForReset();
      return;
    }
    if (_profileUserId == user.id && _profileFuture != null) return;
    _profileUserId = user.id;
    _profileFuture = widget.authService.getCurrentProfile();
  }

  void _profileForReset() {
    _profileUserId = null;
    _profileFuture = null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: widget.authService.authStateChanges,
      builder: (context, snapshot) {
        // Session restoration is still resolving: show a stable loading state
        // instead of briefly rendering the login screen.
        if (snapshot.connectionState == ConnectionState.waiting &&
            widget.authService.currentSession == null) {
          return const _AuthLoadingScreen();
        }

        if (widget.authService.currentSession == null) {
          _profileForReset();
          return LoginScreen(authService: widget.authService);
        }

        _syncProfileFuture();

        return FutureBuilder<Profile?>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingScreen();
            }

            final profile = profileSnapshot.data;
            if (profile?.role == ProfileRole.supervisor ||
                profile?.role == ProfileRole.admin) {
              return SupervisorDashboardScreen(
                service: _resolvedSupervisorService,
                authService: widget.authService,
              );
            }
            return HomeScreen(authService: widget.authService);
          },
        );
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
