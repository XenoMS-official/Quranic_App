// home_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hijri/hijri_calendar.dart';

class HomeData {
  final String verseArabic;
  final String verseEnglish;
  final String hadithArabic;
  final String hadithEnglish;
  final String quote;

  HomeData({
    required this.verseArabic,
    required this.verseEnglish,
    required this.hadithArabic,
    required this.hadithEnglish,
    required this.quote,
  });

  factory HomeData.fromMap(Map<String, dynamic> data) {
    return HomeData(
      verseArabic: data['verse_arabic'] ?? "إِنَّ مَعَ الْعُسْرِ يُسْرًا",
      verseEnglish: "${data['verse_translation'] ?? 'Indeed, with hardship[will be] ease.'} ${data['verse_reference'] ?? '(94:6)'}".trim(),
      hadithArabic: data['hadith_arabic'] ?? "الدُّعَاءُ هُوَ الْعِبَادَةُ",
      hadithEnglish: "${data['hadith_translation'] ?? 'Dua (supplication) is worship.'} ${data['hadith_reference'] ?? '(Abu Dawud)'}".trim(),
      quote: data['quote_text'] ?? '"I can live without money, but I cannot live without love."',
    );
  }
}

class AppRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<HomeData> fetchHomeData() async {
    final doc = await _firestore.collection('app_data').doc('homepage').get();
    return HomeData.fromMap(doc.data() as Map<String, dynamic>? ?? {});
  }

  Future<List<Map<String, dynamic>>> fetchModules() async {
    final snap = await _firestore.collection('islamic_modules').get();
    return snap.docs.map((e) => e.data()).toList();
  }

  Future<List<Map<String, dynamic>>> fetchDuas() async {
    final snap = await _firestore.collection('all_duas').get();
    return snap.docs.map((e) => e.data()).toList();
  }

  Stream<FileResponse> getCachedPdfStream(String url) {
    return DefaultCacheManager().getFileStream(url, withProgress: true);
  }
}

abstract class HomeEvent {}
class LoadHomeEvent extends HomeEvent {}

abstract class HomeState {}
class HomeLoading extends HomeState {}
class HomeLoaded extends HomeState {
  final HomeData homeData;
  final List<Map<String, dynamic>> modules;
  HomeLoaded(this.homeData, this.modules);
}
class HomeError extends HomeState {}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final AppRepository repository;

  HomeBloc({required this.repository}) : super(HomeLoading()) {
    on<LoadHomeEvent>((event, emit) async {
      emit(HomeLoading());
      try {
        final results = await Future.wait([
          repository.fetchHomeData(),
          repository.fetchModules(),
        ]);
        emit(HomeLoaded(results[0] as HomeData, results[1] as List<Map<String, dynamic>>));
      } catch (e) {
        emit(HomeError());
      }
    });
  }
}

abstract class DuaEvent {}
class LoadDuasEvent extends DuaEvent {}
class SearchDuasEvent extends DuaEvent { final String query; SearchDuasEvent(this.query); }

abstract class DuaState {}
class DuaLoading extends DuaState {}
class DuaLoaded extends DuaState {
  final List<Map<String, dynamic>> filteredDuas;
  DuaLoaded(this.filteredDuas);
}

class DuaBloc extends Bloc<DuaEvent, DuaState> {
  final AppRepository repository;
  List<Map<String, dynamic>> _allDuas =[]; 

  DuaBloc({required this.repository}) : super(DuaLoading()) {
    on<LoadDuasEvent>((event, emit) async {
      emit(DuaLoading());
      try {
        _allDuas = await repository.fetchDuas();
        emit(DuaLoaded(_allDuas));
      } catch (e) {
        emit(DuaLoaded(const[]));
      }
    });

    on<SearchDuasEvent>((event, emit) {
      if (event.query.isEmpty) {
        emit(DuaLoaded(_allDuas));
      } else {
        final query = event.query.toLowerCase();
        final filtered = _allDuas.where((dua) {
          final title = (dua['title'] ?? '').toLowerCase();
          final purpose = (dua['purpose'] ?? '').toLowerCase();
          return title.contains(query) || purpose.contains(query);
        }).toList();
        emit(DuaLoaded(filtered));
      }
    });
  }
}

