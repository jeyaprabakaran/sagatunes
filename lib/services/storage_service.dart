import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/playlist.dart';

class StorageService {
  static const String _downloadsBox = 'downloads';
  static const String _likedBox = 'liked';
  static const String _playlistsBox = 'playlists';
  static const String _recentBox = 'recent';
  static const String _prefsBox = 'prefs';
  static const String _likedAlbumsBox = 'liked_albums';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SongAdapter());
    Hive.registerAdapter(PlaylistAdapter());

    await Hive.openBox(_downloadsBox);
    await Hive.openBox<Song>(_likedBox);
    await Hive.openBox<Playlist>(_playlistsBox);
    await Hive.openBox<Song>(_recentBox);
    await Hive.openBox(_prefsBox);
    await Hive.openBox(_likedAlbumsBox); // dynamic box for album JSON maps
  }

  // --- Downloads ---
  static Stream<void> get changesStream =>
      Hive.box(_downloadsBox).watch();

  static Future<void> downloadSong(Song song, String streamUrl) async {
    final box = Hive.box(_downloadsBox);
    try {
      if (kIsWeb) {
        await box.put(song.id, {
          'id': song.id,
          'name': song.name,
          'artistName': song.artistName,
          'imageUrl': song.imageUrl,
          'streamUrl': streamUrl,
          'filePath': null,
          'albumName': song.albumName,
          'language': song.language,
          'duration': song.duration,
          'downloadedAt': DateTime.now().toIso8601String(),
          'fileSize': 0,
        });
        return;
      }
      
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          final status = await Permission.storage.request();
          final manageStatus = await Permission.manageExternalStorage.request();
          if (!status.isGranted && !manageStatus.isGranted) {
            debugPrint('Storage permission denied');
          }
        }
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/SagaTunes');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      
      final fileName = 'saga_${song.id}.mp3';
      final filePath = '${dir.path}/$fileName';
      
      final response = await http.get(
        Uri.parse(streamUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://www.jiosaavn.com/',
        },
      );
      
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        if (Platform.isAndroid) {
          try {
            const channel = MethodChannel('com.sagatunes.app/media_scanner');
            await channel.invokeMethod('scanFile', {'path': filePath});
          } catch (e) {
            debugPrint('Media scanner error: $e');
          }
        }
        
        await box.put(song.id, {
          'id': song.id,
          'name': song.name,
          'artistName': song.artistName,
          'imageUrl': song.imageUrl,
          'streamUrl': streamUrl,
          'filePath': filePath,
          'albumName': song.albumName,
          'language': song.language,
          'duration': song.duration,
          'downloadedAt': DateTime.now().toIso8601String(),
          'fileSize': response.bodyBytes.length,
        });
        debugPrint('Downloaded to: $filePath');
      } else {
        debugPrint('Download failed: ${response.statusCode}');
        await box.put(song.id, {
          'id': song.id,
          'name': song.name,
          'artistName': song.artistName,
          'imageUrl': song.imageUrl,
          'streamUrl': streamUrl,
          'filePath': null,
          'albumName': song.albumName,
          'language': song.language,
          'duration': song.duration,
          'downloadedAt': DateTime.now().toIso8601String(),
          'fileSize': 0,
        });
      }
    } catch (e) {
      debugPrint('Download error: $e');
    }
  }

  static String? getDownloadPath(String songId) {
    final data = Hive.box(_downloadsBox).get(songId);
    if (data == null || data is Song) return null;
    final path = data['filePath'];
    if (path == null || path.isEmpty) return null;
    return path as String;
  }

  static Future<bool> isDownloadedLocally(String songId) async {
    final path = getDownloadPath(songId);
    if (path == null) return false;
    return await File(path).exists();
  }

  static bool isDownloaded(String songId) {
    return Hive.box(_downloadsBox).containsKey(songId);
  }

  static Future<void> deleteDownload(String songId) async {
    final path = getDownloadPath(songId);
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Deleted file: $path');
        }
      } catch (e) {
        debugPrint('File delete error: $e');
      }
    }
    await Hive.box(_downloadsBox).delete(songId);
  }

  static List<Song> getAllDownloads() {
    return Hive.box(_downloadsBox).values.map((data) {
      if (data is Song) return data;
      final d = Map<String, dynamic>.from(data as Map);
      return Song(
        id: d['id'] ?? '',
        name: d['name'] ?? '',
        artistName: d['artistName'] ?? '',
        imageUrl: d['imageUrl'] ?? '',
        streamUrl: d['streamUrl'] ?? '',
        duration: d['duration'] ?? 0,
        language: d['language'] ?? 'Unknown',
        albumName: d['albumName'] ?? '',
      )..isDownloaded = true;
    }).toList();
  }

  static String getDownloadSize(String songId) {
    final data = Hive.box(_downloadsBox).get(songId);
    if (data == null || data is Song) return '';
    final bytes = data['fileSize'] as int? ?? 0;
    if (bytes == 0) return '';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  // --- Liked Songs ---
  static Future<void> likeSong(Song song) async {
    await Hive.box<Song>(_likedBox).put(song.id, song);
  }

  static Future<void> unlikeSong(String songId) async {
    await Hive.box<Song>(_likedBox).delete(songId);
  }

  static bool isLiked(String songId) {
    return Hive.box<Song>(_likedBox).containsKey(songId);
  }

  static List<Song> getAllLiked() {
    return Hive.box<Song>(_likedBox).values.toList().reversed.toList();
  }

  // --- Liked Albums ---
  static Future<void> likeAlbum(Album album) async {
    await Hive.box(_likedAlbumsBox).put(album.id, {
      'id': album.id,
      'name': album.name,
      'artistName': album.artistName,
      'imageUrl': album.imageUrl,
      'year': album.year,
      'songCount': album.songCount,
    });
  }

  static Future<void> unlikeAlbum(String albumId) async {
    await Hive.box(_likedAlbumsBox).delete(albumId);
  }

  static bool isAlbumLiked(String albumId) {
    return Hive.box(_likedAlbumsBox).containsKey(albumId);
  }

  static List<Album> getAllLikedAlbums() {
    return Hive.box(_likedAlbumsBox).values.map((raw) {
      final d = Map<String, dynamic>.from(raw as Map);
      return Album(
        id: d['id'] as String? ?? '',
        name: d['name'] as String? ?? '',
        artistName: d['artistName'] as String? ?? '',
        imageUrl: d['imageUrl'] as String? ?? '',
        year: d['year']?.toString() ?? '',
        songCount: d['songCount'] as int? ?? 0,
      );
    }).toList();
  }

  // --- Playlists ---
  static Future<void> createPlaylist(String name) async {
    final box = Hive.box<Playlist>(_playlistsBox);
    final id = const Uuid().v4();
    await box.put(id, Playlist(id: id, name: name, songs: []));
  }

  static Future<void> addToPlaylist(String playlistId, Song song) async {
    final box = Hive.box<Playlist>(_playlistsBox);
    final playlist = box.get(playlistId);
    if (playlist != null) {
      final updatedSongs = List<Song>.from(playlist.songs)..add(song);
      await box.put(
          playlistId, Playlist(id: playlist.id, name: playlist.name, songs: updatedSongs));
    }
  }

  static Future<void> removeSongFromPlaylist(
      String playlistId, String songId) async {
    final box = Hive.box<Playlist>(_playlistsBox);
    final playlist = box.get(playlistId);
    if (playlist != null) {
      final updatedSongs = List<Song>.from(playlist.songs)
        ..removeWhere((s) => s.id == songId);
      await box.put(
          playlistId, Playlist(id: playlist.id, name: playlist.name, songs: updatedSongs));
    }
  }

  static Future<void> deletePlaylist(String playlistId) async {
    await Hive.box<Playlist>(_playlistsBox).delete(playlistId);
  }

  static List<Playlist> getAllPlaylists() {
    return Hive.box<Playlist>(_playlistsBox).values.toList();
  }

  // --- Recents ---
  static Future<void> addRecent(Song song) async {
    final box = Hive.box<Song>(_recentBox);
    await box.put(song.id, song);
    if (box.length > 20) await box.deleteAt(0);
  }

  // --- Prefs ---
  static String getDefaultLanguage() {
    return Hive.box(_prefsBox).get('default_language', defaultValue: 'tamil');
  }

  static Future<void> setDefaultLanguage(String lang) async {
    await Hive.box(_prefsBox).put('default_language', lang);
  }

  static Future<void> saveLastPlayed({
    required String songId,
    required String songName,
    required String artistName,
    required String imageUrl,
    required String streamUrl,
    required String albumName,
    required String language,
    required int duration,
    required int positionSeconds,
  }) async {
    await Hive.box(_prefsBox).put('last_played', {
      'id': songId,
      'name': songName,
      'artistName': artistName,
      'imageUrl': imageUrl,
      'streamUrl': streamUrl,
      'albumName': albumName,
      'language': language,
      'duration': duration,
      'positionSeconds': positionSeconds,
    });
  }

  static Map<String, dynamic>? getLastPlayed() {
    final data = Hive.box(_prefsBox).get('last_played');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> saveLastPosition(int seconds) async {
    await Hive.box(_prefsBox).put('last_position', seconds);
  }

  static int getLastPosition() {
    return Hive.box(_prefsBox).get('last_position', defaultValue: 0) as int;
  }

  // --- Search History ---
  static Future<void> addSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    List<String> history = getSearchHistory();
    history.remove(query.trim());
    history.insert(0, query.trim());
    if (history.length > 10) {
      history = history.take(10).toList();
    }
    await Hive.box(_prefsBox).put('search_history', history);
  }

  static List<String> getSearchHistory() {
    final data = Hive.box(_prefsBox).get('search_history');
    if (data == null) return [];
    return List<String>.from(data);
  }

  static Future<void> clearSearchHistory() async {
    await Hive.box(_prefsBox).put('search_history', <String>[]);
  }

  static Future<void> removeSearchHistoryItem(String query) async {
    final history = getSearchHistory();
    history.remove(query);
    await Hive.box(_prefsBox).put('search_history', history);
  }
}

