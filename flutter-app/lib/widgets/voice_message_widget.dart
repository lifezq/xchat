import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class VoiceMessageWidget extends StatefulWidget {
  final String voiceUrl;
  final bool isMe;

  const VoiceMessageWidget({
    super.key,
    required this.voiceUrl,
    required this.isMe,
  });

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  final AudioService _audioService = AudioService();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioService.stopPlaying();
      setState(() => _isPlaying = false);
    } else {
      await _audioService.playVoice(widget.voiceUrl);
      setState(() => _isPlaying = true);
      
      // 模拟播放完成
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isMe ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.graphic_eq,
              color: widget.isMe ? Colors.white : Colors.black87,
            ),
          ],
        ),
      ),
    );
  }
}
