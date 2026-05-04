import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/song.dart';
import '../services/storage_service.dart';
import '../services/jiosaavn_service.dart';

class SongThreeDots extends StatelessWidget {
  final Song song;
  final VoidCallback? onDelete;

  const SongThreeDots({super.key, required this.song, this.onDelete});

  JioSaavnService get _api => JioSaavnService();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Color(0xFF7A7890), size: 20),
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: EdgeInsets.zero,
      onSelected: (value) async {
        switch (value) {
          case 'add_playlist':
            _showAddToPlaylistSheet(context);
            break;
          case 'share':
            final shareText = '🎵 "${song.name}" by ${song.artistName}\n'
                'Listen free on Saga Tunes!';
            try {
              await Share.share(shareText);
            } catch (e) {
              await Clipboard.setData(ClipboardData(text: shareText));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard!'),
                    backgroundColor: Color(0xFF1E1E2E)));
              }
            }
            break;
          case 'song_info':
            _showSongInfoDialog(context);
            break;
          case 'go_to_album':
            await _goToAlbum(context);
            break;
          case 'delete':
            if (onDelete != null) onDelete!();
            break;
        }
      },
      itemBuilder: (ctx) => [
        _menuItem('add_playlist', Icons.playlist_add, 'Add to Playlist'),
        _menuItem('share', Icons.share_outlined, 'Share'),
        _menuItem('song_info', Icons.info_outline, 'Song Info'),
        _menuItem('go_to_album', Icons.album_outlined, 'Go to Album'),
        if (onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(children: [
              const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              const SizedBox(width: 10),
              const Text('Delete Download',
                  style: TextStyle(color: Colors.red, fontSize: 14)),
            ]),
          ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, color: const Color(0xFFE8C547), size: 20),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ]),
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
              child: Row(children: [
                const Icon(Icons.playlist_add, color: Color(0xFFE8C547)),
                const SizedBox(width: 8),
                const Text('Add to Playlist',
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
                  await StorageService.addToPlaylist(pl.id, song);
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

  void _showSongInfoDialog(BuildContext context) {
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
                imageUrl: song.imageUrl,
                width: 260, height: 160, fit: BoxFit.cover,
                errorWidget: (c, u, e) => Container(
                    width: 260, height: 160,
                    color: const Color(0xFF1A1A2E),
                    child: const Icon(Icons.music_note,
                        color: Color(0xFF7A7890), size: 48))),
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 65,
              child: Text('$label:',
                  style: const TextStyle(
                      color: Color(0xFF7A7890), fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Future<void> _goToAlbum(BuildContext context) async {
    if (song.albumName.isEmpty) return;
    try {
      final albums = await _api.searchAlbums(song.albumName, limit: 1);
      if (!context.mounted) return;
      if (albums.isNotEmpty) {
        final album = albums.first;
        Navigator.of(context, rootNavigator: true).pushNamed('/album', arguments: {
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
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
