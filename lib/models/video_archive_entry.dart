import 'package:inter_knot/models/discussion.dart';

class VideoArchiveEntry {
  const VideoArchiveEntry({
    required this.discussion,
    required this.displayTitle,
    required this.tags,
    required this.description,
    required this.encodedPayload,
    required this.decodedPayload,
    required this.errorMessage,
  });

  final DiscussionModel discussion;
  final String displayTitle;
  final List<String> tags;
  final String description;
  final String? encodedPayload;
  final Map<String, dynamic>? decodedPayload;
  final String? errorMessage;

  bool get isValid => decodedPayload != null && errorMessage == null;
}