abstract class PdfEvent {}
class LoadPdfEvent extends PdfEvent { final String url; LoadPdfEvent(this.url); }

abstract class PdfState {}
class PdfInitial extends PdfState {}
class PdfDownloading extends PdfState { final double progress; PdfDownloading(this.progress); }
class PdfLoaded extends PdfState { final File pdfFile; PdfLoaded(this.pdfFile); }
class PdfError extends PdfState { final String errorMessage; PdfError(this.errorMessage); }

class PdfBloc extends Bloc<PdfEvent, PdfState> {
  final AppRepository repository;
  
  PdfBloc({required this.repository}) : super(PdfInitial()) {
    on<LoadPdfEvent>((event, emit) async {
      emit(PdfDownloading(0.0));
      try {
        await emit.forEach<FileResponse>(
          repository.getCachedPdfStream(event.url),
          onData: (FileResponse response) {
            if (response is DownloadProgress) {
              double progress = 0.0;
              if (response.totalSize != null && response.totalSize! > 0) {
                progress = response.downloaded / response.totalSize!;
              }
              return PdfDownloading(progress);
            } else if (response is FileInfo) {
              return PdfLoaded(response.file);
            }
            return PdfDownloading(0.0);
          },
          onError: (error, stackTrace) => PdfError("Failed to load PDF. Check internet connection."),
        );
      } catch (e) {
        emit(PdfError("Failed to load PDF. Check internet connection."));
      }
    });
  }
}

abstract class AudioLibraryState {}
class AudioLibraryLoading extends AudioLibraryState {}
class AudioLibraryLoaded extends AudioLibraryState {
  final List<QueryDocumentSnapshot> docs;
  AudioLibraryLoaded(this.docs);
}
class AudioLibraryError extends AudioLibraryState {
  final String message;
  AudioLibraryError(this.message);
}

class AudioLibraryCubit extends Cubit<AudioLibraryState> {
  AudioLibraryCubit() : super(AudioLibraryLoading());

