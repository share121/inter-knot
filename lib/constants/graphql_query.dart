import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/helpers/query_encode.dart';

String getDiscussion(int number) =>
    '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { number author { __typename avatarUrl(size: 50) login ... on User { name } ... on Organization { name } } createdAt lastEditedAt bodyHTML id bodyText title category { id name } poll { question totalVoteCount viewerCanVote viewerHasVoted options(first: 100, orderBy: { field: VOTE_COUNT, direction: DESC }) { totalCount pageInfo { hasNextPage endCursor } nodes { id option totalVoteCount viewerHasVoted } } } labels(first: 50) { nodes { name color } } comments(first: 20) { totalCount pageInfo { endCursor hasNextPage } nodes { author { avatarUrl(size: 50) login } url id bodyHTML createdAt lastEditedAt replies(first: 100) { nodes { author { avatarUrl(size: 50) login } url bodyHTML createdAt lastEditedAt } } } } } } }';

String getUserContributions(String login) {
  final now = DateTime.now();
  final thisYearFrom = DateTime(now.year);
  final thisYearTo = DateTime(now.year, 12, 31, 23, 59, 59);
  final lastYearFrom = DateTime(now.year - 1);
  final lastYearTo = DateTime(now.year - 1, 12, 31, 23, 59, 59);
  return '{ user(login: "$login") { thisYear: contributionsCollection(from: "${thisYearFrom.toIso8601String()}", to: "${thisYearTo.toIso8601String()}") { contributionCalendar { totalContributions } } lastYear: contributionsCollection(from: "${lastYearFrom.toIso8601String()}", to: "${lastYearTo.toIso8601String()}") { contributionCalendar { totalContributions } } } }';
}

String search(String query, String? endCur, [int length = 100]) =>
    '{ search(first: $length, type: DISCUSSION, query: "repo:$owner/$repo ${queryEncode(query)}", after: ${endCur == null ? null : '"$endCur"'}) { pageInfo { endCursor hasNextPage } nodes { ... on Discussion { number updatedAt category { id name } labels(first: 50) { nodes { name color } } } } } }';

String getUserInfo(String login) =>
    '{ user(login: "$login") { repositories { totalCount }, name } }';

String getSelfUserInfo() => '{ viewer { avatarUrl login } }';

String getPinnedDiscussions(String? endCur) =>
    '{ repository(owner: "$owner", name: "$repo") { pinnedDiscussions(first: 100, after: ${endCur == null ? null : '"$endCur"'}) { pageInfo { endCursor hasNextPage } nodes { discussion { number updatedAt category { id name } labels(first: 50) { nodes { name color } } } } } } }';

String getDiscussionCategories() =>
    '{ repository(owner: "$owner", name: "$repo") { discussionCategories(first: 25) { nodes { id name description emoji isAnswerable } } } }';


String getNewVersion() =>
    '{ repository(owner: "$owner", name: "$repo") { releases(first: 1) { nodes { tagName descriptionHTML releaseAssets(first: 100) { nodes { downloadUrl name downloadCount size updatedAt } } } } } }';

String getComments(int number, String? endCur) =>
    '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { comments(first: 20, after: ${endCur == null ? null : '"$endCur"'}) { pageInfo { endCursor hasNextPage } nodes { author { avatarUrl(size: 50) login } url id bodyHTML createdAt lastEditedAt replies(first: 100) { nodes { author { avatarUrl(size: 50) login } url bodyHTML createdAt lastEditedAt } } } } } } } }';

String deleteDiscussion(String id) =>
    'mutation { deleteDiscussion(input: { id: "$id" }) { clientMutationId } }';

String addDiscussionComment(String discussionId, String body) =>
    'mutation { addDiscussionComment(input: { discussionId: "$discussionId", body: "${queryEncode(body)}" }) { clientMutationId } }';

String getAllReports(int number, String? endCur) =>
    '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { comments(first: 100, after: ${endCur == null ? null : '"$endCur"'}) { pageInfo { endCursor hasNextPage } nodes { author { login } body bodyHTML } } } } }';
