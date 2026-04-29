import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/storage_service.dart';
import 'services/audio_service.dart';
import 'models/song.dart';
import 'screens/splash_screen.dart';
import 'navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await StorageService.init();

  if (!kIsWeb) {
    await AudioService().initBackgroundService();
  }

  await _restoreLastPlayed();

  runApp(const SagaTunesApp());
}

Future<void> _restoreLastPlayed() async {
  if (AudioService().currentSong != null) return;

  final lastPlayed = StorageService.getLastPlayed();
  if (lastPlayed == null) return;
  
  final song = Song(
    id: lastPlayed['id'],
    name: lastPlayed['name'],
    artistName: lastPlayed['artistName'],
    imageUrl: lastPlayed['imageUrl'],
    streamUrl: lastPlayed['streamUrl'],
    albumName: lastPlayed['albumName'] ?? '',
    language: lastPlayed['language'] ?? '',
    duration: lastPlayed['duration'] ?? 0,
  );
  
  final position = StorageService.getLastPosition();
  
  // Load song into player WITHOUT auto-playing
  // Just set the current song so mini player shows it
  await AudioService().loadSongWithoutPlaying(song, position);
}

class SagaTunesApp extends StatefulWidget {
  const SagaTunesApp({super.key});

  @override
  State<SagaTunesApp> createState() => _SagaTunesAppState();
}

class _SagaTunesAppState extends State<SagaTunesApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only handle paused state to save position
    // DO NOT stop on detached - let audio_service handle app kill via onTaskRemoved
    if (state == AppLifecycleState.paused) {
      if (AudioService.instance.currentSong != null) {
        StorageService.saveLastPosition(
          AudioService.instance.position.inSeconds,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saga Tunes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        primaryColor: const Color(0xFFE8C547),
        textTheme: GoogleFonts.dmSansTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const AppRouter(),
      },
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