  Future<void> fetchItems(String parentId) async {
    emit(AudioLibraryLoading());
    try {
      var snap = await FirebaseFirestore.instance.collection('kids_zone').doc('nasheeds').collection('drive_items').where('parentId', isEqualTo: parentId).get();
      emit(AudioLibraryLoaded(snap.docs));
    } catch (e) {
      emit(AudioLibraryError("Failed to load audio files."));
    }
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc(repository: AppRepository())..add(LoadHomeEvent()),
      child: Scaffold(
        body: GradientBackground(
          child: CustomPaint(
            painter: IslamicPatternPainter(),
            child: SafeArea(
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoading) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF56B573)));
                  } else if (state is HomeError) {
                    return const Center(child: Text("Error loading data."));
                  } else if (state is HomeLoaded) {
                    return ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children:[
                        _buildWelcomeHeader().animate().fade().slideY(begin: 0.2, curve: Curves.easeOut),
                        const SizedBox(height: 24),
                        
                        Column(
                          children:[
                            _buildDailyCard("Verse of the Day", state.homeData.verseArabic, state.homeData.verseEnglish).animate().fade(delay: 100.ms),
                            const SizedBox(height: 16),
                            _buildDailyCard("Hadith of the Day", state.homeData.hadithArabic, state.homeData.hadithEnglish).animate().fade(delay: 150.ms),
                            const SizedBox(height: 16),
                            Column(
                              children:[
                                const Text("Quote of the Day", style: TextStyle(color: Color(0xFF56B573), fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(state.homeData.quote, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Color(0xFF56B573), fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ).animate().fade(delay: 180.ms),
                          ],
                        ),

                        const SizedBox(height: 24),
                        
                        _buildSectionTitle("Islamic Learning"),
                        const SizedBox(height: 16),
                        _buildIslamicModulesGrid(context, state.modules).animate().fade(delay: 200.ms),

                        const SizedBox(height: 24),

                        _buildSectionTitle("Daily Supplications"),
                        const SizedBox(height: 16),
                        _buildDuasLibraryBlock(context).animate().fade(delay: 250.ms), 
                        
                        const SizedBox(height: 24),

                        _buildSectionTitle("Audio Library"),
                        const SizedBox(height: 16),
                        _buildAudioLibraryBlock(context).animate().fade(delay: 300.ms),

                        const SizedBox(height: 100), 
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    String liveGregorianDate = DateFormat('EEEE, MMM d').format(DateTime.now());
    var today = HijriCalendar.now();
    String liveIslamicDate = "${today.hDay} ${today.longMonthName} ${today.hYear} AH";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAE6A), Color(0xFF56B573)], 
          begin: Alignment.topLeft, 
          end: Alignment.bottomRight
        ),
        boxShadow:[
          BoxShadow(
            color: const Color(0xFF56B573).withOpacity(0.3), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              // Greeting and Welcome Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:[
                    Text(
                      "Assalamu Alaikum,", 
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, letterSpacing: 0.3)
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Welcome Back!", 
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.2)
                    ),
                  ],
                ),
              ),
              // Live Clock moved to the top right
              const LiveClockWidget(),
            ],
          ),
          const SizedBox(height: 24), 
          
          // Modern Frosted-Glass Style Container for Dates
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children:[
                // Calendar Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(FontAwesomeIcons.calendarDay, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 16),
                // Dates
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      Text(
                        liveIslamicDate, 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        liveGregorianDate, 
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 14)
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDailyCard(String title, String arabic, String english) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE8F5E9), width: 2), boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children:[
          Text(title, style: const TextStyle(color: Color(0xFF56B573), fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Text(arabic, textAlign: TextAlign.center, style: GoogleFonts.amiri(fontSize: 26, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.5)),
          const SizedBox(height: 12),
          Text(english, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF56B573)));
  }

  Widget _buildIslamicModulesGrid(BuildContext context, List<Map<String, dynamic>> modules) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.8),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        var data = modules[index];
        var folderIcon = FontAwesomeIcons.book;
        if (data['title'] == 'Tareeka') folderIcon = FontAwesomeIcons.personPraying;
        if (data['title'] == 'Sunnah') folderIcon = FontAwesomeIcons.leaf;
        
        return HoverCard(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => FolderContentScreen(title: data['title'] ?? 'Folder', subfolders: data['subfolders'] ??[]),
            ));
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors:[Color(0xFF4CAE6A), Color(0xFF56B573)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                FaIcon(folderIcon, color: Colors.white, size: 28),
                const SizedBox(height: 12),
                Text(data['title'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDuasLibraryBlock(BuildContext context) {
    return HoverCard(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DuasLibraryScreen()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [Color(0xFF4CAE6A), Color(0xFF56B573)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow:[BoxShadow(color: const Color(0xFF56B573).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children:[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const FaIcon(FontAwesomeIcons.handsPraying, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  Text("Unified Duas Library", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Search & explore authenticated daily supplications", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioLibraryBlock(BuildContext context) {
    return HoverCard(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioLibraryScreen()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors:[Color(0xFF4CAE6A), Color(0xFF56B573)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow:[BoxShadow(color: const Color(0xFF56B573).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children:[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const FaIcon(FontAwesomeIcons.headphones, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  Text("Audio Library", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Naats, Durood, Nasheeds & Speeches", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class DuasLibraryScreen extends StatelessWidget {
  const DuasLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DuaBloc(repository: AppRepository())..add(LoadDuasEvent()),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text("Unified Duas Library", style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF56B573),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children:[
              Builder(builder: (context) {
                return Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8F5E9), width: 2)),
                  child: TextField(
                    onChanged: (value) => context.read<DuaBloc>().add(SearchDuasEvent(value)),
                    decoration: const InputDecoration(
                      hintText: "Search for a dua or purpose...",
                      prefixIcon: Icon(Icons.search, color: Color(0xFF56B573)),
                      border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Expanded(
                child: BlocBuilder<DuaBloc, DuaState>(
                  builder: (context, state) {
                    if (state is DuaLoading) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF56B573)));
                    } else if (state is DuaLoaded) {
                      if (state.filteredDuas.isEmpty) return const Center(child: Text("No duas found."));
                      
                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: state.filteredDuas.length,
                        itemBuilder: (context, index) {
                          var data = state.filteredDuas[index];
                          return Card(
                            elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE8F5E9), width: 2)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              leading: const FaIcon(FontAwesomeIcons.handsPraying, color: Color(0xFF56B573), size: 24),
                              title: Text(data['title'] ?? 'Dua', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(data['purpose'] ?? 'Supplication', style: const TextStyle(color: Color(0xFF56B573), fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF56B573)),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => DuaDetailScreen(duaData: data)));
                              },
                            ),
                          );
                        },
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DuaDetailScreen extends StatelessWidget {
  final Map<String, dynamic> duaData;

  const DuaDetailScreen({super.key, required this.duaData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(duaData['purpose'] ?? 'Dua Detail', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF56B573),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(24), 
            border: Border.all(color: const Color(0xFFE8F5E9), width: 2), 
            boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children:[
              Text(duaData['title'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF56B573), fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 24),
              
              if (duaData['arabic'] != null && duaData['arabic'].isNotEmpty) ...[
                Text(
                  duaData['arabic'], 
                  textAlign: TextAlign.center, 
                  style: GoogleFonts.amiri(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.8),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 24),
              ],
              
              if (duaData['translation'] != null && duaData['translation'].isNotEmpty) ...[
                const Divider(color: Color(0xFFE8F5E9), thickness: 2),
                const SizedBox(height: 16),
                Text(
                  duaData['translation'], 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 24),
              ],
              
              if (duaData['reference'] != null && duaData['reference'].isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    "Reference: ${duaData['reference']}", 
                    style: const TextStyle(color: Color(0xFF56B573), fontWeight: FontWeight.w600, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AudioLibraryScreen extends StatelessWidget {
  const AudioLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AudioLibraryCubit()..fetchItems('root'),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text("Audio Library", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors:[Color(0xFF4CAE6A), Color(0xFF56B573)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              BlocBuilder<AudioLibraryCubit, AudioLibraryState>(
                builder: (context, state) {
                  if (state is AudioLibraryLoading) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF56B573))));
                  if (state is AudioLibraryError) return Center(child: Text(state.message));

                  if (state is AudioLibraryLoaded) {
                    if (state.docs.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("Explore Naats, Durood & Speeches", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 20),
                          itemCount: state.docs.length,
                          itemBuilder: (context, index) {
                            var data = state.docs[index].data() as Map<String, dynamic>;
                            String folderName = data['name'] ?? 'Folder';
                            String folderId = data['id'] ?? '';

                            return Card(
                              elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE8F5E9), width: 2)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                leading: const FaIcon(FontAwesomeIcons.music, color: Color(0xFF56B573), size: 24),
                                title: Text(folderName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                subtitle: const Padding(
                                  padding: EdgeInsets.only(top: 4.0),
                                  child: Text('Tap to explore contents', style: TextStyle(color: Color(0xFF56B573), fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF56B573)),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AudioFolderScreen(parentId: folderId, folderName: folderName))),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AudioFolderScreen extends StatelessWidget {
  final String parentId;
  final String folderName;

  const AudioFolderScreen({super.key, required this.parentId, required this.folderName});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AudioLibraryCubit()..fetchItems(parentId),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F4),
        appBar: AppBar(
          title: Text(folderName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors:[Color(0xFF4CAE6A), Color(0xFF56B573)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        ),
        body: BlocBuilder<AudioLibraryCubit, AudioLibraryState>(
          builder: (context, state) {
            if (state is AudioLibraryLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF56B573)));
            if (state is AudioLibraryError) return Center(child: Text(state.message));

            if (state is AudioLibraryLoaded) {
              if (state.docs.isEmpty) return const Center(child: Text("Folder is empty", style: TextStyle(color: Colors.black54)));

              var docs = state.docs;
              List<Map<String, dynamic>> allAudios = docs.map((e) => e.data() as Map<String, dynamic>).where((data) => data['type'] == 'audio').toList();

              return ListView.builder(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  bool isFolder = data['type'] == 'folder';
                  String itemName = data['name'] ?? 'Unknown File';
                  String cleanName = itemName.replaceAll(RegExp(r'\.mp3|\.wav|\.m4a', caseSensitive: false), '');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6EE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: isFolder 
                          ? Icon(Icons.folder_outlined, color: Colors.blueGrey.shade600, size: 28)
                          : Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.music_note, color: Color(0xFF56B573), size: 24),
                            ),
                      title: Text(cleanName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.black87)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black45),
                      onTap: () {
                        if (isFolder) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => AudioFolderScreen(parentId: data['id'], folderName: itemName)));
                        } else {
                          int selectedIndex = allAudios.indexWhere((element) => element['id'] == data['id']);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => DriveAudioPlayerScreen(audioList: allAudios, initialIndex: selectedIndex != -1 ? selectedIndex : 0)));
                        }
                      },
                    ),
                  );
                },
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}

class DriveAudioPlayerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> audioList;
  final int initialIndex;

  const DriveAudioPlayerScreen({super.key, required this.audioList, required this.initialIndex});

  @override
  State<DriveAudioPlayerScreen> createState() => _DriveAudioPlayerScreenState();
}

class _DriveAudioPlayerScreenState extends State<DriveAudioPlayerScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late int _currentIndex;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 10));

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (_isPlaying) _spinController.repeat(); else _spinController.stop();
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((pos) { if (mounted) setState(() => _position = pos); });
    _audioPlayer.onDurationChanged.listen((dur) { if (mounted) setState(() => _duration = dur); });
    _audioPlayer.onPlayerComplete.listen((event) => _playNext());

    _playAudio(_currentIndex);
  }

  @override
  void dispose() {
    _audioPlayer.stop(); 
    _audioPlayer.release();
    _audioPlayer.dispose();
    _spinController.dispose();
    super.dispose();
  }

  void _playAudio(int index) async {
    if (index < 0 || index >= widget.audioList.length) return;
    if (mounted) setState(() { _currentIndex = index; });
    String fileId = widget.audioList[index]['id'];
    String url = "https://docs.google.com/uc?export=download&id=$fileId";
    await _audioPlayer.play(UrlSource(url));
    _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  void _playNext() { if (_currentIndex < widget.audioList.length - 1) _playAudio(_currentIndex + 1); }
  
  void _playPrev() { if (_currentIndex > 0) _playAudio(_currentIndex - 1); }
  
  void _toggleSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) _playbackSpeed = 1.25;
      else if (_playbackSpeed == 1.25) _playbackSpeed = 1.5;
      else if (_playbackSpeed == 1.5) _playbackSpeed = 2.0;
      else if (_playbackSpeed == 2.0) _playbackSpeed = 0.75;
      else _playbackSpeed = 1.0;
    });
    _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    String currentTitle = widget.audioList[_currentIndex]['name'] ?? 'Unknown Audio';
    currentTitle = currentTitle.replaceAll(RegExp(r'.mp3|.wav|.m4a', caseSensitive: false), '');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: AppBar(title: const Text("Now Playing", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black87), centerTitle: true),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            const Spacer(),
            AnimatedBuilder(
              animation: _spinController,
              builder: (_, child) { return Transform.rotate(angle: _spinController.value * 2 * math.pi, child: child); },
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black87, boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
                child: Center(child: Container(width: 90, height: 90, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF56B573), border: Border.all(color: Colors.black54, width: 4)), child: const Center(child: CircleAvatar(radius: 10, backgroundColor: Colors.black87)))),
              ),
            ),
            const Spacer(),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: Text(currentTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87))),
            const SizedBox(height: 8),
            const Text("Audio Library", style: TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children:[
                  Text(_formatTime(_position), style: const TextStyle(color: Colors.black54)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(activeTrackColor: const Color(0xFF56B573), inactiveTrackColor: const Color(0xFF56B573).withOpacity(0.3), thumbColor: const Color(0xFF56B573), overlayColor: const Color(0xFF56B573).withOpacity(0.2), trackHeight: 6.0),
                      child: Slider(min: 0.0, max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0, value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0), onChanged: (value) async { await _audioPlayer.seek(Duration(seconds: value.toInt())); }),
                    ),
                  ),
                  Text(_formatTime(_duration), style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:[
                  GestureDetector(onTap: _toggleSpeed, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)), child: Text("${_playbackSpeed}x", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAE6A))))),
                  IconButton(iconSize: 40, icon: const Icon(Icons.skip_previous), color: _currentIndex > 0 ? Colors.black87 : Colors.grey, onPressed: _playPrev),
                  GestureDetector(onTap: () { if (_isPlaying) { _audioPlayer.pause(); } else { _audioPlayer.resume(); } }, child: CircleAvatar(radius: 40, backgroundColor: const Color(0xFF56B573), child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 45))),
                  IconButton(iconSize: 40, icon: const Icon(Icons.skip_next), color: _currentIndex < widget.audioList.length - 1 ? Colors.black87 : Colors.grey, onPressed: _playNext),
                  const SizedBox(width: 50),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class FolderContentScreen extends StatelessWidget {
  final String title;
  final List<dynamic> subfolders;

  const FolderContentScreen({super.key, required this.title, required this.subfolders});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF56B573),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: subfolders.isEmpty
          ? const Center(child: Text("This folder is empty.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: subfolders.length,
              itemBuilder: (context, index) {
                var item = subfolders[index];
                
                var iconType = FontAwesomeIcons.folder;
                Color iconColor = Colors.blueGrey;

                if (item['type'] == 'pdf') {
                  iconType = FontAwesomeIcons.filePdf;
                  iconColor = Colors.red;
                } else if (item['type'] == 'audio') {
                  iconType = FontAwesomeIcons.music;
                  iconColor = Colors.green;
                }

                return Card(
                  elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                  child: ListTile(
                    leading: FaIcon(iconType, color: iconColor, size: 24),
                    title: Text(item['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    onTap: () {
                      if (item['type'] == 'pdf') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(pdfUrl: item['url'], title: item['name'])));
                      } else if (item['type'] == 'audio') {
                        List<dynamic> playlist = subfolders.where((e) => e['type'] == 'audio').toList();
                        int initialIndex = playlist.indexWhere((e) => e['url'] == item['url']);
                        if(initialIndex == -1) initialIndex = 0;

                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AudioPlayerScreen(
                            playlist: playlist, 
                            initialIndex: initialIndex
                          )
                        ));
                      } else if (item['type'] == 'folder') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FolderContentScreen(title: item['name'], subfolders: item['subfolders'] ??[])));
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

class LiveClockWidget extends StatefulWidget {
  const LiveClockWidget({super.key});
  @override 
  State<LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<LiveClockWidget> {
  late Timer _timer; 
  String _timeString = "";
  
  @override 
  void initState() {
    super.initState();
    _timeString = DateFormat('hh:mm a').format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) setState(() => _timeString = DateFormat('hh:mm a').format(DateTime.now()));
    });
  }
  
  @override 
  void dispose() { 
    _timer.cancel(); 
    super.dispose(); 
  }
  
  @override 
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), 
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12)
      ), 
      child: Text(
        _timeString, 
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.5)
      )
    );
  }
}

