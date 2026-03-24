import '../models/song.dart';

class Album {
  final String id;
  final String name;
  final String artistName;
  final String imageUrl;
  final int songCount;
  final String year;

  Album({
    required this.id, 
    required this.name,
    required this.artistName, 
    required this.imageUrl,
    this.songCount = 0, 
    this.year = ''
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    String imageUrl = '';
    final images = json['image'] as List?;
    if (images != null && images.length > 2) {
      imageUrl = images[2]['url'] ?? '';
    }
    String artistName = '';
    final artists = json['artists']?['primary'] as List?;
    if (artists != null && artists.isNotEmpty) {
      artistName = artists[0]['name'] ?? '';
    }
    return Album(
      id: json['id'] ?? '',
      name: Song.decodeHtml(json['name'] ?? ''),
      artistName: Song.decodeHtml(artistName),
      imageUrl: imageUrl,
      songCount: json['songCount'] ?? 0,
      year: json['year']?.toString() ?? '',
    );
  }
}
