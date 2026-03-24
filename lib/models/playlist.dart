import 'package:hive/hive.dart';
import 'song.dart';

class Playlist {
  final String id;
  final String name;
  final List<Song> songs;

  Playlist({
    required this.id,
    required this.name,
    required this.songs,
  });
}

class PlaylistAdapter extends TypeAdapter<Playlist> {
  @override
  final int typeId = 1;

  @override
  Playlist read(BinaryReader reader) {
    return Playlist(
      id: reader.readString(),
      name: reader.readString(),
      songs: reader.readList().cast<Song>(),
    );
  }

  @override
  void write(BinaryWriter writer, Playlist obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeList(obj.songs);
  }
}
