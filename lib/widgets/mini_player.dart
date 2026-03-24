import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/audio_service.dart';
import '../models/song.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final AudioService _player = AudioService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Song?>(
      stream: _player.currentSongStream,
      builder: (context, snapshot) {
        final song = snapshot.data ?? _player.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/player'),
          child: Container(
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E), // as specified
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12), // 12px padding
                  child: Row(
                    children: [
                      // Album Art
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: song.imageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF1E1E2E),
                            child: const Icon(Icons.music_note, color: Color(0xFF7A7890), size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title / Artist
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.name,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              song.artistName,
                              style: const TextStyle(color: Color(0xFF7A7890), fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Controls
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _player.playPrevious(),
                      ),
                      const SizedBox(width: 16),
                      StreamBuilder<bool>(
                        stream: _player.playingStream,
                        builder: (context, playingSnapshot) {
                          final isPlaying = playingSnapshot.data ?? false;
                          return IconButton(
                            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              if (isPlaying) {
                                _player.pause();
                              } else {
                                _player.resume();
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _player.playNext(),
                      ),
                    ],
                  ),
                ),
                // Gold Progress Line (Bottom)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, posSnapshot) {
                      final pos = posSnapshot.data?.inMilliseconds ?? 0;
                      final total = song.duration * 1000;
                      final factor = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
                      
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Container(height: 2, color: Colors.transparent),
                              Container(
                                width: constraints.maxWidth * factor,
                                height: 2,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8C547),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      );
                    },
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
