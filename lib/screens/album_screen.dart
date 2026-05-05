import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../services/audio_service.dart';
import '../services/jiosaavn_service.dart';
import '../services/storage_service.dart';
import '../widgets/song_three_dots.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class AlbumScreen extends StatefulWidget {
  final String albumId;
  final String albumName;
  final String artistName;
  final String imageUrl;
  final String year;

  const AlbumScreen({
    super.key,
    required this.albumId,
    required this.albumName,
    required this.artistName,
    required this.imageUrl,
    required this.year,
  });

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final AudioService audioService = AudioService();
  final JioSaavnService jiosaavnService = JioSaavnService();

  List<Song> albumSongs = [];
  bool isLoading = false;
  bool isLiked = false;

  @override
  void initState() {
    super.initState();
    _loadAlbumSongs();
    isLiked = StorageService.isAlbumLiked(widget.albumId);
  }

  Future<void> _loadAlbumSongs() async {
    setState(() => isLoading = true);
    try {
      final songs = await jiosaavnService.getAlbumSongs(widget.albumId);
      setState(() {
        albumSongs = songs;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Album load error: $e');
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        slivers: [
          // Collapsible app bar with album art
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0F),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: const Color(0xFF1E1E2E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) async {
                  if (value == 'add_playlist') {
                    if (albumSongs.isEmpty) return;
                    _showAddToPlaylistSheet(context);
                  } else if (value == 'add_queue') {
                    if (albumSongs.isNotEmpty) {
                      audioService.addToQueue(albumSongs);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added ${albumSongs.length} songs to queue', style: const TextStyle(color: Color(0xFFE8C547))),
                          backgroundColor: const Color(0xFF1E1E2E),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } else if (value == 'share') {
                    final shareText = '💿 Album "${widget.albumName}" by ${widget.artistName}\n'
                        'Listen free on Saga Tunes!';
                    try {
                      await Share.share(shareText);
                    } catch (e) {
                      await Clipboard.setData(ClipboardData(text: shareText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard!'),
                            backgroundColor: Color(0xFF1E1E2E),
                          ),
                        );
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'add_playlist',
                    child: Row(children: const [
                      Icon(Icons.playlist_add, color: Color(0xFFE8C547), size: 20),
                      SizedBox(width: 10),
                      Text('Add to playlist', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'add_queue',
                    child: Row(children: const [
                      Icon(Icons.queue_music, color: Color(0xFFE8C547), size: 20),
                      SizedBox(width: 10),
                      Text('Add to playing queue', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Row(children: const [
                      Icon(Icons.share_outlined, color: Color(0xFFE8C547), size: 20),
                      SizedBox(width: 10),
                      Text('Share', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ]),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E1A40), Color(0xFF2D1F4E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  // Dark gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.9),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Album info bottom of art
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ALBUM',
                          style: TextStyle(
                            color: Color(0xFF7A7890),
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.albumName,
                          style: const TextStyle(
                            color: Color(0xFFE8C547),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'BebasNeue',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              widget.artistName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              ' • ${widget.year}',
                              style: const TextStyle(
                                color: Color(0xFF7A7890),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Play all button
                  GestureDetector(
                    onTap: () {
                      if (albumSongs.isEmpty) return;
                      audioService.playSong(albumSongs[0], albumSongs, 0);
                      Navigator.pushNamed(context, '/player');
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8C547),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Color(0xFF0A0A0F),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Shuffle button
                  GestureDetector(
                    onTap: () {
                      if (albumSongs.isEmpty) return;
                      final shuffled = List<Song>.from(albumSongs)..shuffle();
                      audioService.playSong(shuffled[0], shuffled, 0);
                      Navigator.pushNamed(context, '/player');
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF2E2E45),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.shuffle,
                        color: Color(0xFF7A7890),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Like album button
                  GestureDetector(
                    onTap: () async {
                      final album = Album(
                        id: widget.albumId,
                        name: widget.albumName,
                        artistName: widget.artistName,
                        imageUrl: widget.imageUrl,
                        year: widget.year,
                        songCount: albumSongs.length,
                      );
                      final messenger = ScaffoldMessenger.of(context);
                      if (isLiked) {
                        await StorageService.unlikeAlbum(widget.albumId);
                      } else {
                        await StorageService.likeAlbum(album);
                      }
                      if (!mounted) return;
                      setState(() => isLiked = !isLiked);
                      messenger.showSnackBar(SnackBar(
                        content: Text(isLiked
                          ? '♥ Album saved to Library'
                          : 'Album removed from Library',
                          style: const TextStyle(color: Color(0xFF2DBE78))),
                        backgroundColor: const Color(0xFF1E1E2E),
                        duration: const Duration(seconds: 1)));
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLiked
                            ? const Color(0xFFE8C547)
                            : const Color(0xFF2E2E45),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked
                            ? const Color(0xFFE8C547)
                            : const Color(0xFF7A7890),
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Song count
                  Text(
                    '${albumSongs.length} songs',
                    style: const TextStyle(
                      color: Color(0xFF7A7890),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Currently playing mini bar (if playing from this album)
          if (audioService.currentSong != null &&
              albumSongs.any((s) => s.id == audioService.currentSong!.id))
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: audioService.currentSong!.imageUrl,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            audioService.currentSong!.name,
                            style: const TextStyle(
                              color: Color(0xFFE8C547),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            audioService.currentSong!.artistName,
                            style: const TextStyle(
                              color: Color(0xFF7A7890),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Prev
                    IconButton(
                      icon: const Icon(Icons.skip_previous,
                          color: Colors.white, size: 20),
                      onPressed: () => audioService.playPrevious(),
                    ),
                    // Play/Pause
                    StreamBuilder<bool>(
                      stream: audioService.playingStream,
                      builder: (ctx, snap) {
                        final playing = snap.data ?? false;
                        return IconButton(
                          icon: Icon(
                            playing ? Icons.pause : Icons.play_arrow,
                            color: const Color(0xFFE8C547),
                            size: 24,
                          ),
                          onPressed: () => playing
                              ? audioService.pause()
                              : audioService.resume(),
                        );
                      },
                    ),
                    // Next
                    IconButton(
                      icon: const Icon(Icons.skip_next,
                          color: Colors.white, size: 20),
                      onPressed: () => audioService.playNext(),
                    ),
                  ],
                ),
              ),
            ),

          // Song list
          isLoading
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: const CircularProgressIndicator(
                        color: Color(0xFFE8C547),
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final song = albumSongs[i];
                      final isCurrent =
                          audioService.currentSong?.id == song.id;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: isCurrent
                            ? const Icon(Icons.graphic_eq,
                                color: Color(0xFFE8C547), size: 20)
                            : Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Color(0xFF7A7890),
                                  fontSize: 14,
                                ),
                              ),
                        title: Text(
                          song.name,
                          style: TextStyle(
                            color: isCurrent
                                ? const Color(0xFFE8C547)
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.artistName,
                          style: const TextStyle(
                            color: Color(0xFF7A7890),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDuration(song.duration),
                              style: const TextStyle(
                                color: Color(0xFF7A7890),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            SongThreeDots(song: song),
                          ],
                        ),
                        onTap: () {
                          audioService.playSong(song, albumSongs, i);
                          Navigator.pushNamed(context, '/player');
                        },
                      );
                    },
                    childCount: albumSongs.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context) {
    final playlists = StorageService.getAllPlaylists();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFF2E2E45),
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(children: const [
                Icon(Icons.playlist_add, color: Color(0xFFE8C547)),
                SizedBox(width: 8),
                Text('Add to Playlist',
                    style: TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            const Divider(color: Color(0xFF2E2E45)),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE8C547), width: 1.5),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add, color: Color(0xFFE8C547))),
              title: const Text('Create New Playlist',
                  style: TextStyle(color: Color(0xFFE8C547),
                      fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateDialog(context);
              },
            ),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No playlists yet.',
                    style: TextStyle(color: Color(0xFF7A7890)),
                    textAlign: TextAlign.center))
            else
              ...playlists.map((pl) => ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: pl.songs.isNotEmpty
                      ? CachedNetworkImage(
                      imageUrl: pl.songs[0].imageUrl,
                      width: 44, height: 44, fit: BoxFit.cover,
                      errorWidget: (c, u, e) => Container(
                          width: 44, height: 44,
                          color: const Color(0xFF0A0A0F),
                          child: const Icon(Icons.music_note,
                              color: Color(0xFF7A7890))))
                      : Container(
                      width: 44, height: 44,
                      color: const Color(0xFF0A0A0F),
                      child: const Icon(Icons.music_note,
                          color: Color(0xFF7A7890)))),
                title: Text(pl.name,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text('${pl.songs.length} songs',
                    style: const TextStyle(color: Color(0xFF7A7890))),
                onTap: () async {
                  await StorageService.addSongsToPlaylist(pl.id, albumSongs);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('✓ Added to "${pl.name}"',
                          style: const TextStyle(color: Color(0xFF2DBE78))),
                      backgroundColor: const Color(0xFF1E1E2E),
                      duration: const Duration(seconds: 2)));
                  }
                },
              )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
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
                borderSide: BorderSide(color: Color(0xFFE8C547)))),
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
                if (context.mounted) _showAddToPlaylistSheet(context);
              }
            },
            child: const Text('Create',
                style: TextStyle(color: Color(0xFFE8C547)))),
        ],
      ),
    );
  }
}
