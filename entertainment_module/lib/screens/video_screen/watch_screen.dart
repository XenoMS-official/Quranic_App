import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'full_video_player.dart';
import 'shorts_player.dart';
import 'channel_profile.dart';
import 'filtered_screen.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  String selectedCategory = "All";
  final List<String> categories =["All", "Videos", "Shorts", "Live", "Podcasts", "Documentaries"];

  @override
  void initState() {
    super.initState();
    // Anchor the WatchScreen to Portrait Mode so it NEVER gets caught in rotation glitches
    // when popping back from a Full Screen video.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
        actions:[
          IconButton(
            icon: const Icon(Icons.subscriptions, color: Colors.black),
            onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const FilteredScreen(type: 'subs'))),
          ),
          IconButton(
            icon: const Icon(Icons.thumb_up, color: Colors.black),
            onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const FilteredScreen(type: 'liked'))),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark, color: Colors.black),
            onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const FilteredScreen(type: 'saved'))),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () => showSearch(context: context, delegate: VideoSearchDelegate()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children:[
          Container(
            height: 45,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12, width: 1))
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                bool isSelected = selectedCategory == categories[index];
                return GestureDetector(
                  onTap: () => setState(() => selectedCategory = categories[index]),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      categories[index], 
                      style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('video_hub').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.red));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No content found"));

                var allDocs = snapshot.data!.docs;
                var filteredDocs = allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final sec = data['section'] ?? '';
                  final theme = data['theme'] ?? '';
                  
                  if (selectedCategory == "Videos") return sec == 'video';
                  if (selectedCategory == "Shorts") return sec == 'short';
                  if (selectedCategory == "Live") return sec == 'live' || data['type'] == 'live_or_individual';
                  if (selectedCategory == "Podcasts") return sec == 'podcast';
                  if (selectedCategory == "Documentaries") return theme == 'Documentaries';
                  return true;
                }).toList();

                if (selectedCategory == "Shorts") {
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.56, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) => _buildShortCard(context, filteredDocs[index].data() as Map<String, dynamic>, filteredDocs, index),
                  );
                }

                List<Widget> feedWidgets =[];
                List<QueryDocumentSnapshot> shortsPool =[];
                List<QueryDocumentSnapshot> videoPool =[];

                for (var doc in filteredDocs) {
                  if ((doc.data() as Map)['section'] == 'short') shortsPool.add(doc);
                  else videoPool.add(doc);
                }

                for (int i = 0; i < 2 && i < videoPool.length; i++) {
                  feedWidgets.add(_buildVideoTile(context, videoPool[i].data() as Map<String, dynamic>));
                }

                if (shortsPool.isNotEmpty && selectedCategory == "All") {
                  feedWidgets.add(_buildShortsShelf(context, shortsPool));
                }

                for (int i = 2; i < videoPool.length; i++) {
                  feedWidgets.add(_buildVideoTile(context, videoPool[i].data() as Map<String, dynamic>));
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: feedWidgets,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTile(BuildContext context, Map<String, dynamic> data) {
    bool isLive = data['section'] == 'live' || data['type'] == 'live_or_individual';
    String viewsText = isLive ? '${_formatNumber(data['view_count'] ?? 1200)} watching' : '${_formatNumber(data['view_count'] ?? 0)} views';

    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => FullVideoPlayer(videoData: data))
        ).then((_) {
          // Re-anchor orientation when returning from video player
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        });
      },
      child: Column(
        children:[
          Stack(
            children:[
              // OPTIMIZED: memCacheWidth saves massive amounts of RAM and stops GC skipped frames
              CachedNetworkImage(
                imageUrl: data['thumbnail'], 
                width: double.infinity, 
                height: 220, 
                fit: BoxFit.cover,
                memCacheWidth: 600, // Caches image at lower res to save RAM
              ),
              if (isLive)
                Positioned(
                  bottom: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    color: Colors.red,
                    child: const Row(
                      children:[
                        Icon(Icons.sensors, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text("LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                GestureDetector(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => ChannelProfile(channelName: data['channel_name'] ?? 'Creator'))),
                  child: CircleAvatar(
                    backgroundColor: Colors.grey.shade800, 
                    backgroundImage: CachedNetworkImageProvider(data['thumbnail'], maxWidth: 100),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => ChannelProfile(channelName: data['channel_name'] ?? 'Creator'))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

  Widget _buildShortsShelf(BuildContext context, List<QueryDocumentSnapshot> shorts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children:[
              Icon(Icons.bolt, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text("Shorts", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: shorts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 150,
                  child: _buildShortCard(context, shorts[index].data() as Map<String, dynamic>, shorts, index),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Divider(thickness: 4, color: Colors.black12),
      ],
    );
  }

  Widget _buildShortCard(BuildContext context, Map<String, dynamic> data, List<QueryDocumentSnapshot> allShorts, int index) {
    return GestureDetector(
      onTap: () {
        final List<Map<String, dynamic>> mappedShorts = allShorts.map((e) => e.data() as Map<String, dynamic>).toList();
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => ShortsPlayer(shortsList: mappedShorts, initialIndex: index))
        ).then((_) {
           SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children:[
            // OPTIMIZED: memCacheWidth saves massive amounts of RAM
            CachedNetworkImage(
              imageUrl: data['thumbnail'], 
              fit: BoxFit.cover,
              memCacheWidth: 300, 
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Colors.transparent, Colors.black87], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.5, 1]),
              ),
            ),
            Positioned(
              bottom: 12, left: 8, right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

class VideoSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return[
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) return const Center(child: Text("Search for videos, shorts, or channels"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('video_hub').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.red));

        final results = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = (data['title'] ?? '').toString().toLowerCase();
          final channel = (data['channel_name'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return title.contains(searchLower) || channel.contains(searchLower);
        }).toList();

        if (results.isEmpty) return const Center(child: Text("No results found"));

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final data = results[index].data() as Map<String, dynamic>;
            final isShort = data['section'] == 'short';
            return ListTile(
              // OPTIMIZED
              leading: CachedNetworkImage(
                imageUrl: data['thumbnail'], 
                width: 100, 
                fit: BoxFit.cover,
                memCacheWidth: 200,
              ),
              title: Text(data['title'], maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(data['channel_name']),
              onTap: () {
                if (isShort) {
                  final List<Map<String, dynamic>> mappedResults = results.map((e) => e.data() as Map<String, dynamic>).toList();
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => ShortsPlayer(shortsList: mappedResults, initialIndex: index))
                  ).then((_) {
                     SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                  });
                } else {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => FullVideoPlayer(videoData: data))
                  ).then((_) {
                     SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                  });
                }
              },
            );
          },
        );
      },
    );
  }
}