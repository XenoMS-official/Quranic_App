import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String audioUrl;
  final String title;
  
  const AudioPlayerScreen({super.key, required this.audioUrl, required this.title});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setAudio();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => isPlaying = state == PlayerState.playing);
    });
    
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => duration = newDuration);
    });
    
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => position = newPosition);
    });
  }

  Future<void> _setAudio() async {
    await _audioPlayer.setSourceUrl(widget.audioUrl);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Now Playing", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            // Circular Record Player UI
            Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E1E1E),
                boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Center(
                child: Container(
                  height: 60,
                  width: 60,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4CAF50)),
                  child: Center(child: Container(height: 15, width: 15, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black))),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Audio Library", style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 30),
            
            // Slider
            SliderTheme(
              data: SliderThemeData(
                thumbColor: const Color(0xFF4CAF50),
                activeTrackColor: const Color(0xFF4CAF50).withOpacity(0.5),
                inactiveTrackColor: Colors.grey.shade300,
              ),
              child: Slider(
                min: 0, max: duration.inSeconds.toDouble(), value: position.inSeconds.toDouble(),
                onChanged: (value) async {
                  final pos = Duration(seconds: value.toInt());
                  await _audioPlayer.seek(pos);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children:[
                  Text(formatTime(position), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(formatTime(duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
                  child: const Text("1.0x", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                ),
                const SizedBox(width: 20),
                IconButton(icon: const FaIcon(FontAwesomeIcons.backwardStep, color: Colors.grey), onPressed: () {}),
                GestureDetector(
                  onTap: () async {
                    if (isPlaying) {
                      await _audioPlayer.pause();
                    } else {
                      await _audioPlayer.resume();
                    }
                  },
                  child: Container(
                    height: 70, width: 70, margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4CAF50)),
                    child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
                  ),
                ),
                IconButton(icon: const FaIcon(FontAwesomeIcons.forwardStep, color: Colors.black), onPressed: () {}),
              ],
            )
          ],
        ),
      ),
    );
  }
}