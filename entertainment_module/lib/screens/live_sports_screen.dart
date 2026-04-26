import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'video_screen/channel_profile.dart';

class SportsRepository {
  Future<List<dynamic>> fetchLiveMatches(String sport) async {
    String url = '';
    if (sport == "Football") {
      url = 'https://site.api.espn.com/apis/site/v2/sports/soccer/all/scoreboard';
    } else if (sport == "Basketball") {
      url = 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard';
    } else if (sport == "Cricket") {
      url = 'https://site.api.espn.com/apis/site/v2/sports/cricket/13533/scoreboard';
    } else {
      return _getMockDataForSport(sport);
    }

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> matches = [];

        if (data['events'] != null) {
          for (var event in data['events']) {
            var comp = event['competitions'][0];
            var home = comp['competitors'].firstWhere((c) => c['homeAway'] == 'home', orElse: () => comp['competitors'][0]);
            var away = comp['competitors'].firstWhere((c) => c['homeAway'] == 'away', orElse: () => comp['competitors'][1]);
            
            matches.add({
              "fixture": {"status": {"elapsed": event['status']['type']['shortDetail']}},
              "league": {"name": event['season']?['slug'] ?? sport, "logo": "https://cdn-icons-png.flaticon.com/512/5328/5328083.png"},
              "teams": {
                "home": {
                  "name": home['team']['name'], 
                  "logo": home['team']['logo'] ?? "https://cdn-icons-png.flaticon.com/512/1165/1165187.png"
                },
                "away": {
                  "name": away['team']['name'], 
                  "logo": away['team']['logo'] ?? "https://cdn-icons-png.flaticon.com/512/1165/1165187.png"
                }
              },
              "goals": {
                "home": home['score'] ?? "0", 
                "away": away['score'] ?? "0"
              }
            });
          }
          if (matches.isNotEmpty) return matches;
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return _getMockDataForSport(sport);
  }

  List<dynamic> _getMockDataForSport(String sport) {
    if (sport == "Football") {
      return[
        {
          "fixture": {"status": {"elapsed": "45'"}},
          "league": {"name": "Premier League", "logo": "https://cdn-icons-png.flaticon.com/512/5328/5328083.png"},
          "teams": {
            "home": {"name": "Arsenal", "logo": "https://cdn-icons-png.flaticon.com/512/1165/1165187.png"},
            "away": {"name": "Chelsea", "logo": "https://cdn-icons-png.flaticon.com/512/1165/1165187.png"}
          },
          "goals": {"home": "1", "away": "1"}
        }
      ];
    } else if (sport == "Cricket") {
      return[
        {
          "fixture": {"status": {"elapsed": "Over 15.2"}},
          "league": {"name": "T20 World Cup", "logo": "https://cdn-icons-png.flaticon.com/512/5328/5328083.png"},
          "teams": {
            "home": {"name": "Pakistan", "logo": "https://cdn-icons-png.flaticon.com/512/1165/1165187.png"},
            "away": {"name": "India", "logo": "https://cdn-icons-png.flaticon.com/512/1165/1165187.png"}
          },
          "goals": {"home": "154/3", "away": "152/8"}
        }
      ];
    } else if (sport == "Basketball") {
      return[
        {
          "fixture": {"status": {"elapsed": "Q3"}},
          "league": {"name": "NBA", "logo": "https://cdn-icons-png.flaticon.com/512/5328/5328083.png"},
          "teams": {
            "home": {"name": "Lakers", "logo": "https://cdn-icons-png.flaticon.com/512/1165/1165187.png"},
            "away": {"name": "Warriors", "logo": "https://cdn-icons-png.flaticon.com/512/1165/1165187.png"}
          },
          "goals": {"home": "85", "away": "92"}
        }
      ];
    }
    return[];
  }
}

abstract class LiveSportsEvent {}

class FetchSports extends LiveSportsEvent {
  final String sport;
  FetchSports(this.sport);
}

abstract class LiveSportsState {
  final String selectedSport;
  LiveSportsState(this.selectedSport);
}

class SportsLoading extends LiveSportsState {
  SportsLoading(super.selectedSport);
}

class SportsLoaded extends LiveSportsState {
  final List<dynamic> matches;
  SportsLoaded(super.selectedSport, this.matches);
}

class LiveSportsBloc extends Bloc<LiveSportsEvent, LiveSportsState> {
  final SportsRepository repository;

