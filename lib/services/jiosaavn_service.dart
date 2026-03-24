import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';

class JioSaavnService {
  static const String baseUrl = 'https://jiosavv.vercel.app/api';

  Future<dynamic> _get(String endpoint) async {
    for (int i = 0; i < 2; i++) {
      try {
        final response = await http.get(Uri.parse('$baseUrl$endpoint'));
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } catch (e) {
        debugPrint('API Error: $e');
      }
    }
    return null;
  }

  Future<List<Song>> searchSongs(String query, {int limit = 20}) async {
    try {
      final data = await _get('/search/songs?query=${Uri.encodeComponent(query)}&limit=$limit');
      if (data == null || data['data'] == null || data['data']['results'] == null) return [];
      
      final List<dynamic> items = data['data']['results'];
      return items
          .map((json) => Song.fromJson(json))
          .where((s) => s.streamUrl.isNotEmpty) // Fix: Silent failing due to empty streams
          .toList();
    } catch (e) {
      debugPrint('searchSongs error: $e');
      return [];
    }
  }

  Future<int> fetchTotalResultCount(String query) async {
    try {
      final data = await _get('/search/songs?query=${Uri.encodeComponent(query)}&limit=1');
      if (data != null && data['data'] != null && data['data']['total'] != null) {
        return data['data']['total'] as int;
      }
    } catch (e) {
      debugPrint('fetchTotalResultCount error: $e');
    }
    return 0;
  }

  Future<List<Song>> getSongsByLanguage(String language, {int limit = 20}) async {
    return searchSongs('top $language songs 2026', limit: limit);
  }

  Future<List<Song>> getTrending(String language) async {
    // Uses searchSongs mapping correctly
    return searchSongs('top $language hits 2025', limit: 20);
  }

  Future<String> getLyrics(String songId) async {
    try {
      final response = await http.get(Uri.parse(
        'https://jiosavv.vercel.app/api/songs/$songId/lyrics'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Try multiple response paths
        final lyrics = data['data']?['lyrics'] 
          ?? data['data']?['snippet']
          ?? data['lyrics']
          ?? '';
        return lyrics.toString();
      }
      
      // 404 means lyrics not available for this song
      // This is normal - not all songs have lyrics
      debugPrint('Lyrics not available for song: $songId');
      return ''; // return empty, UI shows "not available"
      
    } catch (e) {
      debugPrint('Lyrics fetch error: $e');
      return '';
    }
  }

  Future<List<Album>> searchAlbums(String query, {int limit = 10}) async {
    try {
      final data = await _get('/search/albums?query=${Uri.encodeComponent(query)}&limit=$limit');
      if (data == null || data['data'] == null || data['data']['results'] == null) return [];
      
      final List<dynamic> items = data['data']['results'];
      return items.map((json) => Album.fromJson(json)).toList();
    } catch (e) {
      debugPrint('searchAlbums error: $e');
      return [];
    }
  }

  Future<List<Artist>> searchArtists(String query, {int limit = 5}) async {
    try {
      final response = await http.get(Uri.parse(
        'https://jiosavv.vercel.app/api/search/artists?query=$query&limit=$limit'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['data']['results'] as List? ?? [];
        return results.map((a) => Artist(
          id: a['id'] ?? '',
          name: a['name'] ?? '',
          imageUrl: (a['image'] as List?)?.isNotEmpty == true
            ? a['image'].last['url'] ?? '' : '',
          songCount: a['songCount'] ?? 0,
        )).toList();
      }
    } catch (e) { debugPrint('Artist search error: $e'); }
    return [];
  }

  Future<List<Song>> getAlbumSongs(String albumId) async {
    try {
      final response = await http.get(Uri.parse(
        'https://jiosavv.vercel.app/api/albums?id=$albumId'));
       if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final songs = data['data']['songs'] as List? ?? [];
        return songs.map((s) => Song.fromJson(s)).toList();
      }
    } catch (e) { debugPrint('Album songs error: $e'); }
    return [];
  }
}
