part of 'api_user.dart';

Future<Response<Map<String, dynamic>>> addDiscussionComment(
        String discussionId, String body) =>
    graphql(
        'mutation { addDiscussionComment(input: { discussionId: "$discussionId", body: "${encode(body)}" }) { clientMutationId } }');
