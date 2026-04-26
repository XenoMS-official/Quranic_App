import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'user_data_cubit.dart';
import 'full_video_player.dart';
import 'shorts_player.dart';

class ChannelProfile extends StatefulWidget {
  final String channelName;
  final List<Map<String, dynamic>>? preloadedVideos; 

  const ChannelProfile({super.key, required this.channelName, this.preloadedVideos});

  @override
  State<ChannelProfile> createState() => _ChannelProfileState();
}

class _ChannelProfileState extends State<ChannelProfile> {
  String selectedCategory = "All";
  final List<String> categories =["All", "Videos", "Shorts"];

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
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.channelName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: widget.preloadedVideos != null 
          ? _buildProfileBody(widget.preloadedVideos!) 
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('video_hub').where('channel_name', isEqualTo: widget.channelName).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.red));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No videos found in this channel."));

                var docsData = snapshot.data!.docs.map((e) => e.data() as Map<String, dynamic>).toList();
                return _buildProfileBody(docsData);
              },
            ),
    );
  }

  Widget _buildProfileBody(List<Map<String, dynamic>> docsData) {
    var channelDocs = docsData.where((d) => d['channel_name'] == widget.channelName).toList();
    if (channelDocs.isEmpty) return const Center(child: Text("No videos found."));

    channelDocs.sort((a, b) {
      String s1 = a['published_at']?.toString() ?? '';
      String s2 = b['published_at']?.toString() ?? '';
      return s2.compareTo(s1); 
    });

    final allShorts = channelDocs.where((data) {
      final section = (data['section'] ?? '').toString().toLowerCase();
      final title = (data['title'] ?? '').toString().toLowerCase();
      return section == 'short' || title.contains('#short') || title.contains('shorts');
    }).toList();

    final allVideos = channelDocs.where((data) {
      final section = (data['section'] ?? '').toString().toLowerCase();
      final title = (data['title'] ?? '').toString().toLowerCase();
      return section != 'short' && !title.contains('#short') && !title.contains('shorts');
    }).toList();

    List<Map<String, dynamic>> displayVideos =[];
    List<Map<String, dynamic>> displayShorts =[];

    if (selectedCategory == "All") {
      displayVideos = allVideos;
      displayShorts = allShorts;
    } else if (selectedCategory == "Videos") {
      displayVideos = allVideos;
    } else if (selectedCategory == "Shorts") {
      displayShorts = allShorts;
    }

    return Column(
      children:[
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children:[
              CircleAvatar(radius: 40, backgroundColor: Colors.grey.shade300, backgroundImage: NetworkImage(channelDocs[0]['thumbnail'] ?? '')),
              const SizedBox(height: 12),
              Text(widget.channelName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text("@${widget.channelName.replaceAll(' ', '').toLowerCase()} • ${channelDocs.length} videos", style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              BlocBuilder<UserDataCubit, UserDataState>(
                builder: (context, state) {
                  bool isSubscribed = state.subscribedChannels.contains(widget.channelName);
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSubscribed ? Colors.grey.shade200 : Colors.black, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), 
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () => context.read<UserDataCubit>().toggleSubscription(widget.channelName),
                      child: Text(isSubscribed ? "Subscribed" : "Subscribe", style: TextStyle(color: isSubscribed ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Container(
          height: 50,
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12, width: 1))),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              bool isSelected = selectedCategory == categories[index];
              return GestureDetector(
                onTap: () => setState(() => selectedCategory = categories[index]),
                child: Container(
                  margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: isSelected ? Colors.black : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                  child: Text(categories[index], style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ListView(
            children:[
              if (displayVideos.isNotEmpty) ...[
                if (selectedCategory == "All")
                  const Padding(padding: EdgeInsets.all(16.0), child: Text("Videos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayVideos.length,
                  itemBuilder: (context, index) {
                    final data = displayVideos[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 140, height: 90, child: CachedNetworkImage(imageUrl: data['thumbnail'] ?? '', fit: BoxFit.cover)),
                      ),
                      title: Text(data['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text("${_formatNumber(data['view_count'] ?? 0)} views", style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      ),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullVideoPlayer(videoData: data, relatedVideosList: channelDocs))),
                    );
                  },
                ),
                const Divider(thickness: 4, color: Colors.black12),
              ],
              
              if (displayShorts.isNotEmpty) ...[
                if (selectedCategory == "All")
                  const Padding(padding: EdgeInsets.all(16.0), child: Row(children:[Icon(Icons.bolt, color: Colors.red), SizedBox(width: 8), Text("Shorts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))])),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8).copyWith(bottom: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.56, crossAxisSpacing: 4, mainAxisSpacing: 4),
                  itemCount: displayShorts.length,
                  itemBuilder: (context, index) {
                    final data = displayShorts[index];
                    return GestureDetector(
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => ShortsPlayer(shortsList: displayShorts, initialIndex: index)));
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children:[
                            CachedNetworkImage(imageUrl: data['thumbnail'] ?? '', fit: BoxFit.cover),
                            Container(decoration: const BoxDecoration(gradient: LinearGradient(colors:[Colors.transparent, Colors.black87], begin: Alignment.center, end: Alignment.bottomCenter))),
                            Positioned(bottom: 8, left: 8, right: 8, child: Text(data['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (displayVideos.isEmpty && displayShorts.isEmpty)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No content in this category.")))
            ],
          ),
        )
      ],
    );
  }
}