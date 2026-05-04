import 'package:hive/hive.dart';

class Song {
  final String id;
  final String name;
  final String artistName;
  final String imageUrl;
  final String streamUrl;
  final int duration;
  final String language;
  final String albumName;
  final String albumId;
  
  bool isDownloaded;
  bool isLiked;

  Song({
    required this.id,
    required this.name,
    required this.artistName,
    required this.imageUrl,
    required this.streamUrl,
    required this.duration,
    required this.language,
    this.albumName = '',
    this.albumId = '',
    this.isDownloaded = false,
    this.isLiked = false,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    String streamUrl = '';
    final downloadUrls = json['downloadUrl'] as List?;
    if (downloadUrls != null && downloadUrls.isNotEmpty) {
      if (downloadUrls.length > 4) {
        streamUrl = downloadUrls[4]['url'] ?? '';
      }
      if (streamUrl.isEmpty && downloadUrls.length > 3) {
        streamUrl = downloadUrls[3]['url'] ?? '';
      }
      if (streamUrl.isEmpty) {
        streamUrl = downloadUrls.last['url'] ?? '';
      }
    }

    String imageUrl = '';
    final images = json['image'] as List?;
    if (images != null && images.length > 2) {
      imageUrl = images[2]['url'] ?? '';
    } else if (images != null && images.isNotEmpty) {
      imageUrl = images.last['url'] ?? '';
    }

    String artistName = 'Unknown Artist';
    final artists = json['artists']?['primary'] as List?;
    if (artists != null && artists.isNotEmpty) {
      artistName = artists[0]['name'] ?? 'Unknown Artist';
    }

    return Song(
      id: json['id'] ?? '',
      name: decodeHtml(json['name'] ?? ''),
      artistName: decodeHtml(artistName),
      imageUrl: imageUrl,
      streamUrl: streamUrl,
      duration: int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
      language: json['language'] ?? 'Unknown',
      albumName: decodeHtml(json['album']?['name'] ?? ''),
      albumId: json['album']?['id']?.toString() ?? '',
    );
  }

  static String decodeHtml(String text) {
    return text
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&apos;', "'");
  }
}

class SongAdapter extends TypeAdapter<Song> {
  @override
  final int typeId = 0;

  @override
  Song read(BinaryReader reader) {
    return Song(
      id: reader.readString(),
      name: reader.readString(),
      artistName: reader.readString(),
      imageUrl: reader.readString(),
      streamUrl: reader.readString(),
      duration: reader.readInt(),
      language: reader.readString(),
      albumName: reader.readString(),
      albumId: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, Song obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.artistName);
    writer.writeString(obj.imageUrl);
    writer.writeString(obj.streamUrl);
    writer.writeInt(obj.duration);
    writer.writeString(obj.language);
    writer.writeString(obj.albumName);
    writer.writeString(obj.albumId);
  }
}
