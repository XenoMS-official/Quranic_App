import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'user_data_cubit.dart';
import 'channel_profile.dart';

class ShortsPlayer extends StatefulWidget {
  final List<Map<String, dynamic>> shortsList; 
  final int initialIndex;

  const ShortsPlayer({super.key, required this.shortsList, required this.initialIndex});

  @override
  State<ShortsPlayer> createState() => _ShortsPlayerState();
}

class _ShortsPlayerState extends State<ShortsPlayer> {
  late PageController _pageController;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // Immersive mode gives a true "TikTok/Reels" full-screen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // Restore system UI when exiting
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        physics: const ClampingScrollPhysics(), 
        itemCount: widget.shortsList.length,
        itemBuilder: (context, index) {
          final data = widget.shortsList[index];
          return ShortVideoItem(
            // THE FIX: ValueKey forces Flutter to create a new controller for each video
            key: ValueKey(data['video_id']), 
            data: data,
            index: index,
            currentIndex: currentIndex,
          );
        },
      ),
    );
  }
}

class ShortVideoItem extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;
  final int currentIndex;

  const ShortVideoItem({
    super.key, 
    required this.data, 
    required this.index, 
    required this.currentIndex
  });

  @override
  State<ShortVideoItem> createState() => _ShortVideoItemState();
}

class _ShortVideoItemState extends State<ShortVideoItem> {
  YoutubePlayerController? _ytController;
  bool _isReady = false; // Used to crossfade the thumbnail into the video

  bool get isCurrent => widget.index == widget.currentIndex;
  bool get isPreloaded => (widget.index - widget.currentIndex).abs() <= 1;

  @override
  void initState() {
    super.initState();
    if (isPreloaded) {
      _initController();
    }
  }

  @override
  void didUpdateWidget(covariant ShortVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Safety check in case Flutter tries to recycle the state
    if (oldWidget.data['video_id'] != widget.data['video_id']) {
      _disposeController();
      if (isPreloaded) _initController();
      return;
    }

    bool wasPreloaded = (oldWidget.index - oldWidget.currentIndex).abs() <= 1;
    if (isPreloaded && !wasPreloaded) {
      _initController();
    } else if (!isPreloaded && wasPreloaded) {
      _disposeController();
    }

    bool wasCurrent = oldWidget.index == oldWidget.currentIndex;
    if (isCurrent && !wasCurrent) {
      _ytController?.play();
    } else if (!isCurrent && wasCurrent) {
      _ytController?.pause();
      _ytController?.seekTo(Duration.zero); // Reset video for next time
    }
  }

  void _initController() {
    if (_ytController != null) return;
    _ytController = YoutubePlayerController(
      initialVideoId: widget.data['video_id'],
      flags: YoutubePlayerFlags(
        autoPlay: isCurrent, 
        mute: false,
        hideControls: true, 
        loop: true,
        forceHD: true,
        disableDragSeek: true,
      ),
    )..addListener(_listener);
  }

  void _listener() {
    if (_ytController?.value.isReady == true && !_isReady) {
      if (mounted) setState(() => _isReady = true);
    }
  }

  void _disposeController() {
    _ytController?.removeListener(_listener);
    _ytController?.dispose();
    _ytController = null;
    _isReady = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _shareShort(String videoId, String title) {
    Share.share('Watch this amazing Short: $title\nhttps://youtu.be/$videoId');
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] ?? 'Short';
    final channel = widget.data['channel_name'] ?? 'Creator';
    final likes = widget.data['like_count'] ?? 1024;
    final videoId = widget.data['video_id'];
    final thumbnail = widget.data['thumbnail'] ?? '';

    return Stack(
      fit: StackFit.expand,
      children:[
        // Base Thumbnail (Always shows instantly when swiping)
        Image.network(thumbnail, fit: BoxFit.cover),
        
        // Video Player (Crossfades in over the thumbnail once buffered)
        if (_ytController != null)
          AnimatedOpacity(
            opacity: _isReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: GestureDetector(
              onTap: () {
                if (_ytController != null) {
                  _ytController!.value.isPlaying ? _ytController!.pause() : _ytController!.play();
                }
              },
              child: AbsorbPointer( 
                absorbing: true,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width * (16 / 9),
                    child: YoutubePlayer(
                      controller: _ytController!,
                      showVideoProgressIndicator: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: 250,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, 
                  end: Alignment.topCenter, 
                  colors:[Colors.black87, Colors.transparent]
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20, right: 8,
          child: BlocBuilder<UserDataCubit, UserDataState>(
            builder: (context, state) {
              bool isLiked = state.likedVideos.contains(videoId);
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children:[
                  GestureDetector(
                    onTap: () => context.read<UserDataCubit>().toggleLike(videoId),
                    child: _buildActionIcon(isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, isLiked ? _formatNumber(likes + 1) : _formatNumber(likes), color: isLiked ? Colors.blue : Colors.white),
                  ),
                  const SizedBox(height: 20),
                  _buildActionIcon(Icons.thumb_down_alt_outlined, "Dislike"),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _shareShort(videoId, title),
                    child: _buildActionIcon(Icons.reply_outlined, "Share"),
                  ),
                  const SizedBox(height: 20),
                  _buildActionIcon(Icons.more_horiz, "More"),
                ],
              );
            },
          ),
        ),
        Positioned(
          bottom: 20, left: 16, right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              Row(
                children:[
                  GestureDetector(
                    onTap: () {
                       _ytController?.pause();
                       Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelProfile(channelName: channel)));
                    },
                    child: CircleAvatar(radius: 16, backgroundColor: Colors.grey, backgroundImage: NetworkImage(thumbnail)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                         _ytController?.pause();
                         Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelProfile(channelName: channel)));
                      },
                      child: Text('@${channel.replaceAll(' ', '')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BlocBuilder<UserDataCubit, UserDataState>(
                    builder: (context, state) {
                      bool isSubscribed = state.subscribedChannels.contains(channel);
                      return GestureDetector(
                        onTap: () => context.read<UserDataCubit>().toggleSubscription(channel),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: isSubscribed ? Colors.white24 : Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Text(isSubscribed ? "Subscribed" : "Subscribe", style: TextStyle(color: isSubscribed ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      );
                    },
                  )
                ],
              ),
              const SizedBox(height: 12),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
        Positioned(
          top: 10, left: 16,
          child: SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), 
                onPressed: () {
                  _ytController?.pause();
                  Navigator.pop(context);
                }
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, String label, {Color color = Colors.white}) {
    return Column(
      children:[
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}