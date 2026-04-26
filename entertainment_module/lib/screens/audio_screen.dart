import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart' as ja; 
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:math' as math; 

enum ReadingMode { simple, translation, audioTranslation, wordByWord, tafseer }
enum ScriptType { indoPak, uthmani }

class SurahBasic {
  final int number;
  final String englishName;
  final String arabicName;
  final int ayahCount;
  final bool isMadni;
  SurahBasic(this.number, this.englishName, this.arabicName, this.ayahCount, this.isMadni);
}

final List<SurahBasic> allSurahsList =[
  SurahBasic(1, "Al-Faatiha", "الفاتحة", 7, false), SurahBasic(2, "Al-Baqara", "البقرة", 286, true), SurahBasic(3, "Aal-i-Imraan", "آل عمران", 200, true), SurahBasic(4, "An-Nisaa", "النساء", 176, true), SurahBasic(5, "Al-Maaida", "المائدة", 120, true), SurahBasic(6, "Al-An'aam", "الأنعام", 165, false), SurahBasic(7, "Al-A'raaf", "الأعراف", 206, false), SurahBasic(8, "Al-Anfaal", "الأنفال", 75, true), SurahBasic(9, "At-Tawba", "التوبة", 129, true), SurahBasic(10, "Yunus", "يونس", 109, false),
  SurahBasic(11, "Hud", "هود", 123, false), SurahBasic(12, "Yusuf", "يوسف", 111, false), SurahBasic(13, "Ar-Ra'd", "الرعد", 43, true), SurahBasic(14, "Ibrahim", "إبراهيم", 52, false), SurahBasic(15, "Al-Hijr", "الحجر", 99, false), SurahBasic(16, "An-Nahl", "النحل", 128, false), SurahBasic(17, "Al-Israa", "الإسراء", 111, false), SurahBasic(18, "Al-Kahf", "الكهف", 110, false), SurahBasic(19, "Maryam", "مريم", 98, false), SurahBasic(20, "Taa-Haa", "طه", 135, false),
  SurahBasic(21, "Al-Anbiyaa", "الأنبياء", 112, false), SurahBasic(22, "Al-Hajj", "الحج", 78, true), SurahBasic(23, "Al-Muminoon", "المؤمنون", 118, false), SurahBasic(24, "An-Noor", "النور", 64, true), SurahBasic(25, "Al-Furqaan", "الفرقان", 77, false), SurahBasic(26, "Ash-Shu'araa", "الشعراء", 227, false), SurahBasic(27, "An-Naml", "النمل", 93, false), SurahBasic(28, "Al-Qasas", "القصص", 88, false), SurahBasic(29, "Al-Ankaboot", "العنكبوت", 69, false), SurahBasic(30, "Ar-Room", "الروم", 60, false),
  SurahBasic(31, "Luqman", "لقمان", 34, false), SurahBasic(32, "As-Sajda", "السجدة", 30, false), SurahBasic(33, "Al-Ahzaab", "الأحزاب", 73, true), SurahBasic(34, "Saba", "سبأ", 54, false), SurahBasic(35, "Faatir", "فاطر", 45, false), SurahBasic(36, "Yaseen", "يس", 83, false), SurahBasic(37, "As-Saaffaat", "الصافات", 182, false), SurahBasic(38, "Saad", "ص", 88, false), SurahBasic(39, "Az-Zumar", "الزمر", 75, false), SurahBasic(40, "Ghafir", "غافر", 85, false),
  SurahBasic(41, "Fussilat", "فصلت", 54, false), SurahBasic(42, "Ash-Shura", "الشورى", 53, false), SurahBasic(43, "Az-Zukhruf", "الزخرف", 89, false), SurahBasic(44, "Ad-Dukhaan", "الدخان", 59, false), SurahBasic(45, "Al-Jaathiya", "الجاثية", 37, false), SurahBasic(46, "Al-Ahqaf", "الأحقاف", 35, false), SurahBasic(47, "Muhammad", "محمد", 38, true), SurahBasic(48, "Al-Fath", "الفتح", 29, true), SurahBasic(49, "Al-Hujuraat", "الحجرات", 18, true), SurahBasic(50, "Qaaf", "ق", 45, false),
  SurahBasic(51, "Adh-Dhaariyat", "الذاريات", 60, false), SurahBasic(52, "At-Tur", "الطور", 49, false), SurahBasic(53, "An-Najm", "النجم", 62, false), SurahBasic(54, "Al-Qamar", "القمر", 55, false), SurahBasic(55, "Ar-Rahmaan", "الرحمن", 78, true), SurahBasic(56, "Al-Waaqia", "الواقعة", 96, false), SurahBasic(57, "Al-Hadid", "الحديد", 29, true), SurahBasic(58, "Al-Mujaadila", "المجادلة", 22, true), SurahBasic(59, "Al-Hashr", "الحشر", 24, true), SurahBasic(60, "Al-Mumtahana", "الممتحنة", 13, true),
  SurahBasic(61, "As-Saff", "الصف", 14, true), SurahBasic(62, "Al-Jumu'a", "الجمعة", 11, true), SurahBasic(63, "Al-Munaafiqoon", "المنافقون", 11, true), SurahBasic(64, "At-Taghaabun", "التغابن", 18, true), SurahBasic(65, "At-Talaaq", "الطلاق", 12, true), SurahBasic(66, "At-Tahrim", "التحريم", 12, true), SurahBasic(67, "Al-Mulk", "الملك", 30, false), SurahBasic(68, "Al-Qalam", "القلم", 52, false), SurahBasic(69, "Al-Haaqqa", "الحاقة", 52, false), SurahBasic(70, "Al-Ma'aarij", "المعارج", 44, false),
  SurahBasic(71, "Nooh", "نوح", 28, false), SurahBasic(72, "Al-Jinn", "الجن", 28, false), SurahBasic(73, "Al-Muzzammil", "المزمل", 20, false), SurahBasic(74, "Al-Muddaththir", "المدثر", 56, false), SurahBasic(75, "Al-Qiyaama", "القيامة", 40, false), SurahBasic(76, "Al-Insaan", "الإنسان", 31, true), SurahBasic(77, "Al-Mursalaat", "المرسلات", 50, false), SurahBasic(78, "An-Naba", "النبأ", 40, false), SurahBasic(79, "An-Naazi'aat", "النازعات", 46, false), SurahBasic(80, "Abasa", "عبس", 42, false),
  SurahBasic(81, "At-Takwir", "التكوير", 29, false), SurahBasic(82, "Al-Infitaar", "الانفطار", 19, false), SurahBasic(83, "Al-Mutaffifeen", "المطففين", 36, false), SurahBasic(84, "Al-Inshiqaaq", "الانشقاق", 25, false), SurahBasic(85, "Al-Burooj", "البروج", 22, false), SurahBasic(86, "At-Taariq", "الطارق", 17, false), SurahBasic(87, "Al-A'laa", "الأعلى", 19, false), SurahBasic(88, "Al-Ghaashiya", "الغاشية", 26, false), SurahBasic(89, "Al-Fajr", "الفجر", 30, false), SurahBasic(90, "Al-Balad", "البلد", 20, false),
  SurahBasic(91, "Ash-Shams", "الشمس", 15, false), SurahBasic(92, "Al-Lail", "الليل", 21, false), SurahBasic(93, "Ad-Dhuhaa", "الضحى", 11, false), SurahBasic(94, "Ash-Sharh", "الشرح", 8, false), SurahBasic(95, "At-Tin", "التين", 8, false), SurahBasic(96, "Al-Alaq", "العلق", 19, false), SurahBasic(97, "Al-Qadr", "القدر", 5, false), SurahBasic(98, "Al-Bayyina", "البينة", 8, true), SurahBasic(99, "Az-Zalzala", "الزلزلة", 8, true), SurahBasic(100, "Al-Aadiyaat", "العاديات", 11, false),
  SurahBasic(101, "Al-Qaari'a", "القارعة", 11, false), SurahBasic(102, "At-Takaathur", "التكاثر", 8, false), SurahBasic(103, "Al-Asr", "العصر", 3, false), SurahBasic(104, "Al-Humaza", "الهمزة", 9, false), SurahBasic(105, "Al-Fil", "الفيل", 5, false), SurahBasic(106, "Quraish", "قريش", 4, false), SurahBasic(107, "Al-Maa'un", "الماعون", 7, false), SurahBasic(108, "Al-Kawthar", "الكوثر", 3, false), SurahBasic(109, "Al-Kaafiroon", "الكافرون", 6, false), SurahBasic(110, "An-Nasr", "النصر", 3, true),
  SurahBasic(111, "Al-Masad", "المسد", 5, false), SurahBasic(112, "Al-Ikhlaas", "الإخلاص", 4, false), SurahBasic(113, "Al-Falaq", "الفلق", 5, false), SurahBasic(114, "An-Naas", "الناس", 6, false)
];

