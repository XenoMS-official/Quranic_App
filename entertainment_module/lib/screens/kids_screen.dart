import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Import your unified components
import 'video_screen/user_data_cubit.dart';
import 'video_screen/filtered_screen.dart';
import 'video_screen/full_video_player.dart';
import 'video_screen/shorts_player.dart';
import 'video_screen/channel_profile.dart';

abstract class KidsVideoState {}
class KidsVideoLoading extends KidsVideoState {}
class KidsVideoLoaded extends KidsVideoState {
  final List<Map<String, dynamic>> allVideos;
  final List<Map<String, dynamic>> filteredVideos;
  final String selectedCategory;
  KidsVideoLoaded({required this.allVideos, required this.filteredVideos, required this.selectedCategory});
}
class KidsVideoError extends KidsVideoState {
  final String message;
  KidsVideoError(this.message);
}

class KidsVideoCubit extends Cubit<KidsVideoState> {
  KidsVideoCubit() : super(KidsVideoLoading());

  Future<void> fetchVideos(String categoryId) async {
    emit(KidsVideoLoading());
    try {
      List<Map<String, dynamic>> allVideos =[];
      var channelsSnap = await FirebaseFirestore.instance.collection('kids_zone').doc(categoryId).collection('channels').get();

      var results = await Future.wait(channelsSnap.docs.map((ch) async {
        List<Map<String, dynamic>> channelVideos =[];
        var vidsSnap = await ch.reference.collection('videos').get();
        for (var v in vidsSnap.docs) {
          var data = v.data();
          data['channel_name'] = ch['name'];
          data['video_id'] = data['videoId'];
          data['view_count'] = data['viewCount'] ?? 1024;
          data['like_count'] = data['likeCount'] ?? 250;

          String title = (data['title'] ?? '').toLowerCase();
          data['section'] = (title.contains('#short') || title.contains('shorts') || title.contains('short')) ? 'short' : 'video';

          channelVideos.add(data);
        }
        return channelVideos;
      }));

      for (var res in results) {
        allVideos.addAll(res);
      }

      allVideos.shuffle();
      emit(KidsVideoLoaded(allVideos: allVideos, filteredVideos: allVideos, selectedCategory: "All"));
    } catch (e) {
      emit(KidsVideoError("Failed to load videos."));
    }
  }

  void changeCategory(String category) {
    if (state is KidsVideoLoaded) {
      final currentState = state as KidsVideoLoaded;
      List<Map<String, dynamic>> filtered = currentState.allVideos.where((d) {
        if (category == "Videos") return d['section'] == 'video';
        if (category == "Shorts") return d['section'] == 'short';
        return true;
      }).toList();
      emit(KidsVideoLoaded(allVideos: currentState.allVideos, filteredVideos: filtered, selectedCategory: category));
    }
  }
}

class KidsScreen extends StatefulWidget {
  const KidsScreen({super.key});
  @override
  State<KidsScreen> createState() => _KidsScreenState();
}

