import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/news_model.dart';
import '../services/news_service.dart';
import 'live_sports_screen.dart'; 

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final NewsService _newsService = NewsService();
  String _selectedCategory = "All News";

  final List<Map<String, dynamic>> _categories =[
    {"name": "All News", "icon": FontAwesomeIcons.globe},
    {"name": "Global News", "icon": FontAwesomeIcons.earthAmericas},
    {"name": "Islamic World", "icon": FontAwesomeIcons.mosque},
    {"name": "Palestine Updates", "icon": FontAwesomeIcons.handFist},
    {"name": "Tech", "icon": FontAwesomeIcons.microchip},
    {"name": "Business", "icon": FontAwesomeIcons.briefcase},
    {"name": "Sports", "icon": FontAwesomeIcons.futbol},
    {"name": "Health", "icon": FontAwesomeIcons.heartPulse},
    {"name": "Science", "icon": FontAwesomeIcons.flask},
    {"name": "Education", "icon": FontAwesomeIcons.graduationCap},
    {"name": "Food", "icon": FontAwesomeIcons.utensils},
    {"name": "Travel", "icon": FontAwesomeIcons.planeDeparture},
  ];

  Future<void> _launchUrl(String urlString) async {
    if (urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No link available for this article.')),
      );
      return;
    }
    
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  void _openLiveSports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LiveSportsScreen()),
    );
  }

  void _showCategoryFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children:[
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Filter by Category",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Pull up to expand, scroll down to close",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: GridView.builder(
                      controller: controller,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat['name'];
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = cat['name']);
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFFF1F8E9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected
                                  ?[BoxShadow(color: const Color(0xFF4CAF50).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
                                  :[],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(
                                  cat['icon'] as dynamic,
                                  color: isSelected ? Colors.white : const Color(0xFF4CAF50),
                                  size: 28,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  cat['name'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children:[
            const Text("Daily News", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text(_selectedCategory, style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50))),
          ],
        ),
        actions:[
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.satelliteDish, color: Colors.redAccent, size: 20),
            onPressed: _openLiveSports,
            tooltip: "Live Sports",
          ).animate().scale(delay: 200.ms),
          
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.sliders, color: Color(0xFF4CAF50), size: 22),
            onPressed: _showCategoryFilterSheet,
          ).animate().scale(delay: 300.ms),
          const SizedBox(width: 8),
        ],
      ),
      body: GradientBackground(
        child: StreamBuilder<List<NewsArticle>>(
          stream: _newsService.getNews(_selectedCategory),
          builder: (context, snapshot) {
            
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:[
                      const FaIcon(FontAwesomeIcons.triangleExclamation, color: Colors.redAccent, size: 50),
                      const SizedBox(height: 16),
                      const Text("Loading Database...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        "Firebase is currently fetching or building an index. Please wait a moment.", 
                        textAlign: TextAlign.center, 
                        style: TextStyle(color: Colors.black54, fontSize: 12)
                      ),
                    ],
                  ),
                ),
              ).animate().fade();
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList();
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState().animate().fade().scale();
            }

            final articles = snapshot.data!;

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 100),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                return _buildNewsCard(articles[index])
                    .animate(key: ValueKey('${_selectedCategory}_$index'))
                    .fade(delay: Duration(milliseconds: 50 * index))
                    .slideY(begin: 0.1);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNewsCard(NewsArticle article) {
    return GestureDetector(
      onTap: () => _launchUrl(article.url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children:[
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
              child: Container(
                height: 110,
                width: 110,
                color: const Color(0xFFE8F5E9),
                child: article.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        article.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: FaIcon(FontAwesomeIcons.image, color: Color(0xFF81C784), size: 30)
                          );
                        },
                      )
                    : const Center(
                        child: FaIcon(FontAwesomeIcons.image, color: Color(0xFF81C784), size: 30)
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children:[
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              article.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (article.subcategory != null && article.subcategory!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFF81C784), width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                article.subcategory!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _timeAgo(article.publishedAt),
                      style: const TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1200.ms, color: const Color(0xFFE8F5E9));
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[
          Lottie.network(
            'https://assets9.lottiefiles.com/packages/lf20_a3kezd2y.json',
            height: 200,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.article_outlined, size: 100, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text("No news found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Check back later for updates.", style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 0) return '${difference.inDays} days ago';
    if (difference.inHours > 0) return '${difference.inHours} hours ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes} mins ago';
    return 'Just now';
  }
}