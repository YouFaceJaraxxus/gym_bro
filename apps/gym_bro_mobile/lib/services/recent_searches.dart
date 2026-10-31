import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/people.dart';

/// Something opened from search: a person or a hashtag.
@immutable
class RecentSearch {
  /// A person: their card as it was when opened.
  final PersonSummary? person;

  /// A hashtag, lowercased, without "#".
  final String? tag;

  const RecentSearch.person(PersonSummary this.person) : tag = null;
  const RecentSearch.hashtag(String this.tag) : person = null;

  String get key => person != null ? 'user:${person!.id}' : 'tag:$tag';

  Map<String, dynamic> toJson() => person != null
      ? {
          'kind': 'user',
          'id': person!.id,
          'username': person!.username,
          'name': person!.name,
          'last_name': person!.lastName,
          'avatar_url': person!.avatarUrl,
        }
      : {'kind': 'hashtag', 'tag': tag};

  static RecentSearch? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return switch (json['kind']) {
      'user' when json['id'] is String => RecentSearch.person(PersonSummary.fromJson(json)),
      'hashtag' when json['tag'] is String => RecentSearch.hashtag(json['tag'] as String),
      _ => null,
    };
  }
}

/// Instagram-style recent searches, kept on this device per signed-in user
/// (newest first, at most [max]).
class RecentSearches {
  RecentSearches(this.userId);

  final String userId;
  static const max = 15;

  String get _key => 'recent_searches_v1:$userId';

  Future<List<RecentSearch>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List).map(RecentSearch.fromJson).whereType<RecentSearch>().toList();
    } catch (e) {
      debugPrint('RecentSearches: could not read: $e');
      return const [];
    }
  }

  /// Puts [item] first (moving it if it was there already); returns the new list.
  Future<List<RecentSearch>> add(RecentSearch item) async {
    final next = [item, ...(await load()).where((r) => r.key != item.key)].take(max).toList();
    await _save(next);
    return next;
  }

  Future<List<RecentSearch>> remove(RecentSearch item) async {
    final next = (await load()).where((r) => r.key != item.key).toList();
    await _save(next);
    return next;
  }

  Future<void> clear() => _save(const []);

  Future<void> _save(List<RecentSearch> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(items.map((r) => r.toJson()).toList()));
    } catch (e) {
      debugPrint('RecentSearches: could not save: $e');
    }
  }
}
