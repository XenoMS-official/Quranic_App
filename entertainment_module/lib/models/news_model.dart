import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String category;
  final String? subcategory;
  final String url; // NEW: url field
  final DateTime publishedAt;

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.category,
    this.subcategory,
    required this.url,
    required this.publishedAt,
  });

  // NEW: Updated to fromFirestore factory
  factory NewsArticle.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
    
    return NewsArticle(
      id: doc.id,
      title: map['title']?.toString() ?? 'No Title',
      description: map['description']?.toString() ?? 'No Description available.',
      thumbnailUrl: map['thumbnailUrl']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Uncategorized',
      subcategory: map['subcategory']?.toString(),
      url: map['url']?.toString() ?? '', // Mapping the URL
      // Safe fallback for publishedAt
      publishedAt: map['publishedAt'] != null && map['publishedAt'] is Timestamp
          ? (map['publishedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}