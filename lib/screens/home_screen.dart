import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../widgets/song_three_dots.dart';
import '../services/jiosaavn_service.dart';
import '../services/audio_service.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final JioSaavnService _api = JioSaavnService();
  final AudioService _player = AudioService();
  
  DateTime? _lastBackPress;
  
  final List<String> _languages = ['All', 'Ambient', 'Jazz', 'Lo-fi', 'Tamil', 'Hindi', 'Telugu', 'Malayalam', 'Kannada', 'English'];
  String _selectedLang = 'All';
  
  bool _isLoading = true;
  String? _error;
  List<Song> _songs = [];
  static const int _multiplier = 10000;
  final PageController _heroController = PageController(
    initialPage: _multiplier ~/ 2,
  );
  List<Song> _heroSongs = [];
  int _heroIndex = 0;
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  String get _mappedQuery {
    switch(_selectedLang.toLowerCase()) {
      case 'all': return 'top hits 2025';
      case 'ambient': return 'ambient music';
      case 'jazz': return 'jazz blues';
      case 'lo-fi': return 'lofi study';
      case 'english': return 'top english hits';
      case 'hindi': return 'top hindi songs';
      case 'telugu': return 'top telugu songs';
      case 'malayalam': return 'top malayalam songs';
      case 'kannada': return 'top kannada songs';
      default: return 'top tamil songs';
    }
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final songs = await _api.searchSongs(_mappedQuery);
      if (mounted) {
        setState(() { 
          _songs = songs; 
          _heroSongs = songs.take(6).toList();
          _isLoading = false; 
        });
        
        _heroTimer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _startHeroTimer();
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        setState(() { _error = "Couldn't load songs. Tap to retry"; _isLoading = false; });
      }
    }
  }

  void _startHeroTimer() {
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_heroSongs.isEmpty) return;
      if (!_heroController.hasClients) return;
      _heroController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut);
    });
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _playSong(Song song, int index) {
    _player.playSong(song, _songs, index);
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      child: Center(
        child: Column(
          children: [
            const Text('SAGA TUNES',
              style: TextStyle(fontFamily: 'BebasNeue', fontSize: 36, color: Color(0xFFE8C547), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('FREE · ALWAYS',
              style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF7A7890), letterSpacing: 2, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCarousel() {
    if (_heroSongs.isEmpty) {
      return Container(
        height: 220,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator(
          color: Color(0xFFE8C547))),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _heroController,
            onPageChanged: (i) => setState(() => _heroIndex = i % _heroSongs.length),
            itemCount: _heroSongs.isEmpty ? 1 : _heroSongs.length * _multiplier,
            itemBuilder: (ctx, i) {
              final song = _heroSongs[i % _heroSongs.length];
              return _buildHeroSlide(song);
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_heroSongs.length, (i) =>
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _heroIndex == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _heroIndex == i
                  ? const Color(0xFFE8C547)
                  : const Color(0xFF2E2E45),
                borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSlide(Song song) {
    return GestureDetector(
      onTap: () {
        _player.playSong(song, _heroSongs, 
          _heroSongs.indexOf(song));
        Navigator.pushNamed(context, '/player');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1E1E2E),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background album art
            CachedNetworkImage(
              imageUrl: song.imageUrl.replaceAll('150x150', '500x500'),
              fit: BoxFit.cover,
              errorWidget: (c,u,e) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E1A40),
                      Color(0xFF2D1F4E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight))),
            ),
            // Dark gradient overlay (bottom)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  )),
              ),
            ),
            // Content overlay
            Positioned(
              left: 16, right: 60, bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [

                  Text(song.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(song.artistName,
                    style: const TextStyle(
                      color: Color(0xFFA09EB8), fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Play button
            Positioned(
              right: 16, bottom: 16,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8C547),
                  shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow,
                  color: Color(0xFF0A0A0F), size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageChips() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isActive = _selectedLang == lang;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedLang = lang);
              _fetchData();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFE8C547) : const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? Colors.transparent : const Color(0xFF2E2E45)),
              ),
              child: Text(lang,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? const Color(0xFF0A0A0F) : const Color(0xFF7A7890),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackRow(Song song, int index) {
    return GestureDetector(
      onTap: () => _playSong(song, index),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: song.imageUrl,
                width: 56, height: 56, fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(color: const Color(0xFF1E1E2E), width: 56, height: 56),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(song.artistName, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF7A7890)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(_formatDuration(song.duration), style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF7A7890))),
            const SizedBox(width: 4),
            SongThreeDots(song: song),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit Saga Tunes'),
              backgroundColor: Color(0xFF1E1E2E),
              duration: Duration(seconds: 2)));
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopSection(),
              Expanded(
                child: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8C547)))
                  : _error != null ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFF7A7890), size: 48),
                          const SizedBox(height: 16),
                          Text(_error!, style: const TextStyle(color: Color(0xFF7A7890))),
                          TextButton(onPressed: _fetchData, child: const Text('Retry', style: TextStyle(color: Color(0xFFE8C547)))),
                        ]
                      )
                    )
                  : _songs.isEmpty ? const Center(child: Text("No songs found", style: TextStyle(color: Color(0xFF7A7890))))
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 120),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildHeroCarousel(),
                        const SizedBox(height: 24),
                        _buildLanguageChips(),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('TOP CHARTS', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF7A7890), letterSpacing: 2)),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(
                          _songs.length > 1 ? _songs.length - 1 : 0, 
                          (index) => _buildTrackRow(_songs[index + 1], index + 1)
                        ),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