class WordData {
  final String arabic;
  final String english;
  final String tajweed;
  WordData({required this.arabic, required this.english, required this.tajweed});
  factory WordData.fromMap(Map<String, dynamic> map) => WordData(arabic: map['arabic'] ?? '', english: map['english'] ?? '', tajweed: map['tajweed'] ?? '');
}

class Ayah {
  final int numberInSurah;
  final int globalNumber;
  String textUthmani;
  String textIndoPak;
  final String textEnglish;
  final String textUrdu;
  final List<WordData> words;

  Ayah({required this.numberInSurah, required this.globalNumber, required this.textUthmani, required this.textIndoPak, required this.textEnglish, required this.textUrdu, required this.words});

  factory Ayah.fromMap(Map<String, dynamic> data) {
    int gId = 0;
    if (data['audio_url'] != null) {
      final parts = data['audio_url'].toString().split('/');
      gId = int.tryParse(parts.last.replaceAll('.mp3', '')) ?? 0;
    }
    List<WordData> wList =[];
    if (data['words'] != null) wList = (data['words'] as List).map((e) => WordData.fromMap(e)).toList();
    return Ayah(
      numberInSurah: data['number'] ?? 0, globalNumber: gId, 
      textUthmani: data['text_uthmani'] ?? data['text_arabic'] ?? '',
      textIndoPak: data['text_indopak'] ?? data['text_arabic'] ?? '',
      textEnglish: data['text_english'] ?? '', textUrdu: data['text_urdu'] ?? '', words: wList,
    );
  }
}

class Reciter {
  final String identifier;
  final String name;
  final String localImage; 
  Reciter({required this.identifier, required this.name, required this.localImage});
  factory Reciter.fromMap(Map<String, dynamic> data, String id) {
    return Reciter(identifier: id, name: data['english_name'] ?? data['name'] ?? id, localImage: data['local_image'] ?? '');
  }
}

class DriveResource {
  final String title;
  final String type;
  final String driveUrl;
  final String folderPath;
  DriveResource({required this.title, required this.type, required this.driveUrl, required this.folderPath});
  factory DriveResource.fromMap(Map<String, dynamic> data) {
    return DriveResource(title: data['title'] ?? 'Resource', type: data['type'] ?? 'audio', driveUrl: data['drive_url'] ?? '', folderPath: data['folder_path'] ?? '');
  }
}

class BookmarkModel {
  final int surahNumber;
  final String surahName;
  final int ayahIndex;
  final int ayahNumber;
  BookmarkModel({required this.surahNumber, required this.surahName, required this.ayahIndex, required this.ayahNumber});
  Map<String, dynamic> toMap() => {'surahNumber': surahNumber, 'surahName': surahName, 'ayahIndex': ayahIndex, 'ayahNumber': ayahNumber};
  factory BookmarkModel.fromMap(Map<String, dynamic> map) => BookmarkModel(surahNumber: map['surahNumber'], surahName: map['surahName'], ayahIndex: map['ayahIndex'], ayahNumber: map['ayahNumber']);
}

class WordLesson {
  final String text;
  final String translation;
  final String transliteration;
  final String audioUrl;
  WordLesson({required this.text, required this.translation, required this.transliteration, required this.audioUrl});
}

class QuranLesson {
  final String surah;
  final int ayah;
  final String arabic;
  final String translation;
  final String urduTranslation;
  final String tafseer;
  final String tajweedTip;
  final String transliteration;
  final String audioUrl;
  final List<WordLesson> words;
  const QuranLesson({required this.surah, required this.ayah, required this.arabic, required this.translation, required this.urduTranslation, required this.tafseer, required this.tajweedTip, required this.transliteration, required this.audioUrl, required this.words});
  factory QuranLesson.empty() => const QuranLesson(surah: 'Al-Fatihah', ayah: 1, arabic: 'Loading...', translation: '', urduTranslation: '', tafseer: '', tajweedTip: '', transliteration: '', audioUrl: '', words:[]);
}

class TutorStats {
  final int attempts;
  final int correctAttempts;
  final int lastScore;
  const TutorStats({required this.attempts, required this.correctAttempts, required this.lastScore});
  Map<String, dynamic> toMap() => {'attempts': attempts, 'correctAttempts': correctAttempts, 'lastScore': lastScore};
  factory TutorStats.fromMap(Map<String, dynamic> map) => TutorStats(attempts: map['attempts'] ?? 0, correctAttempts: map['correctAttempts'] ?? 0, lastScore: map['lastScore'] ?? 0);
}

class QuranAudioProvider extends ChangeNotifier {
  static final ja.AudioPlayer _globalAudioPlayer = ja.AudioPlayer();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Dio _dio = Dio(); 

  final Map<int, Map<String, dynamic>> _surahCache = {};

  List<Ayah> ayahs =[];
  List<Reciter> reciters =[];
  List<DriveResource> resources =[];
  Map<int, String> currentTafseer = {}; 
  List<BookmarkModel> savedBookmarks =[]; 

  bool isLoading = true;
  int _playingAyahIndex = -1;
  bool _isPlaying = false;
  Reciter? _selectedReciter;
  double currentSpeed = 1.0;

  ReadingMode currentReadingMode = ReadingMode.audioTranslation;
  ScriptType currentScriptType = ScriptType.uthmani;
  double arabicFontSize = 26.0;
  String currentFontFamily = 'Amiri'; 

  int currentSurahNumber = 1;
  String currentSurahName = "Loading...";
  String currentSurahArabicName = "";
  String currentSurahRevelation = "";
  int currentSurahTotalAyahs = 0;

  Stream<Duration> get positionStream => _globalAudioPlayer.positionStream;
  Stream<Duration?> get durationStream => _globalAudioPlayer.durationStream;

  QuranAudioProvider() {
    _initData();
    _setupAudioListeners();
  }

  Future<void> _initData() async {
    await _fetchReciters();
    await _fetchDriveResources();
    await _loadBookmarks(); 
    await loadSurah(savedBookmarks.isNotEmpty ? savedBookmarks.first.surahNumber : 1); 
  }

