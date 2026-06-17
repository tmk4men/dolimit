import 'package:flutter/material.dart';

/// ジャンル（アプリ全体で最大 5 個・TODAY / LATER 共有）
class Genre {
  final String id;
  String name;
  int colorValue; // ARGB int
  DateTime createdAt;
  DateTime updatedAt;

  Genre({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Genre.fromJson(Map<String, dynamic> j) => Genre(
        id: j['id'] as String,
        name: j['name'] as String,
        colorValue: j['colorValue'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}
