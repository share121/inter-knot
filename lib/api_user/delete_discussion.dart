part of 'api_user.dart';

Future<Response<Map<String, dynamic>>> deleteDiscussion(String id) => graphql(
    'mutation { deleteDiscussion(input: { id: "$id" }) { clientMutationId } }');
