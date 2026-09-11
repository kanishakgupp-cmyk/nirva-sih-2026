import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
	WidgetsFlutterBinding.ensureInitialized();

	const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
	const supabasePublishableKey =
			String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

	if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
		throw StateError(
			'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be provided with '
			'--dart-define.',
		);
	}

	await Supabase.initialize(
		url: supabaseUrl,
		publishableKey: supabasePublishableKey,
	);

	runApp(const NirvaApp());
}

class NirvaApp extends StatelessWidget {
	const NirvaApp({super.key});

	@override
	Widget build(BuildContext context) {
		return MaterialApp(
			title: 'NIRVA',
			debugShowCheckedModeBanner: false,
			theme: ThemeData(
				colorScheme: ColorScheme.fromSeed(
					seedColor: const Color(0xFF00695C),
					brightness: Brightness.light,
				),
				useMaterial3: true,
				inputDecorationTheme: const InputDecorationTheme(
					border: OutlineInputBorder(),
				),
			),
			home: const NirvaHomeScreen(),
		);
	}
}

class NirvaHomeScreen extends StatelessWidget {
	const NirvaHomeScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);

		return Scaffold(
			body: Center(
				child: Padding(
					padding: const EdgeInsets.all(24),
					child: ConstrainedBox(
						constraints: const BoxConstraints(maxWidth: 520),
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								Text(
									'NIRVA',
									style: theme.textTheme.displaySmall?.copyWith(
										fontWeight: FontWeight.bold,
										color: theme.colorScheme.primary,
									),
								),
								const SizedBox(height: 12),
								Text(
									'Field Evidence & Verification',
									textAlign: TextAlign.center,
									style: theme.textTheme.titleLarge,
								),
								const SizedBox(height: 32),
								Text(
									'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
									textAlign: TextAlign.center,
									style: theme.textTheme.labelLarge?.copyWith(
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
