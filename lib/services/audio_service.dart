import 'package:audio_service/audio_service.dart' as bg_audio;
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../models/song.dart';
import 'storage_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  static AudioService get instance => _instance;
  factory AudioService() => _instance;
  AudioService._internal() {
    _init();
  }

  SagaTunesAudioHandler? _audioHandler;

  Future<void> initBackgroundService() async {
    _audioHandler = await bg_audio.AudioService.init(
      builder: () => SagaTunesAudioHandler(_player),
    config: const bg_audio.AudioServiceConfig(
      androidNotificationChannelId: 'com.sagatunes.app.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: false,
      androidShowNotificationBadge: false,
      androidStopForegroundOnPause: true,
    ),
    );
  }

  final AudioPlayer _player = AudioPlayer();
  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _isHandlingCompletion = false;
  Timer? _saveTimer;
  bool _isLoading = false;

  void _init() {
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onSongCompleted();
      }
    });
  }

  void _onSongCompleted() {
    if (_isHandlingCompletion) return;
    _isHandlingCompletion = true;

    Future.delayed(const Duration(milliseconds: 300), () {
      _isHandlingCompletion = false;
    });

    if (_queue.isEmpty) return;

    if (_isShuffled) {
      final random = Random();
      int nextIndex;
      do {
        nextIndex = random.nextInt(_queue.length);
      } while (nextIndex == _currentIndex && _queue.length > 1);
      playSong(_queue[nextIndex], _queue, nextIndex);
    } else if (_currentIndex < _queue.length - 1) {
      final nextIndex = _currentIndex + 1;
      playSong(_queue[nextIndex], _queue, nextIndex);
      debugPrint('Auto-playing next: ${_queue[nextIndex].name}');
    } else {
      debugPrint('End of queue, looping back to start');
      playSong(_queue[0], _queue, 0);
    }
  }

  // Stream controller for current song updates
  final _currentSongController = StreamController<Song?>.broadcast();

  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;

  // Broadcasts current song whenever playSong is called
  Stream<Song?> get currentSongStream => _currentSongController.stream;

  // Needed for backward compatibility with previous calls
  bool _isShuffled = false;
  bool get isShuffled => _isShuffled;

  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    if (_isShuffled && _queue.isNotEmpty) {
      final current = _queue[_currentIndex];
      final rest = List<Song>.from(_queue)..removeAt(_currentIndex);
      rest.shuffle();
      _queue = [current, ...rest];
      _currentIndex = 0;
    }
  }

  Future<void> playSong(Song song, List<Song> queue, int index) async {
    // Prevent overlapping load requests
    if (_isLoading) {
      await _player.stop();
    }
    _isLoading = true;

    _currentSong = song;
    _queue = queue;
    _currentIndex = index;
    _currentSongController.add(song); // notify listeners

    if (!kIsWeb && _audioHandler != null) {
      _audioHandler!.mediaItem.add(
        bg_audio.MediaItem(
          id: song.id,
          album: song.albumName.isNotEmpty ? song.albumName : 'Saga Tunes',
          title: song.name,
          artist: song.artistName,
          duration: Duration(seconds: song.duration),
          artUri: Uri.parse(song.imageUrl),
        ),
      );
    }

    StorageService.saveLastPlayed(
      songId: song.id,
      songName: song.name,
      artistName: song.artistName,
      imageUrl: song.imageUrl,
      streamUrl: song.streamUrl,
      albumName: song.albumName,
      language: song.language,
      duration: song.duration,
      positionSeconds: 0,
    );
    StorageService.saveLastPosition(0);

    try {
      String? localPath;

      if (StorageService.isDownloaded(song.id)) {
        final path = StorageService.getDownloadPath(song.id);
        if (path != null) {
          final exists = await File(path).exists();
          if (exists) {
            localPath = path;
            debugPrint('Playing LOCAL: $path');
          }
        }
      }

      await _player.stop();

      if (!kIsWeb && localPath != null) {
        await _player.setFilePath(localPath);
      } else {
        final streamUrl = song.streamUrl;
        if (streamUrl.isEmpty) {
          debugPrint('ERROR: Empty stream URL for ${song.name}');
          return;
        }

        debugPrint('Attempting to play STREAM: $streamUrl');

        // Set user agent to avoid some CORS blocks
        await _player.setUrl(
          streamUrl,
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Referer': 'https://www.jiosaavn.com/',
          },
        );
      }
      await _player.play();
      _isLoading = false;

      _saveTimer?.cancel();
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_currentSong != null) {
          StorageService.saveLastPlayed(
            songId: _currentSong!.id,
            songName: _currentSong!.name,
            artistName: _currentSong!.artistName,
            imageUrl: _currentSong!.imageUrl,
            streamUrl: _currentSong!.streamUrl,
            albumName: _currentSong!.albumName,
            language: _currentSong!.language,
            duration: _currentSong!.duration,
            positionSeconds: position.inSeconds,
          );
          StorageService.saveLastPosition(position.inSeconds);
        }
      });
    } catch (e) {
      _isLoading = false;
      debugPrint('Playback error: $e');
      // Try without headers as fallback if stream
      if (song.streamUrl.isNotEmpty) {
        try {
          await _player.setUrl(song.streamUrl);
          await _player.play();
        } catch (e2) {
          debugPrint('Fallback playback also failed: $e2');
        }
      }
    }
  }

  Future<void> stop() async {
    _saveTimer?.cancel();
    await _player.stop();
    if (_audioHandler != null) {
      await _audioHandler!.stop();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    StorageService.saveLastPosition(position.inSeconds);
  }

  Future<void> resume() async => await _player.play();

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> loadSongWithoutPlaying(Song song, int positionSeconds) async {
    _currentSong = song;
    _currentSongController.add(song);

    try {
      String? localPath;
      if (StorageService.isDownloaded(song.id)) {
        final path = StorageService.getDownloadPath(song.id);
        if (path != null) {
          final exists = await File(path).exists();
          if (exists) localPath = path;
        }
      }

      if (!kIsWeb && _audioHandler != null) {
        _audioHandler!.mediaItem.add(
          bg_audio.MediaItem(
            id: song.id,
            album: song.albumName.isNotEmpty ? song.albumName : 'Saga Tunes',
            title: song.name,
            artist: song.artistName,
            duration: Duration(seconds: song.duration),
            artUri: Uri.parse(song.imageUrl),
          ),
        );
      }

      if (!kIsWeb && localPath != null) {
        await _player.setFilePath(localPath);
      } else {
        await _player.setUrl(song.streamUrl);
      }

      if (positionSeconds > 0) {
        await _player.seek(Duration(seconds: positionSeconds));
      }
    } catch (e) {
      debugPrint('Restore error: $e');
    }
  }

  Future<void> playNext() async {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await playSong(_queue[_currentIndex], _queue, _currentIndex);
    }
  }

  Future<void> playPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await playSong(_queue[_currentIndex], _queue, _currentIndex);
    }
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  void dispose() {
    _saveTimer?.cancel();
    _currentSongController.close();
    _player.dispose();
  }
}

