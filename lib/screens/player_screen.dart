import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../models/song.dart';
import '../services/jiosaavn_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioService _player = AudioService();
  final JioSaavnService _api = JioSaavnService();

  // FIX 2 — Add to Playlist sheet
  void _showAddToPlaylistSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final playlists = StorageService.getAllPlaylists();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E45),
                  borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Icon(Icons.playlist_add,
                    color: Color(0xFFE8C547), size: 22),
                  const SizedBox(width: 8),
                  const Text('Add to Playlist',
                    style: TextStyle(color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
              ),
              const Divider(color: Color(0xFF2E2E45), height: 20),

              // Create new playlist option (always first)
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE8C547), width: 1.5),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add, color: Color(0xFFE8C547), size: 22)),
                title: const Text('Create New Playlist',
                  style: TextStyle(color: Color(0xFFE8C547),
                    fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreatePlaylistDialog(context);
                },
              ),

              // If no playlists yet
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No playlists yet. Create one above!',
                    style: TextStyle(color: Color(0xFF7A7890)),
                    textAlign: TextAlign.center))
              else ...[
                const Divider(color: Color(0xFF2E2E45), height: 1),
                // List all existing playlists
                ...playlists.map((playlist) => ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0F),
                      borderRadius: BorderRadius.circular(8)),
                    child: playlist.songs.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: playlist.songs[0].imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => const Icon(
                              Icons.music_note, color: Color(0xFF7A7890))))
                      : const Icon(Icons.music_note, color: Color(0xFF7A7890))),
                  title: Text(playlist.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(
                    '${playlist.songs.length} songs',
                    style: const TextStyle(color: Color(0xFF7A7890), fontSize: 12)),
                  onTap: () async {
                    final song = _player.currentSong;
                    if (song == null) return;
                    await StorageService.addToPlaylist(playlist.id, song);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✓ Added to "${playlist.name}"',
                            style: const TextStyle(color: Color(0xFF2DBE78))),
                          backgroundColor: const Color(0xFF1E1E2E),
                          duration: const Duration(seconds: 2)));
                    }
                  },
                )),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Playlist',
          style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
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
            child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF7A7890)))),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await StorageService.createPlaylist(controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                // Reopen add to playlist sheet
                _showAddToPlaylistSheet();
              }
            },
            child: const Text('Create',
              style: TextStyle(color: Color(0xFFE8C547)))),
        ],
      ),
    );
  }

  void _showSongInfoDialog(Song song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: song.imageUrl.replaceAll('150x150', '500x500'),
                width: 260, height: 160,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) => Container(
                  width: 260, height: 160,
                  color: const Color(0xFF1A1A2E),
                  child: const Icon(Icons.music_note,
                    color: Color(0xFF7A7890), size: 48)),
              )),
            const SizedBox(height: 16),
            _infoRow('Title', song.name),
            _infoRow('Artist', song.artistName),
            _infoRow('Album', song.albumName),
            _infoRow('Language', song.language.toUpperCase()),

            _infoRow('Duration', _formatDuration(song.duration)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
              style: TextStyle(color: Color(0xFFE8C547)))),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70,
            child: Text('$label:',
              style: const TextStyle(color: Color(0xFF7A7890), fontSize: 13))),
          Expanded(child: Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  void _showLyricsSheet(String songId, String songName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2E2E45),
                borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.lyrics_outlined,
                  color: Color(0xFFE8C547), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(songName,
                  style: const TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
            const Divider(color: Color(0xFF2E2E45), height: 20),
            Expanded(
              child: FutureBuilder<String>(
                future: _api.getLyrics(songId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child:
                      CircularProgressIndicator(color: Color(0xFFE8C547)));
                  }
                  final lyrics = snap.data ?? '';
                  if (lyrics.isEmpty) {
                    return const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.music_off, color: Color(0xFF7A7890), size: 48),
                        SizedBox(height: 12),
                        Text('Lyrics not available',
                          style: TextStyle(color: Color(0xFF7A7890))),
                      ],
                    ));
                  }
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Text(lyrics,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 16,
                        height: 1.8, letterSpacing: 0.3)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQueueSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2E2E45),
                borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.queue_music_rounded,
                  color: Color(0xFFE8C547), size: 20),
                const SizedBox(width: 8),
                const Text('Up Next',
                  style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_player.queue.length} songs',
                  style: const TextStyle(color: Color(0xFF7A7890), fontSize: 13)),
              ]),
            ),
            const Divider(color: Color(0xFF2E2E45), height: 20),
            Expanded(
              child: _player.queue.isEmpty
                ? const Center(child: Text('Queue is empty',
                    style: TextStyle(color: Color(0xFF7A7890))))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _player.queue.length,
                    itemBuilder: (ctx, i) {
                      final song = _player.queue[i];
                      final isCurrent = i == _player.currentIndex;
                      return ListTile(
                        tileColor: isCurrent
                          ? const Color(0xFFE8C547).withValues(alpha: 0.1)
                          : null,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: song.imageUrl,
                            width: 44, height: 44, fit: BoxFit.cover,
                            errorWidget: (c, u, e) => Container(
                              width: 44, height: 44,
                              color: const Color(0xFF1E1E2E),
                              child: const Icon(Icons.music_note,
                                color: Color(0xFF7A7890))))),
                        title: Text(song.name,
                          style: TextStyle(
                            color: isCurrent
                              ? const Color(0xFFE8C547) : Colors.white,
                            fontSize: 13,
                            fontWeight: isCurrent
                              ? FontWeight.bold : FontWeight.normal),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(song.artistName,
                          style: const TextStyle(
                            color: Color(0xFF7A7890), fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: isCurrent
                          ? const Icon(Icons.graphic_eq,
                              color: Color(0xFFE8C547), size: 20)
                          : null,
                        onTap: () {
                          _player.playSong(song, _player.queue, i);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: StreamBuilder<Song?>(
                    stream: _player.currentSongStream,
                    builder: (context, snapshot) {
                      final song = snapshot.data ?? _player.currentSong;
                      if (song == null) {
                        return const Center(child: Text('No song playing',
                          style: TextStyle(color: Color(0xFF7A7890))));
                      }
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildAlbumArt(song),
                          const SizedBox(height: 32),
                          _buildSongInfo(song),
                          const SizedBox(height: 24),

                          _buildProgressBar(song),
                          const SizedBox(height: 24),
                          _buildControls(song),
                          const SizedBox(height: 48),
                          _buildBottomRow(song),
                          const SizedBox(height: 48),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.maybePop(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'PLAYING FROM LIBRARY',
                  style: GoogleFonts.dmSans(fontSize: 10, letterSpacing: 1.5,
                    color: const Color(0xFF7A7890), fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _player.currentSong?.albumName ?? 'Unknown Album',
                  style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white,
                    fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
            color: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              final song = _player.currentSong;
              if (song == null) return;
              switch (value) {
                case 'add_playlist':
                  _showAddToPlaylistSheet();
                  break;
                case 'share':
                  // FIX 3 — Share
                  final shareText = '🎵 Listen to "${song.name}" '
                    'by ${song.artistName} on Saga Tunes!\n\n'
                    'Stream free music at Saga Tunes app.';
                  try {
                    await Share.share(
                      shareText,
                      subject: 'Check out this song on Saga Tunes!',
                    );
                  } catch (e) {
                    // Web/desktop fallback — copy to clipboard
                    await Clipboard.setData(ClipboardData(text: shareText));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied to clipboard!'),
                          backgroundColor: Color(0xFF1E1E2E)));
                    }
                  }
                  break;
                case 'song_info':
                  _showSongInfoDialog(song);
                  break;
                case 'go_to_album':
                  // FIX 4 — Go to Album
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Loading album...'),
                        backgroundColor: Color(0xFF1E1E2E),
                        duration: Duration(seconds: 1)));
                  }
                  try {
                    final albums = await _api.searchAlbums(
                      song.albumName, limit: 1);
                    if (!mounted) break;
                    if (albums.isNotEmpty) {
                      final album = albums.first;
                      Navigator.pushNamed(context, '/album', arguments: {
                        'albumId': album.id,
                        'albumName': album.name,
                        'artistName': album.artistName,
                        'imageUrl': album.imageUrl,
                        'year': album.year,
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Album not found'),
                          backgroundColor: Color(0xFF1E1E2E)));
                    }
                  } catch (e) {
                    debugPrint('Go to album error: $e');
                  }
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'add_playlist',
                child: Row(children: [
                  const Icon(Icons.playlist_add,
                    color: Color(0xFFE8C547), size: 20),
                  const SizedBox(width: 10),
                  const Text('Add to Playlist',
                    style: TextStyle(color: Colors.white)),
                ])),
              PopupMenuItem(value: 'share',
                child: Row(children: [
                  const Icon(Icons.share_outlined,
                    color: Color(0xFFE8C547), size: 20),
                  const SizedBox(width: 10),
                  const Text('Share',
                    style: TextStyle(color: Colors.white)),
                ])),
              PopupMenuItem(value: 'song_info',
                child: Row(children: [
                  const Icon(Icons.info_outline,
                    color: Color(0xFFE8C547), size: 20),
                  const SizedBox(width: 10),
                  const Text('Song Info',
                    style: TextStyle(color: Colors.white)),
                ])),
              PopupMenuItem(value: 'go_to_album',
                child: Row(children: [
                  const Icon(Icons.album_outlined,
                    color: Color(0xFFE8C547), size: 20),
                  const SizedBox(width: 10),
                  const Text('Go to Album',
                    style: TextStyle(color: Colors.white)),
                ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(Song song) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1A40), Color(0xFF2D1F4E)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24, offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: song.imageUrl.replaceAll('150x150', '500x500'),
            fit: BoxFit.cover,
            errorWidget: (context, url, err) => const Center(
              child: Icon(Icons.music_note, color: Color(0xFF7A7890), size: 64)),
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo(Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            song.name,
            style: const TextStyle(fontFamily: 'BebasNeue', fontSize: 26,
              color: Colors.white, fontWeight: FontWeight.bold),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            song.artistName,
            style: GoogleFonts.dmSans(fontSize: 15, color: const Color(0xFFA09EB8)),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }



  Widget _buildProgressBar(Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<Duration>(
        stream: _player.positionStream,
        builder: (context, posSnapshot) {
          final pos = posSnapshot.data ?? Duration.zero;
          final total = Duration(seconds: song.duration);
          final msPos = pos.inMilliseconds.toDouble();
          final msTotal = total.inMilliseconds.toDouble();
          final validTotal = msTotal > 0 ? msTotal : 100.0;
          final validPos = msPos.clamp(0.0, validTotal);

          return Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                  activeTrackColor: const Color(0xFFE8C547),
                  inactiveTrackColor: const Color(0xFF2E2E45),
                  trackShape: const RectangularSliderTrackShape(),
                ),
                child: Slider(
                  min: 0,
                  max: validTotal,
                  value: validPos,
                  onChanged: (val) =>
                    _player.seekTo(Duration(milliseconds: val.toInt())),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(pos.inSeconds),
                    style: GoogleFonts.dmSans(fontSize: 12,
                      color: const Color(0xFF7A7890))),
                  Text(_formatDuration(total.inSeconds),
                    style: GoogleFonts.dmSans(fontSize: 12,
                      color: const Color(0xFF7A7890))),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls(Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.shuffle,
              color: _player.isShuffled
                ? const Color(0xFFE8C547)
                : const Color(0xFF7A7890),
              size: 24),
            onPressed: () {
              setState(() => _player.toggleShuffle());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_player.isShuffled
                    ? 'Shuffle ON' : 'Shuffle OFF'),
                  backgroundColor: const Color(0xFF1E1E2E),
                  duration: const Duration(seconds: 1)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28),
            onPressed: () => _player.playPrevious(),
          ),
          StreamBuilder<bool>(
            stream: _player.playingStream,
            builder: (context, playingSnapshot) {
              final isPlaying = playingSnapshot.data ?? false;
              return GestureDetector(
                onTap: () => isPlaying ? _player.pause() : _player.resume(),
                child: Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8C547), shape: BoxShape.circle),
                  child: Center(child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: const Color(0xFF0A0A0F), size: 28)),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
            onPressed: () => _player.playNext(),
          ),
          IconButton(
            icon: StreamBuilder<void>(
              stream: StorageService.changesStream,
              builder: (ctx, _) {
                final downloaded = StorageService.isDownloaded(song.id);
                return Icon(
                  downloaded
                    ? Icons.download_done_rounded
                    : Icons.download_outlined,
                  color: downloaded
                    ? const Color(0xFF2DBE78)
                    : const Color(0xFF7A7890),
                  size: 26);
              },
            ),
            onPressed: () async {
              if (StorageService.isDownloaded(song.id)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Already saved offline'),
                    backgroundColor: Color(0xFF1E1E2E),
                    duration: Duration(seconds: 1)));
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFE8C547))),
                    const SizedBox(width: 12),
                    Text('Saving "${song.name}"...'),
                  ]),
                  backgroundColor: const Color(0xFF1E1E2E),
                  duration: const Duration(seconds: 2)));
              await StorageService.downloadSong(song, song.streamUrl);
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ "${song.name}" saved offline',
                      style: const TextStyle(color: Color(0xFF2DBE78))),
                    backgroundColor: const Color(0xFF1E1E2E),
                    duration: const Duration(seconds: 2)));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomRow(Song song) {
    final isLiked = StorageService.isLiked(song.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked
                ? const Color(0xFFE8C547)
                : const Color(0xFF7A7890),
              size: 22),
            onPressed: () {
              if (isLiked) {
                StorageService.unlikeSong(song.id).then((_) => setState(() {}));
              } else {
                StorageService.likeSong(song).then((_) => setState(() {}));
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.lyrics_outlined,
              color: Color(0xFF7A7890), size: 26),
            onPressed: () {
              final song = _player.currentSong;
              if (song == null) return;
              _showLyricsSheet(song.id, song.name);
            },
          ),
          IconButton(
            icon: const Icon(Icons.queue_music_rounded,
              color: Color(0xFF7A7890), size: 26),
            onPressed: () => _showQueueSheet(),
          ),
        ],
      ),
    );
  }
}
