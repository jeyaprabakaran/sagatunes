import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/playlist.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../widgets/song_three_dots.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final AudioService _player = AudioService();
  final FocusNode _librarySearchFocus = FocusNode();
  final TextEditingController _playlistNameController = TextEditingController();

  String _selectedTab = 'Playlists';
  final List<String> _tabs = ['Playlists', 'Downloads', 'Liked', 'Albums'];

  List<Playlist> _playlists = [];
  List<Song> _downloads = [];
  List<Song> _liked = [];
  List<Album> _likedAlbums = [];

  // FIX 4: tracks which playlist is expanded
  String? _expandedPlaylistId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _librarySearchFocus.dispose();
    _playlistNameController.dispose();
    super.dispose();
  }

  void _loadData() {
    if (mounted) {
      setState(() {
        _playlists = StorageService.getAllPlaylists();
        _downloads = StorageService.getAllDownloads();
        _liked = StorageService.getAllLiked();
        _likedAlbums = StorageService.getAllLikedAlbums();
      });
    }
  }

  void _playSelection(List<Song> songs, int index) {
    if (songs.isNotEmpty) {
      _player.playSong(songs[index], songs, index);
      Navigator.pushNamed(context, '/player');
    }
  }

  String _formatDuration(List<Song> songs) {
    final totalSecs = songs.fold(0, (sum, s) => sum + s.duration);
    final hours = totalSecs ~/ 3600;
    final mins = (totalSecs % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
  }

  bool _isOffline(List<Song> songs) {
    if (songs.isEmpty) return false;
    return songs.every((s) => StorageService.isDownloaded(s.id));
  }

  double _totalSize(List<Song> songs) {
    final totalSecs = songs.fold(0, (sum, s) => sum + s.duration);
    return (totalSecs / 60) * 2.4;
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    _playlistNameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: _playlistNameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name...',
            hintStyle: TextStyle(color: Color(0xFF7A7890)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF2E2E45))),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE8C547))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF7A7890)))),
          TextButton(
            onPressed: () async {
              if (_playlistNameController.text.isNotEmpty) {
                await StorageService.createPlaylist(_playlistNameController.text.trim());
                _loadData();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Create', style: TextStyle(color: Color(0xFFE8C547)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildTabs(),
            Expanded(child: _buildCurrentTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFF2A2A3E)),
            child: const Icon(Icons.person,
                color: Color(0xFFE8C547), size: 22),
          ),
          const SizedBox(width: 12),
          const Text('Your Library',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(
            onTap: () => _showCreatePlaylistDialog(context),
            child: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFF1E1E2E)),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFF1E1E2E), width: 1))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: _tabs.map((tab) => GestureDetector(
            onTap: () => setState(() => _selectedTab = tab),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedTab == tab
                    ? const Color(0xFFE8C547)
                    : Colors.transparent,
                border: _selectedTab == tab
                    ? null
                    : Border.all(color: const Color(0xFF2E2E45)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(tab,
                style: TextStyle(
                  color: _selectedTab == tab
                      ? const Color(0xFF0A0A0F)
                      : const Color(0xFF7A7890),
                  fontWeight: _selectedTab == tab
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 14,
                )),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    if (_selectedTab == 'Playlists') return _buildPlaylistsTab();
    if (_selectedTab == 'Downloads') return _buildDownloadsTab();
    if (_selectedTab == 'Liked') return _buildLikedTab();
    return _buildAlbumsTab();
  }

  // ─── Playlists Tab (FIX 4) ─────────────────────────────────────────────────

  Widget _buildPlaylistsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: _playlists.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) return _buildNewPlaylistCard();
                return _buildPlaylistCard(_playlists[i - 1]);
              },
            ),
          ),

          // Expanded playlist content
          if (_expandedPlaylistId != null) ...[
            () {
              final playlist = _playlists.firstWhere(
                (p) => p.id == _expandedPlaylistId,
                orElse: () =>
                    Playlist(id: '', name: '', songs: []),
              );
              if (playlist.id.isEmpty) return const SizedBox.shrink();
              return _buildExpandedPlaylist(playlist);
            }(),
          ],

          const SizedBox(height: 32),
          _buildRecentlyDownloadedSection(),
        ],
      ),
    );
  }

  Widget _buildExpandedPlaylist(Playlist playlist) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header row: Play All + Delete
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    if (playlist.songs.isEmpty) return;
                    _player.playSong(
                        playlist.songs[0], playlist.songs, 0);
                    Navigator.pushNamed(context, '/player');
                  },
                  icon: const Icon(Icons.play_arrow,
                      color: Color(0xFFE8C547), size: 18),
                  label: const Text('Play All',
                      style: TextStyle(
                          color: Color(0xFFE8C547), fontSize: 13)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E2E),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('Delete Playlist?',
                            style: TextStyle(color: Colors.white)),
                        content: Text(
                            'Delete "${playlist.name}"?',
                            style: const TextStyle(
                                color: Color(0xFF7A7890))),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, false),
                              child: const Text('Cancel',
                                  style: TextStyle(
                                      color: Color(0xFF7A7890)))),
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, true),
                              child: const Text('Delete',
                                  style: TextStyle(
                                      color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await StorageService.deletePlaylist(
                          playlist.id);
                      setState(() {
                        _playlists = StorageService.getAllPlaylists();
                        _expandedPlaylistId = null;
                      });
                    }
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  label: const Text('Delete',
                      style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2E2E45), height: 1),

          // Song list
          if (playlist.songs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No songs yet. Add songs from any song menu.',
                    style: TextStyle(color: Color(0xFF7A7890)),
                    textAlign: TextAlign.center)))
          else
            ...playlist.songs.map((song) => ListTile(
              dense: true,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: song.imageUrl,
                  width: 40, height: 40,
                  fit: BoxFit.cover,
                  errorWidget: (c, u, e) => Container(
                    width: 40, height: 40,
                    color: const Color(0xFF0A0A0F),
                    child: const Icon(Icons.music_note,
                        color: Color(0xFF7A7890), size: 16)),
                ),
              ),
              title: Text(song.name,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(song.artistName,
                style: const TextStyle(
                    color: Color(0xFF7A7890), fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await StorageService.removeSongFromPlaylist(
                          playlist.id, song.id);
                      setState(() {
                        _playlists = StorageService.getAllPlaylists();
                        // Refresh expanded playlist
                        final updated = _playlists.where(
                          (p) => p.id == playlist.id).toList();
                        if (updated.isEmpty) _expandedPlaylistId = null;
                      });
                    },
                    child: const Icon(Icons.remove_circle_outline,
                        color: Color(0xFF7A7890), size: 18)),
                  const SizedBox(width: 4),
                  SongThreeDots(song: song),
                ],
              ),
              onTap: () {
                _player.playSong(
                    song, playlist.songs, playlist.songs.indexOf(song));
                Navigator.pushNamed(context, '/player');
              },
            )),
        ],
      ),
    );
  }

  Widget _buildNewPlaylistCard() {
    return GestureDetector(
      onTap: () => _showCreatePlaylistDialog(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: const Color(0xFF1A1A2E),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFE8C547), width: 2),
                    color: const Color(0xFF1E1E2E)),
                child: const Icon(Icons.person,
                    color: Color(0xFFE8C547), size: 20),
              ),
              const SizedBox(height: 10),
              const Text('New Playlist',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradientFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF2E2E45), Color(0xFF1E1E2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: const Center(
          child:
              Icon(Icons.music_note, color: Color(0xFF7A7890), size: 32)),
    );
  }

  Widget _buildPlaylistCard(Playlist playlist) {
    final isExpanded = _expandedPlaylistId == playlist.id;
    return GestureDetector(
      onTap: () => setState(() {
        _expandedPlaylistId =
            isExpanded ? null : playlist.id;
      }),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: isExpanded
              ? const Color(0xFF2A2A3E) // highlight when expanded
              : const Color(0xFF1A1A2E),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    playlist.songs.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: playlist.songs[0].imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => _gradientFallback())
                        : _gradientFallback(),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? const Color(0xFF2DBE78)
                              : const Color(0xFFE8C547),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.access_time,
                          color: const Color(0xFF0A0A0F),
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(playlist.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                          '${playlist.songs.length} tracks • ${_formatDuration(playlist.songs)}',
                          style: const TextStyle(
                              color: Color(0xFF7A7890), fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOffline(playlist.songs)
                                  ? const Color(0xFFE8C547)
                                  : const Color(0xFF7A7890),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                              _isOffline(playlist.songs)
                                  ? 'OFFLINE'
                                  : 'ONLINE',
                              style: TextStyle(
                                  color: _isOffline(playlist.songs)
                                      ? const Color(0xFFE8C547)
                                      : const Color(0xFF7A7890),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyDownloadedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recently Downloaded',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => setState(() => _selectedTab = 'Downloads'),
                child: const Text('See All',
                    style:
                        TextStyle(color: Color(0xFFE8C547), fontSize: 14)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_downloads.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 48),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.download_outlined,
                      color: Color(0xFF7A7890), size: 48),
                  SizedBox(height: 8),
                  Text('No downloads yet',
                      style: TextStyle(color: Color(0xFF7A7890))),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _downloads.length > 5 ? 5 : _downloads.length,
            itemBuilder: (context, index) =>
                _buildTrackRow(_downloads[index], index, _downloads),
          ),
      ],
    );
  }

  // ─── Downloads Tab ─────────────────────────────────────────────────────────

  Widget _buildDownloadsTab() {
    if (_downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.download_outlined,
                color: Color(0xFF7A7890), size: 64),
            Text('No downloads yet',
                style: TextStyle(color: Color(0xFF7A7890))),
            Text('Tap ↓ on any song to save offline',
                style: TextStyle(color: Color(0xFF7A7890), fontSize: 12)),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                  '${_downloads.length} songs · ${_totalSize(_downloads).toStringAsFixed(1)} MB',
                  style: const TextStyle(
                      color: Color(0xFF7A7890), fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: _downloads.length,
            itemBuilder: (ctx, i) =>
                _buildTrackRow(_downloads[i], i, _downloads),
          ),
        ),
      ],
    );
  }

  // ─── Liked Tab (FIX 2A) ────────────────────────────────────────────────────

  Widget _buildLikedTab() {
    if (_liked.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.favorite_border,
                color: Color(0xFF7A7890), size: 64),
            Text('No liked songs yet',
                style: TextStyle(color: Color(0xFF7A7890))),
            Text('Tap ♡ on any song to save it here',
                style: TextStyle(color: Color(0xFF7A7890), fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: _liked.length,
      itemBuilder: (ctx, i) => _buildLikedRow(_liked[i], i),
    );
  }

  // Liked song row with unlike button (FIX 2A)
  Widget _buildLikedRow(Song song, int index) {
    return GestureDetector(
      onTap: () => _playSelection(_liked, index),
      child: Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: song.imageUrl,
                width: 52, height: 52,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) => Container(
                    width: 52, height: 52,
                    color: const Color(0xFF1E1E2E),
                    child: const Icon(Icons.music_note,
                        color: Color(0xFF7A7890))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(song.artistName,
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: const Color(0xFF7A7890)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Unlike button (FIX 2A)
            GestureDetector(
              onTap: () async {
                await StorageService.unlikeSong(song.id);
                setState(() => _liked = StorageService.getAllLiked());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Removed from Liked'),
                    backgroundColor: Color(0xFF1E1E2E),
                    duration: Duration(seconds: 1)));
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.favorite,
                    color: Color(0xFFE8C547), size: 22)),
            ),
            SongThreeDots(song: song),
          ],
        ),
      ),
    );
  }

  // ─── Albums Tab (FIX 2B) ───────────────────────────────────────────────────

  Widget _buildAlbumsTab() {
    if (_likedAlbums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.album_outlined, color: Color(0xFF7A7890), size: 64),
            SizedBox(height: 12),
            Text('No saved albums yet',
                style: TextStyle(color: Color(0xFF7A7890))),
            SizedBox(height: 4),
            Text('Tap ♥ on any album page to save it',
                style: TextStyle(
                    color: Color(0xFF7A7890), fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: _likedAlbums.length,
      itemBuilder: (ctx, i) => _buildAlbumRow(_likedAlbums[i]),
    );
  }

  Widget _buildAlbumRow(Album album) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: album.imageUrl,
          width: 52, height: 52,
          fit: BoxFit.cover,
          errorWidget: (c, u, e) => Container(
              width: 52, height: 52,
              color: const Color(0xFF1E1E2E),
              child: const Icon(Icons.album,
                  color: Color(0xFF7A7890))),
        ),
      ),
      title: Text(album.name,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${album.artistName}${album.year.isNotEmpty ? ' • ${album.year}' : ''}',
          style: const TextStyle(
              color: Color(0xFF7A7890), fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              await StorageService.unlikeAlbum(album.id);
              setState(() =>
                  _likedAlbums = StorageService.getAllLikedAlbums());
            },
            child: const Icon(Icons.favorite,
                color: Color(0xFFE8C547), size: 22)),
          const SizedBox(width: 8),
          const Icon(Icons.more_vert,
              color: Color(0xFF7A7890), size: 20),
        ],
      ),
      onTap: () => Navigator.pushNamed(context, '/album', arguments: {
        'albumId': album.id,
        'albumName': album.name,
        'artistName': album.artistName,
        'imageUrl': album.imageUrl,
        'year': album.year,
      }),
    );
  }

  // ─── Generic Track Row ─────────────────────────────────────────────────────

  Widget _buildTrackRow(Song song, int index, List<Song> list) {
    final isOffline = StorageService.isDownloaded(song.id);
    return GestureDetector(
      onTap: () => _playSelection(list, index),
      child: Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: song.imageUrl,
                width: 56, height: 56,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) => Container(
                    color: const Color(0xFF1E1E2E),
                    width: 56, height: 56),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                          child: Text(song.artistName,
                              style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: const Color(0xFF7A7890)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      if (isOffline)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFF2DBE78)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('OFFLINE',
                              style: GoogleFonts.dmSans(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2DBE78))),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SongThreeDots(
              song: song,
              onDelete: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E2E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('Delete Download?',
                        style: TextStyle(color: Colors.white, fontSize: 17)),
                    content: Text(
                        'Remove "${song.name}" from downloads?\n'
                        'You will need internet to play it again.',
                        style: const TextStyle(
                            color: Color(0xFF7A7890), fontSize: 14)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel',
                              style: TextStyle(color: Color(0xFF7A7890)))),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                );

                if (confirm == true) {
                  await StorageService.deleteDownload(song.id);
                  if (mounted) {
                    setState(() {
                      _downloads = StorageService.getAllDownloads();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('"${song.name}" deleted from downloads',
                            style: const TextStyle(color: Colors.white)),
                        backgroundColor: const Color(0xFF1E1E2E),
                        duration: const Duration(seconds: 2)));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
