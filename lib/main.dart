import 'package:flutter/material.dart';
import 'features/library/audio_library_page.dart';
import 'features/library/library_service.dart';
import 'features/tts/model_manager.dart';
import 'features/tts/pocket_tts_service.dart';
import 'features/tts/tts_controller.dart';
import 'features/tts/tts_page.dart';
import 'features/tts/voice_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final modelManager = ModelManager();
  final voiceManager = VoiceManager(modelManager: modelManager);
  final ttsService = PocketTtsService(modelManager: modelManager);
  final libraryService = LibraryService();

  final controller = TtsController(
    modelManager: modelManager,
    voiceManager: voiceManager,
    ttsService: ttsService,
    libraryService: libraryService,
  );

  await controller.initialize();

  runApp(PocketVoiceApp(controller: controller));
}

class PocketVoiceApp extends StatelessWidget {
  final TtsController controller;

  const PocketVoiceApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1D4ED8); // Pixel studio blue

    return MaterialApp(
      title: 'Pocket Voice',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
      ),
      home: AppScaffold(controller: controller),
    );
  }
}

class AppScaffold extends StatefulWidget {
  final TtsController controller;

  const AppScaffold({super.key, required this.controller});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pages = [
          TtsPage(controller: widget.controller),
          AudioLibraryPage(controller: widget.controller),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) {
              setState(() => _currentIndex = idx);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.mic_none_rounded),
                selectedIcon: Icon(Icons.mic_rounded),
                label: 'Studio',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music_rounded),
                label: 'Library',
              ),
            ],
          ),
        );
      },
    );
  }
}
