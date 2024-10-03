import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/helpers/query_encode.dart';

String getDiscussion(int number) =>
    '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { author { avatarUrl(size: 50) login } createdAt lastEditedAt bodyHTML id bodyText title comments { totalCount } } } }';

String search(String query, String? endCur, [int length = 100]) =>
    '{ search(first: $length, type: DISCUSSION, query: "repo:$owner/$repo ${queryEncode(query)}", after: ${endCur == null ? null : '"$endCur"'}) { pageInfo { endCursor hasNextPage } nodes { ... on Discussion { number updatedAt } } } }';

String getUserInfo(String login) =>
    '{ user(login: "$login") { repositories { totalCount }, name } }';

String getSelfUserInfo() => '{ viewer { avatarUrl login } }';

String getPinnedDiscussions(String? endCur) =>
    '{ repository(owner: "$owner", name: "$repo") { pinnedDiscussions(first: 100, after: ${endCur == null ? null : '"$endCur"'}) { pageInfo { endCursor hasNextPage } nodes { discussion { number updatedAt } } } } }';

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
