class Song {
  final String id;
  final String name;
  final List<String> artists;
  final String? albumName;
  final String? picUrl;

  Song({
    required this.id,
    required this.name,
    required this.artists,
    this.albumName,
    this.picUrl,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    List<String> artistNames = [];
    if (json['artists'] != null) {
      for (var artist in json['artists']) {
        artistNames.add(artist['name'] ?? '');
      }
    }

    return Song(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      artists: artistNames,
      albumName: json['album']?['name'],
      picUrl: json['album']?['picUrl'],
    );
  }

  String get artistsText => artists.join(', ');
}

class SongDetail {
  final String name;
  final String arName;
  final String alName;
  final String pic;
  final String url;
  final String level;
  final String size;
  final String lyric;
  final String tlyric;

  SongDetail({
    required this.name,
    required this.arName,
    required this.alName,
    required this.pic,
    required this.url,
    required this.level,
    required this.size,
    required this.lyric,
    required this.tlyric,
  });

  factory SongDetail.fromJson(Map<String, dynamic> json) {
    return SongDetail(
      name: json['name'] ?? '',
      arName: json['ar_name'] ?? '',
      alName: json['al_name'] ?? '',
      pic: json['pic'] ?? '',
      url: json['url'] ?? '',
      level: json['level'] ?? '',
      size: json['size'] ?? '',
      lyric: json['lyric'] ?? '',
      tlyric: json['tlyric'] ?? '',
    );
  }
}

class LyricLine {
  final int time;
  final String text;
  final String? translation;

  LyricLine({
    required this.time,
    required this.text,
    this.translation,
  });
}