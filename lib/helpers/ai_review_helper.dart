import 'package:flutter/material.dart';
import 'package:inter_knot/models/discussion.dart';

class AiReviewView {
  const AiReviewView({
    required this.displayName,
    required this.color,
  });

  final String displayName;
  final Color color;
}

const aiReviewFilterOrder = <AiReviewRating>[
  AiReviewRating.risk,
  AiReviewRating.lowQuality,
  AiReviewRating.normal,
  AiReviewRating.highQuality,
];

const _aiReviewViews = <AiReviewRating, AiReviewView>{
  AiReviewRating.risk: AiReviewView(
    displayName: '风险',
    color: Color(0xffef4444),
  ),
  AiReviewRating.lowQuality: AiReviewView(
    displayName: '低质',
    color: Color(0xfff97316),
  ),
  AiReviewRating.normal: AiReviewView(
    displayName: '普通',
    color: Color(0xff9ca3af),
  ),
  AiReviewRating.highQuality: AiReviewView(
    displayName: '高质',
    color: Color(0xff22c55e),
  ),
};

AiReviewView? mapAiReviewRatingView(AiReviewRating? rating) {
  if (rating == null) return null;
  return _aiReviewViews[rating];
}