  int _naturalCompare(String a, String b) {
    final regExp = RegExp(r'(\d+)|(\D+)');
    final matchesA = regExp.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
    final matchesB = regExp.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
    for (int i = 0; i < matchesA.length && i < matchesB.length; i++) {
      final partA = matchesA[i];
      final partB = matchesB[i];
      final numA = int.tryParse(partA);
      final numB = int.tryParse(partB);
      if (numA != null && numB != null) {
        if (numA != numB) return numA.compareTo(numB);
      } else {
        int cmp = partA.compareTo(partB);
        if (cmp != 0) return cmp;
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    String? bookmarksJson = prefs.getString('saved_bookmarks');
    if (bookmarksJson != null) {
      List<dynamic> decoded = jsonDecode(bookmarksJson);
      savedBookmarks = decoded.map((e) => BookmarkModel.fromMap(e)).toList();
    }
    notifyListeners();
  }

  Future<void> saveBookmark(int surahNum, String surahName, int ayahIndex, int ayahNum) async {
    savedBookmarks.removeWhere((b) => b.surahNumber == surahNum && b.ayahIndex == ayahIndex);
    savedBookmarks.insert(0, BookmarkModel(surahNumber: surahNum, surahName: surahName, ayahIndex: ayahIndex, ayahNumber: ayahNum));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_bookmarks', jsonEncode(savedBookmarks.map((e) => e.toMap()).toList()));
    notifyListeners();
  }

  void removeBookmark(BookmarkModel bookmark) async {
    savedBookmarks.remove(bookmark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_bookmarks', jsonEncode(savedBookmarks.map((e) => e.toMap()).toList()));
    notifyListeners();
  }

  bool isAyahBookmarked(int surahNum, int ayahIndex) {
    return savedBookmarks.any((b) => b.surahNumber == surahNum && b.ayahIndex == ayahIndex);
  }

  Future<void> _fetchReciters() async {
    try {
      final snapshot = await _db.collection('quran_reciters').get();
      reciters = snapshot.docs.map((doc) => Reciter.fromMap(doc.data(), doc.id)).toList();
      if (reciters.isNotEmpty) _selectedReciter = reciters.firstWhere((r) => r.identifier == 'ar.alafasy', orElse: () => reciters.first);
    } catch (e) {}
  }

  Future<void> _fetchDriveResources() async {
    try {
      final snapshot = await _db.collection('quran_resources').get();
      resources = snapshot.docs.map((doc) => DriveResource.fromMap(doc.data())).toList();
      resources.sort((a, b) => _naturalCompare(a.title, b.title));
      notifyListeners();
    } catch (e) {}
  }

  Future<void> fetchTafseer(int surahNum) async {
    try {
      var response = await _dio.get("https://api.alquran.cloud/v1/surah/$surahNum/ur.maududi");
      if (response.statusCode == 200) {
        List ayahsData = response.data['data']['ayahs'];
        currentTafseer.clear();
        for (var a in ayahsData) currentTafseer[a['numberInSurah']] = a['text'];
        notifyListeners();
      }
    } catch(e) {}
  }

  Future<void> loadSurah(int surahNum, {int? jumpToAyahIndex}) async {
    isLoading = true;
    _playingAyahIndex = -1;
    _isPlaying = false;
    await _globalAudioPlayer.stop();
    notifyListeners();

    try {
      Map<String, dynamic> data;
      if (_surahCache.containsKey(surahNum)) {
        data = _surahCache[surahNum]!;
      } else {
        String docId = surahNum.toString().padLeft(3, '0');
        DocumentSnapshot doc = await _db.collection('quran_surahs').doc(docId).get(const GetOptions(source: Source.serverAndCache));
        if (doc.exists) {
          data = doc.data() as Map<String, dynamic>;
          _surahCache[surahNum] = data;
        } else throw Exception();
      }

      currentSurahNumber = surahNum;
      currentSurahName = data['name_english'] ?? 'Unknown';
      var surahMatch = allSurahsList.firstWhere((s) => s.number == surahNum, orElse: () => allSurahsList[0]);
      currentSurahArabicName = surahMatch.arabicName;

      String rev = data['revelation_type'] ?? '';
      currentSurahRevelation = rev.isNotEmpty ? "${rev[0].toUpperCase()}${rev.substring(1)}" : "";
      currentSurahTotalAyahs = data['total_ayahs'] ?? 0;

      List<dynamic> ayahsData = data['ayahs'] ??[];
      ayahs = ayahsData.map((e) => Ayah.fromMap(e as Map<String, dynamic>)).toList();
      ayahs.sort((a, b) => a.numberInSurah.compareTo(b.numberInSurah));
      
      if (jumpToAyahIndex != null) _playingAyahIndex = jumpToAyahIndex;
      fetchTafseer(surahNum);

      // ONLINE FETCH: Fetch exact Uthmani and IndoPak scripts directly from API to ensure accurate Talafuz 
      _dio.get("https://api.alquran.cloud/v1/surah/$surahNum/editions/quran-uthmani,quran-indo-pak").then((res) {
        if (res.statusCode == 200) {
          List uAyahs = res.data['data'][0]['ayahs'];
          List iAyahs = res.data['data'][1]['ayahs'];
          for (var ayah in ayahs) {
            var uMatch = uAyahs.firstWhere((a) => a['numberInSurah'] == ayah.numberInSurah, orElse: () => null);
            var iMatch = iAyahs.firstWhere((a) => a['numberInSurah'] == ayah.numberInSurah, orElse: () => null);
            if (uMatch != null) ayah.textUthmani = uMatch['text'];
            if (iMatch != null) ayah.textIndoPak = iMatch['text'];
          }
          notifyListeners(); 
        }
      }).catchError((_) {});

    } catch (e) { ayahs =[]; }

    isLoading = false;
    notifyListeners();
  }

  void setReadingMode(ReadingMode mode) {
    currentReadingMode = mode;
    notifyListeners();
  }

  void setFontFamily(String font) {
    currentFontFamily = font;
    currentScriptType = font == 'IndoPak' ? ScriptType.indoPak : ScriptType.uthmani;
    notifyListeners();
  }

  void changeFontSize(double newSize) {
    arabicFontSize = newSize;
    notifyListeners();
  }

  void toggleSpeed() {
    currentSpeed = (currentSpeed == 1.0) ? 1.5 : (currentSpeed == 1.5 ? 2.0 : 1.0);
    _globalAudioPlayer.setSpeed(currentSpeed);
    notifyListeners();
  }

  void seekAudio(Duration position) => _globalAudioPlayer.seek(position);

  void _setupAudioListeners() {
    _globalAudioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ja.ProcessingState.completed) nextAyah();
    });
  }

  Future<void> togglePlayPause() async {
    if (ayahs.isEmpty) return;
    if (_playingAyahIndex == -1) _playingAyahIndex = 0;
    if (_isPlaying) {
      await _globalAudioPlayer.pause();
      _isPlaying = false;
    } else {
      _isPlaying = true;
      _playCurrentAyah();
    }
    notifyListeners();
  }

  void playSpecificAyah(int index) {
    _playingAyahIndex = index;
    _isPlaying = true;
    _playCurrentAyah();
    notifyListeners();
  }

  Future<void> _playCurrentAyah() async {
    if (_selectedReciter == null || ayahs.isEmpty || _playingAyahIndex < 0) return;
    int globalId = ayahs[_playingAyahIndex].globalNumber;
    String reciterId = _selectedReciter!.identifier;

    try {
      await _globalAudioPlayer.setAudioSource(ja.AudioSource.uri(Uri.parse("https://cdn.islamic.network/quran/audio/128/$reciterId/$globalId.mp3")));
      await _globalAudioPlayer.play();
    } catch (e) {
      _isPlaying = false;
      notifyListeners();
    }
  }

  void nextAyah() {
    if (_playingAyahIndex < ayahs.length - 1) {
      _playingAyahIndex++;
      _playCurrentAyah();
      notifyListeners();
    } else {
      _isPlaying = false;
      notifyListeners();
    }
  }

  void prevAyah() {
    if (_playingAyahIndex > 0) {
      _playingAyahIndex--;
      _playCurrentAyah();
      notifyListeners();
    }
  }

  void setReciter(Reciter reciter) {
    _selectedReciter = reciter;
    if (_isPlaying) _playCurrentAyah();
    notifyListeners();
  }

  int get playingAyahIndex => _playingAyahIndex;
  bool get isPlaying => _isPlaying;
  Reciter? get selectedReciter => _selectedReciter;

  @override
  void dispose() {
    super.dispose();
  }
}

class TutorProvider extends ChangeNotifier {
  static final ja.AudioPlayer _globalAudioPlayer = ja.AudioPlayer();
  static final ja.AudioPlayer _wordAudioPlayer = ja.AudioPlayer();
  final SpeechToText _speechToText = SpeechToText();
  final Dio _dio = Dio();

  int selectedSurah = 1;
  int selectedAyah = 1;
  bool isListening = false;
  bool isSpeechReady = false;
  bool isLoadingLesson = false;
  bool isWordByWordMode = false;
  bool hasEvaluated = false;
  
  String recognizedText = '';
  String displayRecognizedText = ''; 
  
  TutorStats stats = const TutorStats(attempts: 0, correctAttempts: 0, lastScore: 0);
  QuranLesson lesson = QuranLesson.empty();

  SurahBasic get currentSurahMeta => allSurahsList.firstWhere((s) => s.number == selectedSurah);

  TutorProvider() {
    _initSpeechAndStats();
    loadLesson();
  }

  void toggleMode() {
    isWordByWordMode = !isWordByWordMode;
    notifyListeners();
  }

