import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/database/hive_adapters.dart';
import 'core/providers/database_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  const profile = String.fromEnvironment('APP_PROFILE', defaultValue: 'main_peer');
  final subDir = profile == 'main_peer' ? null : profile;
  await Hive.initFlutter(subDir);
  Hive.registerAdapter(PeerModelAdapter());
  Hive.registerAdapter(MessageModelAdapter());
  Hive.registerAdapter(UserProfileAdapter());
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbInitState = ref.watch(databaseInitProvider);

    return MaterialApp(
      title: 'Liaoke',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B4EBA),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: dbInitState.when(
        data: (_) {
          final profile = ref.watch(userProfileProvider);
          if (profile == null) {
            return const WelcomeScreen();
          }
          return const HomeScreen();
        },
        loading: () => const SplashScreen(message: 'Initializing local database...'),
        error: (err, stack) => InitErrorScreen(error: err.toString()),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  final String message;

  const SplashScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing radar/pulse effect simulated by progress bar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 8,
                  )
                ],
              ),
              child: const Icon(
                Icons.radar,
                color: Color(0xFF6366F1),
                size: 64,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'GRYCHAT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'P2P SECURE FILE SYNCHRONIZATION',
              style: TextStyle(
                color: Color(0xFF818CF8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 150,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InitErrorScreen extends ConsumerWidget {
  final String error;

  const InitErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 64,
              ),
              const SizedBox(height: 24),
              const Text(
                'Initialization Failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () {
                  // Invalidate databaseInitProvider to trigger re-initialization
                  ref.invalidate(databaseInitProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}