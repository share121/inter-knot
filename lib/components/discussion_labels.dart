import 'package:flutter/material.dart';
import 'package:inter_knot/models/label.dart';

class DiscussionLabels extends StatelessWidget {
  const DiscussionLabels({
    super.key,
    required this.labels,
    this.padding = EdgeInsets.zero,
    this.fontSize = 11,
    this.spacing = 6,
    this.runSpacing = 6,
    this.excludedNames = const <String>{},
  });

  final List<LabelModel> labels;
  final EdgeInsets padding;
  final double fontSize;
  final double spacing;
  final double runSpacing;
  final Set<String> excludedNames;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final visibleLabels = labels
        .where((label) => !excludedNames.contains(label.name))
        .toList();
    if (visibleLabels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: visibleLabels
            .map(
              (label) => _LabelChip(
                label: label,
                fontSize: fontSize,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.label,
    required this.fontSize,
  });

  final LabelModel label;
  final double fontSize;

  Color _parseLabelColor(String raw) {
    final normalized = raw.trim().replaceAll('#', '');
    if (normalized.length == 6) {
      return Color(int.parse('FF$normalized', radix: 16));
    }
    if (normalized.length == 8) {
      return Color(int.parse(normalized, radix: 16));
    }
    return const Color(0xff6f6f6f);
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _parseLabelColor(label.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: baseColor.withValues(alpha: 0.6)),
      ),
      child: Text(
        label.name,
        style: TextStyle(
          color: baseColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
