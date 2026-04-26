import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_data_cubit.dart';
import 'channel_profile.dart';

class FullVideoPlayer extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final List<Map<String, dynamic>>? relatedVideosList;

  const FullVideoPlayer({super.key, required this.videoData, this.relatedVideosList});

  @override
  State<FullVideoPlayer> createState() => _FullVideoPlayerState();
}

class _FullVideoPlayerState extends State<FullVideoPlayer> {
  late YoutubePlayerController _controller;
  late Map<String, dynamic> currentVideoData;
  List<Map<String, dynamic>> relatedVideos =[];
  bool isDescriptionExpanded = false;
  
  bool _isFullScreen = false;
  bool _isRelatedLoaded = false;

  bool get isShort => currentVideoData['section'] == 'short' || currentVideoData['type'] == 'short';

  @override
  void initState() {
    super.initState();
    currentVideoData = widget.videoData;
    
    // Strict Orientation Locking
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _initController();
    
    // DEFER heavy network operations to save the Main Thread from "Skipped 171 Frames" crashes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 600), () => _fetchRelatedVideos());
    });
  }

  void _initController() {
    _controller = YoutubePlayerController(
      initialVideoId: currentVideoData['video_id'],
      flags: YoutubePlayerFlags(
        autoPlay: true,
        enableCaption: true,
        captionLanguage: 'en',
        forceHD: false, // Critical for Emulator stability
        isLive: currentVideoData['section'] == 'live' || currentVideoData['type'] == 'live_or_individual',
      ),
    )..addListener(_videoListener);
  }

  void _videoListener() {
    if (_controller.value.isFullScreen != _isFullScreen) {
      // Use mounted check to prevent setState during disposal or rapid navigation
      if (mounted) {
        setState(() {
          _isFullScreen = _controller.value.isFullScreen;
        });
      }

      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  Future<void> _fetchRelatedVideos() async {
    if (!mounted) return;
    
    try {
      if (widget.relatedVideosList != null && widget.relatedVideosList!.isNotEmpty) {
        setState(() {
          relatedVideos = List.from(widget.relatedVideosList!);
          relatedVideos.removeWhere((vid) => vid['video_id'] == currentVideoData['video_id']);
          _isRelatedLoaded = true;
        });
        return;
      }

      final snap = await FirebaseFirestore.instance.collection('video_hub').limit(10).get();
      List<Map<String, dynamic>> fetched = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      fetched.removeWhere((vid) => vid['video_id'] == currentVideoData['video_id'] || vid['section'] == 'short');
      fetched.shuffle();
      
      if (mounted) {
        setState(() {
          relatedVideos = fetched;
          _isRelatedLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Error fetching related videos: $e");
    }
  }

  void _playNextVideo() {
    if (relatedVideos.isNotEmpty) {
      if (mounted) {
        setState(() {
          currentVideoData = relatedVideos.removeAt(0);
          _controller.load(currentVideoData['video_id']);
          isDescriptionExpanded = false;
          _isRelatedLoaded = false;
        });
      }
      Future.delayed(const Duration(milliseconds: 500), () => _fetchRelatedVideos());
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Widget _buildVideoPlayerWithGestures(Widget playerWidget) {
    // 1. STRICT PHYSICAL CONSTRAINTS to prevent WebView resizing bugs 
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    final double targetWidth = _isFullScreen ? screenHeight : screenWidth;
    final double targetHeight = _isFullScreen 
        ? screenWidth 
        : (isShort ? (screenWidth * 16 / 9) : (screenWidth * 9 / 16));

    return SizedBox(
      width: targetWidth,
      height: targetHeight,
      child: Stack(
        alignment: Alignment.center,
        children:[
          // The actual Player wrapped firmly to prevent bleed
          Positioned.fill(child: playerWidget),
          
          // Left Double Tap
          Positioned(
            left: 0, top: 0, bottom: 40,
            width: targetWidth * 0.35,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () {
                final newPos = _controller.value.position - const Duration(seconds: 10);
                _controller.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
              },
            ),
          ),
          
          // Right Double Tap
          Positioned(
            right: 0, top: 0, bottom: 40,
            width: targetWidth * 0.35,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () {
                final newPos = _controller.value.position + const Duration(seconds: 10);
                _controller.seekTo(newPos);
              },
              onLongPressStart: (_) {
                _controller.setPlaybackRate(2.0);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Playing at 2x speed"), duration: Duration(milliseconds: 600))
                );
              },
              onLongPressEnd: (_) {
                _controller.setPlaybackRate(1.0);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final basePlayer = YoutubePlayer(
      controller: _controller,
      aspectRatio: isShort ? 9 / 16 : 16 / 9, 
      showVideoProgressIndicator: true,
      progressColors: const ProgressBarColors(
        playedColor: Colors.red,
        handleColor: Colors.redAccent,
      ),
      onEnded: (metaData) => _playNextVideo(),
      bottomActions:[
        const SizedBox(width: 14.0),
        CurrentPosition(),
        const SizedBox(width: 8.0),
        ProgressBar(
          isExpanded: true,
          colors: const ProgressBarColors(playedColor: Colors.red, handleColor: Colors.redAccent),
        ),
        IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 26), onPressed: _playNextVideo),
        const PlaybackSpeedButton(),
        if (!isShort) FullScreenButton(), 
      ],
    );

    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          _controller.toggleFullScreenMode();
          return false; 
        }
        return true; 
      },
      child: Scaffold(
        backgroundColor: _isFullScreen ? Colors.black : Colors.white,
        appBar: _isFullScreen ? null : AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isFullScreen 
            ? Center(child: _buildVideoPlayerWithGestures(basePlayer))
            : Column(
                children:[
                  // This container stops the Player from bleeding into the ListView below it
                  Container(
                    color: Colors.black,
                    child: _buildVideoPlayerWithGestures(basePlayer),
                  ),
                  Expanded(child: _buildPortraitContent()),
                ],
              ),
      ),
    );
  }

  Widget _buildPortraitContent() {
    final title = currentVideoData['title'] ?? 'Video';
    final channel = currentVideoData['channel_name'] ?? 'Creator';
    final isLive = currentVideoData['section'] == 'live' || currentVideoData['type'] == 'live_or_individual';
    final views = isLive ? '${_formatNumber(currentVideoData['view_count'] ?? 1200)} watching' : '${_formatNumber(currentVideoData['view_count'] ?? 0)} views';
    final likes = _formatNumber(currentVideoData['like_count'] ?? 0);
    final videoId = currentVideoData['video_id'];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children:[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children:[
              if (isLive) ...[
                const Icon(Icons.sensors, color: Colors.red, size: 16),
                const SizedBox(width: 4),
              ],
              Text(views, style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children:[
              GestureDetector(
                onTap: () {
                  _controller.pause();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelProfile(channelName: channel, preloadedVideos: widget.relatedVideosList)));
                },
                child: CircleAvatar(
                  backgroundColor: Colors.grey.shade300, 
                  backgroundImage: CachedNetworkImageProvider(currentVideoData['thumbnail'] ?? '')
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _controller.pause();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelProfile(channelName: channel, preloadedVideos: widget.relatedVideosList)));
                  },
                  child: Text(channel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              BlocBuilder<UserDataCubit, UserDataState>(
                builder: (context, state) {
                  bool isSubscribed = state.subscribedChannels.contains(channel);
                  return GestureDetector(
                    onTap: () => context.read<UserDataCubit>().toggleSubscription(channel),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSubscribed ? Colors.grey.shade200 : Colors.black, 
                        borderRadius: BorderRadius.circular(20)
                      ),
                      child: Text(isSubscribed ? "Subscribed" : "Subscribe", style: TextStyle(color: isSubscribed ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<UserDataCubit, UserDataState>(
          builder: (context, state) {
            bool isLiked = state.likedVideos.contains(videoId);
            bool isSaved = state.savedVideos.contains(videoId);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children:[
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children:[
                        _buildPillButton(isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, isLiked ? "Liked" : likes, () => context.read<UserDataCubit>().toggleLike(videoId), showBg: false),
                        Container(height: 20, width: 1, color: Colors.grey.shade400),
                        _buildPillButton(Icons.thumb_down_alt_outlined, "", () {}, showBg: false),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPillButton(Icons.reply_outlined, "Share", () => Share.share('https://youtu.be/$videoId')),
                  const SizedBox(width: 8),
                  _buildPillButton(isSaved ? Icons.library_add_check : Icons.library_add_outlined, isSaved ? "Saved" : "Save", () => context.read<UserDataCubit>().toggleSave(videoId)),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GestureDetector(
            onTap: () => setState(() => isDescriptionExpanded = !isDescriptionExpanded),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(currentVideoData['description'] ?? '', maxLines: isDescriptionExpanded ? null : 2, overflow: isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis),
                  if (!isDescriptionExpanded) 
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text("...more", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Text("Up Next", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        
        // Prevent UI freezing by showing a loader until related videos are securely fetched
        if (!_isRelatedLoaded)
           const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Colors.red)))
        else if (relatedVideos.isEmpty)
           const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No related videos found.")))
        else 
          ...relatedVideos.map((relatedData) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 140, height: 90,
                  child: CachedNetworkImage(
                    imageUrl: relatedData['thumbnail'] ?? '', 
                    fit: BoxFit.cover,
                    memCacheWidth: 280, // RAM Optimization
                  ),
                ),
              ),
              title: Text(relatedData['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text("${relatedData['channel_name']} • ${_formatNumber(relatedData['view_count'] ?? 0)} views", style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ),
              onTap: () {
                // Instantly update the UI but defer the heavy network fetch
                setState(() {
                  currentVideoData = relatedData;
                  _controller.load(currentVideoData['video_id']);
                  isDescriptionExpanded = false;
                  _isRelatedLoaded = false;
                });
                Future.delayed(const Duration(milliseconds: 500), () => _fetchRelatedVideos());
              },
            );
          })
      ],
    );
  }

  Widget _buildPillButton(IconData icon, String label, VoidCallback onTap, {bool showBg = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: showBg ? Colors.grey.shade100 : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children:[
            Icon(icon, size: 20),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]
          ],
        ),
      ),
    );
  }
}