class HoverCard extends StatefulWidget {
  final Widget child; final VoidCallback onTap;
  const HoverCard({super.key, required this.child, required this.onTap});
  @override State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool isHovered = false;
  @override Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true), onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), transform: Matrix4.identity()..scale(isHovered ? 1.05 : 1.0),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: isHovered ?[BoxShadow(color: const Color(0xFF56B573).withOpacity(0.3), blurRadius: 15)] :[]),
          child: widget.child,
        ),
      ),
    );
  }
}

class IslamicPatternPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF56B573).withOpacity(0.03)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    double spacing = 80.0;
    for (double i = 0; i < size.width + spacing; i += spacing) {
      for (double j = 0; j < size.height + spacing; j += spacing) {
        canvas.drawRect(Rect.fromCenter(center: Offset(i, j), width: 40, height: 40), paint);
        canvas.save(); canvas.translate(i, j); canvas.rotate(0.785398); canvas.drawRect(Rect.fromCenter(center: const Offset(0, 0), width: 40, height: 40), paint); canvas.restore();
      }
    }
  }
  @override bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(decoration: const BoxDecoration(color: Color(0xFFF0F4F0)), child: child);
  }
}

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerScreen({super.key, required this.pdfUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PdfBloc(repository: AppRepository())..add(LoadPdfEvent(pdfUrl)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F0),
        appBar: AppBar(
          title: Text(title, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF56B573),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocBuilder<PdfBloc, PdfState>(
          builder: (context, state) {
            if (state is PdfDownloading || state is PdfInitial) {
              double progress = (state is PdfDownloading) ? state.progress : 0.0;
              int percentage = (progress * 100).toInt();

              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:[
                      const FaIcon(FontAwesomeIcons.filePdf, color: Color(0xFFFF5252), size: 90),
                      const SizedBox(height: 24),
                      const Text("Preparing Document...", style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress > 0 ? progress : null, 
                          backgroundColor: Colors.grey.shade300,
                          color: const Color(0xFF56B573),
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text("$percentage%", style: const TextStyle(fontSize: 20, color: Color(0xFF56B573), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            } else if (state is PdfLoaded) {
              return SfPdfViewer.file(state.pdfFile);
            } else if (state is PdfError) {
              return Center(
                child: Text(state.errorMessage, style: const TextStyle(color: Colors.red, fontSize: 16)),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class AudioPlayerScreen extends StatefulWidget {
  final List<dynamic> playlist;
  final int initialIndex;
  
  const AudioPlayerScreen({
    super.key, 
    required this.playlist, 
    required this.initialIndex
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _setAudio();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => isPlaying = state == PlayerState.playing);
    });
    
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => duration = newDuration);
    });
    
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => position = newPosition);
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      _playNext();
    });
  }

  Future<void> _setAudio() async {
    await _audioPlayer.stop(); 
    String audioUrl = widget.playlist[currentIndex]['url'];
    await _audioPlayer.setSourceUrl(audioUrl);
    await _audioPlayer.resume(); 
  }

  void _playNext() {
    if (currentIndex < widget.playlist.length - 1) {
      setState(() { currentIndex++; });
      _setAudio();
    }
  }

  void _playPrevious() {
    if (currentIndex > 0) {
      setState(() { currentIndex--; });
      _setAudio();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    String currentTitle = widget.playlist[currentIndex]['name'] ?? 'Unknown Audio';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Now Playing", 
          style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w600)
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:[
              Container(
                height: 300, width: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF181818),
                  boxShadow:[
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 15))
                  ],
                ),
                child: Center(
                  child: Container(
                    height: 90, width: 90,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF56B573)),
                    child: Center(
                      child: Container(height: 22, width: 22, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF181818)))
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              Column(
                children:[
                  Text(
                    currentTitle, 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Audio Library", 
                    style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w400)
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
              
              Row(
                children:[
                  Text(formatTime(position), style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6.0,
                        thumbColor: const Color(0xFF56B573),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                        overlayColor: const Color(0xFF56B573).withOpacity(0.2),
                        activeTrackColor: const Color(0xFF56B573),
                        inactiveTrackColor: const Color(0xFF56B573).withOpacity(0.2),
                      ),
                      child: Slider(
                        min: 0, 
                        max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0, 
                        value: position.inSeconds.toDouble().clamp(0.0, duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0),
                        onChanged: (value) async {
                          final pos = Duration(seconds: value.toInt());
                          await _audioPlayer.seek(pos);
                        },
                      ),
                    ),
                  ),
                  Text(formatTime(duration), style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
              
              const SizedBox(height: 10),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children:[
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 60, 
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200, 
                          borderRadius: BorderRadius.circular(20)
                        ),
                        child: const Text(
                          "1.0x", 
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAE6A), fontSize: 14)
                        ),
                      ),
                    ),
                  ),
                  
                  IconButton(
                    icon: FaIcon(
                      FontAwesomeIcons.backwardStep, 
                      size: 24, 
                      color: currentIndex > 0 ? Colors.black87 : Colors.black26
                    ), 
                    onPressed: _playPrevious,
                  ),
                  const SizedBox(width: 16),
                  
                  GestureDetector(
                    onTap: () async {
                      if (isPlaying) {
                        await _audioPlayer.pause();
                      } else {
                        await _audioPlayer.resume();
                      }
                    },
                    child: Container(
                      height: 75, width: 75, 
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle, 
                        color: Color(0xFF56B573),
                        boxShadow:[
                          BoxShadow(color: Color(0xFF56B573), blurRadius: 10, offset: Offset(0, 4), spreadRadius: -5)
                        ]
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                        color: Colors.white, 
                        size: 42
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  IconButton(
                    icon: FaIcon(
                      FontAwesomeIcons.forwardStep, 
                      size: 24, 
                      color: currentIndex < widget.playlist.length - 1 ? Colors.black87 : Colors.black26
                    ), 
                    onPressed: _playNext,
                  ),
                  
                  const Expanded(child: SizedBox()), 
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}