class SagaTunesAudioHandler extends bg_audio.BaseAudioHandler
    with bg_audio.QueueHandler, bg_audio.SeekHandler {
  final AudioPlayer _player;

  SagaTunesAudioHandler(this._player) {
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            bg_audio.MediaControl.skipToPrevious,
            if (playing)
              bg_audio.MediaControl.pause
            else
              bg_audio.MediaControl.play,
            bg_audio.MediaControl.skipToNext,
          ],
          systemActions: const {
            bg_audio.MediaAction.seek,
            bg_audio.MediaAction.seekForward,
            bg_audio.MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: const {
            ProcessingState.idle: bg_audio.AudioProcessingState.idle,
            ProcessingState.loading: bg_audio.AudioProcessingState.loading,
            ProcessingState.buffering: bg_audio.AudioProcessingState.buffering,
            ProcessingState.ready: bg_audio.AudioProcessingState.ready,
            ProcessingState.completed: bg_audio.AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ),
      );
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: bg_audio.AudioProcessingState.idle,
        playing: false,
      ),
    );
    mediaItem.add(null);
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: bg_audio.AudioProcessingState.idle,
        playing: false,
      ),
    );
    mediaItem.add(null);
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => AudioService().playNext();

  @override
  Future<void> skipToPrevious() => AudioService().playPrevious();
}
