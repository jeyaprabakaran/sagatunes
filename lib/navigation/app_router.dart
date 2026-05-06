import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

// Internal imports - keeping these as per your structure
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/library_screen.dart';
import '../screens/player_screen.dart';
import '../screens/album_screen.dart';
import '../services/audio_service.dart';
import '../models/song.dart';
import '../widgets/mini_player.dart';

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
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  final AudioService _audioService = AudioService();

  // List of keys for each tab's Navigator
  final List<GlobalKey<NavigatorState>> _tabNavKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  int _selectedIndex = 0;
  int _previousIndex = 0;
  DateTime? _lastBackPressed;

  // Maps the 4 bottom nav items to the 3 actual screens in the IndexedStack
  // (0: Home, 1: Search, 2: Player/Modal, 3: Library)
  int get _stackIndex => _selectedIndex == 3 ? 2 : _selectedIndex;

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
    if (_selectedIndex == index) {
      // Tap same tab → pop to root of that specific tab's navigator
      final stackIdx = index == 3 ? 2 : index;
      _tabNavKeys[stackIdx].currentState?.popUntil((r) => r.isFirst);
      return;
    }

    // FIX: When leaving Search (Index 1), replace its GlobalKey.
    // This forces the Navigator to dispose, clearing the SearchScreen state.
    if (_selectedIndex == 1) {
      _tabNavKeys[1] = GlobalKey<NavigatorState>();
    }

    setState(() => _selectedIndex = index);
    AppRouter.tabController.value = index;
  }

  Future<bool> _onWillPop() async {
    final currentNav = _tabNavKeys[_stackIndex].currentState;

    // 1. Try to pop the internal tab navigator first
    if (currentNav != null && currentNav.canPop()) {
      currentNav.pop();
      return false;
    }

    // 2. If at the root of a tab, but not Home, go back to Home
    if (_selectedIndex != 0) {
      _switchTab(
        0,
      ); // This triggers the search reset logic if coming from Search
      return false;
    }

    // 3. Double-tap to exit logic for the Home tab
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Widget _buildTabNavigator(int stackIndex, Widget screen) {
    return Navigator(
      key: _tabNavKeys[stackIndex],
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Stack(
          children: [
            IndexedStack(
              index: _stackIndex,
              children: [
                _buildTabNavigator(0, const HomeScreen()),
                _buildTabNavigator(1, const SearchScreen()),
                _buildTabNavigator(2, const LibraryScreen()),
              ],
            ),
            const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
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
          _navItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
            index: 0,
            onTap: () => _switchTab(0),
          ),
          _navItem(
            icon: Icons.search,
            activeIcon: Icons.search,
            label: 'Search',
            index: 1,
            onTap: () => _switchTab(1),
          ),

          // Central Play/Pause Button
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
                                color: const Color(
                                  0xFFE8C547,
                                ).withValues(alpha: 0.25),
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
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorWidget: (c, u, e) => const SizedBox(),
                                  ),
                                ),
                              Container(
                                width: 52,
                                height: 52,
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

          // Now Playing Tab (Opens full-screen player)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_selectedIndex != 2) _previousIndex = _selectedIndex;
                setState(() => _selectedIndex = 2);
                AppRouter.tabController.value = 2;
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/player').then((_) {
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
