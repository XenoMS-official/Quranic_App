import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_data_cubit.dart';
import 'full_video_player.dart';
import 'shorts_player.dart';

class FilteredScreen extends StatelessWidget {
  final String type;
  const FilteredScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    String title = type == 'subs' ? 'Subscriptions' : type == 'liked' ? 'Liked Videos' : 'Saved Videos';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<UserDataCubit, UserDataState>(
        builder: (context, state) {
          List<String> targetList = type == 'subs' ? state.subscribedChannels : type == 'liked' ? state.likedVideos : state.savedVideos;

          if (targetList.isEmpty) {
            return const Center(child: Text("No items found."));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('video_hub').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.red));

              var docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (type == 'subs') {
                  return targetList.contains(data['channel_name']);
                } else {
                  return targetList.contains(data['video_id']);
                }
              }).toList();

              if (docs.isEmpty) return const Center(child: Text("No content available right now."));

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final isShort = data['section'] == 'short';

                  return ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    leading: CachedNetworkImage(imageUrl: data['thumbnail'], width: 120, fit: BoxFit.cover),
                    title: Text(data['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(data['channel_name']),
                    onTap: () {
                      if (isShort) {
                        final mappedDocs = docs.map((e) => e.data() as Map<String, dynamic>).toList();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ShortsPlayer(shortsList: mappedDocs, initialIndex: index)));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FullVideoPlayer(videoData: data)));
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}