import 'package:flutter/material.dart';
import '../models/genre.dart';
import '../theme/app_theme.dart';

class GenreChip extends StatelessWidget {
  final Genre? genre;
  const GenreChip({super.key, required this.genre});

  @override
  Widget build(BuildContext context) {
    final g = genre;
    if (g == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: g.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: g.color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(g.name,
              style: TextStyle(fontSize: 11.5, color: g.color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// ジャンルフィルター
sealed class GenreFilter {
  const GenreFilter();
  bool matches(String? genreId);
}

class FilterAll extends GenreFilter {
  const FilterAll();
  @override
  bool matches(String? genreId) => true;
  @override
  bool operator ==(Object other) => other is FilterAll;
  @override
  int get hashCode => 0;
}

class FilterNone extends GenreFilter {
  const FilterNone();
  @override
  bool matches(String? genreId) => genreId == null;
  @override
  bool operator ==(Object other) => other is FilterNone;
  @override
  int get hashCode => 1;
}

class FilterGenre extends GenreFilter {
  final String id;
  const FilterGenre(this.id);
  @override
  bool matches(String? genreId) => genreId == id;
  @override
  bool operator ==(Object other) => other is FilterGenre && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class GenreFilterBar extends StatelessWidget {
  final List<Genre> genres;
  final GenreFilter selection;
  final ValueChanged<GenreFilter> onSelect;
  const GenreFilterBar({super.key, required this.genres, required this.selection, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('すべて', const FilterAll()),
          _chip('ジャンルなし', const FilterNone()),
          for (final g in genres) _chip(g.name, FilterGenre(g.id), dot: g.color),
        ],
      ),
    );
  }

  Widget _chip(String label, GenreFilter value, {Color? dot}) {
    final active = selection == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppTheme.ink : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? AppTheme.ink : AppTheme.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppTheme.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}
