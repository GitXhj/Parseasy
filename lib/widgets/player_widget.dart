import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song_model.dart';
import '../services/api_service.dart';

class PlayerWidget extends StatefulWidget {
  final Song song;

  const PlayerWidget({super.key, required this.song});

  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  SongDetail? _songDetail;
  bool _isLoading = true;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  String _selectedQuality = 'exhigh';
  
  late AnimationController _rotationController;

  // 歌词相关变量
  bool _showLyrics = false;
  List<LyricLine> _lyrics = [];
  int _currentLyricIndex = -1;

  final List<Map<String, String>> _qualityOptions = [
    {'value': 'standard', 'label': '标准音质'},
    {'value': 'exhigh', 'label': '极高音质'},
    {'value': 'lossless', 'label': '无损音质'},
    {'value': 'hires', 'label': 'Hires音质'},
    {'value': 'sky', 'label': '沉浸环绕声'},
    {'value': 'jyeffect', 'label': '高清环绕声'},
    {'value': 'jymaster', 'label': '超清母带'},
  ];

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    
    // 添加监听器时使用 mounted 检查
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });
    
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
          _updateCurrentLyric(position.inMilliseconds);
        });
      }
    });
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (_isPlaying) {
            _rotationController.repeat();
          } else {
            _rotationController.stop();
          }
        });
      }
    });
    
    _loadSongDetail();
  }

  void _updateCurrentLyric(int positionMs) {
    if (_lyrics.isEmpty) return;
    
    for (int i = _lyrics.length - 1; i >= 0; i--) {
      if (positionMs >= _lyrics[i].time) {
        if (_currentLyricIndex != i) {
          _currentLyricIndex = i;
        }
        break;
      }
    }
  }

  Future<void> _loadSongDetail() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    final detail = await ApiService.parseSong(widget.song.id, _selectedQuality);
    
    if (!mounted) return;
    
    if (detail != null) {
      setState(() {
        _songDetail = detail;
        _lyrics = ApiService.parseLyrics(detail.lyric, detail.tlyric);
        _isLoading = false;
      });
      
      await _audioPlayer.play(UrlSource(detail.url));
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('解析失败，请尝试其他音质')),
        );
      }
    }
  }

  Future<void> _changeQuality(String quality) async {
    if (!mounted) return;
    
    setState(() {
      _selectedQuality = quality;
      _isLoading = true;
    });
    
    await _audioPlayer.stop();
    await _loadSongDetail();
  }

  Future<void> _downloadSong() async {
    if (_songDetail == null || !mounted) return;

    final status = await Permission.storage.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要存储权限才能下载')),
        );
      }
      return;
    }

    try {
      final dir = await getExternalStorageDirectory();
      final fileName = '${_songDetail!.name} - ${_songDetail!.arName}.mp3';
      final savePath = '${dir!.path}/$fileName';

      await Dio().download(_songDetail!.url, savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载成功: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parseasy - 析易'),
        actions: [
          IconButton(
            icon: Icon(_showLyrics ? Icons.lyrics : Icons.lyrics_outlined),
            onPressed: () {
              setState(() => _showLyrics = !_showLyrics);
            },
            tooltip: _showLyrics ? '关闭歌词' : '显示歌词',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPlayer(),
    );
  }

  Widget _buildPlayer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: _buildLeftPanel(),
        ),
        Expanded(
          flex: 2,
          child: _buildRightPanel(),
        ),
      ],
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_songDetail != null) ...[
              RotationTransition(
                turns: _rotationController,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _songDetail!.pic,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.music_note, size: 80),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _songDetail!.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _songDetail!.arName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildProgressBar(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: _showLyrics ? _buildLyricsPanel() : _buildControlPanel(),
    );
  }

  Widget _buildControlPanel() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '播放控制',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildPlayControl(),
            const SizedBox(height: 24),
            _buildQualityControl(),
            const SizedBox(height: 24),
            _buildVolumeControl(),
            const SizedBox(height: 24),
            _buildDownloadControl(),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lyrics,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '歌词',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _lyrics.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lyrics,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无歌词',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _lyrics.length,
                    itemBuilder: (context, index) {
                      final lyric = _lyrics[index];
                      final isActive = index == _currentLyricIndex;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.5)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lyric.text,
                              style: TextStyle(
                                fontSize: isActive ? 16 : 14,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isActive
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                              ),
                            ),
                            if (lyric.translation != null &&
                                lyric.translation!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                lyric.translation!,
                                style: TextStyle(
                                  fontSize: isActive ? 12 : 11,
                                  color: isActive
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.7)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Slider(
          value: _position.inSeconds.toDouble(),
          max: _duration.inSeconds.toDouble().clamp(1, double.infinity),
          onChanged: (value) {
            _audioPlayer.seek(Duration(seconds: value.toInt()));
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position)),
              Text(_formatDuration(_duration)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayControl() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(_isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled),
              iconSize: 64,
              color: Theme.of(context).colorScheme.primary,
              onPressed: _togglePlayPause,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityControl() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.high_quality),
                const SizedBox(width: 8),
                const Text('音质选择'),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedQuality,
              items: _qualityOptions.map((option) {
                return DropdownMenuItem(
                  value: option['value'],
                  child: Text(option['label']!),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) _changeQuality(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.volume_up),
                const SizedBox(width: 8),
                const Text('音量调节'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: (value) {
                      setState(() => _volume = value);
                      _audioPlayer.setVolume(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(_volume * 100).toInt()}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadControl() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download),
                const SizedBox(width: 8),
                const Text('下载'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _downloadSong,
                icon: const Icon(Icons.download),
                label: const Text('下载'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}