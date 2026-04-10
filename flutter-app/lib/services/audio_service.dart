import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  
  bool _isRecording = false;
  String? _recordingPath;

  bool get isRecording => _isRecording;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String?> startRecording() async {
    if (!await hasPermission()) {
      return null;
    }

    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${directory.path}/voice_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );

      _isRecording = true;
      return _recordingPath;
    } catch (e) {
      debugPrint('录音失败: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      return path;
    } catch (e) {
      debugPrint('停止录音失败: $e');
      return null;
    }
  }

  Future<void> playVoice(String url) async {
    try {
      if (url.startsWith('http')) {
        await _player.play(UrlSource(url));
      } else {
        await _player.play(DeviceFileSource(url));
      }
    } catch (e) {
      debugPrint('播放语音失败: $e');
    }
  }

  Future<void> stopPlaying() async {
    await _player.stop();
  }

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
