import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/song_model.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String searchApi = 'api_search';
  static const String parseApi = 'api_music';

  static Future<List<Song>> searchSongs(String keyword) async {
    try {
      final response = await http.get(
        Uri.parse('$searchApi?name=$keyword&limit=20'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => Song.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      developer.log('搜索失败: $e', name: 'ApiService');
      return [];
    }
  }

  static Future<SongDetail?> parseSong(String songId, String level) async {
    try {
      final response = await http.post(
        Uri.parse(parseApi),
        body: {
          'url': songId,
          'level': level,
          'type': 'json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 200) {
          return SongDetail.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      developer.log('解析失败: $e', name: 'ApiService');
      return null;
    }
  }

  static List<LyricLine> parseLyrics(String lyricStr, String? translationStr) {
    // 检查歌词是否为空
    if (lyricStr.isEmpty) {
      developer.log('歌词为空', name: 'ApiService');
      return [];
    }

    final lyrics = _parseSingleLyric(lyricStr);
    developer.log('解析原文歌词: ${lyrics.length} 行', name: 'ApiService');

    final translations = (translationStr != null && translationStr.isNotEmpty)
        ? _parseSingleLyric(translationStr)
        : <LyricLine>[];
    developer.log('解析翻译歌词: ${translations.length} 行', name: 'ApiService');

    final Map<int, LyricLine> mergedMap = {};

    // 先添加原文歌词
    for (var lyric in lyrics) {
      mergedMap[lyric.time] = lyric;
    }

    // 添加翻译
    for (var trans in translations) {
      if (mergedMap.containsKey(trans.time)) {
        mergedMap[trans.time] = LyricLine(
          time: trans.time,
          text: mergedMap[trans.time]!.text,
          translation: trans.text,
        );
      } else {
        mergedMap[trans.time] = LyricLine(
          time: trans.time,
          text: trans.text,
          translation: null,
        );
      }
    }

    final result = mergedMap.values.toList();
    result.sort((a, b) => a.time.compareTo(b.time));
    
    developer.log('合并后歌词: ${result.length} 行', name: 'ApiService');
    return result;
  }

static List<LyricLine> _parseSingleLyric(String lyricStr) {
  if (lyricStr.trim().isEmpty) {
    debugPrint('lyricStr 是空的');
    return [];
  }

  final lines = lyricStr.split('\n');
  final List<LyricLine> result = [];

  final regExp = RegExp(
    r'\[(\d+):(\d+)(?:\.(\d+))?\](.*)'
  );

  for (final line in lines) {
    final match = regExp.firstMatch(line);
    if (match == null) continue;

    final min = int.parse(match.group(1)!);
    final sec = int.parse(match.group(2)!);
    final ms = int.parse((match.group(3) ?? '0').padRight(3, '0'));

    final text = match.group(4)?.trim() ?? '';
    if (text.isEmpty) continue;

    final time = (min * 60 + sec) * 1000 + ms;

    result.add(
      LyricLine(
        time: time,
        text: text,
      ),
    );
  }

  
  return result;
}
}