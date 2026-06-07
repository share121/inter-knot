import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/label.dart';

class DiscussionCategoryView {
  const DiscussionCategoryView({
    required this.displayName,
    required this.color,
  });

  final String displayName;
  final Color color;
}

const businessLabelNames = aiReviewRawLabelNames;

const _rawNameToDisplayKey = <String, String>{
  'Announcements': 'Announcements',
  '影片': 'Video',
  '原神': 'Genshin Impact',
  '委托': 'Delegate',
  '崩坏：星穹铁道': 'Honkai: Star Rail',
  '崩坏三': 'Honkai Impact 3',
  '投票': 'Polls',
  '教程': 'Tutorial',
  '灌水': 'Irrigation',
  '科技': 'Technology',
  '绝区零': 'Zenless Zone Zero',
};

const _categoryColors = <String, Color>{
  'Announcements': Color(0xff38bdf8),
  'Video': Color(0xffef4444),
  'Genshin Impact': Color(0xff22c55e),
  'Delegate': Color(0xfff59e0b),
  'Honkai: Star Rail': Color(0xffa855f7),
  'Honkai Impact 3': Color(0xfff472b6),
  'Polls': Color(0xff0ea5e9),
  'Tutorial': Color(0xfffb923c),
  'Irrigation': Color(0xff10b981),
  'Technology': Color(0xff60a5fa),
  'Zenless Zone Zero': Color(0xffff6b6b),
};

DiscussionCategoryView? mapDiscussionCategory(String? rawName) {
  final normalized = rawName?.trim();
  if (normalized == null || normalized.isEmpty) return null;

  final displayKey = _rawNameToDisplayKey[normalized];
  if (displayKey == null) return null;

  final color = _categoryColors[displayKey];
  if (color == null) return null;

  return DiscussionCategoryView(
    displayName: displayKey.tr,
    color: color,
  );
}

bool isVideoDiscussionCategoryName(String? categoryName) {
  final normalized = categoryName?.trim();
  if (normalized == null || normalized.isEmpty) return false;
  return normalized == videoDiscussionCategoryName;
}

bool isVideoDiscussion(DiscussionModel discussion) {
  return isVideoDiscussionCategoryName(discussion.categoryName);
}

List<LabelModel> filterBusinessLabels(
  List<LabelModel> labels, {
  Set<String> excludedNames = businessLabelNames,
}) {
  if (labels.isEmpty) return const <LabelModel>[];
  return labels.where((label) => !excludedNames.contains(label.name)).toList();
}