class _KidsScreenState extends State<KidsScreen> {
  final List<Map<String, dynamic>> _kidsData =[
    {"id": "animated_stories", "title": "Animated Stories", "color": const Color(0xFFFFE082), "icon": "📚", "lottie": "https://assets9.lottiefiles.com/packages/lf20_x9p1ooow.json"},
    {"id": "cartoons", "title": "Cartoons", "color": const Color(0xFF81D4FA), "icon": "📺", "lottie": "https://assets5.lottiefiles.com/packages/lf20_5tvo0cwz.json"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kids Zone", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors:[Color(0xFFFFFFFF), Color(0xFFF1F8E9)])),
        child: SafeArea(
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16).copyWith(bottom: 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85),
            itemCount: _kidsData.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => KidsYoutubeScreen(categoryId: _kidsData[index]["id"], categoryTitle: _kidsData[index]["title"])));
                },
                child: _buildGridTile(_kidsData[index]).animate().fade(delay: Duration(milliseconds: 100 * index)).scale(begin: const Offset(0.8, 0.8)),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGridTile(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: data["color"],
        borderRadius: BorderRadius.circular(30),
        boxShadow:[BoxShadow(color: (data["color"] as Color).withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children:[
          Positioned(right: -20, top: -20, child: CircleAvatar(radius: 50, backgroundColor: Colors.white.withOpacity(0.2))),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children:[
                Expanded(
                  child: Lottie.network(
                    data["lottie"],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Center(child: Text(data["icon"], style: const TextStyle(fontSize: 50))),
                  ),
                ),
                const SizedBox(height: 12),
                Text(data["title"], textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KidsYoutubeScreen extends StatelessWidget {
  final String categoryId;
  final String categoryTitle;

  const KidsYoutubeScreen({super.key, required this.categoryId, required this.categoryTitle});

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> categories =["All", "Videos", "Shorts"];

    return BlocProvider(
      create: (context) => KidsVideoCubit()..fetchVideos(categoryId),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(categoryTitle, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
          actions:[
            IconButton(icon: const Icon(Icons.subscriptions, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FilteredScreen(type: 'subs')))),
            IconButton(icon: const Icon(Icons.thumb_up, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FilteredScreen(type: 'liked')))),
            IconButton(icon: const Icon(Icons.bookmark, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FilteredScreen(type: 'saved')))),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children:[
            Container(
              height: 45,
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12, width: 1))),
              child: BlocBuilder<KidsVideoCubit, KidsVideoState>(
                builder: (context, state) {
                  String selected = (state is KidsVideoLoaded) ? state.selectedCategory : "All";
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      bool isSelected = selected == categories[index];
                      return GestureDetector(
                        onTap: () => context.read<KidsVideoCubit>().changeCategory(categories[index]),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: isSelected ? Colors.black : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Text(categories[index], style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: BlocBuilder<KidsVideoCubit, KidsVideoState>(
                builder: (context, state) {
                  if (state is KidsVideoLoading) return const Center(child: CircularProgressIndicator(color: Colors.red));
                  if (state is KidsVideoError) return Center(child: Text(state.message));

                  if (state is KidsVideoLoaded) {
                    var filteredDocs = state.filteredVideos;
                    if (filteredDocs.isEmpty) return const Center(child: Text("No videos available"));

                    if (state.selectedCategory == "Shorts") {
                      return GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.56, crossAxisSpacing: 8, mainAxisSpacing: 8),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) => buildShortCard(context, filteredDocs[index], filteredDocs, index),
                      );
                    }

                    List<Widget> feedWidgets =[];
                    List<Map<String, dynamic>> shortsPool =[];
                    List<Map<String, dynamic>> videoPool =[];

                    for (var doc in filteredDocs) {
                      if (doc['section'] == 'short') shortsPool.add(doc);
                      else videoPool.add(doc);
                    }

                    for (int i = 0; i < 2 && i < videoPool.length; i++) {
                      feedWidgets.add(_buildVideoTile(context, videoPool[i], videoPool));
                    }

                    if (shortsPool.isNotEmpty && state.selectedCategory == "All") {
                      feedWidgets.add(_buildShortsShelf(context, shortsPool));
                    }

                    for (int i = 2; i < videoPool.length; i++) {
                      feedWidgets.add(_buildVideoTile(context, videoPool[i], videoPool));
                    }

                    return ListView(padding: const EdgeInsets.only(bottom: 20), children: feedWidgets);
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoTile(BuildContext context, Map<String, dynamic> data, List<Map<String, dynamic>> fullVideoPool) {
    String viewsText = '${_formatNumber(data['view_count'] ?? 0)} views';
    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => FullVideoPlayer(
            videoData: data, 
            relatedVideosList: fullVideoPool,
          ))
        );
      },
      child: Column(
        children:[
          CachedNetworkImage(imageUrl: data['thumbnail'] ?? '', width: double.infinity, height: 220, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelProfile(channelName: data['channel_name'] ?? 'Creator', preloadedVideos: fullVideoPool))),
                  child: CircleAvatar(backgroundColor: Colors.grey.shade800, backgroundImage: NetworkImage(data['thumbnail'] ?? '')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelProfile(channelName: data['channel_name'] ?? 'Creator', preloadedVideos: fullVideoPool))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        Text(data['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, height: 1.2)),
                        const SizedBox(height: 4),
                        Text("${data['channel_name']} • $viewsText", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const Icon(Icons.more_vert, color: Colors.black, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortsShelf(BuildContext context, List<Map<String, dynamic>> shorts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children:[Icon(Icons.bolt, color: Colors.red, size: 28), SizedBox(width: 8), Text("Shorts", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: shorts.length,
            itemBuilder: (context, index) {
              return Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: SizedBox(width: 150, child: buildShortCard(context, shorts[index], shorts, index)));
            },
          ),
        ),
        const SizedBox(height: 24),
        const Divider(thickness: 4, color: Colors.black12),
      ],
    );
  }

  Widget buildShortCard(BuildContext context, Map<String, dynamic> data, List<Map<String, dynamic>> allShorts, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => ShortsPlayer(shortsList: allShorts, initialIndex: index))
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: data['thumbnail'] ?? '', fit: BoxFit.cover),
            Container(decoration: const BoxDecoration(gradient: LinearGradient(colors:[Colors.transparent, Colors.black87], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops:[0.5, 1]))),
            Positioned(
              bottom: 12, left: 8, right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  Text(data['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("${_formatNumber(data['view_count'] ?? 0)} views", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}