  Future<void> _initSpeechAndStats() async {
    try {
      isSpeechReady = await _speechToText.initialize(
        onError: (val) {
          if (isListening) {
             isListening = false;
             if (recognizedText.isNotEmpty && !hasEvaluated) _evaluatePronunciation(null);
             notifyListeners();
          }
        },
        onStatus: (val) {
          if ((val == 'notListening' || val == 'done') && isListening) {
            isListening = false;
            if (recognizedText.isNotEmpty && !hasEvaluated) _evaluatePronunciation(null); 
            notifyListeners();
          }
        },
      );
    } catch (e) {}

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('quran_tutor_stats');
    if (raw != null) stats = TutorStats.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> playLessonAudio() async {
    await _globalAudioPlayer.stop();
    if (lesson.audioUrl.isNotEmpty) {
      await _globalAudioPlayer.setUrl(lesson.audioUrl);
      await _globalAudioPlayer.play();
    }
  }

  Future<void> playWordAudio(String urlPath) async {
    await _wordAudioPlayer.stop();
    if (urlPath.isNotEmpty) {
      await _wordAudioPlayer.setUrl("https://verses.quran.com/$urlPath");
      await _wordAudioPlayer.play();
    }
  }

  Future<void> toggleListening(BuildContext context) async {
    if (!isSpeechReady) {
      isSpeechReady = await _speechToText.initialize();
      if (!isSpeechReady) return;
    }

    if (isListening) {
      await _speechToText.stop();
      isListening = false;
      notifyListeners();
      if (recognizedText.isNotEmpty && !hasEvaluated) _evaluatePronunciation(context);
      return;
    }
    
    recognizedText = '';
    displayRecognizedText = '';
    hasEvaluated = false;
    isListening = true;
    notifyListeners();

    await _speechToText.listen(
      listenFor: const Duration(hours: 1), 
      pauseFor: const Duration(hours: 1), 
      listenMode: ListenMode.dictation, 
      partialResults: true, 
      localeId: 'ar_SA', 
      cancelOnError: false,
      onResult: (result) {
        recognizedText = result.recognizedWords;
        displayRecognizedText = _applyTashkeel(recognizedText, lesson.arabic);
        notifyListeners(); 
      },
    );
  }

  String _normalizeArabicText(String text) {
    if (text.isEmpty) return "";
    String cleaned = text.replaceAll(RegExp(r'[\u0610-\u061A\u0653-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED\u0640]'), '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(^|\s)و\s+'), (match) => '${match[1]}و');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(^|\s)يا\s+'), (match) => '${match[1]}يا');
    cleaned = cleaned.replaceAll(RegExp(r'[ٱأإآ]'), 'ا').replaceAll(RegExp(r'[ىئ]'), 'ي').replaceAll('ة', 'ه').replaceAll('ؤ', 'و').replaceAll('ء', '');
    cleaned = cleaned.replaceAll(RegExp(r'[^\u0621-\u064A\u064B-\u0652\s]'), '');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _applyTashkeel(String sttText, String expectedText) {
    if (sttText.isEmpty) return "";
    String stripH(String s) => s.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
    List<String> expWordsRaw = expectedText.split(' ').where((w) => w.isNotEmpty).toList();
    List<String> expWordsNorm = expWordsRaw.map((w) => _normalizeArabicText(w)).toList();
    String fixedStt = sttText.replaceAllMapped(RegExp(r'(^|\s)و\s+'), (match) => '${match[1]}و').replaceAllMapped(RegExp(r'(^|\s)يا\s+'), (match) => '${match[1]}يا');
    List<String> sttWordsRaw = fixedStt.split(' ').where((w) => w.isNotEmpty).toList();
    List<String> result =[];
    int expIndex = 0;
    for (String sw in sttWordsRaw) {
      String normS = _normalizeArabicText(sw);
      String normSBase = stripH(normS);
      bool matched = false;
      for (int i = expIndex; i < expWordsNorm.length && i < expIndex + 3; i++) {
        String expNormBase = stripH(expWordsNorm[i]);
        if (normSBase == expNormBase) {
          bool conflict = false;
          int eIndex = 0;
          for (int aIndex = 0; aIndex < normS.length; aIndex++) {
            String charA = normS[aIndex];
            if (!RegExp(r'[\u064B-\u0652]').hasMatch(charA)) {
              while (eIndex < expWordsNorm[i].length && expWordsNorm[i][eIndex] != charA) eIndex++;
              if (eIndex < expWordsNorm[i].length) eIndex++;
            } else {
              bool matchedHarakat = false;
              for (int k = eIndex; k < expWordsNorm[i].length; k++) {
                if (!RegExp(r'[\u064B-\u0652]').hasMatch(expWordsNorm[i][k])) break;
                if (expWordsNorm[i][k] == charA) { matchedHarakat = true; break; }
              }
              if (!matchedHarakat) { conflict = true; break; }
            }
          }
          if (conflict) result.add(sw); else result.add(expWordsRaw[i]);
          expIndex = i + 1;
          matched = true;
          break;
        }
      }
      if (!matched) result.add(sw);
    }
    return result.join(' ');
  }

  int _levenshteinWord(List<String> a, List<String> b) {
    List<List<int>> d = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) d[i][0] = i;
    for (int j = 0; j <= b.length; j++) d[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        int cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
        d[i][j] = math.min(math.min(d[i - 1][j] + 1, d[i][j - 1] + 1), d[i - 1][j - 1] + cost);
      }
    }
    return d[a.length][b.length];
  }

  int _levenshteinChar(String a, String b) {
    List<List<int>> d = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) d[i][0] = i;
    for (int j = 0; j <= b.length; j++) d[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        int cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
        d[i][j] = math.min(math.min(d[i - 1][j] + 1, d[i][j - 1] + 1), d[i - 1][j - 1] + cost);
      }
    }
    return d[a.length][b.length];
  }

  int _calculateArabicScore(String expectedRaw, String actualRaw) {
    if (expectedRaw.isEmpty || actualRaw.isEmpty) return 0;
    String expectedNorm = _normalizeArabicText(expectedRaw);
    String actualNorm = _normalizeArabicText(actualRaw);
    String stripH(String s) => s.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
    String expectedBase = stripH(expectedNorm);
    String actualBase = stripH(actualNorm);

    int harakatPenalties = 0;
    List<String> aWordsNorm = actualNorm.split(' ').where((w) => w.isNotEmpty).toList();
    List<String> eWordsNorm = expectedNorm.split(' ').where((w) => w.isNotEmpty).toList();

    for (int i = 0; i < aWordsNorm.length; i++) {
      if (i < eWordsNorm.length) {
        String aW = aWordsNorm[i];
        String eW = eWordsNorm[i];
        int eIndex = 0;
        for (int aIndex = 0; aIndex < aW.length; aIndex++) {
          String charA = aW[aIndex];
          if (!RegExp(r'[\u064B-\u0652]').hasMatch(charA)) {
            while (eIndex < eW.length && eW[eIndex] != charA) eIndex++;
            if (eIndex < eW.length) eIndex++;
          } else {
            bool matchedHarakat = false;
            for (int k = eIndex; k < eW.length; k++) {
              if (!RegExp(r'[\u064B-\u0652]').hasMatch(eW[k])) break;
              if (eW[k] == charA) { matchedHarakat = true; break; }
            }
            if (!matchedHarakat) harakatPenalties += 10;
          }
        }
      }
    }

    if (expectedBase.replaceAll(' ', '') == actualBase.replaceAll(' ', '')) return (100 - harakatPenalties).clamp(0, 100);

    List<String> expectedWords = expectedBase.split(' ').where((w) => w.isNotEmpty).toList();
    List<String> actualWords = actualBase.split(' ').where((w) => w.isNotEmpty).toList();
    if (expectedWords.isEmpty || actualWords.isEmpty) return 0;

    int wordDistance = _levenshteinWord(expectedWords, actualWords);
    int maxWords = math.max(expectedWords.length, actualWords.length);
    double wordAccuracy = maxWords == 0 ? 0.0 : ((maxWords - wordDistance) / maxWords);

    String expectedChars = expectedBase.replaceAll(' ', '');
    String actualChars = actualBase.replaceAll(' ', '');
    int charDistance = _levenshteinChar(expectedChars, actualChars);
    int maxChars = math.max(expectedChars.length, actualChars.length);
    double charAccuracy = maxChars == 0 ? 0.0 : ((maxChars - charDistance) / maxChars);

    double finalScore = (wordAccuracy * 0.30 + charAccuracy * 0.70) * 100;
    return (finalScore.round() - harakatPenalties).clamp(0, 100);
  }

  Future<void> _evaluatePronunciation(BuildContext? context) async {
    int score = _calculateArabicScore(lesson.arabic, recognizedText);
    final isCorrect = score >= 70; 

    stats = TutorStats(attempts: stats.attempts + 1, correctAttempts: stats.correctAttempts + (isCorrect ? 1 : 0), lastScore: score);
    hasEvaluated = true; 
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quran_tutor_stats', jsonEncode(stats.toMap()));
    notifyListeners();
  }

  Future<void> loadLesson() async {
    isLoadingLesson = true;
    hasEvaluated = false;
    recognizedText = '';
    displayRecognizedText = '';
    notifyListeners();

    final verseKey = '$selectedSurah:$selectedAyah';
    
    try {
      final cloudRes = await _dio.get('https://api.alquran.cloud/v1/ayah/$verseKey/editions/quran-uthmani,en.asad,ur.jalandhry,ar.alafasy');
      final List cloudData = cloudRes.data['data'] ??[];
      
      final arabicData = cloudData.isNotEmpty ? cloudData[0] : {};
      final englishData = cloudData.length > 1 ? cloudData[1] : {};
      final urduData = cloudData.length > 2 ? cloudData[2] : {};
      final audioData = cloudData.length > 3 ? cloudData[3] : {};

      String tafseerText = "Tafseer not available";
      try {
        final tafRes = await _dio.get('https://api.alquran.cloud/v1/ayah/$verseKey/ur.maududi');
        tafseerText = _stripHtml((tafRes.data['data']['text'] ?? '').toString());
      } catch(e) {}

      String transliteration = "";
      String tajweedRaw = "";
      List<WordLesson> extractedWords =[];
      try {
        final wordsRes = await _dio.get('https://api.quran.com/api/v4/verses/by_key/$verseKey?words=true&word_fields=tajweed,transliteration,translation,text_uthmani,audio_url');
        final verse = wordsRes.data['verse'] ?? {};
        final List wordsData = verse['words'] ??[];
        
        for (var w in wordsData) {
          String trText = ((w['transliteration'] ?? {})['text'] ?? '').toString();
          if (trText.isNotEmpty) transliteration += "$trText ";
          
          if (tajweedRaw.isEmpty) {
            String maybeTajweed = (w['tajweed'] ?? '').toString();
            if (maybeTajweed.isNotEmpty && !maybeTajweed.contains('null')) tajweedRaw = maybeTajweed;
          }
          
          extractedWords.add(WordLesson(
            text: w['text_uthmani'] ?? '', translation: (w['translation'] ?? {})['text'] ?? '',
            transliteration: trText, audioUrl: w['audio_url'] ?? ''
          ));
        }
      } catch (e) {}

      lesson = QuranLesson(
        surah: currentSurahMeta.englishName, ayah: selectedAyah, arabic: (arabicData['text'] ?? '').toString(),
        translation: (englishData['text'] ?? '').toString(), urduTranslation: (urduData['text'] ?? '').toString(),
        tafseer: tafseerText, tajweedTip: tajweedRaw.isNotEmpty ? _stripHtml(tajweedRaw) : "No specific Tajweed rule found for the start of this Ayah.",
        transliteration: transliteration.trim(), audioUrl: (audioData['audio'] ?? '').toString(), words: extractedWords
      );

    } catch (e) {}

    isLoadingLesson = false;
    notifyListeners();
  }

  String _stripHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&').replaceAll('&quot;', '"').trim();
  }

  void changeAyah(int ayah) { selectedAyah = ayah; loadLesson(); }
  void changeSurah(int surah) { selectedSurah = surah; selectedAyah = 1; loadLesson(); }

  @override
  void dispose() {
    _speechToText.cancel();
    super.dispose();
  }
}

