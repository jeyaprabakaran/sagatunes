import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/library_screen.dart';
import '../screens/player_screen.dart';
import '../screens/album_screen.dart';
import '../services/audio_service.dart';
import '../models/song.dart';
import '../widgets/mini_player.dart';
import 'package:flutter/services.dart';

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});
  static final tabController = ValueNotifier<int>(0);

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/player':
        return MaterialPageRoute(builder: (_) => const PlayerScreen());
      case '/album':
        final args = settings.arguments as Map<String, String>? ?? {};
        return MaterialPageRoute(
          builder: (_) => AlbumScreen(
            albumId: args['albumId'] ?? '',
            albumName: args['albumName'] ?? '',
            artistName: args['artistName'] ?? '',
            imageUrl: args['imageUrl'] ?? '',
            year: args['year'] ?? '',
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  final AudioService _audioService = AudioService();

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _selectedIndex = 0;
  int _previousIndex = 0; // to restore after returning from PlayerScreen

  @override
  void initState() {
    super.initState();
    AppRouter.tabController.addListener(_onTabChange);
  }

  @override
  void dispose() {
    AppRouter.tabController.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (mounted) setState(() => _selectedIndex = AppRouter.tabController.value);
  }

  void _switchTab(int index) {
    if (_selectedIndex == index) return;
    
    String routeName = '/home_tab';
    if (index == 1) {
      routeName = '/search';
    } else if (index == 3) {
      routeName = '/library';
    }
    
    _navigatorKey.currentState?.pushNamed(routeName);
    
    setState(() => _selectedIndex = index);
    AppRouter.tabController.value = index;
  }
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = _navigatorKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Stack(
          children: [
            Navigator(
              key: _navigatorKey,
              initialRoute: '/home_tab',
              onGenerateRoute: (settings) {
                Widget page;
                switch (settings.name) {
                  case '/home_tab': page = const HomeScreen(); break;
                  case '/search': page = const SearchScreen(); break;
                  case '/library': page = const LibraryScreen(); break;
                  default: page = const SizedBox.shrink();
                }
                return MaterialPageRoute(builder: (_) => page);
              },
            ),
            const Positioned(
              left: 0, right: 0, bottom: 0,
              child: MiniPlayer(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(context),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0F),
        border: Border(top: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
      ),
      child: Row(
        children: [
          // 0 — Home
          _navItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
            index: 0,
            onTap: () => _switchTab(0),
          ),

          // 1 — Search
          _navItem(
            icon: Icons.search,
            activeIcon: Icons.search,
            label: 'Search',
            index: 1,
            onTap: () => _switchTab(1),
          ),

          // Center — Gold circle: play/pause ONLY, NO navigation
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_audioService.isPlaying) {
                  _audioService.pause();
                } else {
                  _audioService.resume();
                }
              },
              child: Center(
                child: StreamBuilder<Song?>(
                  stream: _audioService.currentSongStream,
                  builder: (ctx, snap) {
                    final song = snap.data ?? _audioService.currentSong;
                    return StreamBuilder<bool>(
                      stream: _audioService.playingStream,
                      builder: (ctx, playSnap) {
                        final playing = playSnap.data ?? false;
                        return Container(
                          width: 52,
                          height: 52,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE8C547),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE8C547)
                                    .withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (song != null && song.imageUrl.isNotEmpty)
                                ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: song.imageUrl,
                                    width: 52, height: 52,
                                    fit: BoxFit.cover,
                                    errorWidget: (c, u, e) =>
                                        const SizedBox(),
                                  ),
                                ),
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.3),
                                ),
                              ),
                              Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 26,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          // 2 — Now Playing: headphones icon → navigates to /player
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_selectedIndex != 2) _previousIndex = _selectedIndex;
                setState(() => _selectedIndex = 2);
                AppRouter.tabController.value = 2;
                Navigator.of(context, rootNavigator: true).pushNamed('/player').then((_) {
                  if (mounted) {
                    setState(() => _selectedIndex = _previousIndex);
                    AppRouter.tabController.value = _previousIndex;
                  }
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.headphones_outlined,
                    size: 22,
                    color: _selectedIndex == 2
                        ? const Color(0xFFE8C547)
                        : const Color(0xFF7A7890),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Now Playing',
                    style: TextStyle(
                      fontSize: 10,
                      color: _selectedIndex == 2
                          ? const Color(0xFFE8C547)
                          : const Color(0xFF7A7890),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3 — Library
          _navItem(
            icon: Icons.library_music_outlined,
            activeIcon: Icons.library_music,
            label: 'Library',
            index: 3,
            onTap: () => _switchTab(3),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final isActive = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive
                  ? const Color(0xFFE8C547)
                  : const Color(0xFF7A7890),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive
                    ? const Color(0xFFE8C547)
                    : const Color(0xFF7A7890),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
