import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserDataState {
  final List<String> likedVideos;
  final List<String> savedVideos;
  final List<String> subscribedChannels;

  UserDataState({
    required this.likedVideos,
    required this.savedVideos,
    required this.subscribedChannels,
  });
}

class UserDataCubit extends Cubit<UserDataState> {
  UserDataCubit() : super(UserDataState(likedVideos:[], savedVideos:[], subscribedChannels:[])) {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    emit(UserDataState(
      likedVideos: prefs.getStringList('liked_videos') ??[],
      savedVideos: prefs.getStringList('saved_videos') ??[],
      subscribedChannels: prefs.getStringList('subscribed_channels') ??[],
    ));
  }

  Future<void> toggleLike(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> current = List.from(state.likedVideos);
    current.contains(videoId) ? current.remove(videoId) : current.add(videoId);
    await prefs.setStringList('liked_videos', current);
    emit(UserDataState(likedVideos: current, savedVideos: state.savedVideos, subscribedChannels: state.subscribedChannels));
  }

  Future<void> toggleSave(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> current = List.from(state.savedVideos);
    current.contains(videoId) ? current.remove(videoId) : current.add(videoId);
    await prefs.setStringList('saved_videos', current);
    emit(UserDataState(likedVideos: state.likedVideos, savedVideos: current, subscribedChannels: state.subscribedChannels));
  }

  Future<void> toggleSubscription(String channelName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> current = List.from(state.subscribedChannels);
    current.contains(channelName) ? current.remove(channelName) : current.add(channelName);
    await prefs.setStringList('subscribed_channels', current);
    emit(UserDataState(likedVideos: state.likedVideos, savedVideos: state.savedVideos, subscribedChannels: current));
  }
}