import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/news_screen.dart';
import 'screens/audio_screen.dart';
import 'screens/video_screen/watch_screen.dart';
import 'screens/kids_screen.dart';

class NavigationMenu extends StatefulWidget {
  const NavigationMenu({super.key});

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const AudioScreen(),
    const WatchScreen(),
    const NewsScreen(),
    const KidsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      body: _screens[_currentIndex],
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        color: const Color(0xFF4CAF50),
        buttonBackgroundColor: const Color(0xFF4CAF50),
        height: 65,
        animationDuration: const Duration(milliseconds: 400),
        index: _currentIndex,
        items: const [
          FaIcon(FontAwesomeIcons.house, color: Colors.white, size: 24),
          FaIcon(FontAwesomeIcons.headphones, color: Colors.white, size: 24),
          FaIcon(FontAwesomeIcons.circlePlay, color: Colors.white, size: 24),
          FaIcon(FontAwesomeIcons.newspaper, color: Colors.white, size: 24),
          FaIcon(FontAwesomeIcons.childReaching, color: Colors.white, size: 24),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}