import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/conversation_provider.dart';
import 'services/cactus_model_service.dart';
import 'pages/conversations_home_page.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize global Cactus model service
  // This loads the model ONCE at startup and keeps it in memory
  print('[EdgeScribe] Initializing Cactus Neural Engine...');
  try {
    await CactusModelService.instance.initialize();
    print('[EdgeScribe] ✓ Neural Engine ready');
  } catch (e) {
    print('[EdgeScribe] ✗ Neural Engine failed to initialize: $e');
    // Continue anyway - app can still work with LLM features disabled
  }

  runApp(const EdgeScribeApp());
}

class EdgeScribeApp extends StatelessWidget {
  const EdgeScribeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider.value(value: CactusModelService.instance),
      ],
      child: MaterialApp(
        title: 'EdgeScribe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00D9FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const AppBootScreen(),
      ),
    );
  }
}

/// Boot screen that shows while the Cactus model loads
class AppBootScreen extends StatefulWidget {
  const AppBootScreen({super.key});

  @override
  State<AppBootScreen> createState() => _AppBootScreenState();
}

class _AppBootScreenState extends State<AppBootScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<CactusModelService>(
      builder: (context, modelService, _) {
        // If model is loaded, show main app
        if (modelService.isLoaded) {
          // Use a microtask to avoid building during build
          Future.microtask(() {
            if (mounted && context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const ConversationsHomePage(),
                ),
              );
            }
          });
        }

        // Show loading screen
        return Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Neural engine icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    size: 48,
                    color: Color(0xFF00D9FF),
                  ),
                ),
                const SizedBox(height: 32),

                // Loading indicator
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00D9FF),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),

                // Status text
                Text(
                  'Booting Neural Engine...',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                // Progress indicator
                if (modelService.loadingProgress != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: modelService.loadingProgress,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF00D9FF),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(modelService.loadingProgress! * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Status message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    modelService.loadingStatus,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
