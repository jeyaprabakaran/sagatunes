import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/song.dart';
import '../services/jiosaavn_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../widgets/song_three_dots.dart';

class Genre {
  final String name;
  final String emoji;
  final Color cardColor;
  final String searchQuery;
  int songCount;
  Genre({required this.name, required this.emoji, required this.cardColor, required this.searchQuery, this.songCount = 0});
}

class ArtistData {
  String name;
  String imageUrl;
  String language;
  int songCount;
  ArtistData({required this.name, required this.imageUrl, required this.language, required this.songCount});
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final JioSaavnService _api = JioSaavnService();
  final AudioService _player = AudioService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  
  bool _isSearching = false;
  bool isLoadingSongs = false;
  bool isLoadingAlbums = false;
  bool isLoadingArtists = false;
  List<Song> songResults = [];
  List<Album> albumResults = [];
  List<Artist> artistResults = [];

  List<ArtistData> _topArtists = [];
  bool _isLoadingArtists = true;
  List<String> _searchHistory = [];
  bool _showHistory = false;

  final List<Genre> _genres = [
    Genre(name:'Rock', emoji:'🎸', cardColor:const Color(0xFF1E1A2E), searchQuery:'rock songs'),
    Genre(name:'Pop', emoji:'🎵', cardColor:const Color(0xFF1A1E2E), searchQuery:'pop songs'),
    Genre(name:'Classical', emoji:'🎻', cardColor:const Color(0xFF1A2A1E), searchQuery:'classical music'),
    Genre(name:'Jazz', emoji:'🎷', cardColor:const Color(0xFF2A1A1E), searchQuery:'jazz music'),
    Genre(name:'Hip Hop', emoji:'🎤', cardColor:const Color(0xFF1A1A2E), searchQuery:'hip hop songs'),
    Genre(name:'Electronic', emoji:'🎹', cardColor:const Color(0xFF1E2A1E), searchQuery:'electronic music'),
    Genre(name:'Devotional', emoji:'🪔', cardColor:const Color(0xFF2A1E1A), searchQuery:'devotional songs'),
    Genre(name:'Folk', emoji:'🥁', cardColor:const Color(0xFF1A2E2A), searchQuery:'folk songs india'),
    Genre(name:'Indie', emoji:'🌊', cardColor:const Color(0xFF1E1A2A), searchQuery:'indie songs'),
    Genre(name:'R&B', emoji:'✨', cardColor:const Color(0xFF2A1A2E), searchQuery:'rnb songs'),
  ];

  @override
  void initState() {
    super.initState();
    _searchHistory = StorageService.getSearchHistory();
    _loadGenreCounts();
    _loadTopArtists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadGenreCounts() async {
    for (int i = 0; i < _genres.length; i++) {
      final count = await _api.fetchTotalResultCount(_genres[i].searchQuery);
      if (mounted) {
        setState(() {
          _genres[i].songCount = count;
        });
      }
    }
  }

  Future<void> _loadTopArtists() async {
    final List<Song> allSongs = [];
    for (final lang in ['tamil', 'hindi', 'telugu', 'english']) {
      final songs = await _api.searchSongs('top $lang hits 2025', limit: 10);
      allSongs.addAll(songs);
    }
    
    final Map<String, ArtistData> artistMap = {};
    for (final song in allSongs) {
      final name = song.artistName;
      if (artistMap.containsKey(name)) {
        artistMap[name]!.songCount++;
        if (artistMap[name]!.imageUrl.isEmpty) {
          artistMap[name]!.imageUrl = song.imageUrl;
        }
      } else {
        artistMap[name] = ArtistData(
          name: name,
          imageUrl: song.imageUrl,
          language: song.language.isEmpty ? 'Unknown' : song.language,
          songCount: 1,
        );
      }
    }
    
    final sorted = artistMap.values.toList()..sort((a, b) => b.songCount.compareTo(a.songCount));
    if (mounted) {
      setState(() {
        _topArtists = sorted.take(10).toList();
        _isLoadingArtists = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() { 
        _isSearching = false; 
        _showHistory = true;
        songResults.clear();
        albumResults.clear();
        artistResults.clear();
      });
      return;
    }
    setState(() => _showHistory = false);
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      StorageService.addSearchHistory(query.trim());
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _isSearching = false);
      return;
    }
    
    setState(() {
      _isSearching = true;
      isLoadingSongs = true;
      isLoadingAlbums = true;
      isLoadingArtists = true;
      songResults = [];
      albumResults = [];
      artistResults = [];
    });

    final results = await Future.wait([
      _api.searchSongs(query, limit: 10),
      _api.searchAlbums(query, limit: 6),
      _api.searchArtists(query, limit: 5),
    ]);

    if (mounted && _searchController.text.trim() == query) {
      setState(() {
        songResults = results[0] as List<Song>;
        albumResults = results[1] as List<Album>;
        artistResults = results[2] as List<Artist>;
        isLoadingSongs = false;
        isLoadingAlbums = false;
        isLoadingArtists = false;
      });
    }
  }