class AudioScreen extends StatelessWidget {
  const AudioScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(create: (_) => QuranAudioProvider(), child: const _AudioScreenView());
  }
}

class _AudioScreenView extends StatefulWidget {
  const _AudioScreenView();
  @override
  State<_AudioScreenView> createState() => _AudioScreenViewState();
}

class _AudioScreenViewState extends State<_AudioScreenView> {
  final ScrollController _scrollController = ScrollController();
  final Color primaryGreen = const Color(0xFF4CAF50);
  final Color pastelGreen = const Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuranAudioProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, provider),
      body: provider.isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryGreen))
        : Stack(
            children:[
              ListView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 200),
                children:[
                  _buildSurahInfoCard(provider),
                  const SizedBox(height: 20),
                  ...provider.ayahs.asMap().entries.map((entry) {
                    int index = entry.key;
                    Ayah ayah = entry.value;
                    bool isHighlighted = provider.playingAyahIndex == index;
                    return _buildAyahCard(context, ayah, index, isHighlighted, provider);
                  }),
                ],
              ),
              Align(alignment: Alignment.bottomCenter, child: _buildMiniPlayer(context, provider)),
            ],
          ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, QuranAudioProvider provider) {
    return AppBar(
      backgroundColor: Colors.white, elevation: 0, centerTitle: false,
      title: const Text("Quran Viewer", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
      actions:[
        IconButton(icon: const Icon(Icons.school, color: Colors.blueAccent), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranTutorScreen()))),
        IconButton(icon: const Icon(Icons.folder_copy, color: Color(0xFF1B5E20)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: const DriveLibraryScreen())))),
        IconButton(icon: const Icon(Icons.record_voice_over, color: Colors.deepOrange), onPressed: () => _showQariListSheet(context, provider, isDarkMode: false)),
        IconButton(icon: Icon(Icons.bookmarks, color: primaryGreen), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: const BookmarksScreen())))),
        IconButton(icon: const Icon(Icons.search, color: Colors.black87), onPressed: () => _showSurahListSheet(context, provider)),
        IconButton(icon: const Icon(Icons.font_download_outlined, color: Colors.black87), onPressed: () => _showAppearanceDrawer(context, provider)),
      ],
    );
  }

  void _showQariListSheet(BuildContext context, QuranAudioProvider provider, {required bool isDarkMode}) {
    Color bgColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;
    Color tileColor = isDarkMode ? Colors.white24 : pastelGreen;

    showModalBottomSheet(
      context: context, backgroundColor: bgColor, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          children:[
            Padding(padding: const EdgeInsets.all(20.0), child: Text("Select Qari (Reciter)", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold))),
            Expanded(
              child: ListView.builder(
                itemCount: provider.reciters.length,
                itemBuilder: (context, index) {
                  final qari = provider.reciters[index];
                  bool isSelected = qari.identifier == provider.selectedReciter?.identifier;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tileColor, backgroundImage: qari.localImage.isNotEmpty ? AssetImage(qari.localImage) : null,
                      child: qari.localImage.isEmpty ? Icon(Icons.person, color: isSelected ? Colors.white : (isDarkMode ? Colors.white : primaryGreen)) : null,
                    ),
                    title: Text(qari.name, style: TextStyle(color: isSelected ? primaryGreen : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? Icon(Icons.check_circle, color: primaryGreen) : null,
                    onTap: () { provider.setReciter(qari); Navigator.pop(context); },
                  );
                },
              ),
            ),
          ],
        );
      }
    );
  }

  void _showSurahListSheet(BuildContext context, QuranAudioProvider provider) {
    String searchQuery = "";
    List<SurahBasic> filteredSurahs = List.from(allSurahsList);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return FractionallySizedBox(
              heightFactor: 0.85, 
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children:[
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    TextField(
                      decoration: InputDecoration(hintText: "Search...", prefixIcon: Icon(Icons.search, color: primaryGreen), filled: true, fillColor: pastelGreen, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                      onChanged: (value) => setState(() => filteredSurahs = allSurahsList.where((s) => s.englishName.toLowerCase().contains(value.toLowerCase()) || s.number.toString().contains(value)).toList()),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredSurahs.length,
                        itemBuilder: (context, index) {
                          final surah = filteredSurahs[index];
                          final isCurrent = provider.currentSurahNumber == surah.number;
                          return ListTile(
                            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: isCurrent ? primaryGreen : pastelGreen, shape: BoxShape.circle), child: Center(child: Text(surah.number.toString(), style: TextStyle(color: isCurrent ? Colors.white : primaryGreen, fontWeight: FontWeight.bold)))),
                            title: Text(surah.englishName, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                            trailing: Text(surah.arabicName, style: const TextStyle(fontSize: 18, fontFamily: 'Amiri')),
                            onTap: () { Navigator.pop(context); provider.loadSurah(surah.number); },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _showAppearanceDrawer(BuildContext context, QuranAudioProvider provider) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  const Text("Appearance & Reading Mode", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<ReadingMode>(
                      segments: const[
                        ButtonSegment(value: ReadingMode.simple, label: Text("Simple")),
                        ButtonSegment(value: ReadingMode.translation, label: Text("Translate")),
                        ButtonSegment(value: ReadingMode.audioTranslation, label: Text("Audio")),
                        ButtonSegment(value: ReadingMode.wordByWord, label: Text("Word by Word")),
                        ButtonSegment(value: ReadingMode.tafseer, label: Text("Tafseer")),
                      ],
                      selected: {provider.currentReadingMode},
                      onSelectionChanged: (Set<ReadingMode> newSelection) {
                        provider.setReadingMode(newSelection.first);
                        setState((){});
                      },
                    ),
                  ),
                  const Divider(height: 20),
                  const Text("Arabic Font Style", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const[
                      ButtonSegment(value: 'Amiri', label: Text("Real Arabic (Uthmani)")),
                      ButtonSegment(value: 'IndoPak', label: Text("Indo-Pak")),
                    ],
                    selected: {provider.currentFontFamily},
                    onSelectionChanged: (Set<String> newSelection) {
                      provider.setFontFamily(newSelection.first);
                      setState((){});
                    },
                  ),
                  const Divider(height: 20),
                  const Text("Arabic Font Size", style: TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: provider.arabicFontSize, min: 18.0, max: 50.0, activeColor: primaryGreen,
                    onChanged: (val) { provider.changeFontSize(val); setState((){}); },
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildSurahInfoCard(QuranAudioProvider provider) {
    String rev = provider.currentSurahRevelation.toLowerCase();
    String bgImage = rev.contains('medinan') || rev.contains('madina') ? 'assets/images/madina.jpg' : 'assets/images/makkah.jpg';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(image: AssetImage(bgImage), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken)),
      ),
      child: Column(
        children:[
          Text("Surah ${provider.currentSurahName}", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("${provider.currentSurahRevelation} • ${provider.currentSurahTotalAyahs} Ayahs", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          const Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ", style: TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'Amiri')),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(provider.isPlaying ? Icons.pause : Icons.play_arrow, color: primaryGreen),
            label: Text(provider.isPlaying ? "Pause Surah" : "Play Full Surah", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            onPressed: () { if (provider.isPlaying) { provider.togglePlayPause(); } else { provider.playSpecificAyah(0); } },
          )
        ],
      ),
    );
  }

  Widget _buildAyahCard(BuildContext context, Ayah ayah, int index, bool isHighlighted, QuranAudioProvider provider) {
    bool showTranslation = provider.currentReadingMode == ReadingMode.translation || provider.currentReadingMode == ReadingMode.audioTranslation;
    bool isBookmarked = provider.isAyahBookmarked(provider.currentSurahNumber, index);
    
    String arabicTextToDisplay = provider.currentScriptType == ScriptType.indoPak ? ayah.textIndoPak : ayah.textUthmani;

    return GestureDetector(
      onTap: () => provider.playSpecificAyah(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isHighlighted ? primaryGreen : Colors.transparent, width: 2),
          boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:[
                CircleAvatar(backgroundColor: pastelGreen, radius: 18, child: Text(ayah.numberInSurah.toString(), style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold))),
                Row(
                  children:[
                    if (isHighlighted && provider.isPlaying) Icon(Icons.multitrack_audio, color: primaryGreen),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: primaryGreen),
                      onPressed: () { 
                        if (isBookmarked) provider.removeBookmark(provider.savedBookmarks.firstWhere((b) => b.surahNumber == provider.currentSurahNumber && b.ayahIndex == index));
                        else provider.saveBookmark(provider.currentSurahNumber, provider.currentSurahName, index, ayah.numberInSurah); 
                      },
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),
            
            if (provider.currentReadingMode == ReadingMode.wordByWord) ...[
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 12,
                  runSpacing: 16,
                  children: ayah.words.map((word) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children:[
                      Text(word.arabic, style: TextStyle(fontSize: provider.arabicFontSize, fontFamily: provider.currentFontFamily, height: 1.5, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(word.english, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  )).toList(),
                ),
              )
            ] else ...[
              Text(arabicTextToDisplay, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: TextStyle(fontSize: provider.arabicFontSize, fontFamily: provider.currentFontFamily, height: 1.8)),
            ],
            
            if (showTranslation && provider.currentReadingMode != ReadingMode.wordByWord) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
              Text(ayah.textEnglish, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4)),
              const SizedBox(height: 12),
              Text(ayah.textUrdu, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 16, color: Colors.black54, fontFamily: 'JameelNooriNastaleeq')),
            ],

            if (provider.currentReadingMode == ReadingMode.tafseer) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
              const Text("Tafseer (Tafheem-ul-Quran):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 8),
              Text(provider.currentTafseer[ayah.numberInSurah] ?? "Loading Tafseer...", textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 16, height: 1.6)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(BuildContext context, QuranAudioProvider provider) {
    if (provider.currentReadingMode == ReadingMode.simple) return const SizedBox.shrink();
    String ayahText = provider.playingAyahIndex != -1 ? "Ayah ${provider.ayahs[provider.playingAyahIndex].numberInSurah}" : "Tap an Ayah to Play";
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: const FullPlayerScreen()))),
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 100), 
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
        child: Row(
          children:[
            GestureDetector(
              onTap: () => provider.togglePlayPause(),
              child: CircleAvatar(radius: 22, backgroundColor: pastelGreen, child: FaIcon(provider.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: primaryGreen, size: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  Text("Surah ${provider.currentSurahName} • $ayahText", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                  Text("Voice: ${provider.selectedReciter?.name ?? ''}", style: const TextStyle(color: Colors.black54, fontSize: 11), maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriveLibraryScreen extends StatefulWidget {
  final String currentPath;
  const DriveLibraryScreen({super.key, this.currentPath = ""});

  @override
  State<DriveLibraryScreen> createState() => _DriveLibraryScreenState();
}

class _DriveLibraryScreenState extends State<DriveLibraryScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuranAudioProvider>();
    
    // Get all raw items in the current path
    List<DriveResource> rawItems = provider.resources.where((r) => r.folderPath == widget.currentPath).toList();
    
    // --- FRONTEND DEDUPLICATION FIX --- 
    // If a folder and an audio file have the EXACT same name, hide the fake audio file
    List<DriveResource> currentItems =[];
    Set<String> folderNames = {};
    
    // First pass: add all folders to list and save their names
    for (var r in rawItems) {
      if (r.type == 'folder') {
        currentItems.add(r);
        folderNames.add(r.title.toLowerCase().trim());
      }
    }
    
    // Second pass: only add audios/pdfs if a folder with that name DOES NOT exist
    for (var r in rawItems) {
      if (r.type != 'folder') {
        if (!folderNames.contains(r.title.toLowerCase().trim())) {
          currentItems.add(r);
        }
      }
    }
    // ---------------------------------

    // Handle Search
    if (searchQuery.isNotEmpty) {
      currentItems = currentItems.where((r) => r.title.toLowerCase().contains(searchQuery.toLowerCase())).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        title: Text(widget.currentPath.isEmpty ? "Unified Library" : widget.currentPath.split('/').reversed.elementAt(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white), elevation: 0,
      ),
      body: Column(
        children:[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search for a resource...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5E20)),
                filled: true, fillColor: const Color(0xFFF4F9F4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: currentItems.length,
              itemBuilder: (context, index) {
                final res = currentItems[index];
                IconData iconData = Icons.play_circle_outline;
                String subtitle = "AUDIO";
                
                if (res.type == 'folder') {
                  iconData = Icons.folder; subtitle = "FOLDER";
                } else if (res.type == 'pdf' || res.type == 'book') {
                  iconData = Icons.picture_as_pdf; subtitle = "PDF DOCUMENT";
                }

                return GestureDetector(
                  onTap: () {
                    if (res.type == 'folder') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: DriveLibraryScreen(currentPath: "${widget.currentPath}${res.title}/"))));
                    } else if (res.type == 'pdf' || res.type == 'book') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(pdfUrl: res.driveUrl, title: res.title)));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryAudioPlayerScreen(audioUrl: res.driveUrl, title: res.title)));
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF4F9F4), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children:[
                        Icon(iconData, color: const Color(0xFF1B5E20), size: 30),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:[
                              Text(res.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF1B5E20)),
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
  }
}

class QuranTutorScreen extends StatelessWidget {
  const QuranTutorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(create: (_) => TutorProvider(), child: const _QuranTutorView());
  }
}

class _QuranTutorView extends StatelessWidget {
  const _QuranTutorView();
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TutorProvider>();
    const primary = Color(0xFF4CAF50); 
    const light = Color(0xFFF1F8E9);

    return Scaffold(
      appBar: AppBar(title: const Text('Quran Tutor & Memorization', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: primary, foregroundColor: Colors.white),
      backgroundColor: light,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children:[
          _SectionCard(
            child: Row(
              children:[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    isExpanded: true, value: provider.selectedSurah,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Surah', filled: true, fillColor: Colors.white),
                    items: allSurahsList.map((s) => DropdownMenuItem(value: s.number, child: Text('${s.number}. ${s.englishName}', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) { if (val != null) provider.changeSurah(val); },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    isExpanded: true, value: provider.selectedAyah,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Ayah', filled: true, fillColor: Colors.white),
                    items: List.generate(provider.currentSurahMeta.ayahCount, (i) => DropdownMenuItem(value: i + 1, child: Text('Ayah ${i + 1}'))),
                    onChanged: (val) { if (val != null) provider.changeAyah(val); },
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:[
                    const Text('Lesson', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4CAF50), fontSize: 18)),
                    Row(
                      children:[
                        const Text("Word-by-Word", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Switch(value: provider.isWordByWordMode, activeColor: const Color(0xFF4CAF50), onChanged: (val) => provider.toggleMode()),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 12),
                if (provider.isLoadingLesson) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF4CAF50))))
                else if (provider.isWordByWordMode)
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 12, runSpacing: 16,
                      children: provider.lesson.words.map((word) => GestureDetector(
                        onTap: () => provider.playWordAudio(word.audioUrl),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF4CAF50), width: 1.5)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children:[
                              Text(word.text, style: const TextStyle(fontSize: 24, fontFamily: 'Amiri', color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text(word.translation, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  )
                else Text(provider.lesson.arabic, textAlign: TextAlign.right, style: const TextStyle(fontSize: 28, height: 1.6, fontFamily: 'Amiri')),
                const SizedBox(height: 16),
                if (!provider.isLoadingLesson && !provider.isWordByWordMode) ...[
                  Text(provider.lesson.translation, style: const TextStyle(color: Colors.black87, fontSize: 15)),
                  const SizedBox(height: 12),
                  Text(provider.lesson.urduTranslation, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 17, color: Colors.black54, fontFamily: 'JameelNooriNastaleeq')),
                ]
              ],
            ),
          ),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                const Text('Tajweed Tip', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4CAF50), fontSize: 16)),
                const SizedBox(height: 8),
                Text(provider.lesson.tajweedTip.isEmpty ? 'Loading...' : provider.lesson.tajweedTip),
                const Divider(height: 24),
                const Text('Tafseer (Tafheem-ul-Quran)', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4CAF50), fontSize: 16)),
                const SizedBox(height: 8),
                Text(provider.lesson.tafseer.isEmpty ? 'Loading...' : provider.lesson.tafseer, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                const Text('Memorization Practice', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4CAF50), fontSize: 18)),
                const SizedBox(height: 8),
                const Text('1. Tap Listen\n2. Tap Mic to Start Speaking\n3. Tap Stop to Check Accuracy', style: TextStyle(height: 1.5)),
                const SizedBox(height: 16),
                Row(
                  children:[
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () => provider.playLessonAudio(), icon: const Icon(Icons.volume_up), label: const Text('Listen Full Ayah'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: provider.isListening ? Colors.redAccent : const Color(0xFFF57C00), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () => provider.toggleListening(context), icon: Icon(provider.isListening ? Icons.stop : Icons.mic), label: Text(provider.isListening ? 'Stop & Check' : 'Speak'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: provider.hasEvaluated ? (provider.stats.lastScore >= 70 ? Colors.green.shade50 : Colors.red.shade50) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16), border: Border.all(color: provider.hasEvaluated ? (provider.stats.lastScore >= 70 ? Colors.green : Colors.redAccent) : Colors.transparent)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children:[
                      if (provider.hasEvaluated) ...[ Text("Score: ${provider.stats.lastScore}%", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: provider.stats.lastScore >= 70 ? Colors.green.shade700 : Colors.redAccent)), const SizedBox(height: 12), ],
                      Text('You Said:', style: TextStyle(fontWeight: FontWeight.w600, color: provider.isListening ? Colors.redAccent : Colors.blueGrey)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: Text(
                          provider.isListening ? (provider.recognizedText.isNotEmpty ? provider.displayRecognizedText : 'Listening actively...') : (provider.recognizedText.isNotEmpty ? provider.displayRecognizedText : 'Tap "Speak" to start.'), 
                          style: TextStyle(fontSize: provider.recognizedText.isNotEmpty ? 24 : 16, color: provider.recognizedText.isNotEmpty ? Colors.black87 : Colors.grey, fontFamily: provider.recognizedText.isNotEmpty ? 'Amiri' : null, fontStyle: provider.recognizedText.isNotEmpty ? FontStyle.normal : FontStyle.italic),
                          textAlign: provider.recognizedText.isNotEmpty ? TextAlign.right : TextAlign.left, textDirection: provider.recognizedText.isNotEmpty ? TextDirection.rtl : TextDirection.ltr,
                        ),
                      ),
                      const Divider(height: 30),
                      Text('Expected (Actual Ayah):', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                        child: Text(provider.lesson.arabic.isEmpty ? '...' : provider.lesson.arabic, style: const TextStyle(fontSize: 24, color: Colors.black87, fontFamily: 'Amiri'), textAlign: TextAlign.right, textDirection: TextDirection.rtl),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          _SectionCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children:[
                Column(children:[ Text(provider.stats.attempts.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF4CAF50))), const Text('Attempts', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)), ]),
                Column(children:[ Text(provider.stats.correctAttempts.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF4CAF50))), const Text('Correct', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)), ]),
                Column(children:[ Text('${provider.stats.lastScore}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF4CAF50))), const Text('Last Score', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)), ]),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: child,
    );
  }
}

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuranAudioProvider>();
    final Color primaryGreen = const Color(0xFF4CAF50);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FFF7),
      appBar: AppBar(title: const Text("Saved Bookmarks", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black87)),
      body: provider.savedBookmarks.isEmpty 
        ? const Center(child: Text("No bookmarks saved yet.", style: TextStyle(color: Colors.grey, fontSize: 16)))
        : ListView.builder(
            padding: const EdgeInsets.all(16), itemCount: provider.savedBookmarks.length,
            itemBuilder: (context, index) {
              final bm = provider.savedBookmarks[index];
              return Card(
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: CircleAvatar(backgroundColor: const Color(0xFFE8F5E9), child: Icon(Icons.bookmark, color: primaryGreen)),
                  title: Text("Surah ${bm.surahName}", style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Ayah ${bm.ayahNumber}"),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => provider.removeBookmark(bm)),
                  onTap: () { Navigator.pop(context); provider.loadSurah(bm.surahNumber, jumpToAyahIndex: bm.ayahIndex); },
                ),
              );
            },
          ),
    );
  }
}

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuranAudioProvider>();
    final Color primaryGreen = const Color(0xFF4CAF50);
    String rev = provider.currentSurahRevelation.toLowerCase();
    String bgImage = rev.contains('medinan') || rev.contains('madina') ? 'assets/images/madina.jpg' : 'assets/images/makkah.jpg';

    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        children:[
          Positioned.fill(child: Image.asset(bgImage, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.80))),
          SafeArea(
            child: Column(
              children:[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:[
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      const Text("Now Playing", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 48), 
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                Container(
                  width: MediaQuery.of(context).size.width * 0.80, padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(color: const Color(0xFF28282B), borderRadius: BorderRadius.circular(24), boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))]),
                  child: Column(
                    children:[
                      Text("${provider.currentSurahNumber}. ${provider.currentSurahName}", style: const TextStyle(fontSize: 16, color: Colors.white70)),
                      const SizedBox(height: 16),
                      Text(provider.currentSurahArabicName, style: const TextStyle(fontSize: 48, fontFamily: 'Amiri', color: Color(0xFFE8C872), fontWeight: FontWeight.bold)), 
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                GestureDetector(
                  onTap: () {
                    final state = context.findAncestorStateOfType<_AudioScreenViewState>();
                    state?._showQariListSheet(context, provider, isDarkMode: true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children:[
                        CircleAvatar(
                          radius: 12, backgroundColor: Colors.transparent,
                          backgroundImage: provider.selectedReciter?.localImage.isNotEmpty == true ? AssetImage(provider.selectedReciter!.localImage) : null,
                          child: provider.selectedReciter?.localImage.isEmpty == true ? const Icon(Icons.person, color: Colors.white, size: 14) : null,
                        ),
                        const SizedBox(width: 12),
                        Text(provider.selectedReciter?.name ?? "Select Qari", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children:[
                      Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 22)),
                      GestureDetector(
                        onTap: () => provider.toggleSpeed(),
                        child: Container(
                          width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                          child: Center(child: Text("x${provider.currentSpeed.toStringAsFixed(1).replaceAll('.0', '')}", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                StreamBuilder<Duration?>(
                  stream: provider.durationStream,
                  builder: (context, snapshot) {
                    final duration = snapshot.data ?? Duration.zero;
                    return StreamBuilder<Duration>(
                      stream: provider.positionStream,
                      builder: (context, snapshot) {
                        var position = snapshot.data ?? Duration.zero;
                        if (position > duration) position = duration;
                        String formatDuration(Duration d) => "${d.inHours.toString().padLeft(2, "0")}:${d.inMinutes.remainder(60).toString().padLeft(2, "0")}:${d.inSeconds.remainder(60).toString().padLeft(2, "0")}";
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children:[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children:[
                                    Text(formatDuration(position), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                    Text(formatDuration(duration), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                  ],
                                ),
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(trackHeight: 4.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0)),
                                child: Slider(
                                  activeColor: primaryGreen, inactiveColor: Colors.white24, min: 0.0,
                                  max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0, value: position.inMilliseconds.toDouble(),
                                  onChanged: (value) => provider.seekAudio(Duration(milliseconds: value.toInt())),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children:[
                      IconButton(icon: Icon(Icons.loop, color: primaryGreen), onPressed: () {}),
                      IconButton(iconSize: 32, color: Colors.white, icon: const Icon(Icons.skip_previous), onPressed: provider.playingAyahIndex > 0 ? () => provider.prevAyah() : null),
                      GestureDetector(
                        onTap: () => provider.togglePlayPause(),
                        child: Container(
                          width: 70, height: 70, decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: primaryGreen, width: 2), shape: BoxShape.circle),
                          child: Icon(provider.isPlaying ? Icons.pause : Icons.play_arrow, color: primaryGreen, size: 36),
                        ),
                      ),
                      IconButton(iconSize: 32, color: Colors.white, icon: const Icon(Icons.skip_next), onPressed: provider.playingAyahIndex < provider.ayahs.length - 1 ? () => provider.nextAyah() : null),
                      IconButton(icon: const Icon(Icons.queue_music, color: Colors.white54), onPressed: () {}),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LibraryAudioPlayerScreen extends StatefulWidget {
  final String audioUrl;
  final String title;
  const LibraryAudioPlayerScreen({super.key, required this.audioUrl, required this.title});
  @override
  State<LibraryAudioPlayerScreen> createState() => _LibraryAudioPlayerScreenState();
}

class _LibraryAudioPlayerScreenState extends State<LibraryAudioPlayerScreen> {
  final ja.AudioPlayer _audioPlayer = ja.AudioPlayer();
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  double speed = 1.0;
  SurahBasic? _matchedSurah;

  @override
  void initState() {
    super.initState();
    _identifySurah();
    _setAudio();
    _audioPlayer.playerStateStream.listen((state) { if (mounted) setState(() => isPlaying = state.playing); });
    _audioPlayer.durationStream.listen((newDuration) { if (mounted) setState(() => duration = newDuration ?? Duration.zero); });
    _audioPlayer.positionStream.listen((newPosition) { if (mounted) setState(() => position = newPosition); });
  }

  void _identifySurah() {
    final titleLower = widget.title.toLowerCase();
    for (var s in allSurahsList) {
      if (titleLower.contains(s.englishName.toLowerCase()) || titleLower.contains(s.number.toString().padLeft(3, '0'))) {
        _matchedSurah = s; break;
      }
    }
  }

  String _getOptimizedDriveUrl(String originalUrl) {
    if (originalUrl.contains('googleapis.com') && originalUrl.contains('/files/')) {
      try {
        final uri = Uri.parse(originalUrl);
        final pathSegments = uri.pathSegments;
        int filesIndex = pathSegments.indexOf('files');
        if (filesIndex != -1 && filesIndex + 1 < pathSegments.length) {
          String fileId = pathSegments[filesIndex + 1];
          return "https://drive.google.com/uc?export=download&id=$fileId";
        }
      } catch (e) {
        return originalUrl;
      }
    }
    return originalUrl;
  }

  Future<void> _setAudio() async {
    try {
      String safeUrl = _getOptimizedDriveUrl(widget.audioUrl);
      await _audioPlayer.setAudioSource(ja.AudioSource.uri(
        Uri.parse(safeUrl), 
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'} 
      ));
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Error playing audio. The file might be too large or access is restricted.", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent, duration: Duration(seconds: 4),
        ));
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}"; 
  }

  @override
  Widget build(BuildContext context) {
    String bgImage = 'assets/images/makkah.jpg'; 
    if (_matchedSurah != null) bgImage = _matchedSurah!.isMadni ? 'assets/images/madina.jpg' : 'assets/images/makkah.jpg';

    bool isParah = widget.title.toLowerCase().contains("parah");
    String displaySubtitle = isParah ? "Parah Recitation" : (_matchedSurah != null ? "Surah ${_matchedSurah!.englishName} • ${_matchedSurah!.isMadni ? "Madni" : "Makki"}" : "Cloud Storage Audio");

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children:[
          Positioned.fill(child: Image.asset(bgImage, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.80))), 
          SafeArea(
            child: Column(
              children:[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:[
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      const Text("Library Player", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                Container(
                  width: MediaQuery.of(context).size.width * 0.80, padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(color: const Color(0xFF28282B), borderRadius: BorderRadius.circular(24), boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))]),
                  child: Column(
                    children:[
                      Text(displaySubtitle, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                      const SizedBox(height: 16),
                      Text(
                        widget.title.replaceAll(RegExp(r'[-_]+'), ' '), 
                        textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, 
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFFE8C872), fontFamily: 'Amiri', shadows:[Shadow(color: Colors.black.withOpacity(0.8), offset: const Offset(0, 2), blurRadius: 4)]) 
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children:[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children:[
                            Text(formatTime(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(formatTime(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      SliderTheme(
                        data: SliderThemeData(thumbColor: const Color(0xFF4CAF50), activeTrackColor: const Color(0xFF4CAF50), inactiveTrackColor: Colors.white24, overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)),
                        child: Slider(
                          min: 0, max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0, value: position.inMilliseconds.toDouble(),
                          onChanged: (value) async => await _audioPlayer.seek(Duration(milliseconds: value.toInt())),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children:[
                      GestureDetector(
                        onTap: () { setState(() => speed = speed == 1.0 ? 1.5 : (speed == 1.5 ? 2.0 : 1.0)); _audioPlayer.setSpeed(speed); },
                        child: Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: Center(child: Text("x${speed.toStringAsFixed(1).replaceAll('.0', '')}", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)))),
                      ),
                      IconButton(iconSize: 32, icon: const Icon(Icons.replay_10, color: Colors.white), onPressed: () => _audioPlayer.seek(position - const Duration(seconds: 10))),
                      GestureDetector(
                        onTap: () async { if (isPlaying) await _audioPlayer.pause(); else await _audioPlayer.play(); },
                        child: Container(width: 70, height: 70, decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: const Color(0xFF4CAF50), width: 2), shape: BoxShape.circle), child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: const Color(0xFF4CAF50), size: 36)),
                      ),
                      IconButton(iconSize: 32, icon: const Icon(Icons.forward_10, color: Colors.white), onPressed: () => _audioPlayer.seek(position + const Duration(seconds: 10))),
                      const SizedBox(width: 50), 
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  const PdfViewerScreen({super.key, required this.pdfUrl, required this.title});
  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPdfPath;
  bool _isDownloading = true;
  bool _hasError = false;
  double _progress = 0.0;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _downloadAndCachePdf();
  }

  String _getOptimizedDriveUrl(String originalUrl) {
    if (originalUrl.contains('googleapis.com') && originalUrl.contains('/files/')) {
      try {
        final uri = Uri.parse(originalUrl);
        final pathSegments = uri.pathSegments;
        int filesIndex = pathSegments.indexOf('files');
        if (filesIndex != -1 && filesIndex + 1 < pathSegments.length) {
          String fileId = pathSegments[filesIndex + 1];
          return "https://drive.google.com/uc?export=download&id=$fileId";
        }
      } catch (e) {
        return originalUrl;
      }
    }
    return originalUrl;
  }

  Future<void> _downloadAndCachePdf() async {
    setState(() { _isDownloading = true; _hasError = false; _progress = 0.0; });
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File('${dir.path}/$safeTitle.pdf');

      if (await file.exists() && await file.length() > 1000) {
        setState(() { _localPdfPath = file.path; _isDownloading = false; }); return;
      }
      
      if (await file.exists()) await file.delete();
      
      String optimizedUrl = _getOptimizedDriveUrl(widget.pdfUrl);

      await Dio().download(
        optimizedUrl, 
        file.path, 
        options: Options(followRedirects: true, receiveTimeout: const Duration(minutes: 5)), 
        onReceiveProgress: (count, total) { 
          if (total != -1) setState(() => _progress = count / total); 
        }
      );
      
      setState(() { _localPdfPath = file.path; _isDownloading = false; });
    } catch (e) { 
      setState(() { _isDownloading = false; _hasError = true; }); 
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _isFullScreen 
          ? null 
          : AppBar(
              title: Text(widget.title, style: const TextStyle(color: Colors.white)), 
              backgroundColor: const Color(0xFF4CAF50), 
              iconTheme: const IconThemeData(color: Colors.white),
              actions:[
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: "Enter Full Screen",
                  onPressed: _toggleFullScreen,
                )
              ],
            ),
      body: Stack(
        children:[
          _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:[
                      const Icon(Icons.error_outline, size: 80, color: Colors.red), const SizedBox(height: 16),
                      const Text("Failed to download PDF.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 16),
                      ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)), onPressed: _downloadAndCachePdf, icon: const Icon(Icons.refresh, color: Colors.white), label: const Text("Retry", style: TextStyle(color: Colors.white)))
                    ],
                  ),
                )
              : _isDownloading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children:[
                          const Icon(Icons.picture_as_pdf, size: 80, color: Colors.redAccent), const SizedBox(height: 20),
                          Text("Preparing Document...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey.shade800)), const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: _progress, minHeight: 12, color: const Color(0xFF4CAF50), backgroundColor: Colors.grey.shade300)),
                          ),
                          const SizedBox(height: 16),
                          Text("${(_progress * 100).toStringAsFixed(0)}%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                        ],
                      ),
                    )
                  : _localPdfPath != null 
                      ? InteractiveViewer(
                          panEnabled: false, 
                          boundaryMargin: EdgeInsets.zero,
                          scaleEnabled: false, 
                          child: SfPdfViewer.file(
                            File(_localPdfPath!),
                            canShowScrollHead: false, 
                            canShowScrollStatus: false, 
                          ),
                        ) 
                      : const SizedBox.shrink(),
                      
          if (_isFullScreen)
            Positioned(
              right: 20,
              bottom: 30,
              child: FloatingActionButton.extended(
                backgroundColor: const Color(0xFF1B5E20).withOpacity(0.9),
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                label: const Text("Exit Full Screen", style: TextStyle(color: Colors.white)),
                onPressed: _toggleFullScreen,
              ),
            )
        ],
      ),
    );
  }
}