  LiveSportsBloc({required this.repository}) : super(SportsLoading("Football")) {
    on<FetchSports>((event, emit) async {
      emit(SportsLoading(event.sport));
      final matches = await repository.fetchLiveMatches(event.sport);
      emit(SportsLoaded(event.sport, matches));
    });
  }
}

class LiveSportsScreen extends StatelessWidget {
  const LiveSportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LiveSportsBloc(repository: SportsRepository())..add(FetchSports("Football")),
      child: const LiveSportsView(),
    );
  }
}

class LiveSportsView extends StatefulWidget {
  const LiveSportsView({super.key});

  @override
  State<LiveSportsView> createState() => _LiveSportsViewState();
}

class _LiveSportsViewState extends State<LiveSportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _sportsList =[
    {"name": "Football", "icon": FontAwesomeIcons.futbol},
    {"name": "Cricket", "icon": FontAwesomeIcons.baseballBatBall},
    {"name": "Basketball", "icon": FontAwesomeIcons.basketball},
    {"name": "Tennis", "icon": FontAwesomeIcons.tableTennisPaddleBall},
  ];

  // 🌟 FIXED: Replaced dead URLs with permanent working Unsplash image links
  final List<Map<String, dynamic>> _videoCategories =[
    {
      "name": "Fighting & Combat",
      "icon": FontAwesomeIcons.handFist,
      "image": "https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=500&q=80",
      "channels":["UFC - Ultimate Fighting Championship", "ONE Championship"]
    },
    {
      "name": "Team & Individual",
      "icon": FontAwesomeIcons.peopleGroup,
      "image": "https://images.unsplash.com/photo-1526232761682-d26e03ac148e?w=500&q=80",
      "channels":["Dude Perfect", "Red Bull", "Sky Sports", "UR · Cristiano"]
    },
    {
      "name": "Swimming",
      "icon": FontAwesomeIcons.personSwimming,
      "image": "https://images.unsplash.com/photo-1530549387789-4c1017266635?w=500&q=80",
      "channels":["Olympics", "Global Swimming Network"]
    },
    {
      "name": "Cricket",
      "icon": FontAwesomeIcons.baseballBatBall,
      "image": "https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=500&q=80",
      "channels":["Sony Sports", "Ten Sports"]
    }
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children:[
            const FaIcon(FontAwesomeIcons.satelliteDish, color: Colors.redAccent, size: 20)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
            const SizedBox(width: 10),
            const Text("Live Sports", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const[
            Tab(text: "Live Scores", icon: FaIcon(FontAwesomeIcons.futbol, size: 18)),
            Tab(text: "Highlights & TV", icon: FaIcon(FontAwesomeIcons.tv, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children:[
          Column(
            children:[
              _buildSportSelector(),
              Expanded(
                child: BlocBuilder<LiveSportsBloc, LiveSportsState>(
                  builder: (context, state) {
                    if (state is SportsLoading) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
                    } else if (state is SportsLoaded) {
                      if (state.matches.isEmpty) {
                        return _buildNoMatchYet(state.selectedSport);
                      }
                      return RefreshIndicator(
                        onRefresh: () async {
                          context.read<LiveSportsBloc>().add(FetchSports(state.selectedSport));
                        },
                        color: const Color(0xFF4CAF50),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 20),
                          itemCount: state.matches.length,
                          itemBuilder: (context, index) {
                            return MatchCard(
                              match: state.matches[index],
                              selectedSport: state.selectedSport,
                            )
                                .animate(key: ValueKey('${state.selectedSport}_$index'))
                                .fade(delay: Duration(milliseconds: 100 * index))
                                .slideY(begin: 0.2);
                          },
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
          _buildHighlightsTab(),
        ],
      ),
    );
  }

  Widget _buildSportSelector() {
    return BlocBuilder<LiveSportsBloc, LiveSportsState>(
      builder: (context, state) {
        return Container(
          height: 60,
          margin: const EdgeInsets.only(top: 10, bottom: 5),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sportsList.length,
            itemBuilder: (context, index) {
              final sport = _sportsList[index];
              final isSelected = state.selectedSport == sport['name'];

              return GestureDetector(
                onTap: () {
                  if (!isSelected) {
                    context.read<LiveSportsBloc>().add(FetchSports(sport['name']));
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4CAF50) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isSelected
                        ?[BoxShadow(color: const Color(0xFF4CAF50).withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))]
                        :[BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children:[
                      FaIcon(
                        sport['icon'],
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sport['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNoMatchYet(String sportName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[
          FaIcon(FontAwesomeIcons.calendarXmark, size: 60, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            "No Live $sportName Matches",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            "Check back later for live action.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ).animate().fade().scale(),
    );
  }

  Widget _buildHighlightsTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _videoCategories.length,
      itemBuilder: (context, index) {
        final category = _videoCategories[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryChannelsScreen(
                  categoryName: category['name'],
                  channels: category['channels'],
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade300, // Background color while loading
              borderRadius: BorderRadius.circular(24),
              image: DecorationImage(
                image: CachedNetworkImageProvider(category['image']),
                fit: BoxFit.cover,
                colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.darken),
              ),
              boxShadow:[
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))
              ],
            ),
            child: Stack(
              children:[
                const Positioned(
                  top: 16,
                  right: 16,
                  child: FaIcon(FontAwesomeIcons.play, color: Colors.white70, size: 20),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      FaIcon(category['icon'], color: const Color(0xFF4CAF50), size: 24),
                      const SizedBox(height: 8),
                      Text(
                        category['name'],
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fade(delay: Duration(milliseconds: 100 * index)).slideY(begin: 0.2),
        );
      },
    );
  }
}

class CategoryChannelsScreen extends StatelessWidget {
  final String categoryName;
  final List<String> channels;

  const CategoryChannelsScreen({super.key, required this.categoryName, required this.channels});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(categoryName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channelName = channels[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChannelProfile(channelName: channelName)),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow:[
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children:[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF4CAF50).withOpacity(0.2),
                    child: Text(
                      channelName[0].toUpperCase(),
                      style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      channelName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const FaIcon(FontAwesomeIcons.chevronRight, color: Colors.grey, size: 16),
                ],
              ),
            ).animate().fade(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.1),
          );
        },
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final dynamic match;
  final String selectedSport;

  const MatchCard({super.key, required this.match, required this.selectedSport});

  Future<void> _watchMatch(BuildContext context) async {
    String sportPath = selectedSport == "Football" ? "" : selectedSport.toLowerCase();
    final Uri url = Uri.parse('https://www.flashscore.com/$sportPath');

    if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open live stream link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeTeam = match['teams']['home'];
    final awayTeam = match['teams']['away'];
    final goals = match['goals'];
    final status = match['fixture']['status'];
    final league = match['league'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow:[
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children:[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              Row(
                children: [
                  Image.network(league['logo'], height: 20, width: 20, errorBuilder: (_, __, ___) => const FaIcon(FontAwesomeIcons.trophy, size: 16, color: Colors.amber)),
                  const SizedBox(width: 8),
                  Text(league['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  "${status['elapsed']}",
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.5, end: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              Expanded(
                child: Column(
                  children: [
                    Image.network(homeTeam['logo'], height: 50, width: 50, errorBuilder: (_, __, ___) => const FaIcon(FontAwesomeIcons.shieldHalved, size: 40)),
                    const SizedBox(height: 8),
                    Text(homeTeam['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              Column(
                children:[
                  Text(
                    "${goals['home']} - ${goals['away']}",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF2E3192)),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  children:[
                    Image.network(awayTeam['logo'], height: 50, width: 50, errorBuilder: (_, __, ___) => const FaIcon(FontAwesomeIcons.shieldHalved, size: 40)),
                    const SizedBox(height: 8),
                    Text(awayTeam['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _watchMatch(context),
              icon: const FaIcon(FontAwesomeIcons.play, size: 14, color: Colors.white),
              label: const Text("Watch Broadcaster Info", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
            ),
          )
        ],
      ),
    );
  }
}