  void _playSong(Song song, int index) {
    _player.playSong(song, songResults, index);
  }

  String _formatCount(int count) {
    if (count > 1000000) return '${(count / 1000000).toStringAsFixed(1)}M+';
    if (count > 1000) return '${(count / 1000).toStringAsFixed(0)}K+';
    return '$count';
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
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(
              child: _isSearching
                ? _buildSearchResults()
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: _showHistory 
                      ? _buildSearchHistory() 
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBrowseGrid(),
                            const SizedBox(height: 32),
                            _buildArtistsRow(),
                          ],
                        ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Discover', style: TextStyle(fontFamily: 'BebasNeue', fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE8C547), width: 2), color: const Color(0xFF1E1E2E)),
            child: const Icon(Icons.person, color: Color(0xFFE8C547), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search, color: Color(0xFF7A7890), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onTap: () {
                  if (_searchController.text.isEmpty) {
                    setState(() => _showHistory = true);
                  }
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF7A7890)),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF7A7890), size: 20),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text('No recent searches',
            style: TextStyle(color: Color(0xFF7A7890)),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(children: [
            const Text('Recent Searches',
              style: TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                await StorageService.clearSearchHistory();
                setState(() => _searchHistory = []);
              },
              child: const Text('Clear All',
                style: TextStyle(color: Color(0xFFE8C547),
                  fontSize: 13))),
          ]),
        ),
        ...(_searchHistory.map((query) =>
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.history,
              color: Color(0xFF7A7890), size: 20),
            title: Text(query,
              style: const TextStyle(color: Colors.white,
                fontSize: 14)),
            trailing: GestureDetector(
              onTap: () async {
                await StorageService.removeSearchHistoryItem(query);
                setState(() {
                  _searchHistory = StorageService.getSearchHistory();
                });
              },
              child: const Icon(Icons.close,
                color: Color(0xFF7A7890), size: 18)),
            onTap: () {
              _searchController.text = query;
              setState(() => _showHistory = false);
              _performSearch(query);
            },
          )
        )),
      ],
    );
  }

  Widget _buildSearchResults() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        // ARTISTS SECTION
        if (isLoadingArtists)
          _buildSectionSkeleton('Artists')
        else if (artistResults.isNotEmpty) ...[
          _buildSectionHeader('Artists', 
            onSeeAll: () => _showAllArtists()),
          ...artistResults.map(_buildArtistRow),
          const SizedBox(height: 16),
        ],

        // ALBUMS SECTION  
        if (isLoadingAlbums)
          _buildSectionSkeleton('Albums')
        else if (albumResults.isNotEmpty) ...[
          _buildSectionHeader('Albums',
            onSeeAll: () => _showAllAlbums()),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: albumResults.length,
              itemBuilder: (ctx, i) => 
                _buildAlbumCard(albumResults[i]),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // SONGS SECTION
        if (isLoadingSongs)
          _buildSectionSkeleton('Songs')
        else if (songResults.isNotEmpty) ...[
          _buildSectionHeader('Songs',
            onSeeAll: () => _showAllSongs()),
          ...songResults.asMap().entries.map((e) => _buildTrackRow(e.value, e.key)),
        ],

        // NO RESULTS
        if (!isLoadingSongs && !isLoadingAlbums && 
            !isLoadingArtists &&
            songResults.isEmpty && albumResults.isEmpty && 
            artistResults.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.search_off, 
                    color: Color(0xFF7A7890), size: 48),
                  const SizedBox(height: 12),
                  Text('No results for "${_searchController.text}"',
                    style: const TextStyle(color: Color(0xFF7A7890))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showAllArtists() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 8),
              child: Row(children: [
                const Text('All Artists',
                  style: TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                    color: Color(0xFF7A7890)),
                  onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            const Divider(color: Color(0xFF2E2E45)),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: artistResults.length,
                itemBuilder: (ctx, i) =>
                  _buildArtistRow(artistResults[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllAlbums() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 8),
              child: Row(children: [
                const Text('All Albums',
                  style: TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                    color: Color(0xFF7A7890)),
                  onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            const Divider(color: Color(0xFF2E2E45)),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85),
                itemCount: albumResults.length,
                itemBuilder: (ctx, i) =>
                  _buildAlbumCard(albumResults[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllSongs() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 8),
              child: Row(children: [
                const Text('All Songs',
                  style: TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                    color: Color(0xFF7A7890)),
                  onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            const Divider(color: Color(0xFF2E2E45)),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: songResults.length,
                itemBuilder: (ctx, i) =>
                  _buildTrackRow(songResults[i], i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSkeleton(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator(color: Color(0xFFE8C547))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(children: [
        Text(title, style: const TextStyle(
          color: Colors.white, fontSize: 18,
          fontWeight: FontWeight.bold)),
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Text('See All', style: TextStyle(
              color: Color(0xFFE8C547), fontSize: 13)),
          ),
      ]),
    );
  }

  Widget _buildAlbumCard(Album album) {
    return GestureDetector(
      onTap: () {
        // FIX 7: navigate to album page instead of playing directly
        Navigator.of(context, rootNavigator: true).pushNamed('/album', arguments: {
          'albumId': album.id,
          'albumName': album.name,
          'artistName': album.artistName,
          'imageUrl': album.imageUrl,
          'year': album.year,
        });
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(left: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: album.imageUrl,
                width: 120, height: 120,
                fit: BoxFit.cover,
                errorWidget: (c,u,e) => Container(
                  width: 120, height: 120,
                  color: const Color(0xFF1E1E2E),
                  child: const Icon(Icons.album,
                    color: Color(0xFF7A7890), size: 40)),
              ),
            ),
            const SizedBox(height: 6),
            Text(album.name,
              style: const TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(album.artistName,
              style: const TextStyle(color: Color(0xFF7A7890),
                fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistRow(Artist artist) {
    return GestureDetector(
      onTap: () async {
        final songs = await _api.searchSongs(artist.name, limit: 20);
        setState(() {
          songResults = songs;
          albumResults = [];
          artistResults = [];
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(
            color: Color(0xFF1E1E2E), width: 0.5))),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CachedNetworkImage(
              imageUrl: artist.imageUrl,
              width: 48, height: 48,
              fit: BoxFit.cover,
              errorWidget: (c,u,e) => Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E2E),
                  shape: BoxShape.circle),
                child: const Icon(Icons.person,
                  color: Color(0xFF7A7890))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(artist.name, style: const TextStyle(
                color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const Text('Artist', style: TextStyle(
                color: Color(0xFF7A7890), fontSize: 12)),
            ],
          )),
          const Icon(Icons.chevron_right,
            color: Color(0xFF7A7890), size: 20),
        ]),
      ),
    );
  }

  Widget _buildTrackRow(Song song, int index) {
    return GestureDetector(
      onTap: () => _playSong(song, index),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: song.imageUrl,
                width: 56, height: 56, fit: BoxFit.cover,
                errorWidget: (context, url, err) => Container(color: const Color(0xFF1E1E2E), width: 56, height: 56),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(song.artistName, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF7A7890)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(_formatDuration(song.duration), style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF7A7890))),
            const SizedBox(width: 4),
            SongThreeDots(song: song),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreCard(Genre genre) {
    return GestureDetector(
      onTap: () {
        _searchController.text = genre.searchQuery;
        _performSearch(genre.searchQuery);
      },
      child: Container(
        decoration: BoxDecoration(color: genre.cardColor, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(genre.emoji, style: const TextStyle(fontSize: 32)),
            const Spacer(),
            Text(genre.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            genre.songCount == 0
              ? const SizedBox(width: 60, height: 10, child: LinearProgressIndicator(backgroundColor: Color(0xFF2E2E45), color: Color(0xFFE8C547)))
              : Text('${_formatCount(genre.songCount)} tracks', style: const TextStyle(color: Color(0xFF7A7890), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Browse Music', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _genres.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              return _buildGenreCard(_genres[index]);
            },
          ),
        ],
      ),
    );
  }



  Widget _buildArtistsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: const Text('Top Artists', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        if (_isLoadingArtists)
           const Center(child: CircularProgressIndicator(color: Color(0xFFE8C547)))
        else
           ListView.builder(
             shrinkWrap: true,
             physics: const NeverScrollableScrollPhysics(),
             padding: const EdgeInsets.symmetric(horizontal: 16),
             itemCount: _topArtists.length,
             itemBuilder: (context, index) {
               final artist = _topArtists[index];
               return GestureDetector(
                 onTap: () async {
                   final songs = await _api.searchSongs(artist.name, limit: 20);
                   setState(() {
                     songResults = songs;
                     albumResults = [];
                     artistResults = [];
                     _isSearching = true; // Set search mode
                   });
                 },
                 child: Container(
                   padding: const EdgeInsets.symmetric(vertical: 10),
                   decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E1E2E), width: 0.5))),
                   child: Row(
                     children: [
                       ClipRRect(
                         borderRadius: BorderRadius.circular(24),
                         child: CachedNetworkImage(
                           imageUrl: artist.imageUrl,
                           width: 52, height: 52,
                           fit: BoxFit.cover,
                           placeholder: (c, u) => Container(width: 52, height: 52, decoration: const BoxDecoration(color: Color(0xFF1E1E2E), shape: BoxShape.circle), child: const Icon(Icons.person, color: Color(0xFF7A7890), size: 24)),
                           errorWidget: (c, u, e) => Container(width: 52, height: 52, decoration: const BoxDecoration(color: Color(0xFF1E1E2E), shape: BoxShape.circle), child: const Icon(Icons.person, color: Color(0xFF7A7890), size: 24)),
                         ),
                       ),
                       const SizedBox(width: 14),
                       Expanded(
                         child: Text(artist.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                       ),
                       const Icon(Icons.chevron_right, color: Color(0xFF7A7890), size: 20),
                     ],
                   ),
                 ),
               );
             },
           ),
      ],
    );
  }
}
