import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'full_video_player.dart';

class ContentListScreen extends StatelessWidget {
  final String sectionType;
  final String title;

  const ContentListScreen({super.key, required this.sectionType, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('video_hub').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No content available yet."));
          }

          final docs = snapshot.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final type = (data['type'] ?? "").toString().toLowerCase();
            final section = (data['section'] ?? "").toString().toLowerCase();
            final theme = (data['theme'] ?? "").toString().toLowerCase();
            final t = (data['title'] ?? "").toString().toLowerCase();

            if (sectionType == "Live") {
               return type == 'live_or_individual' || section == 'live' || theme.contains('live');
            } else if (sectionType == "Shorts") {
               return section == 'short';
            } else if (sectionType == "Podcasts") {
               return section == 'podcast' || theme == 'podcasts' || t.contains('podcast');
            } else if (sectionType == "Videos") {
               final isShort = section == 'short';
               final isLive = type == 'live_or_individual' || theme.contains('live');
               final isPodcast = section == 'podcast' || theme == 'podcasts' || t.contains('podcast');
               return !isShort && !isLive && !isPodcast;
            }
            return false;
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text("No content found for this category.", style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          if (sectionType == 'Shorts') {
            return PageView.builder(
              scrollDirection: Axis.vertical, 
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return _buildShortFullscreenCard(context, data);
              },
            );
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return _buildCinematicCard(context, data);
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildShortFullscreenCard(BuildContext context, Map<String, dynamic> data) {
    final cardTitle = data['title'] ?? 'Short Video';
    final channel = data['channel_name'] ?? 'Creator';
    final imageUrl = data['thumbnail'] ?? 'https://images.unsplash.com/photo-1565552643983-c64639d67180?auto=format&fit=crop&q=80';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullVideoPlayer(videoData: data))),
      child: Stack(
        fit: StackFit.expand,
        children:[
          CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors:[Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.8)],
              ),
            ),
          ),
          const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 80)),
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                Text(cardTitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 10),
                Row(
                  children:[
                    CircleAvatar(radius: 16, backgroundColor: const Color(0xFF2E7D32), child: Text(channel[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14))),
                    const SizedBox(width: 8),
                    Text(channel, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCinematicCard(BuildContext context, Map<String, dynamic> data) {
    final cardTitle = data['title'] ?? 'Video';
    final channel = data['channel_name'] ?? data['theme'] ?? 'Content';
    final imageUrl = data['thumbnail'] ?? 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?auto=format&fit=crop&q=80';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullVideoPlayer(videoData: data))),
      child: Container(
        height: 220,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: DecorationImage(
            image: CachedNetworkImageProvider(imageUrl), 
            fit: BoxFit.cover, 
            colorFilter: const ColorFilter.mode(Colors.black38, BlendMode.darken)
          ),
          boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Stack(
          children:[
            Positioned(
              top: 16, left: 16, 
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(12)), 
                child: Text(channel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
              )
            ),
            const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 60)),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)), 
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors:[Colors.black.withOpacity(0.9), Colors.transparent])
                ),
                child: Text(cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}