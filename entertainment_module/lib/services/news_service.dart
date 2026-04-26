import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/news_model.dart';

class NewsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<NewsArticle>> getNews(String category) {
  
    Query query = _db.collection('news');

    if (category != "All News") {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      // 2. Convert docs to objects
      List<NewsArticle> articles = snapshot.docs.map((doc) {
        try {
          return NewsArticle.fromFirestore(doc);
        } catch (e) {
          debugPrint('Error mapping article ${doc.id}: $e');
          return null; 
        }
      }).whereType<NewsArticle>().toList(); /

      articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      return articles;
    });
  }
}